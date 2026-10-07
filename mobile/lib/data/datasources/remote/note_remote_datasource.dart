import '../../../core/constants/api_constants.dart';
import '../../../core/network/api_client.dart';

/// Raw JSON calls for /notes.
abstract class NoteRemoteDataSource {
  Future<Map<String, dynamic>> getNotesPage({int? repoId, String? query, int page = 1, int limit = 100});
  Future<Map<String, dynamic>> createNote({required int repoId, required String content});
  Future<Map<String, dynamic>> updateNote(int id, {required String content});
  Future<void> deleteNote(int id);
}

class NoteRemoteDataSourceImpl implements NoteRemoteDataSource {
  final ApiClient apiClient;

  NoteRemoteDataSourceImpl({required this.apiClient});

  @override
  Future<Map<String, dynamic>> getNotesPage({int? repoId, String? query, int page = 1, int limit = 100}) async {
    final response = await apiClient.get(
      ApiConstants.notes,
      queryParameters: {
        'repo_id': ?repoId,
        if (query != null && query.trim().isNotEmpty) 'q': query.trim(),
        'page': page,
        'limit': limit,
      },
    );
    return response.data as Map<String, dynamic>;
  }

  @override
  Future<Map<String, dynamic>> createNote({required int repoId, required String content}) async {
    final response = await apiClient.post(ApiConstants.notes, data: {'repo_id': repoId, 'content': content});
    return response.data as Map<String, dynamic>;
  }

  @override
  Future<Map<String, dynamic>> updateNote(int id, {required String content}) async {
    final response = await apiClient.patch('${ApiConstants.notes}/$id', data: {'content': content});
    return response.data as Map<String, dynamic>;
  }

  @override
  Future<void> deleteNote(int id) async {
    await apiClient.delete('${ApiConstants.notes}/$id');
  }
}
