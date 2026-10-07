import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../data/repositories/repo_repository.dart';
import 'repo_event.dart';
import 'repo_state.dart';

class RepoBloc extends Bloc<RepoEvent, RepoState> {
  final RepoRepository repoRepository;

  RepoBloc({required this.repoRepository}) : super(RepoInitial()) {
    on<FetchTrendingReposRequested>(_onFetchTrendingReposRequested);
    on<SearchReposRequested>(_onSearchReposRequested);
  }

  Future<void> _onFetchTrendingReposRequested(
    FetchTrendingReposRequested event,
    Emitter<RepoState> emit,
  ) async {
    if (!event.isRefresh) {
      emit(RepoLoading());
    }
    try {
      final repos = await repoRepository.getTrendingRepos(
        language: event.language,
      );
      emit(RepoLoaded(repos: repos, selectedLanguage: event.language));
    } catch (e) {
      emit(RepoFailure(e.toString()));
    }
  }

  Future<void> _onSearchReposRequested(
    SearchReposRequested event,
    Emitter<RepoState> emit,
  ) async {
    if (event.query.trim().isEmpty) {
      add(const FetchTrendingReposRequested());
      return;
    }
    emit(RepoLoading());
    try {
      final repos = await repoRepository.searchRepos(event.query);
      emit(RepoLoaded(repos: repos));
    } catch (e) {
      emit(RepoFailure(e.toString()));
    }
  }
}
