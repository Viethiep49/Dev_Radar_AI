import 'package:equatable/equatable.dart';

import '../../../data/models/repo_filters_model.dart';
import '../../../data/models/repo_model.dart';

/// idle = nothing to search yet (empty text, no filter): show topic suggestions.
enum SearchStatus { idle, loading, success, failure }

class SearchState extends Equatable {
  final SearchStatus status;
  final String query;
  final String? language;
  final String? topic;
  final RepoSort sort;

  final List<RepoModel> results;
  final int page;
  final int total;
  final bool hasMore;
  final bool isLoadingMore;

  final RepoFiltersModel filters;

  final bool fromCache;
  final DateTime? cachedAt;
  final String? errorMessage;
  final String? loadMoreError;

  const SearchState({
    this.status = SearchStatus.idle,
    this.query = '',
    this.language,
    this.topic,
    this.sort = RepoSort.stars,
    this.results = const [],
    this.page = 0,
    this.total = 0,
    this.hasMore = false,
    this.isLoadingMore = false,
    this.filters = const RepoFiltersModel(),
    this.fromCache = false,
    this.cachedAt,
    this.errorMessage,
    this.loadMoreError,
  });

  /// True when something should be searched (text or a filter).
  bool get hasCriteria => query.trim().isNotEmpty || language != null || topic != null;

  int get activeFilterCount => (language != null ? 1 : 0) + (topic != null ? 1 : 0) + (sort != RepoSort.stars ? 1 : 0);

  SearchState copyWith({
    SearchStatus? status,
    String? query,
    String? Function()? language,
    String? Function()? topic,
    RepoSort? sort,
    List<RepoModel>? results,
    int? page,
    int? total,
    bool? hasMore,
    bool? isLoadingMore,
    RepoFiltersModel? filters,
    bool? fromCache,
    DateTime? Function()? cachedAt,
    String? Function()? errorMessage,
    String? Function()? loadMoreError,
  }) {
    return SearchState(
      status: status ?? this.status,
      query: query ?? this.query,
      language: language != null ? language() : this.language,
      topic: topic != null ? topic() : this.topic,
      sort: sort ?? this.sort,
      results: results ?? this.results,
      page: page ?? this.page,
      total: total ?? this.total,
      hasMore: hasMore ?? this.hasMore,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      filters: filters ?? this.filters,
      fromCache: fromCache ?? this.fromCache,
      cachedAt: cachedAt != null ? cachedAt() : this.cachedAt,
      errorMessage: errorMessage != null ? errorMessage() : this.errorMessage,
      loadMoreError: loadMoreError != null ? loadMoreError() : this.loadMoreError,
    );
  }

  @override
  List<Object?> get props => [
        status,
        query,
        language,
        topic,
        sort,
        results,
        page,
        total,
        hasMore,
        isLoadingMore,
        filters,
        fromCache,
        cachedAt,
        errorMessage,
        loadMoreError,
      ];
}
