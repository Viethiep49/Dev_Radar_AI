import 'package:bloc_test/bloc_test.dart';
import 'package:dev_radar_ai/core/network/api_exceptions.dart';
import 'package:dev_radar_ai/core/notifications/local_notification_service.dart';
import 'package:dev_radar_ai/data/datasources/local/cache_local_datasource.dart';
import 'package:dev_radar_ai/data/datasources/remote/notification_remote_datasource.dart';
import 'package:dev_radar_ai/data/models/notification_model.dart';
import 'package:dev_radar_ai/data/repositories/cache_policy.dart';
import 'package:dev_radar_ai/data/repositories/notification_repository.dart';
import 'package:dev_radar_ai/data/services/release_alert_service.dart';
import 'package:dev_radar_ai/presentation/state/notifications/notifications_cubit.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show TimeOfDay;
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../settings/fakes.dart';

class MockNotificationRemote extends Mock implements NotificationRemoteDataSource {}

class MockNotificationRepository extends Mock implements NotificationRepository {}

Map<String, dynamic> notificationJson(int id, {bool isRead = false, int? repoId = 7}) => {
      'id': id,
      'type': 'release',
      'title': 'owner/repo v$id',
      'body': 'Phiên bản mới',
      'repo_id': repoId,
      'data': {'tag_name': 'v$id', 'html_url': 'https://github.com/owner/repo'},
      'is_read': isRead,
      'created_at': '2026-10-01T10:00:00Z',
    };

NotificationModel notification(int id, {bool isRead = false}) =>
    NotificationModel.fromJson(notificationJson(id, isRead: isRead));

Map<String, dynamic> page(List<Map<String, dynamic>> items, {int page = 1, int total = -1}) =>
    {'items': items, 'page': page, 'limit': 100, 'total': total < 0 ? items.length : total};

void main() {
  group('NotificationModel', () {
    test('parses the release tag', () {
      final n = notification(3);
      expect(n.releaseTag, 'v3');
      expect(n.repoId, 7);
      expect(n.copyWith(isRead: true).isRead, isTrue);
    });
  });

  group('NotificationRepositoryImpl', () {
    late MockNotificationRemote remote;
    late MemoryCacheLocalDataSource cache;
    late NotificationRepositoryImpl repository;

    setUp(() {
      remote = MockNotificationRemote();
      cache = MemoryCacheLocalDataSource();
      repository = NotificationRepositoryImpl(remoteDataSource: remote, cache: cache);
    });

    test('loads every page', () async {
      when(() => remote.getNotificationsPage(unreadOnly: false, page: 1)).thenAnswer(
        (_) async => {'items': [notificationJson(2)], 'page': 1, 'limit': 1, 'total': 2},
      );
      when(() => remote.getNotificationsPage(unreadOnly: false, page: 2)).thenAnswer(
        (_) async => {'items': [notificationJson(1)], 'page': 2, 'limit': 1, 'total': 2},
      );

      final result = await repository.getNotifications();

      expect(result.data.map((n) => n.id), [2, 1]);
    });

    test('shows cached notifications when offline', () async {
      await cache.put(NotificationRepositoryImpl.listKey, page([notificationJson(5)]));
      when(() => remote.getNotificationsPage(unreadOnly: false, page: 1)).thenThrow(NetworkException());

      final result = await repository.getNotifications();

      expect(result.fromCache, isTrue);
      expect(result.data.single.id, 5);
    });

    test('markRead clears the cached list', () async {
      await cache.put(NotificationRepositoryImpl.listKey, page([notificationJson(5)]));
      when(() => remote.markRead(5)).thenAnswer((_) async {});

      await repository.markRead(5);

      expect(await cache.get(NotificationRepositoryImpl.listKey), isNull);
    });

    test('getUnread asks only for unread notifications', () async {
      when(() => remote.getNotificationsPage(unreadOnly: true, page: 1))
          .thenAnswer((_) async => page([notificationJson(9)]));
      final unread = await repository.getUnread();
      expect(unread.single.id, 9);
    });
  });

  group('NotificationsCubit', () {
    late MockNotificationRepository repository;

    setUp(() => repository = MockNotificationRepository());

    blocTest<NotificationsCubit, NotificationsState>(
      'load emits loading then the list',
      build: () {
        when(() => repository.getNotifications()).thenAnswer((_) async => Cached([notification(1)]));
        return NotificationsCubit(repository);
      },
      act: (cubit) => cubit.load(),
      expect: () => [
        const NotificationsState(status: NotificationsStatus.loading),
        NotificationsState(status: NotificationsStatus.loaded, items: [notification(1)]),
      ],
    );

    blocTest<NotificationsCubit, NotificationsState>(
      'markRead is optimistic',
      build: () {
        when(() => repository.markRead(1)).thenAnswer((_) async {});
        return NotificationsCubit(repository);
      },
      seed: () => NotificationsState(status: NotificationsStatus.loaded, items: [notification(1), notification(2)]),
      act: (cubit) => cubit.markRead(1),
      expect: () => [
        NotificationsState(
          status: NotificationsStatus.loaded,
          items: [notification(1, isRead: true), notification(2)],
        ),
      ],
    );

    blocTest<NotificationsCubit, NotificationsState>(
      'delete is reverted with an action error when the call fails',
      build: () {
        when(() => repository.delete(1)).thenThrow(ApiException('Lỗi server', statusCode: 500));
        return NotificationsCubit(repository);
      },
      seed: () => NotificationsState(status: NotificationsStatus.loaded, items: [notification(1)]),
      act: (cubit) => cubit.delete(1),
      expect: () => [
        const NotificationsState(status: NotificationsStatus.loaded, items: []),
        NotificationsState(status: NotificationsStatus.loaded, items: [notification(1)], actionError: 'Lỗi server'),
      ],
    );

    blocTest<NotificationsCubit, NotificationsState>(
      'markAllRead marks everything read',
      build: () {
        when(() => repository.markAllRead()).thenAnswer((_) async {});
        return NotificationsCubit(repository);
      },
      seed: () => NotificationsState(status: NotificationsStatus.loaded, items: [notification(1), notification(2)]),
      act: (cubit) => cubit.markAllRead(),
      verify: (cubit) => expect(cubit.state.unreadCount, 0),
    );

    blocTest<UnreadCountCubit, int>(
      'UnreadCountCubit keeps its value on errors',
      build: () {
        when(() => repository.getUnreadCount()).thenThrow(NetworkException());
        return UnreadCountCubit(repository);
      },
      seed: () => 3,
      act: (cubit) => cubit.refresh(),
      expect: () => <int>[],
    );
  });

  group('ReleaseAlertService', () {
    late MockNotificationRepository repository;
    late MockLocalNotificationService local;
    late MemoryStorage storage;
    late ReleaseAlertService service;

    setUp(() {
      repository = MockNotificationRepository();
      local = MockLocalNotificationService();
      storage = MemoryStorage();
      service = ReleaseAlertService(notificationRepository: repository, localNotifications: local, storage: storage);
      when(() => local.showReleaseNotification(
            id: any(named: 'id'),
            title: any(named: 'title'),
            body: any(named: 'body'),
            repoId: any(named: 'repoId'),
          )).thenAnswer((_) async {});
    });

    test('first run only remembers the newest id', () async {
      when(() => repository.getUnread()).thenAnswer((_) async => [notification(4), notification(2)]);

      expect(await service.checkForNewReleases(), 0);
      expect(storage.values[NotificationPrefKeys.lastShownNotificationId], 4);
      verifyNever(() => local.showReleaseNotification(id: any(named: 'id'), title: any(named: 'title')));
    });

    test('shows only notifications newer than the last shown one', () async {
      storage.values[NotificationPrefKeys.lastShownNotificationId] = 4;
      when(() => repository.getUnread()).thenAnswer((_) async => [notification(6), notification(5), notification(3)]);

      expect(await service.checkForNewReleases(), 2);
      verify(() => local.showReleaseNotification(id: 5, title: 'owner/repo v5', body: 'Phiên bản mới', repoId: 7))
          .called(1);
      verify(() => local.showReleaseNotification(id: 6, title: 'owner/repo v6', body: 'Phiên bản mới', repoId: 7))
          .called(1);
      expect(storage.values[NotificationPrefKeys.lastShownNotificationId], 6);
    });

    test('does nothing when release alerts are turned off', () async {
      storage.values[NotificationPrefKeys.releaseAlertsEnabled] = false;
      expect(await service.checkForNewReleases(), 0);
      verifyNever(() => repository.getUnread());
    });

    test('never throws when offline', () async {
      storage.values[NotificationPrefKeys.lastShownNotificationId] = 1;
      when(() => repository.getUnread()).thenThrow(NetworkException());
      expect(await service.checkForNewReleases(), 0);
    });
  });

  group('LocalNotificationService.nextInstanceOf', () {
    setUpAll(tz_data.initializeTimeZones);

    test('today when the time is still ahead, otherwise tomorrow', () {
      final location = tz.getLocation('Asia/Ho_Chi_Minh');
      final now = tz.TZDateTime(location, 2026, 10, 8, 18, 30);

      final later = LocalNotificationService.nextInstanceOf(const TimeOfDay(hour: 20, minute: 0), now);
      final earlier = LocalNotificationService.nextInstanceOf(const TimeOfDay(hour: 7, minute: 15), now);

      expect(later, tz.TZDateTime(location, 2026, 10, 8, 20, 0));
      expect(earlier, tz.TZDateTime(location, 2026, 10, 9, 7, 15));
    });

    test('is a no-op on unsupported platforms', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.linux;
      try {
        final service = LocalNotificationService();
        expect(service.isSupported, isFalse);
        await service.init();
        await service.scheduleDailyReminder(const TimeOfDay(hour: 20, minute: 0));
        expect(await service.requestPermission(), isFalse);
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });
  });
}
