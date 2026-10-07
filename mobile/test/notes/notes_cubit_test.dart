import 'package:bloc_test/bloc_test.dart';
import 'package:dev_radar_ai/core/network/api_exceptions.dart';
import 'package:dev_radar_ai/data/models/note_model.dart';
import 'package:dev_radar_ai/data/repositories/cache_policy.dart';
import 'package:dev_radar_ai/data/repositories/note_repository.dart';
import 'package:dev_radar_ai/presentation/state/load_status.dart';
import 'package:dev_radar_ai/presentation/state/notes/note_editor_cubit.dart';
import 'package:dev_radar_ai/presentation/state/notes/notes_cubit.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../helpers/library_fixtures.dart';

class MockNoteRepository extends Mock implements NoteRepository {}

NoteModel note(int id, {int repoId = 1}) => NoteModel.fromJson(noteJson(id, repoId: repoId));

void main() {
  late MockNoteRepository repository;

  setUp(() => repository = MockNoteRepository());

  group('NotesCubit', () {
    blocTest<NotesCubit, NotesState>(
      'loads the notes of one repo',
      setUp: () => when(() => repository.getNotes(repoId: 3, query: ''))
          .thenAnswer((_) async => Cached([note(1, repoId: 3)])),
      build: () => NotesCubit(repository, repoId: 3),
      act: (cubit) => cubit.load(),
      expect: () => [
        const NotesState(status: LoadStatus.loading),
        NotesState(status: LoadStatus.success, notes: [note(1, repoId: 3)]),
      ],
    );

    blocTest<NotesCubit, NotesState>(
      'search keeps the query in the state',
      setUp: () => when(() => repository.getNotes(repoId: null, query: 'bloc'))
          .thenAnswer((_) async => Cached([note(2)])),
      build: () => NotesCubit(repository),
      act: (cubit) => cubit.search(' bloc '),
      verify: (cubit) {
        expect(cubit.state.query, 'bloc');
        expect(cubit.state.notes, [note(2)]);
      },
    );

    test('delete reloads the list', () async {
      when(() => repository.deleteNote(1)).thenAnswer((_) async {});
      when(() => repository.getNotes(repoId: null, query: '')).thenAnswer((_) async => const Cached([]));
      final cubit = NotesCubit(repository);

      expect(await cubit.delete(1), isNull);
      verify(() => repository.getNotes(repoId: null, query: '')).called(1);
    });
  });

  group('NoteEditorCubit', () {
    blocTest<NoteEditorCubit, NoteEditorState>(
      'rejects empty content without calling the API',
      build: () => NoteEditorCubit(repository, repoId: 1),
      act: (cubit) => cubit.save('   '),
      expect: () => [const NoteEditorState(errorMessage: 'Nội dung ghi chú không được để trống')],
      verify: (_) => verifyNever(() => repository.createNote(repoId: any(named: 'repoId'), content: any(named: 'content'))),
    );

    blocTest<NoteEditorCubit, NoteEditorState>(
      'creates a note for the repo',
      setUp: () => when(() => repository.createNote(repoId: 1, content: 'hello')).thenAnswer((_) async => note(9)),
      build: () => NoteEditorCubit(repository, repoId: 1),
      act: (cubit) => cubit.save(' hello '),
      expect: () => [const NoteEditorState(saving: true), const NoteEditorState(done: true)],
    );

    blocTest<NoteEditorCubit, NoteEditorState>(
      'updates an existing note',
      setUp: () => when(() => repository.updateNote(4, content: 'new')).thenAnswer((_) async => note(4)),
      build: () => NoteEditorCubit(repository, note: note(4)),
      act: (cubit) => cubit.save('new'),
      expect: () => [const NoteEditorState(saving: true), const NoteEditorState(done: true)],
    );

    blocTest<NoteEditorCubit, NoteEditorState>(
      'shows the API error when deleting fails',
      setUp: () => when(() => repository.deleteNote(4)).thenThrow(NetworkException('offline')),
      build: () => NoteEditorCubit(repository, note: note(4)),
      act: (cubit) => cubit.delete(),
      expect: () => [const NoteEditorState(saving: true), const NoteEditorState(errorMessage: 'offline')],
    );
  });
}
