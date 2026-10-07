import 'package:dev_radar_ai/core/network/api_exceptions.dart';
import 'package:dev_radar_ai/data/datasources/local/cache_local_datasource.dart';
import 'package:dev_radar_ai/data/datasources/remote/collection_remote_datasource.dart';
import 'package:dev_radar_ai/data/repositories/collection_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../helpers/library_fixtures.dart';

class MockCollectionRemote extends Mock implements CollectionRemoteDataSource {}

void main() {
  late MockCollectionRemote remote;
  late MemoryCacheLocalDataSource cache;
  late CollectionRepositoryImpl repository;

  setUp(() {
    remote = MockCollectionRemote();
    cache = MemoryCacheLocalDataSource();
    repository = CollectionRepositoryImpl(remoteDataSource: remote, cache: cache);
  });

  group('getCollections', () {
    test('loads every page and caches the full list', () async {
      when(() => remote.getCollectionsPage(query: null, page: 1)).thenAnswer(
        (_) async => pageJson([collectionJson(1), collectionJson(2)], page: 1, limit: 2, total: 3),
      );
      when(() => remote.getCollectionsPage(query: null, page: 2)).thenAnswer(
        (_) async => pageJson([collectionJson(3)], page: 2, limit: 2, total: 3),
      );

      final result = await repository.getCollections();

      expect(result.fromCache, isFalse);
      expect(result.data.map((c) => c.id), [1, 2, 3]);
      expect(await cache.get(CollectionRepositoryImpl.listKey), isNotNull);
    });

    test('falls back to the cache when offline', () async {
      when(() => remote.getCollectionsPage(query: null, page: 1))
          .thenAnswer((_) async => pageJson([collectionJson(1)]));
      await repository.getCollections();

      when(() => remote.getCollectionsPage(query: null, page: 1)).thenThrow(NetworkException());
      final result = await repository.getCollections();

      expect(result.fromCache, isTrue);
      expect(result.cachedAt, isNotNull);
      expect(result.data.single.id, 1);
    });

    test('offline without cache rethrows', () async {
      when(() => remote.getCollectionsPage(query: null, page: 1)).thenThrow(TimeoutException());
      expect(repository.getCollections(), throwsA(isA<TimeoutException>()));
    });

    test('a 404 is not hidden by the cache', () async {
      when(() => remote.getCollectionsPage(query: null, page: 1))
          .thenAnswer((_) async => pageJson([collectionJson(1)]));
      await repository.getCollections();
      when(() => remote.getCollectionsPage(query: null, page: 1))
          .thenThrow(ApiException('not found', statusCode: 404));

      expect(repository.getCollections(), throwsA(isA<ApiException>()));
    });

    test('search uses the API and, when offline, filters the cached list', () async {
      when(() => remote.getCollectionsPage(query: null, page: 1)).thenAnswer(
        (_) async => pageJson([collectionJson(1, name: 'Flutter'), collectionJson(2, name: 'AI')]),
      );
      await repository.getCollections();

      when(() => remote.getCollectionsPage(query: 'flutter', page: 1))
          .thenAnswer((_) async => pageJson([collectionJson(1, name: 'Flutter')]));
      final online = await repository.getCollections(query: ' flutter ');
      expect(online.fromCache, isFalse);
      expect(online.data.single.id, 1);

      when(() => remote.getCollectionsPage(query: 'ai', page: 1)).thenThrow(NetworkException());
      final offline = await repository.getCollections(query: 'ai');
      expect(offline.fromCache, isTrue);
      expect(offline.data.single.id, 2);
    });
  });

  group('writes invalidate the cache', () {
    setUp(() async {
      await cache.put(CollectionRepositoryImpl.listKey, pageJson([collectionJson(1)]));
      await cache.put(CollectionRepositoryImpl.detailKey(1), collectionDetailJson(1, [5]));
      await cache.put(CollectionRepositoryImpl.detailKey(2), collectionDetailJson(2, [6]));
    });

    test('create clears the list', () async {
      when(() => remote.createCollection(name: 'New', description: null))
          .thenAnswer((_) async => collectionJson(9, name: 'New'));

      final created = await repository.createCollection(name: 'New', description: '  ');

      expect(created.id, 9);
      expect(await cache.get(CollectionRepositoryImpl.listKey), isNull);
    });

    test('update clears the list and that detail only', () async {
      when(() => remote.updateCollection(1, name: 'X', description: 'd'))
          .thenAnswer((_) async => collectionJson(1, name: 'X'));

      await repository.updateCollection(1, name: 'X', description: 'd');

      expect(await cache.get(CollectionRepositoryImpl.listKey), isNull);
      expect(await cache.get(CollectionRepositoryImpl.detailKey(1)), isNull);
      expect(await cache.get(CollectionRepositoryImpl.detailKey(2)), isNotNull);
    });

    test('delete clears the list and the detail', () async {
      when(() => remote.deleteCollection(1)).thenAnswer((_) async {});

      await repository.deleteCollection(1);

      expect(await cache.get(CollectionRepositoryImpl.listKey), isNull);
      expect(await cache.get(CollectionRepositoryImpl.detailKey(1)), isNull);
    });

    test('addRepo treats 409 (already there) as success', () async {
      when(() => remote.addRepo(1, 5)).thenThrow(ApiException('exists', statusCode: 409));

      await repository.addRepo(1, 5);

      expect(await cache.get(CollectionRepositoryImpl.detailKey(1)), isNull);
    });

    test('addRepo rethrows other errors', () async {
      when(() => remote.addRepo(1, 5)).thenThrow(ApiException('not found', statusCode: 404));
      expect(repository.addRepo(1, 5), throwsA(isA<ApiException>()));
    });

    test('removeRepo clears the list and the detail', () async {
      when(() => remote.removeRepo(1, 5)).thenAnswer((_) async {});

      await repository.removeRepo(1, 5);

      expect(await cache.get(CollectionRepositoryImpl.listKey), isNull);
      expect(await cache.get(CollectionRepositoryImpl.detailKey(1)), isNull);
    });
  });

  test('getCollection parses repos and is cached per id', () async {
    when(() => remote.getCollection(1)).thenAnswer((_) async => collectionDetailJson(1, [5, 6]));

    final result = await repository.getCollection(1);

    expect(result.data.collection.id, 1);
    expect(result.data.repos.map((r) => r.repo.id), [5, 6]);
    expect(await cache.get(CollectionRepositoryImpl.detailKey(1)), isNotNull);
  });
}
