import '../datasources/local/cache_local_datasource.dart';
import '../datasources/remote/learning_remote_datasource.dart';
import '../models/learning_model.dart';
import '../models/page_model.dart';
import 'cache_policy.dart';

/// Learning path. Implemented by LearningRepositoryImpl
/// ({required LearningRemoteDataSource remoteDataSource, required CacheLocalDataSource cache}).
abstract class LearningRepository {
  /// GET /learning?status= (all pages). Cached per status.
  Future<Cached<List<LearningItemModel>>> getItems({LearningStatus? status});

  /// PUT /learning/{repoId} {"status"}; null -> DELETE /learning/{repoId}.
  Future<void> setStatus(int repoId, LearningStatus? status);
}

class LearningRepositoryImpl implements LearningRepository {
  /// Cache keys: "learning:all", "learning:want_to_try", ... Every write clears all of them.
  static const String keyPrefix = 'learning:';
  static String listKey(LearningStatus? status) => '$keyPrefix${status?.apiValue ?? 'all'}';

  final LearningRemoteDataSource remoteDataSource;
  final CacheLocalDataSource cache;

  LearningRepositoryImpl({required this.remoteDataSource, required this.cache});

  Future<Map<String, dynamic>> _fetchAll(LearningStatus? status) async {
    final items = <dynamic>[];
    var page = 1;
    while (true) {
      final json = await remoteDataSource.getItemsPage(status: status?.apiValue, page: page);
      final pageModel = PageModel.fromJson(json, (item) => item);
      items.addAll(pageModel.items);
      if (!pageModel.hasMore || pageModel.items.isEmpty) break;
      page++;
    }
    return {'items': items};
  }

  @override
  Future<Cached<List<LearningItemModel>>> getItems({LearningStatus? status}) {
    return fetchWithCache(
      cache: cache,
      key: listKey(status),
      fetch: () => _fetchAll(status),
      parse: (json) => ((json as Map<String, dynamic>)['items'] as List<dynamic>)
          .map((e) => LearningItemModel.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  @override
  Future<void> setStatus(int repoId, LearningStatus? status) async {
    if (status == null) {
      await remoteDataSource.deleteStatus(repoId);
    } else {
      await remoteDataSource.setStatus(repoId, status.apiValue);
    }
    await cache.removeByPrefix(keyPrefix);
  }
}
