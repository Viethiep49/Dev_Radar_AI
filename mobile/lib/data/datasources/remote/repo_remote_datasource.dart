import '../../../core/constants/api_constants.dart';
import '../../../core/network/api_client.dart';

/// Raw JSON calls for /repos. The repository parses and caches the results.
abstract class RepoRemoteDataSource {
  /// GET /repos/feed -> Page[RepoOut] (repos matching the user's preferences, trending first).
  Future<Map<String, dynamic>> getFeed({int page = 1, int limit = 20});

  /// GET /repos?q=&language=&topic=&sort= -> Page[RepoOut].
  Future<Map<String, dynamic>> searchRepos({
    String? query,
    String? language,
    String? topic,
    String sort = 'stars',
    int page = 1,
    int limit = 20,
  });

  /// GET /repos/filters -> {languages: [{name, count}], topics: [...]}.
  Future<Map<String, dynamic>> getFilters();

  /// GET /repos/{id} -> RepoDetailOut.
  Future<Map<String, dynamic>> getRepoDetail(int id);

  /// GET /repos/{id}/stars?days= -> [{date, stars}], oldest first.
  Future<List<dynamic>> getStarHistory(int id, {int days = 30});
}

class RepoRemoteDataSourceImpl implements RepoRemoteDataSource {
  final ApiClient apiClient;

  RepoRemoteDataSourceImpl({required this.apiClient});

  @override
  Future<Map<String, dynamic>> getFeed({int page = 1, int limit = 20}) async {
    final response = await apiClient.get(
      ApiConstants.repoFeed,
      queryParameters: {'page': page, 'limit': limit},
    );
    return response.data as Map<String, dynamic>;
  }

  @override
  Future<Map<String, dynamic>> searchRepos({
    String? query,
    String? language,
    String? topic,
    String sort = 'stars',
    int page = 1,
    int limit = 20,
  }) async {
    final params = <String, dynamic>{'sort': sort, 'page': page, 'limit': limit};
    if (query != null && query.trim().isNotEmpty) params['q'] = query.trim();
    if (language != null && language.isNotEmpty) params['language'] = language;
    if (topic != null && topic.isNotEmpty) params['topic'] = topic;
    final response = await apiClient.get(ApiConstants.repos, queryParameters: params);
    return response.data as Map<String, dynamic>;
  }

  @override
  Future<Map<String, dynamic>> getFilters() async {
    final response = await apiClient.get(ApiConstants.repoFilters);
    return response.data as Map<String, dynamic>;
  }

  @override
  Future<Map<String, dynamic>> getRepoDetail(int id) async {
    final response = await apiClient.get('${ApiConstants.repos}/$id');
    return response.data as Map<String, dynamic>;
  }

  @override
  Future<List<dynamic>> getStarHistory(int id, {int days = 30}) async {
    final response = await apiClient.get(
      '${ApiConstants.repos}/$id/stars',
      queryParameters: {'days': days},
    );
    return response.data as List<dynamic>;
  }
}
