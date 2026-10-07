import '../datasources/local/cache_local_datasource.dart';
import '../datasources/remote/chat_remote_datasource.dart';
import '../models/chat_message_model.dart';
import '../models/page_model.dart';
import 'cache_policy.dart';

/// Chat with a repo (AI answers based on its README/docs).
abstract class ChatRepository {
  /// Whole history, oldest first. Cached per repo for offline reading.
  Future<Cached<List<ChatMessageModel>>> getHistory(int repoId);

  Future<ChatExchangeModel> ask(int repoId, String question);

  Future<void> clearHistory(int repoId);
}

class ChatRepositoryImpl implements ChatRepository {
  static String historyKey(int repoId) => 'chat:$repoId';

  final ChatRemoteDataSource remoteDataSource;
  final CacheLocalDataSource cache;

  ChatRepositoryImpl({required this.remoteDataSource, required this.cache});

  Future<Map<String, dynamic>> _fetchAll(int repoId) async {
    final items = <dynamic>[];
    var page = 1;
    while (true) {
      final json = await remoteDataSource.getHistoryPage(repoId, page: page);
      final pageModel = PageModel.fromJson(json, (item) => item);
      items.addAll(pageModel.items);
      if (!pageModel.hasMore || pageModel.items.isEmpty) break;
      page++;
    }
    return {'items': items};
  }

  @override
  Future<Cached<List<ChatMessageModel>>> getHistory(int repoId) {
    return fetchWithCache(
      cache: cache,
      key: historyKey(repoId),
      fetch: () => _fetchAll(repoId),
      parse: (json) => ((json as Map<String, dynamic>)['items'] as List<dynamic>)
          .map((e) => ChatMessageModel.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  @override
  Future<ChatExchangeModel> ask(int repoId, String question) async {
    final json = await remoteDataSource.ask(repoId, question.trim());
    final exchange = ChatExchangeModel.fromJson(json);
    // Append to the cached history so it stays readable offline.
    final entry = await cache.get(historyKey(repoId));
    if (entry != null) {
      final items = List<dynamic>.from((entry.json as Map<String, dynamic>)['items'] as List<dynamic>)
        ..add(json['question'])
        ..add(json['answer']);
      await cache.put(historyKey(repoId), {'items': items});
    }
    return exchange;
  }

  @override
  Future<void> clearHistory(int repoId) async {
    await remoteDataSource.clear(repoId);
    await cache.remove(historyKey(repoId));
  }
}
