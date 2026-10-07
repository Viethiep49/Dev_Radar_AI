import 'package:dev_radar_ai/data/models/collection_model.dart';
import 'package:dev_radar_ai/data/models/learning_model.dart';
import 'package:dev_radar_ai/data/models/note_model.dart';
import 'package:dev_radar_ai/data/repositories/cache_policy.dart';
import 'package:dev_radar_ai/data/repositories/collection_repository.dart';
import 'package:dev_radar_ai/data/repositories/learning_repository.dart';
import 'package:dev_radar_ai/data/repositories/note_repository.dart';
import 'package:dev_radar_ai/presentation/screens/collections/collections_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../helpers/library_fixtures.dart';

class MockCollectionRepository extends Mock implements CollectionRepository {}

class MockNoteRepository extends Mock implements NoteRepository {}

class MockLearningRepository extends Mock implements LearningRepository {}

void main() {
  late MockCollectionRepository collections;
  late MockNoteRepository notes;
  late MockLearningRepository learning;

  setUp(() {
    collections = MockCollectionRepository();
    notes = MockNoteRepository();
    learning = MockLearningRepository();
    when(() => collections.getCollections(query: any(named: 'query'))).thenAnswer(
      (_) async => Cached([
        CollectionModel.fromJson(collectionJson(1, name: 'Học Flutter', itemCount: 3)),
        CollectionModel.fromJson(collectionJson(2, name: 'AI', itemCount: 0)),
      ]),
    );
    when(() => notes.getNotes(repoId: any(named: 'repoId'), query: any(named: 'query')))
        .thenAnswer((_) async => Cached([NoteModel.fromJson(noteJson(1, content: 'Ghi chú docker'))]));
    when(() => learning.getItems(status: any(named: 'status'))).thenAnswer(
      (_) async => Cached([LearningItemModel.fromJson(learningJson(1, status: 'used'))],
          fromCache: true, cachedAt: DateTime(2026, 10, 8)),
    );
  });

  Widget app() => MultiRepositoryProvider(
        providers: [
          RepositoryProvider<CollectionRepository>.value(value: collections),
          RepositoryProvider<NoteRepository>.value(value: notes),
          RepositoryProvider<LearningRepository>.value(value: learning),
        ],
        child: const MaterialApp(home: Scaffold(body: CollectionsScreen())),
      );

  testWidgets('shows collections, notes and the learning path on a small phone', (tester) async {
    tester.view.physicalSize = const Size(320 * 3, 640 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    expect(find.text('Collection 1'), findsNothing);
    expect(find.text('Học Flutter 1'), findsOneWidget);
    expect(find.text('3 repo · 02/10/2026'), findsOneWidget);

    await tester.tap(find.text('Ghi chú'));
    await tester.pumpAndSettle();
    expect(find.text('Ghi chú docker 1'), findsOneWidget);

    await tester.tap(find.text('Lộ trình'));
    await tester.pumpAndSettle();
    expect(find.text('Đã sử dụng'), findsWidgets);
    expect(find.textContaining('Đang offline'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
