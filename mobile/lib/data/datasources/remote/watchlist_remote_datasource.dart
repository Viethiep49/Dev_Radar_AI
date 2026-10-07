import '../../../core/constants/api_constants.dart';
import '../../../core/network/api_client.dart';

/// Raw JSON from the /watchlist endpoints.
abstract class WatchlistRemoteDataSource {
  Future<Map<String, dynamic>> getWatchlistPage({int page = 1, int limit = 100});
  Future<void> watch(int repoId);
  Future<void> unwatch(int repoId);
}

class WatchlistRemoteDataSourceImpl implements WatchlistRemoteDataSource {
  final ApiClient apiClient;

  WatchlistRemoteDataSourceImpl({required this.apiClient});

  @override
  Future<Map<String, dynamic>> getWatchlistPage({int page = 1, int limit = 100}) async {
    final response = await apiClient.get(
      ApiConstants.watchlist,
      queryParameters: {'page': page, 'limit': limit},
    );
    return response.data as Map<String, dynamic>;
  }

  @override
  Future<void> watch(int repoId) async {
    await apiClient.post('${ApiConstants.watchlist}/$repoId');
  }

  @override
  Future<void> unwatch(int repoId) async {
    await apiClient.delete('${ApiConstants.watchlist}/$repoId');
  }
}
