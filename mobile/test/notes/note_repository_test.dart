import 'package:dev_radar_ai/core/network/api_exceptions.dart';
import 'package:dev_radar_ai/data/datasources/local/cache_local_datasource.dart';
import 'package:dev_radar_ai/data/datasources/remote/note_remote_datasource.dart';
import 'package:dev_radar_ai/data/repositories/note_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../helpers/library_fixtures.dart';

class MockNoteRemote extends Mock implements NoteRemoteDataSource {}

void main() {
  late MockNoteRemote remote;
  late MemoryCacheLocalDataSource cache;
  late NoteRepositoryImpl repository;

  setUp(() {
    remote = MockNoteRemote();
    cache = MemoryCacheLocalDataSource();
    repository = NoteRepositoryImpl(remoteDataSource: remote, cache: cache);
  });

  test('getNotes for one repo uses its own cache key', () async {
    when(() => remote.getNotesPage(repoId: 3, query: null, page: 1))
        .thenAnswer((_) async => pageJson([noteJson(1, repoId: 3)]));

    final result = await repository.getNotes(repoId: 3);

    expect(result.data.single.repoId, 3);
    expect(await cache.get(NoteRepositoryImpl.listKey(3)), isNotNull);
    expect(await cache.get(NoteRepositoryImpl.listKey(null)), isNull);
  });

  test('getNotes falls back to the cache on a server error', () async {
    when(() => remote.getNotesPage(repoId: null, query: null, page: 1))
        .thenAnswer((_) async => pageJson([noteJson(1), noteJson(2)]));
    await repository.getNotes();
    when(() => remote.getNotesPage(repoId: null, query: null, page: 1))
        .thenThrow(ApiException('boom', statusCode: 503));

    final result = await repository.getNotes();

    expect(result.fromCache, isTrue);
    expect(result.data.length, 2);
  });

  test('offline search filters cached notes by content', () async {
    when(() => remote.getNotesPage(repoId: null, query: null, page: 1)).thenAnswer(
      (_) async => pageJson([noteJson(1, content: 'cài đặt docker'), noteJson(2, content: 'bloc pattern')]),
    );
    await repository.getNotes();
    when(() => remote.getNotesPage(repoId: null, query: 'docker', page: 1)).thenThrow(NetworkException());

    final result = await repository.getNotes(query: 'docker');

    expect(result.fromCache, isTrue);
    expect(result.data.single.id, 1);
  });

  test('create / update / delete clear every notes cache entry', () async {
    when(() => remote.createNote(repoId: 1, content: 'hello')).thenAnswer((_) async => noteJson(5));
    when(() => remote.updateNote(5, content: 'bye')).thenAnswer((_) async => noteJson(5, content: 'bye'));
    when(() => remote.deleteNote(5)).thenAnswer((_) async {});

    Future<void> fill() async {
      await cache.put(NoteRepositoryImpl.listKey(null), pageJson([]));
      await cache.put(NoteRepositoryImpl.listKey(1), pageJson([]));
      await cache.put('collections', pageJson([]));
    }

    for (final write in <Future<void> Function()>[
      () => repository.createNote(repoId: 1, content: '  hello  '),
      () => repository.updateNote(5, content: 'bye'),
      () => repository.deleteNote(5),
    ]) {
      await fill();
      await write();
      expect(await cache.get(NoteRepositoryImpl.listKey(null)), isNull);
      expect(await cache.get(NoteRepositoryImpl.listKey(1)), isNull);
      expect(await cache.get('collections'), isNotNull, reason: 'other features keep their cache');
    }
  });
}
