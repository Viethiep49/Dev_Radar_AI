import '../datasources/local/cache_local_datasource.dart';
import '../datasources/remote/repo_remote_datasource.dart';
import '../models/page_model.dart';
import '../models/repo_detail_model.dart';
import '../models/repo_filters_model.dart';
import '../models/repo_model.dart';
import 'cache_policy.dart';

/// Discover data: feed, search, filters, repo detail, star history.
abstract class RepoRepository {
  /// Personalised feed. Page 1 is cached for offline use.
  Future<Cached<PageModel<RepoModel>>> getFeed({int page = 1});

  /// Search / filter / sort. Page 1 without a text query is cached (e.g. a language chip).
  Future<Cached<PageModel<RepoModel>>> searchRepos({
    String? query,
    String? language,
    String? topic,
    RepoSort sort = RepoSort.stars,
    int page = 1,
  });

  Future<Cached<RepoFiltersModel>> getFilters();

  /// Cached per repo id.
  Future<Cached<RepoDetailModel>> getRepoDetail(int id);

  /// Cached per repo id.
  Future<Cached<List<StarPointModel>>> getStarHistory(int id, {int days = 30});

  /// Asks the backend to generate this repo's AI summary now. Blocks for up to
  /// ~2 minutes. Not cached: the caller reloads the detail afterwards, which
  /// refreshes the cache.
  Future<void> generateSummary(int id);
}

class RepoRepositoryImpl implements RepoRepository {
  static const int pageSize = 20;

  static const String feedKey = 'feed:page=1';
  static const String filtersKey = 'repo_filters';
  static String searchKey({String? language, String? topic, required RepoSort sort}) =>
      'repos:lang=${language ?? ''}&topic=${topic ?? ''}&sort=${sort.apiValue}';
  static String detailKey(int id) => 'repo_detail:$id';
  static String starsKey(int id, int days) => 'repo_stars:$id:$days';

  final RepoRemoteDataSource remoteDataSource;
  final CacheLocalDataSource cache;

  RepoRepositoryImpl({required this.remoteDataSource, required this.cache});

  static PageModel<RepoModel> _parsePage(dynamic json) =>
      PageModel.fromJson(json as Map<String, dynamic>, RepoModel.fromJson);

  @override
  Future<Cached<PageModel<RepoModel>>> getFeed({int page = 1}) async {
    Future<Map<String, dynamic>> fetch() => remoteDataSource.getFeed(page: page, limit: pageSize);
    if (page != 1) return Cached(_parsePage(await fetch()));
    return fetchWithCache(cache: cache, key: feedKey, fetch: fetch, parse: _parsePage);
  }

  @override
  Future<Cached<PageModel<RepoModel>>> searchRepos({
    String? query,
    String? language,
    String? topic,
    RepoSort sort = RepoSort.stars,
    int page = 1,
  }) async {
    Future<Map<String, dynamic>> fetch() => remoteDataSource.searchRepos(
          query: query,
          language: language,
          topic: topic,
          sort: sort.apiValue,
          page: page,
          limit: pageSize,
        );
    final hasText = query != null && query.trim().isNotEmpty;
    if (hasText || page != 1) return Cached(_parsePage(await fetch()));
    return fetchWithCache(
      cache: cache,
      key: searchKey(language: language, topic: topic, sort: sort),
      fetch: fetch,
      parse: _parsePage,
    );
  }

  @override
  Future<Cached<RepoFiltersModel>> getFilters() {
    return fetchWithCache(
      cache: cache,
      key: filtersKey,
      fetch: remoteDataSource.getFilters,
      parse: (json) => RepoFiltersModel.fromJson(json as Map<String, dynamic>),
    );
  }

  @override
  Future<Cached<RepoDetailModel>> getRepoDetail(int id) {
    return fetchWithCache(
      cache: cache,
      key: detailKey(id),
      fetch: () => remoteDataSource.getRepoDetail(id),
      parse: (json) => RepoDetailModel.fromJson(json as Map<String, dynamic>),
    );
  }

  @override
  Future<Cached<List<StarPointModel>>> getStarHistory(int id, {int days = 30}) {
    return fetchWithCache(
      cache: cache,
      key: starsKey(id, days),
      fetch: () => remoteDataSource.getStarHistory(id, days: days),
      parse: (json) =>
          (json as List<dynamic>).map((e) => StarPointModel.fromJson(e as Map<String, dynamic>)).toList(),
    );
  }

  @override
  Future<void> generateSummary(int id) async {
    await remoteDataSource.generateSummary(id);
  }
}
