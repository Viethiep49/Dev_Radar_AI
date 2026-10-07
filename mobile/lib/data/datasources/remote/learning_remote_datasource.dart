import '../../../core/constants/api_constants.dart';
import '../../../core/network/api_client.dart';

/// Raw JSON calls for /learning. [status] is the backend value ("want_to_try" | "learning" | "used").
abstract class LearningRemoteDataSource {
  Future<Map<String, dynamic>> getItemsPage({String? status, int page = 1, int limit = 100});
  Future<void> setStatus(int repoId, String status);
  Future<void> deleteStatus(int repoId);
}

class LearningRemoteDataSourceImpl implements LearningRemoteDataSource {
  final ApiClient apiClient;

  LearningRemoteDataSourceImpl({required this.apiClient});

  @override
  Future<Map<String, dynamic>> getItemsPage({String? status, int page = 1, int limit = 100}) async {
    final response = await apiClient.get(
      ApiConstants.learning,
      queryParameters: {'status': ?status, 'page': page, 'limit': limit},
    );
    return response.data as Map<String, dynamic>;
  }

  @override
  Future<void> setStatus(int repoId, String status) async {
    await apiClient.put('${ApiConstants.learning}/$repoId', data: {'status': status});
  }

  @override
  Future<void> deleteStatus(int repoId) async {
    await apiClient.delete('${ApiConstants.learning}/$repoId');
  }
}
