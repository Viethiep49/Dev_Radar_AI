import '../../core/notifications/local_notification_service.dart';
import '../../core/utils/storage_service.dart';
import '../repositories/notification_repository.dart';

/// Turns new backend notifications (e.g. "flutter/flutter released 3.30.0") into
/// local phone notifications. Called when the app starts / comes back to the foreground.
///
/// Push via FCM needs Firebase keys that are not configured yet; this gives the
/// same result while the app is used regularly.
class ReleaseAlertService {
  final NotificationRepository notificationRepository;
  final LocalNotificationService localNotifications;
  final StorageService storage;

  /// Avoids a burst of notifications after a long time offline.
  static const int maxAlertsPerCheck = 5;

  ReleaseAlertService({
    required this.notificationRepository,
    required this.localNotifications,
    required this.storage,
  });

  /// Shows a local notification for every unread backend notification newer than
  /// the last one shown. Returns how many were shown. Never throws (best effort).
  Future<int> checkForNewReleases() async {
    try {
      final enabled = await storage.getBool(NotificationPrefKeys.releaseAlertsEnabled) ?? true;
      if (!enabled) return 0;

      final lastShownId = await storage.getInt(NotificationPrefKeys.lastShownNotificationId);
      final unread = await notificationRepository.getUnread();
      if (unread.isEmpty) return 0;

      final newestId = unread.map((n) => n.id).reduce((a, b) => a > b ? a : b);
      if (lastShownId == null) {
        // First run: remember where we are instead of replaying old notifications.
        await storage.setInt(NotificationPrefKeys.lastShownNotificationId, newestId);
        return 0;
      }

      final fresh = unread.where((n) => n.id > lastShownId).toList()
        ..sort((a, b) => a.id.compareTo(b.id));
      final toShow = fresh.length > maxAlertsPerCheck ? fresh.sublist(fresh.length - maxAlertsPerCheck) : fresh;
      for (final notification in toShow) {
        await localNotifications.showReleaseNotification(
          id: notification.id,
          title: notification.title,
          body: notification.body,
          repoId: notification.repoId,
        );
      }
      if (fresh.isNotEmpty) {
        await storage.setInt(NotificationPrefKeys.lastShownNotificationId, newestId);
      }
      return toShow.length;
    } catch (_) {
      return 0; // offline or not logged in: try again next time
    }
  }
}
