import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../data/models/note_model.dart';
import '../../../data/repositories/note_repository.dart';
import '../load_status.dart';

class NotesState extends Equatable {
  final LoadStatus status;
  final List<NoteModel> notes;
  final String query;
  final bool fromCache;
  final DateTime? cachedAt;
  final String? errorMessage;

  const NotesState({
    this.status = LoadStatus.initial,
    this.notes = const [],
    this.query = '',
    this.fromCache = false,
    this.cachedAt,
    this.errorMessage,
  });

  NotesState copyWith({
    LoadStatus? status,
    List<NoteModel>? notes,
    String? query,
    bool? fromCache,
    DateTime? cachedAt,
    String? errorMessage,
  }) {
    return NotesState(
      status: status ?? this.status,
      notes: notes ?? this.notes,
      query: query ?? this.query,
      fromCache: fromCache ?? this.fromCache,
      cachedAt: cachedAt ?? this.cachedAt,
      errorMessage: errorMessage,
    );
  }

  @override
  List<Object?> get props => [status, notes, query, fromCache, cachedAt, errorMessage];
}

/// All my notes, or only the notes of [repoId]. Search + create/update/delete.
class NotesCubit extends Cubit<NotesState> {
  final NoteRepository repository;
  final int? repoId;

  NotesCubit(this.repository, {this.repoId}) : super(const NotesState());

  Future<void> load({String? query}) async {
    final q = query ?? state.query;
    emit(state.copyWith(status: state.notes.isEmpty ? LoadStatus.loading : state.status, query: q));
    try {
      final result = await repository.getNotes(repoId: repoId, query: q);
      if (q != state.query) return;
      emit(state.copyWith(
        status: LoadStatus.success,
        notes: result.data,
        fromCache: result.fromCache,
        cachedAt: result.cachedAt,
      ));
    } catch (e) {
      if (q != state.query) return;
      emit(state.copyWith(status: LoadStatus.failure, errorMessage: e.toString()));
    }
  }

  Future<void> search(String query) => load(query: query.trim());

  Future<String?> create({required int repoId, required String content}) =>
      _write(() => repository.createNote(repoId: repoId, content: content));

  Future<String?> update(int id, {required String content}) =>
      _write(() => repository.updateNote(id, content: content));

  Future<String?> delete(int id) => _write(() => repository.deleteNote(id));

  Future<String?> _write(Future<void> Function() action) async {
    try {
      await action();
      await load();
      return null;
    } catch (e) {
      return e.toString();
    }
  }
}
