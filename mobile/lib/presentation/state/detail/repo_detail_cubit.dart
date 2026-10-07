import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../data/models/learning_model.dart';
import '../../../data/models/repo_model.dart';
import '../../../data/repositories/learning_repository.dart';
import '../../../data/repositories/repo_repository.dart';
import '../../../data/repositories/watchlist_repository.dart';
import 'repo_detail_state.dart';

/// Repo detail screen: detail + star chart, watch toggle, learning status.
class RepoDetailCubit extends Cubit<RepoDetailState> {
  final int repoId;
  final RepoRepository repoRepository;
  final WatchlistRepository watchlistRepository;
  final LearningRepository learningRepository;

  int _feedbackId = 0;

  RepoDetailCubit({
    required this.repoId,
    RepoModel? initialRepo,
    required this.repoRepository,
    required this.watchlistRepository,
    required this.learningRepository,
  }) : super(RepoDetailState(initialRepo: initialRepo));

  Future<void> load() async {
    await Future.wait([_loadDetail(showLoading: true), _loadStars()]);
  }

  /// Reload silently, e.g. after the "add to collection" sheet changed the collections.
  Future<void> refresh() => _loadDetail(showLoading: false);

  Future<void> _loadDetail({required bool showLoading}) async {
    if (showLoading) {
      emit(state.copyWith(status: RepoDetailStatus.loading, errorMessage: () => null));
    }
    try {
      final result = await repoRepository.getRepoDetail(repoId);
      if (isClosed) return;
      emit(state.copyWith(
        status: RepoDetailStatus.success,
        detail: result.data,
        fromCache: result.fromCache,
        cachedAt: () => result.cachedAt,
        errorMessage: () => null,
      ));
    } catch (e) {
      if (isClosed) return;
      if (state.detail != null) {
        emit(state.copyWith(feedback: _feedback(e.toString(), isError: true)));
      } else {
        emit(state.copyWith(status: RepoDetailStatus.failure, errorMessage: () => e.toString()));
      }
    }
  }

  Future<void> _loadStars() async {
    try {
      final result = await repoRepository.getStarHistory(repoId);
      if (isClosed) return;
      emit(state.copyWith(stars: result.data, starsLoading: false));
    } catch (_) {
      if (isClosed) return;
      emit(state.copyWith(stars: const [], starsLoading: false)); // chart shows "no data"
    }
  }

  /// Optimistic: flips the flag first, reverts if the API call fails.
  Future<void> toggleWatch() async {
    final detail = state.detail;
    if (detail == null || state.watchBusy) return;
    final watch = !detail.isWatched;
    emit(state.copyWith(detail: detail.copyWith(isWatched: watch), watchBusy: true));
    try {
      if (watch) {
        await watchlistRepository.watch(repoId);
      } else {
        await watchlistRepository.unwatch(repoId);
      }
      if (isClosed) return;
      emit(state.copyWith(
        watchBusy: false,
        feedback: _feedback(watch
            ? 'Đã theo dõi – bạn sẽ được báo khi có bản phát hành mới'
            : 'Đã bỏ theo dõi'),
      ));
    } catch (e) {
      if (isClosed) return;
      emit(state.copyWith(
        detail: state.detail!.copyWith(isWatched: !watch),
        watchBusy: false,
        feedback: _feedback(e.toString(), isError: true),
      ));
    }
  }

  /// Sets the learning status; tapping the current status again clears it (pass null).
  Future<void> setLearningStatus(LearningStatus? status) async {
    final detail = state.detail;
    if (detail == null || state.learningBusy) return;
    final previous = detail.learningStatus;
    if (previous == status) return;
    emit(state.copyWith(detail: detail.copyWith(learningStatus: () => status), learningBusy: true));
    try {
      await learningRepository.setStatus(repoId, status);
      if (isClosed) return;
      emit(state.copyWith(
        learningBusy: false,
        feedback: _feedback(status == null ? 'Đã xoá trạng thái học tập' : 'Đã chuyển sang "${status.label}"'),
      ));
    } catch (e) {
      if (isClosed) return;
      emit(state.copyWith(
        detail: state.detail!.copyWith(learningStatus: () => previous),
        learningBusy: false,
        feedback: _feedback(e.toString(), isError: true),
      ));
    }
  }

  DetailFeedback _feedback(String message, {bool isError = false}) =>
      DetailFeedback(++_feedbackId, message, isError: isError);
}
