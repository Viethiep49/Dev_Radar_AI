import 'package:bloc_test/bloc_test.dart';
import 'package:dev_radar_ai/core/network/api_exceptions.dart';
import 'package:dev_radar_ai/data/datasources/local/cache_local_datasource.dart';
import 'package:dev_radar_ai/data/datasources/remote/watchlist_remote_datasource.dart';
import 'package:dev_radar_ai/data/models/watchlist_item_model.dart';
import 'package:dev_radar_ai/data/repositories/cache_policy.dart';
import 'package:dev_radar_ai/data/repositories/watchlist_repository.dart';
import 'package:dev_radar_ai/presentation/state/watchlist/watchlist_cubit.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../settings/fakes.dart';

class MockWatchlistRemote extends Mock implements WatchlistRemoteDataSource {}

class MockWatchlistRepository extends Mock implements WatchlistRepository {}

Map<String, dynamic> itemJson(int repoId, {String? tag}) => {
      'repo': repoBriefJson(repoId, fullName: 'owner/repo$repoId'),
      'watched_at': '2026-10-01T10:00:00Z',
      'latest_release': tag == null ? null : {'tag_name': tag, 'published_at': '2026-10-02T00:00:00Z'},
    };

WatchlistItemModel item(int repoId) => WatchlistItemModel.fromJson(itemJson(repoId));

void main() {
  group('WatchlistRepositoryImpl', () {
    late MockWatchlistRemote remote;
    late MemoryCacheLocalDataSource cache;
    late WatchlistRepositoryImpl repository;

    setUp(() {
      remote = MockWatchlistRemote();
      cache = MemoryCacheLocalDataSource();
      repository = WatchlistRepositoryImpl(remoteDataSource: remote, cache: cache);
    });

    test('loads all pages and parses the latest release', () async {
      when(() => remote.getWatchlistPage(page: 1)).thenAnswer(
        (_) async => {'items': [itemJson(1, tag: 'v1.2.0')], 'page': 1, 'limit': 1, 'total': 2},
      );
      when(() => remote.getWatchlistPage(page: 2)).thenAnswer(
        (_) async => {'items': [itemJson(2)], 'page': 2, 'limit': 1, 'total': 2},
      );

      final result = await repository.getWatchlist();

      expect(result.data.map((i) => i.repo.id), [1, 2]);
      expect(result.data.first.latestReleaseTag, 'v1.2.0');
      expect(result.data.last.latestReleaseTag, isNull);
    });

    test('falls back to cache when offline', () async {
      await cache.put(WatchlistRepositoryImpl.listKey, {'items': [itemJson(3)]});
      when(() => remote.getWatchlistPage(page: 1)).thenThrow(NetworkException());

      final result = await repository.getWatchlist();

      expect(result.fromCache, isTrue);
      expect(result.data.single.repo.id, 3);
    });

    test('watch treats 409 as success and clears the cache', () async {
      await cache.put(WatchlistRepositoryImpl.listKey, {'items': []});
      when(() => remote.watch(1)).thenThrow(ApiException('exists', statusCode: 409));

      await repository.watch(1);

      expect(await cache.get(WatchlistRepositoryImpl.listKey), isNull);
    });

    test('unwatch rethrows real errors', () {
      when(() => remote.unwatch(1)).thenThrow(ApiException('boom', statusCode: 500));
      expect(repository.unwatch(1), throwsA(isA<ApiException>()));
    });
  });

  group('WatchlistCubit', () {
    late MockWatchlistRepository repository;

    setUp(() => repository = MockWatchlistRepository());

    blocTest<WatchlistCubit, WatchlistState>(
      'load emits the list',
      build: () {
        when(() => repository.getWatchlist()).thenAnswer((_) async => Cached([item(1)]));
        return WatchlistCubit(repository);
      },
      act: (cubit) => cubit.load(),
      expect: () => [
        const WatchlistState(status: WatchlistStatus.loading),
        WatchlistState(status: WatchlistStatus.loaded, items: [item(1)]),
      ],
    );

    blocTest<WatchlistCubit, WatchlistState>(
      'unwatch removes the repo at once and restores it on failure',
      build: () {
        when(() => repository.unwatch(1)).thenThrow(NetworkException('Mất mạng'));
        return WatchlistCubit(repository);
      },
      seed: () => WatchlistState(status: WatchlistStatus.loaded, items: [item(1), item(2)]),
      act: (cubit) => cubit.unwatch(1),
      expect: () => [
        WatchlistState(status: WatchlistStatus.loaded, items: [item(2)]),
        WatchlistState(status: WatchlistStatus.loaded, items: [item(1), item(2)], actionError: 'Mất mạng'),
      ],
    );
  });
}
