import '../../core/network/api_exceptions.dart';
import '../datasources/local/cache_local_datasource.dart';
import '../datasources/remote/watchlist_remote_datasource.dart';
import '../models/page_model.dart';
import '../models/watchlist_item_model.dart';
import 'cache_policy.dart';

/// Watched repos (release notifications). Implemented by WatchlistRepositoryImpl
/// ({required WatchlistRemoteDataSource remoteDataSource, required CacheLocalDataSource cache}).
abstract class WatchlistRepository {
  /// GET /watchlist (all pages). Cached.
  Future<Cached<List<WatchlistItemModel>>> getWatchlist();

  /// POST /watchlist/{repoId}. 409 (already watched) is treated as success.
  Future<void> watch(int repoId);

  /// DELETE /watchlist/{repoId}.
  Future<void> unwatch(int repoId);
}

class WatchlistRepositoryImpl implements WatchlistRepository {
  static const String listKey = 'watchlist';

  final WatchlistRemoteDataSource remoteDataSource;
  final CacheLocalDataSource cache;

  WatchlistRepositoryImpl({required this.remoteDataSource, required this.cache});

  Future<Map<String, dynamic>> _fetchAll() async {
    final items = <dynamic>[];
    var page = 1;
    while (true) {
      final json = await remoteDataSource.getWatchlistPage(page: page);
      final pageModel = PageModel.fromJson(json, (item) => item);
      items.addAll(pageModel.items);
      if (!pageModel.hasMore || pageModel.items.isEmpty) break;
      page++;
    }
    return {'items': items};
  }

  @override
  Future<Cached<List<WatchlistItemModel>>> getWatchlist() {
    return fetchWithCache(
      cache: cache,
      key: listKey,
      fetch: _fetchAll,
      parse: (json) => ((json as Map<String, dynamic>)['items'] as List<dynamic>)
          .map((e) => WatchlistItemModel.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  @override
  Future<void> watch(int repoId) async {
    try {
      await remoteDataSource.watch(repoId);
    } on ApiException catch (e) {
      if (e.statusCode != 409) rethrow; // already watched: fine
    }
    await cache.remove(listKey);
  }

  @override
  Future<void> unwatch(int repoId) async {
    try {
      await remoteDataSource.unwatch(repoId);
    } on ApiException catch (e) {
      if (e.statusCode != 404) rethrow; // already not watched: fine
    }
    await cache.remove(listKey);
  }
}
