import 'package:equatable/equatable.dart';

import '../../../data/models/chat_message_model.dart';

enum ChatHistoryStatus { loading, success, failure }

class ChatState extends Equatable {
  final ChatHistoryStatus historyStatus;
  final List<ChatMessageModel> messages;

  /// Waiting for the AI answer (shows the typing bubble).
  final bool isSending;

  /// The question whose answer failed; shown with a "Gửi lại" button.
  final String? failedQuestion;
  final String? errorMessage;

  final bool fromCache;
  final DateTime? cachedAt;

  const ChatState({
    this.historyStatus = ChatHistoryStatus.loading,
    this.messages = const [],
    this.isSending = false,
    this.failedQuestion,
    this.errorMessage,
    this.fromCache = false,
    this.cachedAt,
  });

  ChatState copyWith({
    ChatHistoryStatus? historyStatus,
    List<ChatMessageModel>? messages,
    bool? isSending,
    String? Function()? failedQuestion,
    String? Function()? errorMessage,
    bool? fromCache,
    DateTime? Function()? cachedAt,
  }) {
    return ChatState(
      historyStatus: historyStatus ?? this.historyStatus,
      messages: messages ?? this.messages,
      isSending: isSending ?? this.isSending,
      failedQuestion: failedQuestion != null ? failedQuestion() : this.failedQuestion,
      errorMessage: errorMessage != null ? errorMessage() : this.errorMessage,
      fromCache: fromCache ?? this.fromCache,
      cachedAt: cachedAt != null ? cachedAt() : this.cachedAt,
    );
  }

  @override
  List<Object?> get props => [historyStatus, messages, isSending, failedQuestion, errorMessage, fromCache, cachedAt];
}
