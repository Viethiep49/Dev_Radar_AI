import '../datasources/local/cache_local_datasource.dart';
import '../datasources/remote/stats_remote_datasource.dart';
import '../models/stats_model.dart';
import 'cache_policy.dart';

/// Personal statistics for the Stats tab (pie / bar charts).
abstract class StatsRepository {
  Future<Cached<StatsOverviewModel>> getOverview();

  /// [weeks] weeks ending with the current one, oldest first.
  Future<Cached<List<WeeklyStatModel>>> getWeekly({int weeks = 8});

  /// Languages of the repos on the learning path, most used first.
  Future<Cached<List<LanguageStatModel>>> getLanguages();
}

class StatsRepositoryImpl implements StatsRepository {
  static const String overviewKey = 'stats:overview';
  static String weeklyKey(int weeks) => 'stats:weekly=$weeks';
  static const String languagesKey = 'stats:languages';

  final StatsRemoteDataSource remoteDataSource;
  final CacheLocalDataSource cache;

  StatsRepositoryImpl({required this.remoteDataSource, required this.cache});

  @override
  Future<Cached<StatsOverviewModel>> getOverview() {
    return fetchWithCache(
      cache: cache,
      key: overviewKey,
      fetch: remoteDataSource.getOverview,
      parse: (json) => StatsOverviewModel.fromJson(json as Map<String, dynamic>),
    );
  }

  @override
  Future<Cached<List<WeeklyStatModel>>> getWeekly({int weeks = 8}) {
    return fetchWithCache(
      cache: cache,
      key: weeklyKey(weeks),
      fetch: () => remoteDataSource.getWeekly(weeks: weeks),
      parse: (json) => (json as List<dynamic>)
          .map((e) => WeeklyStatModel.fromJson(e as Map<String, dynamic>))
          .toList()
        ..sort((a, b) => a.weekStart.compareTo(b.weekStart)),
    );
  }

  @override
  Future<Cached<List<LanguageStatModel>>> getLanguages() {
    return fetchWithCache(
      cache: cache,
      key: languagesKey,
      fetch: remoteDataSource.getLanguages,
      parse: (json) => (json as List<dynamic>)
          .map((e) => LanguageStatModel.fromJson(e as Map<String, dynamic>))
          .toList()
        ..sort((a, b) => b.count.compareTo(a.count)),
    );
  }
}
