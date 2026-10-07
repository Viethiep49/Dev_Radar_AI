import '../../core/network/api_exceptions.dart';
import '../datasources/local/cache_local_datasource.dart';

/// Data plus where it came from. When [fromCache] is true the UI shows an
/// "offline – data from [cachedAt]" banner with a retry button.
class Cached<T> {
  final T data;
  final bool fromCache;
  final DateTime? cachedAt;

  const Cached(this.data, {this.fromCache = false, this.cachedAt});
}

/// Network-first read with SQLite fallback.
///
/// 1. Call the API ([fetch] returns the decoded JSON), save it under [key], return it.
/// 2. If the call fails because of the network (no connection, timeout, server 5xx)
///    and something is cached under [key], return the cached copy instead.
/// 3. Other errors (401, 404, validation...) are rethrown: old data would hide them.
Future<Cached<T>> fetchWithCache<T>({
  required CacheLocalDataSource cache,
  required String key,
  required Future<dynamic> Function() fetch,
  required T Function(dynamic json) parse,
}) async {
  try {
    final json = await fetch();
    final data = parse(json);
    await cache.put(key, json);
    return Cached(data);
  } on ApiException catch (e) {
    if (!isOfflineError(e)) rethrow;
    final entry = await cache.get(key);
    if (entry == null) rethrow;
    return Cached(parse(entry.json), fromCache: true, cachedAt: entry.updatedAt);
  }
}

/// True for errors where showing cached data makes sense.
bool isOfflineError(Object error) {
  if (error is NetworkException || error is TimeoutException) return true;
  if (error is ApiException) {
    final status = error.statusCode;
    return status != null && status >= 500;
  }
  return false;
}
