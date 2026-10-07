import 'package:bloc_test/bloc_test.dart';
import 'package:dev_radar_ai/core/network/api_exceptions.dart';
import 'package:dev_radar_ai/data/models/collection_model.dart';
import 'package:dev_radar_ai/data/repositories/cache_policy.dart';
import 'package:dev_radar_ai/data/repositories/collection_repository.dart';
import 'package:dev_radar_ai/presentation/state/collections/add_to_collection_cubit.dart';
import 'package:dev_radar_ai/presentation/state/collections/collection_detail_cubit.dart';
import 'package:dev_radar_ai/presentation/state/collections/collections_cubit.dart';
import 'package:dev_radar_ai/presentation/state/load_status.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../helpers/library_fixtures.dart';

class MockCollectionRepository extends Mock implements CollectionRepository {}

CollectionModel collection(int id) => CollectionModel.fromJson(collectionJson(id));

void main() {
  late MockCollectionRepository repository;

  setUp(() => repository = MockCollectionRepository());

  group('CollectionsCubit', () {
    blocTest<CollectionsCubit, CollectionsState>(
      'load emits loading then the collections',
      setUp: () => when(() => repository.getCollections(query: ''))
          .thenAnswer((_) async => Cached([collection(1), collection(2)])),
      build: () => CollectionsCubit(repository),
      act: (cubit) => cubit.load(),
      expect: () => [
        const CollectionsState(status: LoadStatus.loading),
        CollectionsState(status: LoadStatus.success, collections: [collection(1), collection(2)]),
      ],
    );

    blocTest<CollectionsCubit, CollectionsState>(
      'load keeps the offline flag from the cache',
      setUp: () => when(() => repository.getCollections(query: ''))
          .thenAnswer((_) async => Cached([collection(1)], fromCache: true, cachedAt: DateTime(2026))),
      build: () => CollectionsCubit(repository),
      act: (cubit) => cubit.load(),
      skip: 1,
      expect: () => [
        CollectionsState(
          status: LoadStatus.success,
          collections: [collection(1)],
          fromCache: true,
          cachedAt: DateTime(2026),
        ),
      ],
    );

    blocTest<CollectionsCubit, CollectionsState>(
      'load failure shows the error message',
      setUp: () => when(() => repository.getCollections(query: '')).thenThrow(NetworkException('offline')),
      build: () => CollectionsCubit(repository),
      act: (cubit) => cubit.load(),
      skip: 1,
      expect: () => [const CollectionsState(status: LoadStatus.failure, errorMessage: 'offline')],
    );

    blocTest<CollectionsCubit, CollectionsState>(
      'search passes the trimmed query',
      setUp: () => when(() => repository.getCollections(query: 'ai'))
          .thenAnswer((_) async => Cached([collection(3)])),
      build: () => CollectionsCubit(repository),
      act: (cubit) => cubit.search('  ai '),
      verify: (cubit) {
        expect(cubit.state.query, 'ai');
        expect(cubit.state.collections, [collection(3)]);
      },
    );

    test('create calls the repository, reloads and returns null', () async {
      when(() => repository.createCollection(name: 'New', description: null))
          .thenAnswer((_) async => collection(9));
      when(() => repository.getCollections(query: '')).thenAnswer((_) async => Cached([collection(9)]));
      final cubit = CollectionsCubit(repository);

      final error = await cubit.create(name: ' New ');

      expect(error, isNull);
      expect(cubit.state.collections, [collection(9)]);
    });

    test('delete returns the error message on failure', () async {
      when(() => repository.deleteCollection(1)).thenThrow(ApiException('Không tìm thấy', statusCode: 404));
      final cubit = CollectionsCubit(repository);

      expect(await cubit.delete(1), 'Không tìm thấy');
    });
  });

  group('CollectionDetailCubit', () {
    final detail = CollectionDetailModel.fromJson(collectionDetailJson(1, [5, 6]));

    blocTest<CollectionDetailCubit, CollectionDetailState>(
      'load emits the detail',
      setUp: () => when(() => repository.getCollection(1)).thenAnswer((_) async => Cached(detail)),
      build: () => CollectionDetailCubit(repository, 1),
      act: (cubit) => cubit.load(),
      expect: () => [
        const CollectionDetailState(status: LoadStatus.loading),
        CollectionDetailState(status: LoadStatus.success, detail: detail),
      ],
    );

    test('removeRepo restores the repo when the call fails', () async {
      when(() => repository.getCollection(1)).thenAnswer((_) async => Cached(detail));
      when(() => repository.removeRepo(1, 5)).thenThrow(NetworkException('offline'));
      final cubit = CollectionDetailCubit(repository, 1);
      await cubit.load();

      final error = await cubit.removeRepo(5);

      expect(error, 'offline');
      expect(cubit.state.detail!.repos.length, 2);
      expect(cubit.changed, isFalse);
    });

    test('delete marks the state as deleted', () async {
      when(() => repository.deleteCollection(1)).thenAnswer((_) async {});
      final cubit = CollectionDetailCubit(repository, 1);

      expect(await cubit.delete(), isNull);
      expect(cubit.state.deleted, isTrue);
      expect(cubit.changed, isTrue);
    });
  });

  group('AddToCollectionCubit', () {
    test('toggle adds and removes the repo', () async {
      when(() => repository.addRepo(2, 7)).thenAnswer((_) async {});
      when(() => repository.removeRepo(1, 7)).thenAnswer((_) async {});
      final cubit = AddToCollectionCubit(repository, repoId: 7, currentCollectionIds: [1]);

      await cubit.toggle(2);
      await cubit.toggle(1);

      expect(cubit.state.selectedIds, {2});
      expect(cubit.state.changed, isTrue);
      expect(cubit.state.busyIds, isEmpty);
    });

    test('toggle keeps the selection when the call fails', () async {
      when(() => repository.addRepo(2, 7)).thenThrow(NetworkException('offline'));
      final cubit = AddToCollectionCubit(repository, repoId: 7, currentCollectionIds: const []);

      expect(await cubit.toggle(2), 'offline');
      expect(cubit.state.selectedIds, isEmpty);
      expect(cubit.state.changed, isFalse);
    });

    test('createAndAdd creates the collection and selects it', () async {
      when(() => repository.createCollection(name: 'Mới')).thenAnswer((_) async => collection(4));
      when(() => repository.addRepo(4, 7)).thenAnswer((_) async {});
      when(() => repository.getCollections()).thenAnswer((_) async => Cached([collection(4)]));
      final cubit = AddToCollectionCubit(repository, repoId: 7, currentCollectionIds: const []);

      expect(await cubit.createAndAdd('Mới'), isNull);
      expect(cubit.state.selectedIds, {4});
      expect(cubit.state.collections, [collection(4)]);
    });
  });
}
