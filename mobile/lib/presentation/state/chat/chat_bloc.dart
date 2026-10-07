import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../data/models/chat_message_model.dart';
import '../../../data/repositories/chat_repository.dart';
import 'chat_event.dart';
import 'chat_state.dart';

/// Chat with one repo: history, ask (optimistic question bubble), retry, clear.
class ChatBloc extends Bloc<ChatEvent, ChatState> {
  final int repoId;
  final ChatRepository chatRepository;

  ChatBloc({required this.repoId, required this.chatRepository}) : super(const ChatState()) {
    on<ChatStarted>(_onStarted);
    on<ChatQuestionSent>(_onQuestionSent);
    on<ChatRetryRequested>(_onRetry);
    on<ChatCleared>(_onCleared);
  }

  Future<void> _onStarted(ChatStarted event, Emitter<ChatState> emit) async {
    emit(state.copyWith(historyStatus: ChatHistoryStatus.loading, errorMessage: () => null));
    try {
      final result = await chatRepository.getHistory(repoId);
      emit(state.copyWith(
        historyStatus: ChatHistoryStatus.success,
        messages: result.data,
        fromCache: result.fromCache,
        cachedAt: () => result.cachedAt,
      ));
    } catch (e) {
      emit(state.copyWith(historyStatus: ChatHistoryStatus.failure, errorMessage: () => e.toString()));
    }
  }

  Future<void> _onQuestionSent(ChatQuestionSent event, Emitter<ChatState> emit) async {
    final question = event.question.trim();
    if (question.isEmpty || state.isSending) return;
    final pending = ChatMessageModel(role: 'user', content: question, createdAt: DateTime.now());
    emit(state.copyWith(
      messages: [...state.messages, pending],
      isSending: true,
      failedQuestion: () => null,
      errorMessage: () => null,
    ));
    await _ask(question, pending, emit);
  }

  Future<void> _onRetry(ChatRetryRequested event, Emitter<ChatState> emit) async {
    final question = state.failedQuestion;
    if (question == null || state.isSending) return;
    // The failed question is still the last (unsaved) bubble.
    final pending = state.messages.isNotEmpty && state.messages.last.id == null
        ? state.messages.last
        : ChatMessageModel(role: 'user', content: question, createdAt: DateTime.now());
    final messages = state.messages.contains(pending) ? state.messages : [...state.messages, pending];
    emit(state.copyWith(
      messages: messages,
      isSending: true,
      failedQuestion: () => null,
      errorMessage: () => null,
    ));
    await _ask(question, pending, emit);
  }

  Future<void> _ask(String question, ChatMessageModel pending, Emitter<ChatState> emit) async {
    try {
      final exchange = await chatRepository.ask(repoId, question);
      final messages = [...state.messages]..remove(pending);
      emit(state.copyWith(
        messages: [...messages, exchange.question, exchange.answer],
        isSending: false,
        fromCache: false,
      ));
    } catch (e) {
      emit(state.copyWith(
        isSending: false,
        failedQuestion: () => question,
        errorMessage: () => e.toString(),
      ));
    }
  }

  Future<void> _onCleared(ChatCleared event, Emitter<ChatState> emit) async {
    if (state.isSending) return;
    try {
      await chatRepository.clearHistory(repoId);
      emit(state.copyWith(
        messages: const [],
        failedQuestion: () => null,
        errorMessage: () => null,
        fromCache: false,
      ));
    } catch (e) {
      emit(state.copyWith(errorMessage: () => e.toString()));
    }
  }
}
