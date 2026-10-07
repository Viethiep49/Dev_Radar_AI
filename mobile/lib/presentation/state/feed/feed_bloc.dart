import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../data/models/page_model.dart';
import '../../../data/models/repo_filters_model.dart';
import '../../../data/models/repo_model.dart';
import '../../../data/repositories/cache_policy.dart';
import '../../../data/repositories/repo_repository.dart';
import 'feed_event.dart';
import 'feed_state.dart';

/// Home feed: "Dành cho bạn" (GET /repos/feed) or one language (GET /repos?language=, trending),
/// with pull-to-refresh and infinite scroll.
class FeedBloc extends Bloc<FeedEvent, FeedState> {
  static const int maxLanguageChips = 8;

  final RepoRepository repoRepository;

  /// Increases on every new first-page load, so a slow old response is ignored.
  int _generation = 0;

  FeedBloc({required this.repoRepository}) : super(const FeedState()) {
    on<FeedStarted>(_onStarted);
    on<FeedRefreshed>(_onRefreshed);
    on<FeedLanguageSelected>(_onLanguageSelected);
    on<FeedLoadMoreRequested>(_onLoadMore);
  }

  Future<Cached<PageModel<RepoModel>>> _fetch(String? language, int page) {
    if (language == null) return repoRepository.getFeed(page: page);
    return repoRepository.searchRepos(language: language, sort: RepoSort.trending, page: page);
  }

  Future<void> _onStarted(FeedStarted event, Emitter<FeedState> emit) async {
    await Future.wait([_loadFirstPage(emit, showLoading: true), _loadLanguages(emit)]);
  }

  Future<void> _onRefreshed(FeedRefreshed event, Emitter<FeedState> emit) async {
    final showLoading = state.repos.isEmpty;
    await Future.wait([
      _loadFirstPage(emit, showLoading: showLoading),
      if (state.languages.isEmpty) _loadLanguages(emit),
    ]);
  }

  Future<void> _onLanguageSelected(FeedLanguageSelected event, Emitter<FeedState> emit) async {
    if (event.language == state.language && state.status == FeedStatus.success) return;
    emit(state.copyWith(language: () => event.language));
    await _loadFirstPage(emit, showLoading: true);
  }

  Future<void> _loadFirstPage(Emitter<FeedState> emit, {required bool showLoading}) async {
    final generation = ++_generation;
    final language = state.language;
    if (showLoading) {
      emit(state.copyWith(status: FeedStatus.loading, repos: const [], errorMessage: () => null));
    }
    try {
      final result = await _fetch(language, 1);
      if (generation != _generation) return;
      emit(state.copyWith(
        status: FeedStatus.success,
        repos: result.data.items,
        page: 1,
        // Older pages are not cached, so do not try to page offline.
        hasMore: !result.fromCache && result.data.hasMore,
        isLoadingMore: false,
        fromCache: result.fromCache,
        cachedAt: () => result.cachedAt,
        errorMessage: () => null,
        loadMoreError: () => null,
      ));
    } catch (e) {
      if (generation != _generation) return;
      if (state.repos.isNotEmpty && !showLoading) {
        // Refresh failed: keep the list, just report it.
        emit(state.copyWith(loadMoreError: () => e.toString()));
      } else {
        emit(state.copyWith(status: FeedStatus.failure, errorMessage: () => e.toString()));
      }
    }
  }

  Future<void> _onLoadMore(FeedLoadMoreRequested event, Emitter<FeedState> emit) async {
    if (state.status != FeedStatus.success || state.isLoadingMore || !state.hasMore) return;
    final generation = _generation;
    final nextPage = state.page + 1;
    emit(state.copyWith(isLoadingMore: true, loadMoreError: () => null));
    try {
      final result = await _fetch(state.language, nextPage);
      if (generation != _generation) return;
      emit(state.copyWith(
        repos: [...state.repos, ...result.data.items],
        page: nextPage,
        hasMore: result.data.hasMore && result.data.items.isNotEmpty,
        isLoadingMore: false,
      ));
    } catch (e) {
      if (generation != _generation) return;
      emit(state.copyWith(isLoadingMore: false, loadMoreError: () => e.toString()));
    }
  }

  Future<void> _loadLanguages(Emitter<FeedState> emit) async {
    try {
      final filters = await repoRepository.getFilters();
      emit(state.copyWith(
        languages: filters.data.languages.take(maxLanguageChips).map((l) => l.name).toList(),
      ));
    } catch (_) {
      // Chips are optional; the feed still works without them.
    }
  }
}
