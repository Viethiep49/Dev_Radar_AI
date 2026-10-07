import '../models/collection_model.dart';
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
