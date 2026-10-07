import 'package:bloc_test/bloc_test.dart';
import 'package:dev_radar_ai/core/network/api_exceptions.dart';
import 'package:dev_radar_ai/data/datasources/local/cache_local_datasource.dart';
import 'package:dev_radar_ai/data/datasources/remote/preferences_remote_datasource.dart';
import 'package:dev_radar_ai/data/models/preferences_model.dart';
import 'package:dev_radar_ai/data/models/user_model.dart';
import 'package:dev_radar_ai/data/repositories/auth_repository.dart';
import 'package:dev_radar_ai/data/repositories/cache_policy.dart';
import 'package:dev_radar_ai/data/repositories/preferences_repository.dart';
import 'package:dev_radar_ai/presentation/state/onboarding/onboarding_cubit.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../settings/fakes.dart';

class MockPreferencesRemote extends Mock implements PreferencesRemoteDataSource {}

class MockPreferencesRepository extends Mock implements PreferencesRepository {}

class MockAuthRepository extends Mock implements AuthRepository {}

const options = FilterOptionsModel(
  languages: [FilterOptionModel(name: 'Dart', count: 5), FilterOptionModel(name: 'Python', count: 9)],
  topics: [FilterOptionModel(name: 'flutter', count: 4), FilterOptionModel(name: 'ai', count: 7)],
);

void main() {
  setUpAll(() => registerFallbackValue(const PreferencesModel()));

  group('PreferencesRepositoryImpl', () {
    late MockPreferencesRemote remote;
    late MemoryCacheLocalDataSource cache;
    late PreferencesRepositoryImpl repository;

    setUp(() {
      remote = MockPreferencesRemote();
      cache = MemoryCacheLocalDataSource();
      repository = PreferencesRepositoryImpl(remoteDataSource: remote, cache: cache);
    });

    test('save writes the new preferences to the cache and drops the feed cache', () async {
      await cache.put('feed:page=1', {'items': []});
      when(() => remote.savePreferences(languages: ['Dart'], topics: ['ai']))
          .thenAnswer((_) async => {'languages': ['Dart'], 'topics': ['ai']});

      final saved = await repository.savePreferences(const PreferencesModel(languages: ['Dart'], topics: ['ai']));

      expect(saved.languages, ['Dart']);
      expect((await cache.get(PreferencesRepositoryImpl.preferencesKey))!.json['topics'], ['ai']);
      expect(await cache.get('feed:page=1'), isNull);
    });

    test('filter options come from the cache when offline', () async {
      await cache.put(PreferencesRepositoryImpl.filtersKey, {
        'languages': [
          {'name': 'Dart', 'count': 5},
        ],
        'topics': [],
      });
      when(() => remote.getFilterOptions()).thenThrow(NetworkException());

      final result = await repository.getFilterOptions();

      expect(result.fromCache, isTrue);
      expect(result.data.languages.single.name, 'Dart');
    });
  });

  group('OnboardingCubit', () {
    late MockPreferencesRepository preferences;
    late MockAuthRepository auth;
    late MemoryStorage storage;

    OnboardingCubit build() => OnboardingCubit(preferencesRepository: preferences, authRepository: auth, storage: storage);

    setUp(() {
      preferences = MockPreferencesRepository();
      auth = MockAuthRepository();
      storage = MemoryStorage();
      when(() => preferences.getFilterOptions()).thenAnswer((_) async => const Cached(options));
      when(() => preferences.getPreferences())
          .thenAnswer((_) async => const Cached(PreferencesModel(languages: ['Rust'], topics: ['ai'])));
      when(() => auth.getStoredUser()).thenAnswer((_) async => const UserModel(id: 42, email: 'a@b.c', displayName: 'A'));
    });

    test('load pre-selects saved choices and keeps ones missing from the options', () async {
      final cubit = build();
      await cubit.load();

      expect(cubit.state.status, OnboardingStatus.ready);
      expect(cubit.state.selectedLanguages, {'Rust'});
      expect(cubit.state.selectedTopics, {'ai'});
      expect(cubit.state.options.languages.first.name, 'Rust');
    });

    test('search filters both lists', () async {
      final cubit = build();
      await cubit.load();
      cubit.setQuery('PY');

      expect(cubit.state.visibleLanguages.map((o) => o.name), ['Python']);
      expect(cubit.state.visibleTopics, isEmpty);
    });

    test('toggle adds and removes', () async {
      final cubit = build();
      await cubit.load();
      cubit
        ..toggleLanguage('Dart')
        ..toggleLanguage('Rust')
        ..toggleTopic('flutter');

      expect(cubit.state.selectedLanguages, {'Dart'});
      expect(cubit.state.selectedTopics, {'ai', 'flutter'});
      expect(cubit.state.selectedCount, 3);
    });

    test('save sends the choices and marks onboarding done for the user', () async {
      when(() => preferences.savePreferences(any())).thenAnswer((_) async => const PreferencesModel());
      final cubit = build();
      await cubit.load();
      cubit.toggleLanguage('Dart');

      await cubit.save();

      final sent = verify(() => preferences.savePreferences(captureAny())).captured.single as PreferencesModel;
      expect(sent.languages.toSet(), {'Rust', 'Dart'});
      expect(storage.onboardingDone, {42});
      expect(cubit.state.isDone, isTrue);
    });

    blocTest<OnboardingCubit, OnboardingState>(
      'save failure keeps the screen open with an error',
      build: () {
        when(() => preferences.savePreferences(any())).thenThrow(NetworkException('Mất mạng'));
        return build();
      },
      act: (cubit) => cubit.save(),
      expect: () => [
        const OnboardingState(isSaving: true),
        const OnboardingState(actionError: 'Mất mạng'),
      ],
    );

    test('skip marks onboarding done without saving', () async {
      final cubit = build();
      await cubit.skip();

      expect(cubit.state.isDone, isTrue);
      expect(storage.onboardingDone, {42});
      verifyNever(() => preferences.savePreferences(any()));
    });

    blocTest<OnboardingCubit, OnboardingState>(
      'load failure',
      build: () {
        when(() => preferences.getFilterOptions()).thenThrow(TimeoutException());
        return build();
      },
      act: (cubit) => cubit.load(),
      expect: () => [
        const OnboardingState(status: OnboardingStatus.loading),
        isA<OnboardingState>().having((s) => s.status, 'status', OnboardingStatus.failure),
      ],
    );
  });
}
