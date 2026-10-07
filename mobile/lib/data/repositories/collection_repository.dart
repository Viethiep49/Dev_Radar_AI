import '../../core/network/api_exceptions.dart';
import '../datasources/local/cache_local_datasource.dart';
import '../datasources/remote/collection_remote_datasource.dart';
import '../models/collection_model.dart';
import '../models/page_model.dart';
import 'cache_policy.dart';

/// Collections CRUD + items. Implemented by CollectionRepositoryImpl
/// ({required CollectionRemoteDataSource remoteDataSource, required CacheLocalDataSource cache}).
abstract class CollectionRepository {
  /// GET /collections?q= (all pages). Cached for offline use when [query] is empty.
  Future<Cached<List<CollectionModel>>> getCollections({String? query});

  /// GET /collections/{id}. Cached per id.
  Future<Cached<CollectionDetailModel>> getCollection(int id);

  Future<CollectionModel> createCollection({required String name, String? description});

  Future<CollectionModel> updateCollection(int id, {required String name, String? description});

  Future<void> deleteCollection(int id);

  /// POST /collections/{id}/items {"repo_id"}. 409 (already there) is treated as success.
  Future<void> addRepo(int collectionId, int repoId);

  Future<void> removeRepo(int collectionId, int repoId);
}

class CollectionRepositoryImpl implements CollectionRepository {
  /// Cache keys: the full list, and one entry per collection detail.
  static const String listKey = 'collections';
  static String detailKey(int id) => 'collection:$id';

  final CollectionRemoteDataSource remoteDataSource;
  final CacheLocalDataSource cache;

  CollectionRepositoryImpl({required this.remoteDataSource, required this.cache});

  /// Loads every page and returns {"items": [...]} so the whole list is cached as one entry.
  Future<Map<String, dynamic>> _fetchAll({String? query}) async {
    final items = <dynamic>[];
    var page = 1;
    while (true) {
      final json = await remoteDataSource.getCollectionsPage(query: query, page: page);
      final pageModel = PageModel.fromJson(json, (item) => item);
      items.addAll(pageModel.items);
      if (!pageModel.hasMore || pageModel.items.isEmpty) break;
      page++;
    }
    return {'items': items};
  }

  static List<CollectionModel> _parseList(dynamic json) => ((json as Map<String, dynamic>)['items'] as List<dynamic>)
      .map((e) => CollectionModel.fromJson(e as Map<String, dynamic>))
      .toList();

  @override
  Future<Cached<List<CollectionModel>>> getCollections({String? query}) async {
    final q = query?.trim() ?? '';
    if (q.isEmpty) {
      return fetchWithCache(cache: cache, key: listKey, fetch: _fetchAll, parse: _parseList);
    }
    try {
      return Cached(_parseList(await _fetchAll(query: q)));
    } on ApiException catch (e) {
      // Offline search: filter the cached full list locally.
      if (!isOfflineError(e)) rethrow;
      final entry = await cache.get(listKey);
      if (entry == null) rethrow;
      final needle = q.toLowerCase();
      final filtered = _parseList(entry.json)
          .where((c) =>
              c.name.toLowerCase().contains(needle) || (c.description ?? '').toLowerCase().contains(needle))
          .toList();
      return Cached(filtered, fromCache: true, cachedAt: entry.updatedAt);
    }
  }

  @override
  Future<Cached<CollectionDetailModel>> getCollection(int id) {
    return fetchWithCache(
      cache: cache,
      key: detailKey(id),
      fetch: () => remoteDataSource.getCollection(id),
      parse: (json) => CollectionDetailModel.fromJson(json as Map<String, dynamic>),
    );
  }

  @override
  Future<CollectionModel> createCollection({required String name, String? description}) async {
    final json = await remoteDataSource.createCollection(name: name, description: _blankToNull(description));
    await cache.remove(listKey);
    return CollectionModel.fromJson(json);
  }

  @override
  Future<CollectionModel> updateCollection(int id, {required String name, String? description}) async {
    final json = await remoteDataSource.updateCollection(id, name: name, description: _blankToNull(description));
    await _invalidate(id);
    return CollectionModel.fromJson(json);
  }

  @override
  Future<void> deleteCollection(int id) async {
    await remoteDataSource.deleteCollection(id);
    await _invalidate(id);
  }

  @override
  Future<void> addRepo(int collectionId, int repoId) async {
    try {
      await remoteDataSource.addRepo(collectionId, repoId);
    } on ApiException catch (e) {
      if (e.statusCode != 409) rethrow; // already in the collection: fine
    }
    await _invalidate(collectionId);
  }

  @override
  Future<void> removeRepo(int collectionId, int repoId) async {
    await remoteDataSource.removeRepo(collectionId, repoId);
    await _invalidate(collectionId);
  }

  Future<void> _invalidate(int collectionId) async {
    await cache.remove(listKey); // item counts / names changed
    await cache.remove(detailKey(collectionId));
  }

  static String? _blankToNull(String? value) {
    final trimmed = value?.trim();
    return (trimmed == null || trimmed.isEmpty) ? null : trimmed;
  }
}
