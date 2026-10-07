import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../data/models/collection_model.dart';
import '../../../data/repositories/collection_repository.dart';
import '../load_status.dart';

class CollectionsState extends Equatable {
  final LoadStatus status;
  final List<CollectionModel> collections;
  final String query;
  final bool fromCache;
  final DateTime? cachedAt;
  final String? errorMessage;

  const CollectionsState({
    this.status = LoadStatus.initial,
    this.collections = const [],
    this.query = '',
    this.fromCache = false,
    this.cachedAt,
    this.errorMessage,
  });

  CollectionsState copyWith({
    LoadStatus? status,
    List<CollectionModel>? collections,
    String? query,
    bool? fromCache,
    DateTime? cachedAt,
    String? errorMessage,
  }) {
    return CollectionsState(
      status: status ?? this.status,
      collections: collections ?? this.collections,
      query: query ?? this.query,
      fromCache: fromCache ?? this.fromCache,
      cachedAt: cachedAt ?? this.cachedAt,
      errorMessage: errorMessage,
    );
  }

  @override
  List<Object?> get props => [status, collections, query, fromCache, cachedAt, errorMessage];
}

/// List + search + create/update/delete of the user's collections.
/// Write methods return null on success or an error message for a SnackBar.
class CollectionsCubit extends Cubit<CollectionsState> {
  final CollectionRepository repository;

  CollectionsCubit(this.repository) : super(const CollectionsState());

  Future<void> load({String? query}) async {
    final q = query ?? state.query;
    // Keep showing the current list while refreshing / searching.
    emit(state.copyWith(
      status: state.collections.isEmpty ? LoadStatus.loading : state.status,
      query: q,
    ));
    try {
      final result = await repository.getCollections(query: q);
      if (q != state.query) return; // a newer search started meanwhile
      emit(state.copyWith(
        status: LoadStatus.success,
        collections: result.data,
        fromCache: result.fromCache,
        cachedAt: result.cachedAt,
      ));
    } catch (e) {
      if (q != state.query) return;
      emit(state.copyWith(status: LoadStatus.failure, errorMessage: e.toString()));
    }
  }

  Future<void> search(String query) => load(query: query.trim());

  Future<String?> create({required String name, String? description}) {
    return _write(() => repository.createCollection(name: name.trim(), description: description));
  }

  Future<String?> update(int id, {required String name, String? description}) {
    return _write(() => repository.updateCollection(id, name: name.trim(), description: description));
  }

  Future<String?> delete(int id) => _write(() => repository.deleteCollection(id));

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
