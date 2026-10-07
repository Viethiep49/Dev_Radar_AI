import 'package:bloc_test/bloc_test.dart';
import 'package:dev_radar_ai/core/network/api_exceptions.dart';
import 'package:dev_radar_ai/data/models/repo_filters_model.dart';
import 'package:dev_radar_ai/data/repositories/cache_policy.dart';
import 'package:dev_radar_ai/data/repositories/repo_repository.dart';
import 'package:dev_radar_ai/presentation/state/feed/feed_bloc.dart';
import 'package:dev_radar_ai/presentation/state/feed/feed_event.dart';
import 'package:dev_radar_ai/presentation/state/feed/feed_state.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../helpers/repo_fixtures.dart';

class MockRepoRepository extends Mock implements RepoRepository {}

void main() {
  late MockRepoRepository repository;

  const filters = RepoFiltersModel(languages: [
    FilterOption(name: 'Dart', count: 5),
    FilterOption(name: 'Go', count: 2),
  ]);

  setUpAll(() => registerFallbackValue(RepoSort.stars));

  setUp(() {
    repository = MockRepoRepository();
    when(() => repository.getFilters()).thenAnswer((_) async => const Cached(filters));
  });

  blocTest<FeedBloc, FeedState>(
    'FeedStarted loads the personalised feed and the language chips',
    build: () {
      when(() => repository.getFeed(page: 1)).thenAnswer((_) async => Cached(repoPage([1, 2], total: 40)));
      return FeedBloc(repoRepository: repository);
    },
    act: (bloc) => bloc.add(const FeedStarted()),
    verify: (bloc) {
      final state = bloc.state;
      expect(state.status, FeedStatus.success);
      expect(state.repos.map((r) => r.id), [1, 2]);
      expect(state.hasMore, isTrue);
      expect(state.languages, ['Dart', 'Go']);
    },
  );

  blocTest<FeedBloc, FeedState>(
    'shows the offline banner data and stops paging when the feed comes from cache',
    build: () {
      when(() => repository.getFeed(page: 1)).thenAnswer(
        (_) async => Cached(repoPage([1], total: 40), fromCache: true, cachedAt: DateTime(2026, 10, 8)),
      );
      return FeedBloc(repoRepository: repository);
    },
    act: (bloc) => bloc.add(const FeedStarted()),
    verify: (bloc) {
      expect(bloc.state.fromCache, isTrue);
      expect(bloc.state.hasMore, isFalse);
    },
  );

  blocTest<FeedBloc, FeedState>(
    'emits failure when the first page cannot be loaded',
    build: () {
      when(() => repository.getFeed(page: 1)).thenThrow(NetworkException('Mất mạng'));
      return FeedBloc(repoRepository: repository);
    },
    act: (bloc) => bloc.add(const FeedStarted()),
    verify: (bloc) {
      expect(bloc.state.status, FeedStatus.failure);
      expect(bloc.state.errorMessage, 'Mất mạng');
    },
  );

  blocTest<FeedBloc, FeedState>(
    'load more appends the next page',
    build: () {
      when(() => repository.getFeed(page: 1)).thenAnswer((_) async => Cached(repoPage([1, 2], limit: 2, total: 3)));
      when(() => repository.getFeed(page: 2))
          .thenAnswer((_) async => Cached(repoPage([3], page: 2, limit: 2, total: 3)));
      return FeedBloc(repoRepository: repository);
    },
    act: (bloc) async {
      bloc.add(const FeedStarted());
      await Future<void>.delayed(Duration.zero);
      bloc.add(const FeedLoadMoreRequested());
    },
    wait: const Duration(milliseconds: 10),
    verify: (bloc) {
      expect(bloc.state.repos.map((r) => r.id), [1, 2, 3]);
      expect(bloc.state.page, 2);
      expect(bloc.state.hasMore, isFalse);
      expect(bloc.state.isLoadingMore, isFalse);
    },
  );

  blocTest<FeedBloc, FeedState>(
    'a language chip loads trending repos of that language',
    build: () {
      when(() => repository.getFeed(page: 1)).thenAnswer((_) async => Cached(repoPage([1])));
      when(() => repository.searchRepos(language: 'Go', sort: RepoSort.trending, page: 1))
          .thenAnswer((_) async => Cached(repoPage([9])));
      return FeedBloc(repoRepository: repository);
    },
    act: (bloc) async {
      bloc.add(const FeedStarted());
      await Future<void>.delayed(Duration.zero);
      bloc.add(const FeedLanguageSelected('Go'));
    },
    wait: const Duration(milliseconds: 10),
    verify: (bloc) {
      expect(bloc.state.language, 'Go');
      expect(bloc.state.repos.single.id, 9);
    },
  );
}
