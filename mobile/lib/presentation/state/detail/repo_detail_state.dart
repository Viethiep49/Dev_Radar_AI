import 'package:equatable/equatable.dart';

import '../../../data/models/repo_detail_model.dart';
import '../../../data/models/repo_filters_model.dart';
import '../../../data/models/repo_model.dart';

enum RepoDetailStatus { loading, success, failure }

/// One-shot message for a SnackBar; [id] changes every time so the same text shows again.
class DetailFeedback extends Equatable {
  final int id;
  final String message;
  final bool isError;

  const DetailFeedback(this.id, this.message, {this.isError = false});

  @override
  List<Object?> get props => [id, message, isError];
}

class RepoDetailState extends Equatable {
  final RepoDetailStatus status;

  /// Basic info shown right away (from the list), replaced by detail.repo once loaded.
  final RepoModel? initialRepo;
  final RepoDetailModel? detail;

  final List<StarPointModel> stars;
  final bool starsLoading;

  final bool fromCache;
  final DateTime? cachedAt;
  final String? errorMessage;

  final bool watchBusy;
  final bool learningBusy;
  final bool summaryBusy;
  final DetailFeedback? feedback;

  const RepoDetailState({
    this.status = RepoDetailStatus.loading,
    this.initialRepo,
    this.detail,
    this.stars = const [],
    this.starsLoading = true,
    this.fromCache = false,
    this.cachedAt,
    this.errorMessage,
    this.watchBusy = false,
    this.learningBusy = false,
    this.summaryBusy = false,
    this.feedback,
  });

  RepoModel? get repo => detail?.repo ?? initialRepo;

  RepoDetailState copyWith({
    RepoDetailStatus? status,
    RepoDetailModel? detail,
    List<StarPointModel>? stars,
    bool? starsLoading,
    bool? fromCache,
    DateTime? Function()? cachedAt,
    String? Function()? errorMessage,
    bool? watchBusy,
    bool? learningBusy,
    bool? summaryBusy,
    DetailFeedback? feedback,
  }) {
    return RepoDetailState(
      status: status ?? this.status,
      initialRepo: initialRepo,
      detail: detail ?? this.detail,
      stars: stars ?? this.stars,
      starsLoading: starsLoading ?? this.starsLoading,
      fromCache: fromCache ?? this.fromCache,
      cachedAt: cachedAt != null ? cachedAt() : this.cachedAt,
      errorMessage: errorMessage != null ? errorMessage() : this.errorMessage,
      watchBusy: watchBusy ?? this.watchBusy,
      learningBusy: learningBusy ?? this.learningBusy,
      summaryBusy: summaryBusy ?? this.summaryBusy,
      feedback: feedback ?? this.feedback,
    );
  }

  @override
  List<Object?> get props => [
        status,
        initialRepo,
        detail,
        stars,
        starsLoading,
        fromCache,
        cachedAt,
        errorMessage,
        watchBusy,
        learningBusy,
        summaryBusy,
        feedback,
      ];
}
