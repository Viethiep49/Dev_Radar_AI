import 'package:equatable/equatable.dart';

import '../../../data/models/repo_model.dart';

enum FeedStatus { initial, loading, success, failure }

class FeedState extends Equatable {
  final FeedStatus status;
  final List<RepoModel> repos;

  /// null = "Dành cho bạn" (personalised feed), otherwise the chosen language.
  final String? language;

  /// Language chips (most common languages, from GET /repos/filters).
  final List<String> languages;

  final int page;
  final bool hasMore;
  final bool isLoadingMore;

  /// True when the shown page 1 comes from the SQLite cache.
  final bool fromCache;
  final DateTime? cachedAt;

  final String? errorMessage;

  /// Error of the last "load more" (the list stays visible).
  final String? loadMoreError;

  const FeedState({
    this.status = FeedStatus.initial,
    this.repos = const [],
    this.language,
    this.languages = const [],
    this.page = 0,
    this.hasMore = false,
    this.isLoadingMore = false,
    this.fromCache = false,
    this.cachedAt,
    this.errorMessage,
    this.loadMoreError,
  });

  FeedState copyWith({
    FeedStatus? status,
    List<RepoModel>? repos,
    String? Function()? language,
    List<String>? languages,
    int? page,
    bool? hasMore,
    bool? isLoadingMore,
    bool? fromCache,
    DateTime? Function()? cachedAt,
    String? Function()? errorMessage,
    String? Function()? loadMoreError,
  }) {
    return FeedState(
      status: status ?? this.status,
      repos: repos ?? this.repos,
      language: language != null ? language() : this.language,
      languages: languages ?? this.languages,
      page: page ?? this.page,
      hasMore: hasMore ?? this.hasMore,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      fromCache: fromCache ?? this.fromCache,
      cachedAt: cachedAt != null ? cachedAt() : this.cachedAt,
      errorMessage: errorMessage != null ? errorMessage() : this.errorMessage,
      loadMoreError: loadMoreError != null ? loadMoreError() : this.loadMoreError,
    );
  }

  @override
  List<Object?> get props => [
        status,
        repos,
        language,
        languages,
        page,
        hasMore,
        isLoadingMore,
        fromCache,
        cachedAt,
        errorMessage,
        loadMoreError,
      ];
}
