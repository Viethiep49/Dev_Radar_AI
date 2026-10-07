import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart' show TimeOfDay;
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/notifications/local_notification_service.dart';
import '../../../core/utils/storage_service.dart';
import '../../../data/datasources/local/cache_local_datasource.dart';

class SettingsState extends Equatable {
  final bool loaded;
  final bool releaseAlertsEnabled;
  final bool reminderEnabled;
  final TimeOfDay reminderTime;
  final int cacheCount;
  final bool isClearingCache;

  /// One-shot messages for a snackbar.
  final String? message;
  final String? errorMessage;

  const SettingsState({
    this.loaded = false,
    this.releaseAlertsEnabled = true,
    this.reminderEnabled = false,
    this.reminderTime = const TimeOfDay(hour: 20, minute: 0),
    this.cacheCount = 0,
    this.isClearingCache = false,
    this.message,
    this.errorMessage,
  });

  SettingsState copyWith({
    bool? loaded,
    bool? releaseAlertsEnabled,
    bool? reminderEnabled,
    TimeOfDay? reminderTime,
    int? cacheCount,
    bool? isClearingCache,
    String? message,
    String? errorMessage,
  }) {
    return SettingsState(
      loaded: loaded ?? this.loaded,
      releaseAlertsEnabled: releaseAlertsEnabled ?? this.releaseAlertsEnabled,
      reminderEnabled: reminderEnabled ?? this.reminderEnabled,
      reminderTime: reminderTime ?? this.reminderTime,
      cacheCount: cacheCount ?? this.cacheCount,
      isClearingCache: isClearingCache ?? this.isClearingCache,
      message: message,
      errorMessage: errorMessage,
    );
  }

  @override
  List<Object?> get props => [
        loaded,
        releaseAlertsEnabled,
        reminderEnabled,
        reminderTime,
        cacheCount,
        isClearingCache,
        message,
        errorMessage,
      ];
}

/// Notification switches, study reminder time and the SQLite cache (Settings tab).
class SettingsCubit extends Cubit<SettingsState> {
  final StorageService storage;
  final LocalNotificationService notifications;
  final CacheLocalDataSource cache;

  SettingsCubit({required this.storage, required this.notifications, required this.cache})
      : super(const SettingsState());

  Future<void> load() async {
    final minutes =
        await storage.getInt(NotificationPrefKeys.reminderMinutes) ?? NotificationPrefKeys.defaultReminderMinutes;
    emit(state.copyWith(
      loaded: true,
      releaseAlertsEnabled: await storage.getBool(NotificationPrefKeys.releaseAlertsEnabled) ?? true,
      reminderEnabled: await storage.getBool(NotificationPrefKeys.reminderEnabled) ?? false,
      reminderTime: TimeOfDay(hour: minutes ~/ 60, minute: minutes % 60),
      cacheCount: await cache.count(),
    ));
  }

  Future<void> setReleaseAlerts(bool enabled) async {
    if (enabled) {
      await notifications.requestPermission();
    }
    await storage.setBool(NotificationPrefKeys.releaseAlertsEnabled, enabled);
    emit(state.copyWith(releaseAlertsEnabled: enabled));
  }

  Future<void> setReminderEnabled(bool enabled) async {
    try {
      if (enabled) {
        final granted = await notifications.requestPermission();
        if (!granted && notifications.isSupported) {
          emit(state.copyWith(errorMessage: 'Bạn cần cho phép thông báo trong cài đặt của máy'));
          return;
        }
        await notifications.scheduleDailyReminder(state.reminderTime);
      } else {
        await notifications.cancelDailyReminder();
      }
      await storage.setBool(NotificationPrefKeys.reminderEnabled, enabled);
      emit(state.copyWith(
        reminderEnabled: enabled,
        message: enabled ? 'Sẽ nhắc học lúc ${_format(state.reminderTime)} mỗi ngày' : null,
      ));
    } catch (e) {
      emit(state.copyWith(errorMessage: 'Không đặt được lịch nhắc: $e'));
    }
  }

  Future<void> setReminderTime(TimeOfDay time) async {
    await storage.setInt(NotificationPrefKeys.reminderMinutes, time.hour * 60 + time.minute);
    emit(state.copyWith(reminderTime: time));
    if (state.reminderEnabled) {
      try {
        await notifications.scheduleDailyReminder(time);
        emit(state.copyWith(message: 'Đã đổi giờ nhắc học thành ${_format(time)}'));
      } catch (e) {
        emit(state.copyWith(errorMessage: 'Không đặt được lịch nhắc: $e'));
      }
    }
  }

  Future<void> clearCache() async {
    emit(state.copyWith(isClearingCache: true));
    try {
      await cache.clear();
      emit(state.copyWith(isClearingCache: false, cacheCount: await cache.count(), message: 'Đã xoá dữ liệu cache'));
    } catch (e) {
      emit(state.copyWith(isClearingCache: false, errorMessage: 'Không xoá được cache: $e'));
    }
  }

  static String _format(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
}
