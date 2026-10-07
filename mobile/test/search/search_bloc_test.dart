import 'package:bloc_test/bloc_test.dart';
import 'package:dev_radar_ai/core/network/api_exceptions.dart';
import 'package:dev_radar_ai/data/models/repo_filters_model.dart';
import 'package:dev_radar_ai/data/repositories/cache_policy.dart';
import 'package:dev_radar_ai/data/repositories/repo_repository.dart';
import 'package:dev_radar_ai/presentation/state/search/search_bloc.dart';
import 'package:dev_radar_ai/presentation/state/search/search_event.dart';
import 'package:dev_radar_ai/presentation/state/search/search_state.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../helpers/repo_fixtures.dart';

class MockRepoRepository extends Mock implements RepoRepository {}

void main() {
  late MockRepoRepository repository;
  const debounce = Duration(milliseconds: 20);

  setUpAll(() => registerFallbackValue(RepoSort.stars));

  setUp(() => repository = MockRepoRepository());

  SearchBloc build() => SearchBloc(repoRepository: repository, debounce: debounce);

  void stubSearch({String? query, String? language, String? topic, RepoSort sort = RepoSort.stars, int page = 1, required List<int> ids, int total = 1}) {
    when(() => repository.searchRepos(query: query, language: language, topic: topic, sort: sort, page: page))
        .thenAnswer((_) async => Cached(repoPage(ids, page: page, limit: 1, total: total)));
  }

  blocTest<SearchBloc, SearchState>(
    'typing is debounced: only the last text is searched',
    build: () {
      stubSearch(query: 'flutter', ids: [1]);
      return build();
    },
    act: (bloc) {
      bloc.add(const SearchQueryChanged('f'));
      bloc.add(const SearchQueryChanged('flu'));
      bloc.add(const SearchQueryChanged('flutter'));
    },
    wait: const Duration(milliseconds: 80),
    verify: (bloc) {
      expect(bloc.state.status, SearchStatus.success);
      expect(bloc.state.results.single.id, 1);
      verify(() => repository.searchRepos(query: 'flutter', language: null, topic: null, sort: RepoSort.stars, page: 1))
          .called(1);
      verifyNever(() => repository.searchRepos(query: 'f', language: any(named: 'language'), topic: any(named: 'topic'), sort: any(named: 'sort'), page: any(named: 'page')));
    },
  );

  blocTest<SearchBloc, SearchState>(
    'clearing the text and filters goes back to idle without calling the API',
    build: build,
    act: (bloc) => bloc.add(const SearchSubmitted('')),
    expect: () => [const SearchState()],
    verify: (_) => verifyNever(() => repository.searchRepos(
          query: any(named: 'query'),
          language: any(named: 'language'),
          topic: any(named: 'topic'),
          sort: any(named: 'sort'),
          page: any(named: 'page'),
        )),
  );

  blocTest<SearchBloc, SearchState>(
    'filters alone trigger a search with language, topic and sort',
    build: () {
      stubSearch(query: '', language: 'Dart', topic: 'ui', sort: RepoSort.newest, ids: [5]);
      return build();
    },
    act: (bloc) => bloc.add(const SearchFiltersChanged(language: 'Dart', topic: 'ui', sort: RepoSort.newest)),
    verify: (bloc) {
      expect(bloc.state.results.single.id, 5);
      expect(bloc.state.activeFilterCount, 3);
    },
  );

  blocTest<SearchBloc, SearchState>(
    'load more fetches the next page',
    build: () {
      stubSearch(query: 'x', ids: [1], total: 2);
      stubSearch(query: 'x', page: 2, ids: [2], total: 2);
      return build();
    },
    act: (bloc) async {
      bloc.add(const SearchSubmitted('x'));
      await Future<void>.delayed(Duration.zero);
      bloc.add(const SearchLoadMoreRequested());
    },
    wait: const Duration(milliseconds: 10),
    verify: (bloc) {
      expect(bloc.state.results.map((r) => r.id), [1, 2]);
      expect(bloc.state.hasMore, isFalse);
    },
  );

  blocTest<SearchBloc, SearchState>(
    'an API error shows failure, retry searches again',
    build: () {
      var calls = 0;
      when(() => repository.searchRepos(query: 'x', language: null, topic: null, sort: RepoSort.stars, page: 1))
          .thenAnswer((_) async {
        if (calls++ == 0) throw TimeoutException();
        return Cached(repoPage([3]));
      });
      return build();
    },
    act: (bloc) async {
      bloc.add(const SearchSubmitted('x'));
      await Future<void>.delayed(Duration.zero);
      expect(bloc.state.status, SearchStatus.failure);
      bloc.add(const SearchRetried());
    },
    wait: const Duration(milliseconds: 10),
    verify: (bloc) => expect(bloc.state.results.single.id, 3),
  );

  blocTest<SearchBloc, SearchState>(
    'SearchStarted loads the filter options',
    build: () {
      when(() => repository.getFilters()).thenAnswer(
        (_) async => const Cached(RepoFiltersModel(topics: [FilterOption(name: 'ai', count: 4)])),
      );
      return build();
    },
    act: (bloc) => bloc.add(const SearchStarted()),
    verify: (bloc) => expect(bloc.state.filters.topics.single.name, 'ai'),
  );
}
