import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../data/models/collection_model.dart';
import '../../../data/repositories/collection_repository.dart';
import '../load_status.dart';

class CollectionDetailState extends Equatable {
  final LoadStatus status;
  final CollectionDetailModel? detail;
  final bool fromCache;
  final DateTime? cachedAt;
  final String? errorMessage;

  /// True once the collection was deleted: the screen pops.
  final bool deleted;

  const CollectionDetailState({
    this.status = LoadStatus.initial,
    this.detail,
    this.fromCache = false,
    this.cachedAt,
    this.errorMessage,
    this.deleted = false,
  });

  CollectionDetailState copyWith({
    LoadStatus? status,
    CollectionDetailModel? detail,
    bool? fromCache,
    DateTime? cachedAt,
    String? errorMessage,
    bool? deleted,
  }) {
    return CollectionDetailState(
      status: status ?? this.status,
      detail: detail ?? this.detail,
      fromCache: fromCache ?? this.fromCache,
      cachedAt: cachedAt ?? this.cachedAt,
      errorMessage: errorMessage,
      deleted: deleted ?? this.deleted,
    );
  }

  @override
  List<Object?> get props => [status, detail, fromCache, cachedAt, errorMessage, deleted];
}

/// One collection: its repos, remove a repo, rename, delete.
class CollectionDetailCubit extends Cubit<CollectionDetailState> {
  final CollectionRepository repository;
  final int collectionId;

  /// Set when anything changed, so the list screen can refresh after pop.
  bool changed = false;

  CollectionDetailCubit(this.repository, this.collectionId) : super(const CollectionDetailState());

  Future<void> load() async {
    if (state.detail == null) emit(state.copyWith(status: LoadStatus.loading));
    try {
      final result = await repository.getCollection(collectionId);
      emit(state.copyWith(
        status: LoadStatus.success,
        detail: result.data,
        fromCache: result.fromCache,
        cachedAt: result.cachedAt,
      ));
    } catch (e) {
      emit(state.copyWith(status: LoadStatus.failure, errorMessage: e.toString()));
    }
  }

  Future<String?> removeRepo(int repoId) async {
    final detail = state.detail;
    if (detail == null) return null;
    // Optimistic: hide the repo right away, put it back if the call fails.
    final remaining = detail.repos.where((r) => r.repo.id != repoId).toList();
    emit(state.copyWith(detail: CollectionDetailModel(collection: detail.collection, repos: remaining)));
    try {
      await repository.removeRepo(collectionId, repoId);
      changed = true;
      await load();
      return null;
    } catch (e) {
      emit(state.copyWith(detail: detail));
      return e.toString();
    }
  }

  Future<String?> rename({required String name, String? description}) async {
    try {
      await repository.updateCollection(collectionId, name: name.trim(), description: description);
      changed = true;
      await load();
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  Future<String?> delete() async {
    try {
      await repository.deleteCollection(collectionId);
      changed = true;
      emit(state.copyWith(deleted: true));
      return null;
    } catch (e) {
      return e.toString();
    }
  }
}
