import 'package:bloc_test/bloc_test.dart';
import 'package:dev_radar_ai/core/network/api_exceptions.dart';
import 'package:dev_radar_ai/data/models/learning_model.dart';
import 'package:dev_radar_ai/data/models/repo_detail_model.dart';
import 'package:dev_radar_ai/data/models/repo_filters_model.dart';
import 'package:dev_radar_ai/data/repositories/cache_policy.dart';
import 'package:dev_radar_ai/data/repositories/learning_repository.dart';
import 'package:dev_radar_ai/data/repositories/repo_repository.dart';
import 'package:dev_radar_ai/data/repositories/watchlist_repository.dart';
import 'package:dev_radar_ai/presentation/state/detail/repo_detail_cubit.dart';
import 'package:dev_radar_ai/presentation/state/detail/repo_detail_state.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../helpers/repo_fixtures.dart';

class MockRepoRepository extends Mock implements RepoRepository {}

class MockWatchlistRepository extends Mock implements WatchlistRepository {}

class MockLearningRepository extends Mock implements LearningRepository {}

void main() {
  late MockRepoRepository repos;
  late MockWatchlistRepository watchlist;
  late MockLearningRepository learning;

  setUpAll(() => registerFallbackValue(LearningStatus.learning));

  setUp(() {
    repos = MockRepoRepository();
    watchlist = MockWatchlistRepository();
    learning = MockLearningRepository();
    when(() => repos.getRepoDetail(1)).thenAnswer((_) async => Cached(RepoDetailModel.fromJson(detailJson(1))));
    when(() => repos.getStarHistory(1)).thenAnswer(
      (_) async => Cached([StarPointModel(date: DateTime(2026, 10, 1), stars: 5)]),
    );
  });

  RepoDetailCubit build() => RepoDetailCubit(
        repoId: 1,
        initialRepo: repoModel(1),
        repoRepository: repos,
        watchlistRepository: watchlist,
        learningRepository: learning,
      );

  test('starts with the repo from the list so the header shows immediately', () {
    final cubit = build();
    expect(cubit.state.repo?.id, 1);
    expect(cubit.state.status, RepoDetailStatus.loading);
    cubit.close();
  });

  blocTest<RepoDetailCubit, RepoDetailState>(
    'load fetches detail and star history',
    build: build,
    act: (cubit) => cubit.load(),
    verify: (cubit) {
      expect(cubit.state.status, RepoDetailStatus.success);
      expect(cubit.state.detail?.summary, 'A great repo');
      expect(cubit.state.stars.single.stars, 5);
      expect(cubit.state.starsLoading, isFalse);
    },
  );

  blocTest<RepoDetailCubit, RepoDetailState>(
    'load failure without data shows an error',
    build: () {
      when(() => repos.getRepoDetail(1)).thenThrow(NetworkException('offline'));
      return build();
    },
    act: (cubit) => cubit.load(),
    verify: (cubit) {
      expect(cubit.state.status, RepoDetailStatus.failure);
      expect(cubit.state.errorMessage, 'offline');
    },
  );

  blocTest<RepoDetailCubit, RepoDetailState>(
    'toggleWatch is optimistic and calls watch()',
    build: () {
      when(() => watchlist.watch(1)).thenAnswer((_) async {});
      return build();
    },
    act: (cubit) async {
      await cubit.load();
      await cubit.toggleWatch();
    },
    verify: (cubit) {
      expect(cubit.state.detail!.isWatched, isTrue);
      expect(cubit.state.watchBusy, isFalse);
      expect(cubit.state.feedback?.isError, isFalse);
      verify(() => watchlist.watch(1)).called(1);
    },
  );

  blocTest<RepoDetailCubit, RepoDetailState>(
    'toggleWatch reverts and reports when the API fails',
    build: () {
      when(() => watchlist.watch(1)).thenThrow(ApiException('Lỗi server', statusCode: 500));
      return build();
    },
    act: (cubit) async {
      await cubit.load();
      await cubit.toggleWatch();
    },
    verify: (cubit) {
      expect(cubit.state.detail!.isWatched, isFalse);
      expect(cubit.state.feedback?.isError, isTrue);
      expect(cubit.state.feedback?.message, 'Lỗi server');
    },
  );

  blocTest<RepoDetailCubit, RepoDetailState>(
    'setLearningStatus saves the new status, null clears it',
    build: () {
      when(() => learning.setStatus(1, any())).thenAnswer((_) async {});
      when(() => learning.setStatus(1, null)).thenAnswer((_) async {});
      return build();
    },
    act: (cubit) async {
      await cubit.load();
      await cubit.setLearningStatus(LearningStatus.used);
      expect(cubit.state.detail!.learningStatus, LearningStatus.used);
      await cubit.setLearningStatus(null);
    },
    verify: (cubit) {
      expect(cubit.state.detail!.learningStatus, isNull);
      verify(() => learning.setStatus(1, LearningStatus.used)).called(1);
      verify(() => learning.setStatus(1, null)).called(1);
    },
  );

  blocTest<RepoDetailCubit, RepoDetailState>(
    'setLearningStatus reverts on error',
    build: () {
      when(() => learning.setStatus(1, any())).thenThrow(NetworkException('offline'));
      return build();
    },
    act: (cubit) async {
      await cubit.load();
      await cubit.setLearningStatus(LearningStatus.learning);
    },
    verify: (cubit) {
      expect(cubit.state.detail!.learningStatus, isNull);
      expect(cubit.state.feedback?.isError, isTrue);
    },
  );
}
