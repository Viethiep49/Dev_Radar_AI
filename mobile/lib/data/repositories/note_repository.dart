import '../../core/network/api_exceptions.dart';
import '../datasources/local/cache_local_datasource.dart';
import '../datasources/remote/note_remote_datasource.dart';
import '../models/note_model.dart';
import '../models/page_model.dart';
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

class NoteRepositoryImpl implements NoteRepository {
  /// Cache keys: "notes:all" and "notes:repo=ID". Every write clears all of them.
  static const String keyPrefix = 'notes:';
  static String listKey(int? repoId) => repoId == null ? '${keyPrefix}all' : '${keyPrefix}repo=$repoId';

  final NoteRemoteDataSource remoteDataSource;
  final CacheLocalDataSource cache;

  NoteRepositoryImpl({required this.remoteDataSource, required this.cache});

  Future<Map<String, dynamic>> _fetchAll({int? repoId, String? query}) async {
    final items = <dynamic>[];
    var page = 1;
    while (true) {
      final json = await remoteDataSource.getNotesPage(repoId: repoId, query: query, page: page);
      final pageModel = PageModel.fromJson(json, (item) => item);
      items.addAll(pageModel.items);
      if (!pageModel.hasMore || pageModel.items.isEmpty) break;
      page++;
    }
    return {'items': items};
  }

  static List<NoteModel> _parseList(dynamic json) => ((json as Map<String, dynamic>)['items'] as List<dynamic>)
      .map((e) => NoteModel.fromJson(e as Map<String, dynamic>))
      .toList();

  @override
  Future<Cached<List<NoteModel>>> getNotes({int? repoId, String? query}) async {
    final q = query?.trim() ?? '';
    if (q.isEmpty) {
      return fetchWithCache(
        cache: cache,
        key: listKey(repoId),
        fetch: () => _fetchAll(repoId: repoId),
        parse: _parseList,
      );
    }
    try {
      return Cached(_parseList(await _fetchAll(repoId: repoId, query: q)));
    } on ApiException catch (e) {
      // Offline search: filter the cached list locally (content or repo name).
      if (!isOfflineError(e)) rethrow;
      final entry = await cache.get(listKey(repoId));
      if (entry == null) rethrow;
      final needle = q.toLowerCase();
      final filtered = _parseList(entry.json)
          .where((n) =>
              n.content.toLowerCase().contains(needle) || n.repo.fullName.toLowerCase().contains(needle))
          .toList();
      return Cached(filtered, fromCache: true, cachedAt: entry.updatedAt);
    }
  }

  @override
  Future<NoteModel> createNote({required int repoId, required String content}) async {
    final json = await remoteDataSource.createNote(repoId: repoId, content: content.trim());
    await cache.removeByPrefix(keyPrefix);
    return NoteModel.fromJson(json);
  }

  @override
  Future<NoteModel> updateNote(int id, {required String content}) async {
    final json = await remoteDataSource.updateNote(id, content: content.trim());
    await cache.removeByPrefix(keyPrefix);
    return NoteModel.fromJson(json);
  }

  @override
  Future<void> deleteNote(int id) async {
    await remoteDataSource.deleteNote(id);
    await cache.removeByPrefix(keyPrefix);
  }
}
