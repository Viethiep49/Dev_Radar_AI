import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show TimeOfDay;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

/// SharedPreferences keys of the notification settings (read/written through StorageService).
class NotificationPrefKeys {
  NotificationPrefKeys._();

  static const String releaseAlertsEnabled = 'notif_release_alerts_enabled';
  static const String reminderEnabled = 'notif_reminder_enabled';

  /// Reminder time as minutes after midnight (e.g. 20:00 -> 1200).
  static const String reminderMinutes = 'notif_reminder_minutes';

  /// Id of the newest backend notification already shown as a local notification.
  static const String lastShownNotificationId = 'notif_last_shown_id';

  static const int defaultReminderMinutes = 20 * 60;
}

/// Local notifications (flutter_local_notifications):
/// - a daily study reminder at a time the user picks (zonedSchedule, repeats every day),
/// - "new release" alerts raised by ReleaseAlertService from the backend notifications.
///
/// Everything is a no-op on web and other unsupported platforms.
class LocalNotificationService {
  static const int dailyReminderId = 1;

  /// Backend notification ids are offset so they never clash with [dailyReminderId].
  static const int releaseIdOffset = 1000;

  static const String _reminderChannelId = 'study_reminder';
  static const String _releaseChannelId = 'repo_releases';
  static const String _repoPayloadPrefix = 'repo:';

  final FlutterLocalNotificationsPlugin _plugin;
  final _repoTapController = StreamController<int?>.broadcast();
  bool _initialized = false;
  int? _launchRepoId;

  LocalNotificationService({FlutterLocalNotificationsPlugin? plugin})
      : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  /// Repo id of a tapped notification (null for the study reminder: open the app home).
  Stream<int?> get onRepoTapped => _repoTapController.stream;

  bool get isSupported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS);

  Future<void> init() async {
    if (_initialized || !isSupported) return;
    await _initTimeZone();
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        // Permission is asked later, when the user turns a notification on.
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      ),
      onDidReceiveNotificationResponse: (response) => _repoTapController.add(_repoIdFrom(response.payload)),
    );
    _initialized = true;

    // App started by tapping a notification: keep the repo id for the first screen.
    final launch = await _plugin.getNotificationAppLaunchDetails();
    if (launch?.didNotificationLaunchApp ?? false) {
      _launchRepoId = _repoIdFrom(launch?.notificationResponse?.payload);
    }
  }

  /// Repo id of the notification that launched the app (returned once).
  int? takeLaunchRepoId() {
    final id = _launchRepoId;
    _launchRepoId = null;
    return id;
  }

  Future<void> _initTimeZone() async {
    tz_data.initializeTimeZones();
    try {
      final info = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(info.identifier));
    } catch (_) {
      // Unknown zone name: fall back to Vietnam time (the app's audience).
      tz.setLocalLocation(tz.getLocation('Asia/Ho_Chi_Minh'));
    }
  }

  /// Asks the OS for permission to show notifications (Android 13+, iOS). True if granted.
  Future<bool> requestPermission() async {
    if (!isSupported) return false;
    await init();
    if (defaultTargetPlatform == TargetPlatform.android) {
      final android =
          _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      return await android?.requestNotificationsPermission() ?? true;
    }
    final ios = _plugin.resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();
    return await ios?.requestPermissions(alert: true, badge: true, sound: true) ?? false;
  }

  /// Shows the study reminder every day at [time] (replaces the previous schedule).
  Future<void> scheduleDailyReminder(TimeOfDay time) async {
    if (!isSupported) return;
    await init();
    await _plugin.cancel(id: dailyReminderId);
    await _plugin.zonedSchedule(
      id: dailyReminderId,
      title: 'Đến giờ học rồi! 📚',
      body: "Hôm nay bạn đã xem repo nào trong 'Đang tìm hiểu' chưa? Mở DevRadar để tiếp tục lộ trình nhé.",
      scheduledDate: nextInstanceOf(time, tz.TZDateTime.now(tz.local)),
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          _reminderChannelId,
          'Nhắc học hằng ngày',
          channelDescription: 'Nhắc bạn tiếp tục lộ trình tìm hiểu repo',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      // Inexact: no SCHEDULE_EXACT_ALARM permission needed; a few minutes late is fine.
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  Future<void> cancelDailyReminder() async {
    if (!isSupported) return;
    await init();
    await _plugin.cancel(id: dailyReminderId);
  }

  /// Shows a "new release" notification. [id] is the backend notification id.
  Future<void> showReleaseNotification({
    required int id,
    required String title,
    String? body,
    int? repoId,
  }) async {
    if (!isSupported) return;
    await init();
    await _plugin.show(
      id: releaseIdOffset + id,
      title: title,
      body: body,
      payload: repoId == null ? null : '$_repoPayloadPrefix$repoId',
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          _releaseChannelId,
          'Phiên bản mới',
          channelDescription: 'Repo bạn theo dõi có release mới',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
    );
  }

  /// Next date-time at [time] that is after [now] (today if still ahead, else tomorrow).
  @visibleForTesting
  static tz.TZDateTime nextInstanceOf(TimeOfDay time, tz.TZDateTime now) {
    var scheduled = tz.TZDateTime(now.location, now.year, now.month, now.day, time.hour, time.minute);
    if (!scheduled.isAfter(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
  }

  static int? _repoIdFrom(String? payload) {
    if (payload == null || !payload.startsWith(_repoPayloadPrefix)) return null;
    return int.tryParse(payload.substring(_repoPayloadPrefix.length));
  }

  void dispose() => _repoTapController.close();
}
