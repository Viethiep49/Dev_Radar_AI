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
