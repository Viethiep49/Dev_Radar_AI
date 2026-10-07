import '../../../core/constants/api_constants.dart';
import '../../../core/network/api_client.dart';

/// Raw JSON calls for /chat/{repoId}.
abstract class ChatRemoteDataSource {
  /// GET /chat/{repoId}?page=&limit= -> Page[ChatMessageOut], oldest first.
  Future<Map<String, dynamic>> getHistoryPage(int repoId, {int page = 1, int limit = 100});

  /// POST /chat/{repoId} {question} -> {question, answer}.
  Future<Map<String, dynamic>> ask(int repoId, String question);

  /// DELETE /chat/{repoId}.
  Future<void> clear(int repoId);
}

class ChatRemoteDataSourceImpl implements ChatRemoteDataSource {
  final ApiClient apiClient;

  ChatRemoteDataSourceImpl({required this.apiClient});

  @override
  Future<Map<String, dynamic>> getHistoryPage(int repoId, {int page = 1, int limit = 100}) async {
    final response = await apiClient.get(
      '${ApiConstants.chat}/$repoId',
      queryParameters: {'page': page, 'limit': limit},
    );
    return response.data as Map<String, dynamic>;
  }

  @override
  Future<Map<String, dynamic>> ask(int repoId, String question) async {
    final response = await apiClient.post(
      '${ApiConstants.chat}/$repoId',
      data: {'question': question},
    );
    return response.data as Map<String, dynamic>;
  }

  @override
  Future<void> clear(int repoId) async {
    await apiClient.delete('${ApiConstants.chat}/$repoId');
  }
}
