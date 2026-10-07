import '../../../core/constants/api_constants.dart';
import '../../../core/network/api_client.dart';

/// Raw JSON from the /notifications endpoints.
abstract class NotificationRemoteDataSource {
  /// One page: {"items", "page", "limit", "total"}, newest first.
  Future<Map<String, dynamic>> getNotificationsPage({bool unreadOnly = false, int page = 1, int limit = 100});
  Future<int> getUnreadCount();
  Future<void> markRead(int id);
  Future<int> markAllRead();
  Future<void> delete(int id);
}

class NotificationRemoteDataSourceImpl implements NotificationRemoteDataSource {
  final ApiClient apiClient;

  NotificationRemoteDataSourceImpl({required this.apiClient});

  @override
  Future<Map<String, dynamic>> getNotificationsPage({bool unreadOnly = false, int page = 1, int limit = 100}) async {
    final response = await apiClient.get(
      ApiConstants.notifications,
      queryParameters: {'unread_only': unreadOnly, 'page': page, 'limit': limit},
    );
    return response.data as Map<String, dynamic>;
  }

  @override
  Future<int> getUnreadCount() async {
    final response = await apiClient.get(ApiConstants.notificationsUnreadCount);
    return (response.data as Map<String, dynamic>)['count'] as int? ?? 0;
  }

  @override
  Future<void> markRead(int id) async {
    await apiClient.patch('${ApiConstants.notifications}/$id/read');
  }

  @override
  Future<int> markAllRead() async {
    final response = await apiClient.post(ApiConstants.notificationsReadAll);
    return (response.data as Map<String, dynamic>)['updated'] as int? ?? 0;
  }

  @override
  Future<void> delete(int id) async {
    await apiClient.delete('${ApiConstants.notifications}/$id');
  }
}
