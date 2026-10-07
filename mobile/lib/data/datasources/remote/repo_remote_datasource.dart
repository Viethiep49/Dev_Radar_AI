import '../../../core/constants/api_constants.dart';
import '../../../core/network/api_client.dart';
import '../../models/repo_model.dart';

abstract class RepoRemoteDataSource {
  Future<List<RepoModel>> getRepos({
    int page = 1,
    int limit = 20,
    String? language,
    String? sort,
  });

  Future<List<RepoModel>> searchRepos(
    String query, {
    int page = 1,
    int limit = 20,
  });

  Future<Map<String, dynamic>> getRepoDetail(int id);

  Future<Map<String, dynamic>> askQuestion(int repoId, String question);

  Future<List<dynamic>> getChatHistory(int repoId);

  Future<void> updateLearningStatus(int repoId, String? status);
}

class RepoRemoteDataSourceImpl implements RepoRemoteDataSource {
  final ApiClient apiClient;

  RepoRemoteDataSourceImpl({required this.apiClient});

  @override
  Future<List<RepoModel>> getRepos({
    int page = 1,
    int limit = 20,
    String? language,
    String? sort,
  }) async {
    final queryParams = <String, dynamic>{
      'page': page,
      'limit': limit,
    };
    if (language != null && language.isNotEmpty) {
      queryParams['language'] = language;
    }
    if (sort != null && sort.isNotEmpty) {
      queryParams['sort'] = sort;
    }

    final response = await apiClient.get(
      ApiConstants.repos,
      queryParameters: queryParams,
    );

    final data = response.data;
    if (data is Map<String, dynamic> && data.containsKey('items')) {
      final items = data['items'] as List<dynamic>;
      return items.map((e) => RepoModel.fromJson(e as Map<String, dynamic>)).toList();
    }
    return [];
  }

  @override
  Future<List<RepoModel>> searchRepos(
    String query, {
    int page = 1,
    int limit = 20,
  }) async {
    final response = await apiClient.get(
      ApiConstants.repos,
      queryParameters: {
        'q': query,
        'page': page,
        'limit': limit,
      },
    );

    final data = response.data;
    if (data is Map<String, dynamic> && data.containsKey('items')) {
      final items = data['items'] as List<dynamic>;
      return items.map((e) => RepoModel.fromJson(e as Map<String, dynamic>)).toList();
    }
    return [];
  }

  @override
  Future<Map<String, dynamic>> getRepoDetail(int id) async {
    final response = await apiClient.get('${ApiConstants.repos}/$id');
    return response.data as Map<String, dynamic>;
  }

  @override
  Future<Map<String, dynamic>> askQuestion(int repoId, String question) async {
    final response = await apiClient.post(
      '${ApiConstants.apiV1}/chat/$repoId',
      data: {'question': question},
    );
    return response.data as Map<String, dynamic>;
  }

  @override
  Future<List<dynamic>> getChatHistory(int repoId) async {
    final response = await apiClient.get('${ApiConstants.apiV1}/chat/$repoId');
    final data = response.data;
    if (data is Map<String, dynamic> && data.containsKey('items')) {
      return data['items'] as List<dynamic>;
    }
    return [];
  }

  @override
  Future<void> updateLearningStatus(int repoId, String? status) async {
    if (status == null) {
      await apiClient.delete('${ApiConstants.apiV1}/learning/$repoId');
    } else {
      await apiClient.put(
        '${ApiConstants.apiV1}/learning/$repoId',
        data: {'status': status},
      );
    }
  }
}
