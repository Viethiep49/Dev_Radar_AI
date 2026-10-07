import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../data/models/note_model.dart';
import '../../../data/repositories/note_repository.dart';

class NoteEditorState extends Equatable {
  final bool saving;

  /// Set after a successful save/delete: the editor pops with `true`.
  final bool done;
  final String? errorMessage;

  const NoteEditorState({this.saving = false, this.done = false, this.errorMessage});

  @override
  List<Object?> get props => [saving, done, errorMessage];
}

/// Create a note (when [note] is null) or edit/delete an existing one.
class NoteEditorCubit extends Cubit<NoteEditorState> {
  final NoteRepository repository;
  final NoteModel? note;
  final int? repoId;

  NoteEditorCubit(this.repository, {this.note, this.repoId}) : super(const NoteEditorState());

  bool get isEditing => note != null;

  Future<void> save(String content) async {
    final text = content.trim();
    if (text.isEmpty) {
      emit(const NoteEditorState(errorMessage: 'Nội dung ghi chú không được để trống'));
      return;
    }
    final targetRepo = note?.repoId ?? repoId;
    if (targetRepo == null) {
      emit(const NoteEditorState(errorMessage: 'Chưa chọn repo cho ghi chú'));
      return;
    }
    emit(const NoteEditorState(saving: true));
    try {
      if (note == null) {
        await repository.createNote(repoId: targetRepo, content: text);
      } else {
        await repository.updateNote(note!.id, content: text);
      }
      emit(const NoteEditorState(done: true));
    } catch (e) {
      emit(NoteEditorState(errorMessage: e.toString()));
    }
  }

  Future<void> delete() async {
    if (note == null) return;
    emit(const NoteEditorState(saving: true));
    try {
      await repository.deleteNote(note!.id);
      emit(const NoteEditorState(done: true));
    } catch (e) {
      emit(NoteEditorState(errorMessage: e.toString()));
    }
  }
}
