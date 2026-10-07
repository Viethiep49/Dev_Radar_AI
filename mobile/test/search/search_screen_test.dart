import 'package:dev_radar_ai/core/network/api_exceptions.dart';
import 'package:dev_radar_ai/data/models/repo_filters_model.dart';
import 'package:dev_radar_ai/data/repositories/cache_policy.dart';
import 'package:dev_radar_ai/data/repositories/repo_repository.dart';
import 'package:dev_radar_ai/presentation/screens/search/search_screen.dart';
import 'package:dev_radar_ai/presentation/widgets/repo_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../helpers/repo_fixtures.dart';

class MockRepoRepository extends Mock implements RepoRepository {}

void main() {
  late MockRepoRepository repository;

  setUpAll(() => registerFallbackValue(RepoSort.stars));

  setUp(() {
    repository = MockRepoRepository();
    when(() => repository.getFilters()).thenAnswer(
      (_) async => const Cached(RepoFiltersModel(
        topics: [FilterOption(name: 'flutter', count: 12)],
        languages: [FilterOption(name: 'Dart', count: 8)],
      )),
    );
  });

  Future<void> pumpScreen(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(400, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      RepositoryProvider<RepoRepository>.value(
        value: repository,
        child: const MaterialApp(home: Scaffold(body: SearchScreen())),
      ),
    );
    await tester.pump();
  }

  testWidgets('shows topic suggestions and searches when one is tapped', (tester) async {
    when(() => repository.searchRepos(query: '', language: null, topic: 'flutter', sort: RepoSort.stars, page: 1))
        .thenAnswer((_) async => Cached(repoPage([1, 2], total: 2)));

    await pumpScreen(tester);
    expect(find.text('#flutter · 12'), findsOneWidget);

    await tester.tap(find.text('#flutter · 12'));
    await tester.pump(); // loading
    await tester.pump(const Duration(milliseconds: 600)); // results + animations

    expect(find.byType(RepoCard), findsNWidgets(2));
    expect(find.text('Tìm thấy 2 repository · Nhiều sao'), findsOneWidget);
    expect(find.widgetWithText(InputChip, '#flutter'), findsOneWidget);
  });

  testWidgets('shows an error with a retry button', (tester) async {
    var calls = 0;
    when(() => repository.searchRepos(query: 'abc', language: null, topic: null, sort: RepoSort.stars, page: 1))
        .thenAnswer((_) async {
      if (calls++ == 0) throw NetworkException('Không có mạng');
      return Cached(repoPage([3]));
    });

    await pumpScreen(tester);
    await tester.enterText(find.byType(TextField), 'abc');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.text('Không có mạng'), findsOneWidget);

    await tester.tap(find.text('Thử lại'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.byType(RepoCard), findsOneWidget);
  });
}
