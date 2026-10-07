import '../models/learning_model.dart';
import 'cache_policy.dart';

/// Learning path. Implemented by LearningRepositoryImpl
/// ({required LearningRemoteDataSource remoteDataSource, required CacheLocalDataSource cache}).
abstract class LearningRepository {
  /// GET /learning?status= (all pages). Cached per status.
  Future<Cached<List<LearningItemModel>>> getItems({LearningStatus? status});

  /// PUT /learning/{repoId} {"status"}; null -> DELETE /learning/{repoId}.
  Future<void> setStatus(int repoId, LearningStatus? status);
}
