import 'package:bloc_test/bloc_test.dart';
import 'package:dev_radar_ai/core/network/api_exceptions.dart';
import 'package:dev_radar_ai/core/notifications/local_notification_service.dart';
import 'package:dev_radar_ai/data/datasources/local/cache_local_datasource.dart';
import 'package:dev_radar_ai/data/models/user_model.dart';
import 'package:dev_radar_ai/data/repositories/auth_repository.dart';
import 'package:dev_radar_ai/presentation/state/settings/change_password_cubit.dart';
import 'package:dev_radar_ai/presentation/state/settings/profile_cubit.dart';
import 'package:dev_radar_ai/presentation/state/settings/settings_cubit.dart';
import 'package:flutter/material.dart' show TimeOfDay;
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'fakes.dart';

class MockAuthRepository extends Mock implements AuthRepository {}

void main() {
  setUpAll(() => registerFallbackValue(const TimeOfDay(hour: 0, minute: 0)));

  group('SettingsCubit', () {
    late MemoryStorage storage;
    late MockLocalNotificationService notifications;
    late MemoryCacheLocalDataSource cache;

    SettingsCubit build() => SettingsCubit(storage: storage, notifications: notifications, cache: cache);

    setUp(() {
      storage = MemoryStorage();
      notifications = MockLocalNotificationService();
      cache = MemoryCacheLocalDataSource();
      when(() => notifications.isSupported).thenReturn(true);
      when(() => notifications.requestPermission()).thenAnswer((_) async => true);
      when(() => notifications.scheduleDailyReminder(any())).thenAnswer((_) async {});
      when(() => notifications.cancelDailyReminder()).thenAnswer((_) async {});
    });

    test('load reads saved settings and the cache size', () async {
      storage.values[NotificationPrefKeys.reminderEnabled] = true;
      storage.values[NotificationPrefKeys.reminderMinutes] = 7 * 60 + 30;
      await cache.put('a', {'x': 1});
      final cubit = build();

      await cubit.load();

      expect(cubit.state.loaded, isTrue);
      expect(cubit.state.releaseAlertsEnabled, isTrue); // default on
      expect(cubit.state.reminderEnabled, isTrue);
      expect(cubit.state.reminderTime, const TimeOfDay(hour: 7, minute: 30));
      expect(cubit.state.cacheCount, 1);
    });

    test('enabling the reminder schedules it and saves the switch', () async {
      final cubit = build();
      await cubit.load();

      await cubit.setReminderEnabled(true);

      verify(() => notifications.scheduleDailyReminder(const TimeOfDay(hour: 20, minute: 0))).called(1);
      expect(storage.values[NotificationPrefKeys.reminderEnabled], isTrue);
      expect(cubit.state.reminderEnabled, isTrue);
    });

    test('reminder stays off when permission is denied', () async {
      when(() => notifications.requestPermission()).thenAnswer((_) async => false);
      final cubit = build();
      await cubit.load();

      await cubit.setReminderEnabled(true);

      verifyNever(() => notifications.scheduleDailyReminder(any()));
      expect(cubit.state.reminderEnabled, isFalse);
      expect(cubit.state.errorMessage, isNotNull);
    });

    test('changing the time reschedules an active reminder', () async {
      storage.values[NotificationPrefKeys.reminderEnabled] = true;
      final cubit = build();
      await cubit.load();

      await cubit.setReminderTime(const TimeOfDay(hour: 6, minute: 5));

      verify(() => notifications.scheduleDailyReminder(const TimeOfDay(hour: 6, minute: 5))).called(1);
      expect(storage.values[NotificationPrefKeys.reminderMinutes], 365);
    });

    test('disabling the reminder cancels it', () async {
      storage.values[NotificationPrefKeys.reminderEnabled] = true;
      final cubit = build();
      await cubit.load();

      await cubit.setReminderEnabled(false);

      verify(() => notifications.cancelDailyReminder()).called(1);
      expect(storage.values[NotificationPrefKeys.reminderEnabled], isFalse);
    });

    test('clearCache empties the SQLite cache', () async {
      await cache.put('feed:page=1', {'items': []});
      final cubit = build();
      await cubit.load();

      await cubit.clearCache();

      expect(await cache.count(), 0);
      expect(cubit.state.cacheCount, 0);
      expect(cubit.state.message, 'Đã xoá dữ liệu cache');
    });

    test('release alerts switch is saved', () async {
      final cubit = build();
      await cubit.setReleaseAlerts(false);
      expect(storage.values[NotificationPrefKeys.releaseAlertsEnabled], isFalse);
      expect(cubit.state.releaseAlertsEnabled, isFalse);
    });
  });

  group('ChangePasswordCubit', () {
    late MockAuthRepository auth;

    setUp(() => auth = MockAuthRepository());

    test('validate', () {
      expect(ChangePasswordCubit.validate(newPassword: '', confirmPassword: ''), isNotNull);
      expect(ChangePasswordCubit.validate(newPassword: '123', confirmPassword: '123'), isNotNull);
      expect(ChangePasswordCubit.validate(newPassword: 'secret1', confirmPassword: 'secret2'), isNotNull);
      expect(ChangePasswordCubit.validate(newPassword: 'secret1', confirmPassword: 'secret1'), isNull);
    });

    blocTest<ChangePasswordCubit, ChangePasswordState>(
      'invalid input fails without calling the API',
      build: () => ChangePasswordCubit(auth),
      act: (cubit) => cubit.submit(oldPassword: 'old', newPassword: 'abc', confirmPassword: 'abc'),
      expect: () => [
        const ChangePasswordState(
          status: ChangePasswordStatus.failure,
          errorMessage: 'Mật khẩu mới phải từ 6 ký tự trở lên',
        ),
      ],
      verify: (_) => verifyNever(() => auth.changePassword(any(), any())),
    );

    blocTest<ChangePasswordCubit, ChangePasswordState>(
      'success',
      build: () {
        when(() => auth.changePassword('old', 'secret1')).thenAnswer((_) async {});
        return ChangePasswordCubit(auth);
      },
      act: (cubit) => cubit.submit(oldPassword: 'old', newPassword: 'secret1', confirmPassword: 'secret1'),
      expect: () => [
        const ChangePasswordState(status: ChangePasswordStatus.submitting),
        const ChangePasswordState(status: ChangePasswordStatus.success),
      ],
    );

    blocTest<ChangePasswordCubit, ChangePasswordState>(
      'shows the backend message on a wrong old password',
      build: () {
        when(() => auth.changePassword(any(), any()))
            .thenThrow(ApiException('Mật khẩu hiện tại không chính xác', statusCode: 400));
        return ChangePasswordCubit(auth);
      },
      act: (cubit) => cubit.submit(oldPassword: 'x', newPassword: 'secret1', confirmPassword: 'secret1'),
      expect: () => [
        const ChangePasswordState(status: ChangePasswordStatus.submitting),
        const ChangePasswordState(
          status: ChangePasswordStatus.failure,
          errorMessage: 'Mật khẩu hiện tại không chính xác',
        ),
      ],
    );
  });

  group('ProfileCubit', () {
    late MockAuthRepository auth;
    const user = UserModel(id: 1, email: 'a@b.c', displayName: 'A', avatarUrl: 'https://github.com/torvalds.png');

    setUp(() => auth = MockAuthRepository());

    test('selectGithubAvatar builds the GitHub avatar URL', () {
      final cubit = ProfileCubit(auth)..selectGithubAvatar(' @torvalds ');
      expect(cubit.state.pendingAvatarUrl, 'https://github.com/torvalds.png');
    });

    blocTest<ProfileCubit, ProfileState>(
      'saveAvatar returns the updated user once',
      build: () {
        when(() => auth.updateAvatar('https://github.com/torvalds.png')).thenAnswer((_) async => user);
        return ProfileCubit(auth);
      },
      act: (cubit) async {
        cubit.selectGithubAvatar('torvalds');
        await cubit.saveAvatar('https://fallback');
      },
      expect: () => [
        const ProfileState(pendingAvatarUrl: 'https://github.com/torvalds.png'),
        const ProfileState(pendingAvatarUrl: 'https://github.com/torvalds.png', isSaving: true),
        const ProfileState(pendingAvatarUrl: 'https://github.com/torvalds.png', savedUser: user),
      ],
    );

    blocTest<ProfileCubit, ProfileState>(
      'saveAvatar error',
      build: () {
        when(() => auth.updateAvatar(any())).thenThrow(ApiException('avatar_url must be an http(s) URL'));
        return ProfileCubit(auth);
      },
      act: (cubit) => cubit.saveAvatar('ftp://x'),
      expect: () => [
        const ProfileState(isSaving: true),
        const ProfileState(errorMessage: 'avatar_url must be an http(s) URL'),
      ],
    );
  });
}
