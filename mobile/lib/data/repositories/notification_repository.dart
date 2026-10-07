import '../datasources/local/cache_local_datasource.dart';
import '../datasources/remote/notification_remote_datasource.dart';
import '../models/notification_model.dart';
import '../models/page_model.dart';
import 'cache_policy.dart';

/// Notifications saved by the backend (new releases of watched repos...).
abstract class NotificationRepository {
  /// All notifications, newest first. Cached for offline use.
  Future<Cached<List<NotificationModel>>> getNotifications();

  /// Unread notifications only (not cached; used to raise local notifications).
  Future<List<NotificationModel>> getUnread();

  Future<int> getUnreadCount();

  Future<void> markRead(int id);

  Future<void> markAllRead();

  Future<void> delete(int id);
}

class NotificationRepositoryImpl implements NotificationRepository {
  static const String listKey = 'notifications';

  /// Safety cap: at most this many pages (x100) are loaded.
  static const int maxPages = 5;

  final NotificationRemoteDataSource remoteDataSource;
  final CacheLocalDataSource cache;

  NotificationRepositoryImpl({required this.remoteDataSource, required this.cache});

  Future<Map<String, dynamic>> _fetchAll({bool unreadOnly = false}) async {
    final items = <dynamic>[];
    for (var page = 1; page <= maxPages; page++) {
      final json = await remoteDataSource.getNotificationsPage(unreadOnly: unreadOnly, page: page);
      final pageModel = PageModel.fromJson(json, (item) => item);
      items.addAll(pageModel.items);
      if (!pageModel.hasMore || pageModel.items.isEmpty) break;
    }
    return {'items': items};
  }

  static List<NotificationModel> _parseList(dynamic json) =>
      ((json as Map<String, dynamic>)['items'] as List<dynamic>)
          .map((e) => NotificationModel.fromJson(e as Map<String, dynamic>))
          .toList();

  @override
  Future<Cached<List<NotificationModel>>> getNotifications() {
    return fetchWithCache(cache: cache, key: listKey, fetch: _fetchAll, parse: _parseList);
  }

  @override
  Future<List<NotificationModel>> getUnread() async => _parseList(await _fetchAll(unreadOnly: true));

  @override
  Future<int> getUnreadCount() => remoteDataSource.getUnreadCount();

  @override
  Future<void> markRead(int id) async {
    await remoteDataSource.markRead(id);
    await cache.remove(listKey);
  }

  @override
  Future<void> markAllRead() async {
    await remoteDataSource.markAllRead();
    await cache.remove(listKey);
  }

  @override
  Future<void> delete(int id) async {
    await remoteDataSource.delete(id);
    await cache.remove(listKey);
  }
}
