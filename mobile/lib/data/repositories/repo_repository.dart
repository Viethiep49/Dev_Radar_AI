import '../datasources/remote/repo_remote_datasource.dart';
import '../models/repo_model.dart';

abstract class RepoRepository {
  Future<List<RepoModel>> getTrendingRepos({
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

class RepoRepositoryImpl implements RepoRepository {
  final RepoRemoteDataSource remoteDataSource;
  List<RepoModel> _cachedRepos = [];

  RepoRepositoryImpl({required this.remoteDataSource});

  @override
  Future<List<RepoModel>> getTrendingRepos({
    int page = 1,
    int limit = 20,
    String? language,
    String? sort,
  }) async {
    try {
      final repos = await remoteDataSource.getRepos(
        page: page,
        limit: limit,
        language: language,
        sort: sort,
      );
      if (page == 1 && (language == null || language.isEmpty)) {
        _cachedRepos = repos;
      }
      return repos;
    } catch (e) {
      if (_cachedRepos.isNotEmpty && page == 1) {
        if (language != null && language.isNotEmpty) {
          final filtered = _cachedRepos
              .where((r) => r.language?.toLowerCase() == language.toLowerCase())
              .toList();
          return filtered;
        }
        return _cachedRepos;
      }
      rethrow;
    }
  }

  @override
  Future<List<RepoModel>> searchRepos(
    String query, {
    int page = 1,
    int limit = 20,
  }) async {
    return await remoteDataSource.searchRepos(
      query,
      page: page,
      limit: limit,
    );
  }

  @override
  Future<Map<String, dynamic>> getRepoDetail(int id) async {
    return await remoteDataSource.getRepoDetail(id);
  }

  @override
  Future<Map<String, dynamic>> askQuestion(int repoId, String question) async {
    return await remoteDataSource.askQuestion(repoId, question);
  }

  @override
  Future<List<dynamic>> getChatHistory(int repoId) async {
    return await remoteDataSource.getChatHistory(repoId);
  }

  @override
  Future<void> updateLearningStatus(int repoId, String? status) async {
    return await remoteDataSource.updateLearningStatus(repoId, status);
  }
}
