import '../models/note_model.dart';
import 'cache_policy.dart';

/// Notes CRUD. Implemented by NoteRepositoryImpl
/// ({required NoteRemoteDataSource remoteDataSource, required CacheLocalDataSource cache}).
abstract class NoteRepository {
  /// GET /notes?repo_id=&q= (all pages). Cached when [query] is empty.
  Future<Cached<List<NoteModel>>> getNotes({int? repoId, String? query});

  Future<NoteModel> createNote({required int repoId, required String content});

  Future<NoteModel> updateNote(int id, {required String content});

  Future<void> deleteNote(int id);
}
