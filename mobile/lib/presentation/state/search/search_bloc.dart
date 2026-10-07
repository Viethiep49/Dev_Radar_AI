import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../data/repositories/repo_repository.dart';
import 'search_event.dart';
import 'search_state.dart';

/// Search repos by text + language/topic filters + sort, paginated.
/// Typing is debounced so the API is called once the user pauses.
class SearchBloc extends Bloc<SearchEvent, SearchState> {
  static const Duration debounceDuration = Duration(milliseconds: 400);

  final RepoRepository repoRepository;
  final Duration debounce;

  Timer? _debounceTimer;
  int _generation = 0;

  SearchBloc({required this.repoRepository, this.debounce = debounceDuration}) : super(const SearchState()) {
    on<SearchStarted>(_onStarted);
    on<SearchQueryChanged>(_onQueryChanged);
    on<SearchDebounceElapsed>((event, emit) => _search(emit));
    on<SearchSubmitted>(_onSubmitted);
    on<SearchFiltersChanged>(_onFiltersChanged);
    on<SearchRetried>((event, emit) => _search(emit));
    on<SearchLoadMoreRequested>(_onLoadMore);
  }

  Future<void> _onStarted(SearchStarted event, Emitter<SearchState> emit) async {
    try {
      final filters = await repoRepository.getFilters();
      emit(state.copyWith(filters: filters.data));
    } catch (_) {
      // Without filter options the text search still works.
    }
  }

  void _onQueryChanged(SearchQueryChanged event, Emitter<SearchState> emit) {
    if (event.query == state.query) return;
    emit(state.copyWith(query: event.query));
    _debounceTimer?.cancel();
    _debounceTimer = Timer(debounce, () {
      if (!isClosed) add(const SearchDebounceElapsed());
    });
  }

  Future<void> _onSubmitted(SearchSubmitted event, Emitter<SearchState> emit) async {
    _debounceTimer?.cancel();
    emit(state.copyWith(query: event.query));
    await _search(emit);
  }

  Future<void> _onFiltersChanged(SearchFiltersChanged event, Emitter<SearchState> emit) async {
    _debounceTimer?.cancel();
    emit(state.copyWith(language: () => event.language, topic: () => event.topic, sort: event.sort));
    await _search(emit);
  }

  Future<void> _search(Emitter<SearchState> emit) async {
    final generation = ++_generation;
    if (!state.hasCriteria) {
      emit(state.copyWith(
        status: SearchStatus.idle,
        results: const [],
        page: 0,
        total: 0,
        hasMore: false,
        isLoadingMore: false,
        fromCache: false,
        errorMessage: () => null,
      ));
      return;
    }
    emit(state.copyWith(status: SearchStatus.loading, errorMessage: () => null, loadMoreError: () => null));
    try {
      final result = await repoRepository.searchRepos(
        query: state.query,
        language: state.language,
        topic: state.topic,
        sort: state.sort,
      );
      if (generation != _generation) return;
      emit(state.copyWith(
        status: SearchStatus.success,
        results: result.data.items,
        page: 1,
        total: result.data.total,
        hasMore: !result.fromCache && result.data.hasMore,
        isLoadingMore: false,
        fromCache: result.fromCache,
        cachedAt: () => result.cachedAt,
      ));
    } catch (e) {
      if (generation != _generation) return;
      emit(state.copyWith(status: SearchStatus.failure, errorMessage: () => e.toString()));
    }
  }

  Future<void> _onLoadMore(SearchLoadMoreRequested event, Emitter<SearchState> emit) async {
    if (state.status != SearchStatus.success || state.isLoadingMore || !state.hasMore) return;
    final generation = _generation;
    final nextPage = state.page + 1;
    emit(state.copyWith(isLoadingMore: true, loadMoreError: () => null));
    try {
      final result = await repoRepository.searchRepos(
        query: state.query,
        language: state.language,
        topic: state.topic,
        sort: state.sort,
        page: nextPage,
      );
      if (generation != _generation) return;
      emit(state.copyWith(
        results: [...state.results, ...result.data.items],
        page: nextPage,
        hasMore: result.data.hasMore && result.data.items.isNotEmpty,
        isLoadingMore: false,
      ));
    } catch (e) {
      if (generation != _generation) return;
      emit(state.copyWith(isLoadingMore: false, loadMoreError: () => e.toString()));
    }
  }

  @override
  Future<void> close() {
    _debounceTimer?.cancel();
    return super.close();
  }
}
