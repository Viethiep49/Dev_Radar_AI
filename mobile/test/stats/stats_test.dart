import 'package:bloc_test/bloc_test.dart';
import 'package:dev_radar_ai/core/network/api_exceptions.dart';
import 'package:dev_radar_ai/data/datasources/local/cache_local_datasource.dart';
import 'package:dev_radar_ai/data/datasources/remote/stats_remote_datasource.dart';
import 'package:dev_radar_ai/data/models/stats_model.dart';
import 'package:dev_radar_ai/data/repositories/cache_policy.dart';
import 'package:dev_radar_ai/data/repositories/stats_repository.dart';
import 'package:dev_radar_ai/presentation/state/stats/stats_cubit.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockStatsRemote extends Mock implements StatsRemoteDataSource {}

class MockStatsRepository extends Mock implements StatsRepository {}

const overviewJson = {
  'total_repos': 6,
  'by_status': {'want_to_try': 3, 'learning': 2, 'used': 1},
  'collections_count': 2,
  'notes_count': 4,
  'completed_this_week': 1,
};

const overview = StatsOverviewModel(
  totalRepos: 6,
  wantToTry: 3,
  learning: 2,
  used: 1,
  collectionsCount: 2,
  notesCount: 4,
  completedThisWeek: 1,
);

void main() {
  group('StatsRepositoryImpl', () {
    late MockStatsRemote remote;
    late MemoryCacheLocalDataSource cache;
    late StatsRepositoryImpl repository;

    setUp(() {
      remote = MockStatsRemote();
      cache = MemoryCacheLocalDataSource();
      repository = StatsRepositoryImpl(remoteDataSource: remote, cache: cache);
    });

    test('parses overview and caches it', () async {
      when(() => remote.getOverview()).thenAnswer((_) async => Map<String, dynamic>.from(overviewJson));

      final result = await repository.getOverview();

      expect(result.data, overview);
      expect(result.fromCache, isFalse);
      expect(await cache.get(StatsRepositoryImpl.overviewKey), isNotNull);
    });

    test('falls back to the cached overview when offline', () async {
      await cache.put(StatsRepositoryImpl.overviewKey, overviewJson);
      when(() => remote.getOverview()).thenThrow(NetworkException());

      final result = await repository.getOverview();

      expect(result.fromCache, isTrue);
      expect(result.data.totalRepos, 6);
    });

    test('rethrows when offline and nothing is cached', () {
      when(() => remote.getOverview()).thenThrow(TimeoutException());
      expect(repository.getOverview(), throwsA(isA<TimeoutException>()));
    });

    test('weekly is sorted oldest first and languages most used first', () async {
      when(() => remote.getWeekly(weeks: 4)).thenAnswer((_) async => [
            {'week_start': '2026-09-28', 'completed': 1, 'started': 2},
            {'week_start': '2026-09-21', 'completed': 0, 'started': 1},
          ]);
      when(() => remote.getLanguages()).thenAnswer((_) async => [
            {'language': 'Go', 'count': 1},
            {'language': 'Dart', 'count': 5},
          ]);

      final weekly = await repository.getWeekly(weeks: 4);
      final languages = await repository.getLanguages();

      expect(weekly.data.first.weekStart, DateTime(2026, 9, 21));
      expect(languages.data.map((l) => l.language), ['Dart', 'Go']);
    });
  });

  group('StatsCubit', () {
    late MockStatsRepository repository;
    final weekly = [WeeklyStatModel(weekStart: DateTime(2026, 9, 21), completed: 1, started: 2)];
    const languages = [LanguageStatModel(language: 'Dart', count: 3)];

    setUp(() {
      repository = MockStatsRepository();
      when(() => repository.getOverview()).thenAnswer((_) async => const Cached(overview));
      when(() => repository.getWeekly(weeks: any(named: 'weeks'))).thenAnswer((_) async => Cached(weekly));
      when(() => repository.getLanguages()).thenAnswer((_) async => const Cached(languages));
    });

    blocTest<StatsCubit, StatsState>(
      'load emits loading then loaded with all three parts',
      build: () => StatsCubit(repository),
      act: (cubit) => cubit.load(),
      expect: () => [
        const StatsState(status: StatsStatus.loading),
        StatsState(status: StatsStatus.loaded, overview: overview, weekly: weekly, languages: languages),
      ],
    );

    blocTest<StatsCubit, StatsState>(
      'load marks the state as offline when any part comes from the cache',
      build: () {
        when(() => repository.getLanguages()).thenAnswer(
          (_) async => Cached(languages, fromCache: true, cachedAt: DateTime(2026, 10, 1)),
        );
        return StatsCubit(repository);
      },
      act: (cubit) => cubit.load(),
      skip: 1,
      verify: (cubit) {
        expect(cubit.state.fromCache, isTrue);
        expect(cubit.state.cachedAt, DateTime(2026, 10, 1));
      },
    );

    blocTest<StatsCubit, StatsState>(
      'load emits failure with the error message',
      build: () {
        when(() => repository.getOverview()).thenThrow(NetworkException('Mất mạng'));
        return StatsCubit(repository);
      },
      act: (cubit) => cubit.load(),
      expect: () => [
        const StatsState(status: StatsStatus.loading),
        const StatsState(status: StatsStatus.failure, errorMessage: 'Mất mạng'),
      ],
    );

    blocTest<StatsCubit, StatsState>(
      'changeWeeks reloads only the weekly chart',
      build: () => StatsCubit(repository),
      seed: () => StatsState(status: StatsStatus.loaded, overview: overview, weekly: weekly, languages: languages),
      act: (cubit) => cubit.changeWeeks(12),
      verify: (cubit) {
        expect(cubit.state.weeks, 12);
        verify(() => repository.getWeekly(weeks: 12)).called(1);
        verifyNever(() => repository.getOverview());
      },
    );

    test('isEmpty when the learning path is empty', () {
      const empty = StatsState(
        overview: StatsOverviewModel(
          totalRepos: 0,
          wantToTry: 0,
          learning: 0,
          used: 0,
          collectionsCount: 0,
          notesCount: 0,
          completedThisWeek: 0,
        ),
      );
      expect(empty.isEmpty, isTrue);
      expect(const StatsState(overview: overview).isEmpty, isFalse);
    });
  });
}
