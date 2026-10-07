import 'package:bloc_test/bloc_test.dart';
import 'package:dev_radar_ai/core/network/api_exceptions.dart';
import 'package:dev_radar_ai/data/models/chat_message_model.dart';
import 'package:dev_radar_ai/data/repositories/cache_policy.dart';
import 'package:dev_radar_ai/data/repositories/chat_repository.dart';
import 'package:dev_radar_ai/presentation/state/chat/chat_bloc.dart';
import 'package:dev_radar_ai/presentation/state/chat/chat_event.dart';
import 'package:dev_radar_ai/presentation/state/chat/chat_state.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../helpers/repo_fixtures.dart';

class MockChatRepository extends Mock implements ChatRepository {}

void main() {
  late MockChatRepository repository;

  final exchange = ChatExchangeModel.fromJson({
    'question': chatMessageJson(3, 'user', 'Cài thế nào?'),
    'answer': chatMessageJson(4, 'assistant', 'Dùng pub add'),
  });

  setUp(() {
    repository = MockChatRepository();
    when(() => repository.getHistory(1)).thenAnswer(
      (_) async => Cached([ChatMessageModel.fromJson(chatMessageJson(1, 'user', 'Xin chào'))]),
    );
  });

  ChatBloc build() => ChatBloc(repoId: 1, chatRepository: repository);

  blocTest<ChatBloc, ChatState>(
    'ChatStarted loads the history',
    build: build,
    act: (bloc) => bloc.add(const ChatStarted()),
    verify: (bloc) {
      expect(bloc.state.historyStatus, ChatHistoryStatus.success);
      expect(bloc.state.messages.single.content, 'Xin chào');
    },
  );

  blocTest<ChatBloc, ChatState>(
    'sending shows the question at once, then replaces it with the saved exchange',
    build: () {
      when(() => repository.ask(1, 'Cài thế nào?')).thenAnswer((_) async => exchange);
      return build();
    },
    seed: () => const ChatState(historyStatus: ChatHistoryStatus.success),
    act: (bloc) => bloc.add(const ChatQuestionSent('  Cài thế nào?  ')),
    expect: () => [
      isA<ChatState>()
          .having((s) => s.isSending, 'isSending', true)
          .having((s) => s.messages.single.id, 'pending id', isNull)
          .having((s) => s.messages.single.content, 'content', 'Cài thế nào?'),
      isA<ChatState>()
          .having((s) => s.isSending, 'isSending', false)
          .having((s) => s.messages.map((m) => m.id).toList(), 'ids', [3, 4])
          .having((s) => s.messages.last.sources.single.excerpt, 'source', 'Install with pub'),
    ],
  );

  blocTest<ChatBloc, ChatState>(
    'a failed question can be retried',
    build: () {
      var calls = 0;
      when(() => repository.ask(1, 'Cài thế nào?')).thenAnswer((_) async {
        if (calls++ == 0) throw TimeoutException();
        return exchange;
      });
      return build();
    },
    seed: () => const ChatState(historyStatus: ChatHistoryStatus.success),
    act: (bloc) async {
      bloc.add(const ChatQuestionSent('Cài thế nào?'));
      await Future<void>.delayed(Duration.zero);
      expect(bloc.state.failedQuestion, 'Cài thế nào?');
      expect(bloc.state.messages.length, 1); // the pending bubble stays
      bloc.add(const ChatRetryRequested());
    },
    wait: const Duration(milliseconds: 10),
    verify: (bloc) {
      expect(bloc.state.failedQuestion, isNull);
      expect(bloc.state.messages.map((m) => m.id).toList(), [3, 4]);
    },
  );

  blocTest<ChatBloc, ChatState>(
    'empty questions are ignored',
    build: build,
    act: (bloc) => bloc.add(const ChatQuestionSent('   ')),
    expect: () => <ChatState>[],
  );

  blocTest<ChatBloc, ChatState>(
    'ChatCleared empties the history',
    build: () {
      when(() => repository.clearHistory(1)).thenAnswer((_) async {});
      return build();
    },
    seed: () => ChatState(
      historyStatus: ChatHistoryStatus.success,
      messages: [ChatMessageModel.fromJson(chatMessageJson(1, 'user', 'x'))],
    ),
    act: (bloc) => bloc.add(const ChatCleared()),
    verify: (bloc) {
      expect(bloc.state.messages, isEmpty);
      verify(() => repository.clearHistory(1)).called(1);
    },
  );
}
