import 'package:equatable/equatable.dart';

sealed class FeedEvent extends Equatable {
  const FeedEvent();

  @override
  List<Object?> get props => [];
}

/// First load: feed page 1 + language chips.
class FeedStarted extends FeedEvent {
  const FeedStarted();
}

/// Pull-to-refresh or "Thử lại".
class FeedRefreshed extends FeedEvent {
  const FeedRefreshed();
}

/// The list was scrolled near its end.
class FeedLoadMoreRequested extends FeedEvent {
  const FeedLoadMoreRequested();
}

/// A language chip was tapped. null = "Dành cho bạn" (personalised feed).
class FeedLanguageSelected extends FeedEvent {
  final String? language;

  const FeedLanguageSelected(this.language);

  @override
  List<Object?> get props => [language];
}
