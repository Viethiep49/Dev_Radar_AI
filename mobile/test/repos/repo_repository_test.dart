import 'package:dev_radar_ai/core/network/api_exceptions.dart';
import 'package:dev_radar_ai/data/datasources/local/cache_local_datasource.dart';
import 'package:dev_radar_ai/data/datasources/remote/repo_remote_datasource.dart';
import 'package:dev_radar_ai/data/models/learning_model.dart';
import 'package:dev_radar_ai/data/models/repo_filters_model.dart';
import 'package:dev_radar_ai/data/repositories/repo_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../helpers/repo_fixtures.dart';

class MockRepoRemote extends Mock implements RepoRemoteDataSource {}

void main() {
  late MockRepoRemote remote;
  late MemoryCacheLocalDataSource cache;
  late RepoRepositoryImpl repository;

  setUp(() {
    remote = MockRepoRemote();
    cache = MemoryCacheLocalDataSource();
    repository = RepoRepositoryImpl(remoteDataSource: remote, cache: cache);
  });

  group('getFeed', () {
    test('returns page 1 from the API and caches it', () async {
      when(() => remote.getFeed(page: 1, limit: 20)).thenAnswer((_) async => pageJson([1, 2], total: 30));

      final result = await repository.getFeed();

      expect(result.fromCache, isFalse);
      expect(result.data.items.map((r) => r.id), [1, 2]);
      expect(result.data.total, 30);
      expect(await cache.get(RepoRepositoryImpl.feedKey), isNotNull);
    });

    test('falls back to the cached page 1 when offline', () async {
      when(() => remote.getFeed(page: 1, limit: 20)).thenAnswer((_) async => pageJson([1, 2]));
      await repository.getFeed();
      when(() => remote.getFeed(page: 1, limit: 20)).thenThrow(NetworkException());

      final result = await repository.getFeed();

      expect(result.fromCache, isTrue);
      expect(result.cachedAt, isNotNull);
      expect(result.data.items.map((r) => r.id), [1, 2]);
    });

    test('rethrows when offline and nothing is cached', () async {
      when(() => remote.getFeed(page: 1, limit: 20)).thenThrow(TimeoutException());

      expect(repository.getFeed(), throwsA(isA<TimeoutException>()));
    });

    test('does not use the cache for a 401', () async {
      when(() => remote.getFeed(page: 1, limit: 20)).thenAnswer((_) async => pageJson([1]));
      await repository.getFeed();
      when(() => remote.getFeed(page: 1, limit: 20)).thenThrow(UnauthorizedException());

      expect(repository.getFeed(), throwsA(isA<UnauthorizedException>()));
    });

    test('later pages are not cached', () async {
      when(() => remote.getFeed(page: 2, limit: 20)).thenAnswer((_) async => pageJson([21], page: 2, total: 21));

      final result = await repository.getFeed(page: 2);

      expect(result.data.items.single.id, 21);
      expect(await cache.count(), 0);
    });
  });

  group('searchRepos', () {
    test('passes query, filters and sort to the API without caching text searches', () async {
      when(() => remote.searchRepos(
            query: 'flut',
            language: 'Dart',
            topic: 'ui',
            sort: 'trending',
            page: 1,
            limit: 20,
          )).thenAnswer((_) async => pageJson([3]));

      final result = await repository.searchRepos(query: 'flut', language: 'Dart', topic: 'ui', sort: RepoSort.trending);

      expect(result.data.items.single.id, 3);
      expect(await cache.count(), 0);
    });

    test('caches a filter-only first page (language chip)', () async {
      when(() => remote.searchRepos(language: 'Go', sort: 'trending', page: 1, limit: 20))
          .thenAnswer((_) async => pageJson([4]));

      await repository.searchRepos(language: 'Go', sort: RepoSort.trending);

      expect(await cache.get(RepoRepositoryImpl.searchKey(language: 'Go', sort: RepoSort.trending)), isNotNull);
    });
  });

  test('getRepoDetail parses the detail and the user flags', () async {
    when(() => remote.getRepoDetail(7)).thenAnswer(
      (_) async => detailJson(7, isWatched: true, learningStatus: 'learning', collectionIds: [1, 2]),
    );

    final detail = (await repository.getRepoDetail(7)).data;

    expect(detail.repo.fullName, 'owner7/repo7');
    expect(detail.isWatched, isTrue);
    expect(detail.learningStatus, LearningStatus.learning);
    expect(detail.collectionIds, [1, 2]);
    expect(detail.summary, 'A great repo');
    expect(detail.quickstart, 'flutter pub add repo7');
    expect(detail.readme, '# repo7');
    expect(detail.pushedAt, DateTime.utc(2026, 10, 1));
  });

  test('getStarHistory parses points', () async {
    when(() => remote.getStarHistory(7, days: 30)).thenAnswer((_) async => [
          {'date': '2026-10-01', 'stars': 10},
          {'date': '2026-10-02', 'stars': 15},
        ]);

    final points = (await repository.getStarHistory(7)).data;

    expect(points.map((p) => p.stars), [10, 15]);
    expect(points.first.date, DateTime(2026, 10, 1));
  });

  test('getFilters parses languages and topics', () async {
    when(() => remote.getFilters()).thenAnswer((_) async => {
          'languages': [
            {'name': 'Dart', 'count': 3},
          ],
          'topics': [
            {'name': 'ai', 'count': 5},
          ],
        });

    final filters = (await repository.getFilters()).data;

    expect(filters.languages.single, const FilterOption(name: 'Dart', count: 3));
    expect(filters.topics.single.name, 'ai');
  });
}
