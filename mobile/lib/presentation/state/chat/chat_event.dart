import 'package:equatable/equatable.dart';

sealed class ChatEvent extends Equatable {
  const ChatEvent();

  @override
  List<Object?> get props => [];
}

/// Loads the saved history of this repo.
class ChatStarted extends ChatEvent {
  const ChatStarted();
}

class ChatQuestionSent extends ChatEvent {
  final String question;

  const ChatQuestionSent(this.question);

  @override
  List<Object?> get props => [question];
}

/// Re-send the question that failed.
class ChatRetryRequested extends ChatEvent {
  const ChatRetryRequested();
}

/// Delete the whole history of this repo.
class ChatCleared extends ChatEvent {
  const ChatCleared();
}
