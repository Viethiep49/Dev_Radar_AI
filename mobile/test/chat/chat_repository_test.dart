import 'package:dev_radar_ai/core/network/api_exceptions.dart';
import 'package:dev_radar_ai/data/datasources/local/cache_local_datasource.dart';
import 'package:dev_radar_ai/data/datasources/remote/chat_remote_datasource.dart';
import 'package:dev_radar_ai/data/repositories/chat_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../helpers/repo_fixtures.dart';

class MockChatRemote extends Mock implements ChatRemoteDataSource {}

void main() {
  late MockChatRemote remote;
  late MemoryCacheLocalDataSource cache;
  late ChatRepositoryImpl repository;

  setUp(() {
    remote = MockChatRemote();
    cache = MemoryCacheLocalDataSource();
    repository = ChatRepositoryImpl(remoteDataSource: remote, cache: cache);
  });

  test('getHistory loads every page in order', () async {
    when(() => remote.getHistoryPage(1, page: 1)).thenAnswer((_) async => {
          'items': [chatMessageJson(1, 'user', 'q1')],
          'page': 1,
          'limit': 1,
          'total': 2,
        });
    when(() => remote.getHistoryPage(1, page: 2)).thenAnswer((_) async => {
          'items': [chatMessageJson(2, 'assistant', 'a1')],
          'page': 2,
          'limit': 1,
          'total': 2,
        });

    final history = (await repository.getHistory(1)).data;

    expect(history.map((m) => m.content), ['q1', 'a1']);
    expect(history.last.sources.single.path, 'README.md');
  });

  test('history is readable offline and ask() appends to the cached copy', () async {
    when(() => remote.getHistoryPage(1, page: 1)).thenAnswer((_) async => {
          'items': [chatMessageJson(1, 'user', 'q1'), chatMessageJson(2, 'assistant', 'a1')],
          'page': 1,
          'limit': 100,
          'total': 2,
        });
    await repository.getHistory(1);
    when(() => remote.ask(1, 'q2')).thenAnswer((_) async => {
          'question': chatMessageJson(3, 'user', 'q2'),
          'answer': chatMessageJson(4, 'assistant', 'a2'),
        });

    final exchange = await repository.ask(1, ' q2 ');
    expect(exchange.answer.content, 'a2');

    when(() => remote.getHistoryPage(1, page: 1)).thenThrow(NetworkException());
    final offline = await repository.getHistory(1);
    expect(offline.fromCache, isTrue);
    expect(offline.data.map((m) => m.content), ['q1', 'a1', 'q2', 'a2']);
  });

  test('clearHistory deletes on the server and the cache', () async {
    await cache.put(ChatRepositoryImpl.historyKey(1), {'items': []});
    when(() => remote.clear(1)).thenAnswer((_) async {});

    await repository.clearHistory(1);

    verify(() => remote.clear(1)).called(1);
    expect(await cache.get(ChatRepositoryImpl.historyKey(1)), isNull);
  });
}
