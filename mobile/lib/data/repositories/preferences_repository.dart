import '../datasources/local/cache_local_datasource.dart';
import '../datasources/remote/preferences_remote_datasource.dart';
import '../models/preferences_model.dart';
import 'cache_policy.dart';

/// Languages / topics the user follows (onboarding + Settings), and the choices for them.
abstract class PreferencesRepository {
  Future<Cached<PreferencesModel>> getPreferences();

  /// Replaces the whole list (PUT /preferences).
  Future<PreferencesModel> savePreferences(PreferencesModel preferences);

  /// Languages and topics that exist in the repo database, with repo counts.
  Future<Cached<FilterOptionsModel>> getFilterOptions();
}

class PreferencesRepositoryImpl implements PreferencesRepository {
  static const String preferencesKey = 'preferences';
  static const String filtersKey = 'repo_filters';

  final PreferencesRemoteDataSource remoteDataSource;
  final CacheLocalDataSource cache;

  PreferencesRepositoryImpl({required this.remoteDataSource, required this.cache});

  @override
  Future<Cached<PreferencesModel>> getPreferences() {
    return fetchWithCache(
      cache: cache,
      key: preferencesKey,
      fetch: remoteDataSource.getPreferences,
      parse: (json) => PreferencesModel.fromJson(json as Map<String, dynamic>),
    );
  }

  @override
  Future<PreferencesModel> savePreferences(PreferencesModel preferences) async {
    final json = await remoteDataSource.savePreferences(
      languages: preferences.languages,
      topics: preferences.topics,
    );
    await cache.put(preferencesKey, json);
    // The personalised feed depends on the preferences.
    await cache.removeByPrefix('feed');
    return PreferencesModel.fromJson(json);
  }

  @override
  Future<Cached<FilterOptionsModel>> getFilterOptions() {
    return fetchWithCache(
      cache: cache,
      key: filtersKey,
      fetch: remoteDataSource.getFilterOptions,
      parse: (json) => FilterOptionsModel.fromJson(json as Map<String, dynamic>),
    );
  }
}
