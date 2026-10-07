import 'package:equatable/equatable.dart';

abstract class RepoEvent extends Equatable {
  const RepoEvent();

  @override
  List<Object?> get props => [];
}

class FetchTrendingReposRequested extends RepoEvent {
  final String? language;
  final bool isRefresh;

  const FetchTrendingReposRequested({this.language, this.isRefresh = false});

  @override
  List<Object?> get props => [language, isRefresh];
}

class SearchReposRequested extends RepoEvent {
  final String query;

  const SearchReposRequested(this.query);

  @override
  List<Object?> get props => [query];
}
