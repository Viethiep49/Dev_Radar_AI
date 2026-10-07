import 'package:equatable/equatable.dart';

import '../../../data/models/repo_filters_model.dart';

sealed class SearchEvent extends Equatable {
  const SearchEvent();

  @override
  List<Object?> get props => [];
}

/// Loads the filter options (languages, topics).
class SearchStarted extends SearchEvent {
  const SearchStarted();
}

/// Text typed in the search box; the search runs after a short pause (debounce).
class SearchQueryChanged extends SearchEvent {
  final String query;

  const SearchQueryChanged(this.query);

  @override
  List<Object?> get props => [query];
}

/// Keyboard "search" button: search right away.
class SearchSubmitted extends SearchEvent {
  final String query;

  const SearchSubmitted(this.query);

  @override
  List<Object?> get props => [query];
}

/// New filter values from the filter sheet or a topic chip.
class SearchFiltersChanged extends SearchEvent {
  final String? language;
  final String? topic;
  final RepoSort sort;

  const SearchFiltersChanged({this.language, this.topic, this.sort = RepoSort.stars});

  @override
  List<Object?> get props => [language, topic, sort];
}

class SearchLoadMoreRequested extends SearchEvent {
  const SearchLoadMoreRequested();
}

/// "Thử lại" after an error.
class SearchRetried extends SearchEvent {
  const SearchRetried();
}

/// Internal: the debounce timer fired.
class SearchDebounceElapsed extends SearchEvent {
  const SearchDebounceElapsed();
}
