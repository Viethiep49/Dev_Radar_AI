import '../../../core/constants/api_constants.dart';
import '../../../core/network/api_client.dart';

/// Raw JSON calls for /collections. The repository parses and caches.
abstract class CollectionRemoteDataSource {
  /// One page: {"items", "page", "limit", "total"}.
  Future<Map<String, dynamic>> getCollectionsPage({String? query, int page = 1, int limit = 100});
  Future<Map<String, dynamic>> getCollection(int id);
  Future<Map<String, dynamic>> createCollection({required String name, String? description});
  Future<Map<String, dynamic>> updateCollection(int id, {required String name, String? description});
  Future<void> deleteCollection(int id);
  Future<void> addRepo(int collectionId, int repoId);
  Future<void> removeRepo(int collectionId, int repoId);
}

class CollectionRemoteDataSourceImpl implements CollectionRemoteDataSource {
  final ApiClient apiClient;

  CollectionRemoteDataSourceImpl({required this.apiClient});

  @override
  Future<Map<String, dynamic>> getCollectionsPage({String? query, int page = 1, int limit = 100}) async {
    final response = await apiClient.get(
      ApiConstants.collections,
      queryParameters: {
        if (query != null && query.trim().isNotEmpty) 'q': query.trim(),
        'page': page,
        'limit': limit,
      },
    );
    return response.data as Map<String, dynamic>;
  }

  @override
  Future<Map<String, dynamic>> getCollection(int id) async {
    final response = await apiClient.get('${ApiConstants.collections}/$id');
    return response.data as Map<String, dynamic>;
  }

  @override
  Future<Map<String, dynamic>> createCollection({required String name, String? description}) async {
    final response = await apiClient.post(
      ApiConstants.collections,
      data: {'name': name, 'description': description},
    );
    return response.data as Map<String, dynamic>;
  }

  @override
  Future<Map<String, dynamic>> updateCollection(int id, {required String name, String? description}) async {
    final response = await apiClient.patch(
      '${ApiConstants.collections}/$id',
      data: {'name': name, 'description': description},
    );
    return response.data as Map<String, dynamic>;
  }

  @override
  Future<void> deleteCollection(int id) async {
    await apiClient.delete('${ApiConstants.collections}/$id');
  }

  @override
  Future<void> addRepo(int collectionId, int repoId) async {
    await apiClient.post('${ApiConstants.collections}/$collectionId/items', data: {'repo_id': repoId});
  }

  @override
  Future<void> removeRepo(int collectionId, int repoId) async {
    await apiClient.delete('${ApiConstants.collections}/$collectionId/items/$repoId');
  }
}
