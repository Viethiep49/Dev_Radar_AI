import 'package:bloc_test/bloc_test.dart';
import 'package:dev_radar_ai/core/network/api_exceptions.dart';
import 'package:dev_radar_ai/data/datasources/local/cache_local_datasource.dart';
import 'package:dev_radar_ai/data/datasources/remote/learning_remote_datasource.dart';
import 'package:dev_radar_ai/data/models/learning_model.dart';
import 'package:dev_radar_ai/data/repositories/cache_policy.dart';
import 'package:dev_radar_ai/data/repositories/learning_repository.dart';
import 'package:dev_radar_ai/presentation/state/learning/learning_cubit.dart';
import 'package:dev_radar_ai/presentation/state/load_status.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../helpers/library_fixtures.dart';

class MockLearningRemote extends Mock implements LearningRemoteDataSource {}

class MockLearningRepository extends Mock implements LearningRepository {}

LearningItemModel item(int id, {String status = 'learning'}) =>
    LearningItemModel.fromJson(learningJson(id, repoId: id, status: status));

void main() {
  group('LearningRepositoryImpl', () {
    late MockLearningRemote remote;
    late MemoryCacheLocalDataSource cache;
    late LearningRepositoryImpl repository;

    setUp(() {
      remote = MockLearningRemote();
      cache = MemoryCacheLocalDataSource();
      repository = LearningRepositoryImpl(remoteDataSource: remote, cache: cache);
    });

    test('getItems sends the backend status value and parses items', () async {
      when(() => remote.getItemsPage(status: 'used', page: 1))
          .thenAnswer((_) async => pageJson([learningJson(1, status: 'used')]));

      final result = await repository.getItems(status: LearningStatus.used);

      expect(result.data.single.status, LearningStatus.used);
      expect(result.data.single.completedAt, isNotNull);
      expect(await cache.get(LearningRepositoryImpl.listKey(LearningStatus.used)), isNotNull);
    });

    test('getItems uses the cache when offline', () async {
      when(() => remote.getItemsPage(status: null, page: 1)).thenAnswer((_) async => pageJson([learningJson(1)]));
      await repository.getItems();
      when(() => remote.getItemsPage(status: null, page: 1)).thenThrow(TimeoutException());

      final result = await repository.getItems();

      expect(result.fromCache, isTrue);
      expect(result.data.single.id, 1);
    });

    test('setStatus uses PUT, null uses DELETE, both clear the learning cache', () async {
      when(() => remote.setStatus(4, 'want_to_try')).thenAnswer((_) async {});
      when(() => remote.deleteStatus(4)).thenAnswer((_) async {});

      await cache.put(LearningRepositoryImpl.listKey(null), pageJson([]));
      await repository.setStatus(4, LearningStatus.wantToTry);
      expect(await cache.get(LearningRepositoryImpl.listKey(null)), isNull);

      await cache.put(LearningRepositoryImpl.listKey(LearningStatus.learning), pageJson([]));
      await repository.setStatus(4, null);
      expect(await cache.get(LearningRepositoryImpl.listKey(LearningStatus.learning)), isNull);

      verify(() => remote.setStatus(4, 'want_to_try')).called(1);
      verify(() => remote.deleteStatus(4)).called(1);
    });
  });

  group('LearningCubit', () {
    late MockLearningRepository repository;

    setUp(() => repository = MockLearningRepository());

    blocTest<LearningCubit, LearningState>(
      'setFilter reloads with that status',
      setUp: () => when(() => repository.getItems(status: LearningStatus.used))
          .thenAnswer((_) async => Cached([item(2, status: 'used')])),
      build: () => LearningCubit(repository),
      act: (cubit) => cubit.setFilter(LearningStatus.used),
      expect: () => [
        const LearningState(status: LoadStatus.loading, filter: LearningStatus.used),
        LearningState(status: LoadStatus.success, filter: LearningStatus.used, items: [item(2, status: 'used')]),
      ],
    );

    test('changeStatus calls the repository and reloads', () async {
      when(() => repository.setStatus(1, LearningStatus.used)).thenAnswer((_) async {});
      when(() => repository.getItems(status: null)).thenAnswer((_) async => Cached([item(1, status: 'used')]));
      final cubit = LearningCubit(repository);

      expect(await cubit.changeStatus(1, LearningStatus.used), isNull);
      expect(cubit.state.items.single.status, LearningStatus.used);
    });

    test('remove returns the error message on failure', () async {
      when(() => repository.setStatus(1, null)).thenThrow(NetworkException('offline'));
      final cubit = LearningCubit(repository);

      expect(await cubit.remove(1), 'offline');
    });
  });
}
