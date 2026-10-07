import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../data/models/collection_model.dart';
import '../../../data/repositories/collection_repository.dart';
import '../load_status.dart';

class AddToCollectionState extends Equatable {
  final LoadStatus status;
  final List<CollectionModel> collections;

  /// Collections that currently contain the repo.
  final Set<int> selectedIds;

  /// Collection ids with a request in flight (checkbox shows a spinner).
  final Set<int> busyIds;
  final bool changed;
  final String? errorMessage;

  const AddToCollectionState({
    this.status = LoadStatus.initial,
    this.collections = const [],
    this.selectedIds = const {},
    this.busyIds = const {},
    this.changed = false,
    this.errorMessage,
  });

  AddToCollectionState copyWith({
    LoadStatus? status,
    List<CollectionModel>? collections,
    Set<int>? selectedIds,
    Set<int>? busyIds,
    bool? changed,
    String? errorMessage,
  }) {
    return AddToCollectionState(
      status: status ?? this.status,
      collections: collections ?? this.collections,
      selectedIds: selectedIds ?? this.selectedIds,
      busyIds: busyIds ?? this.busyIds,
      changed: changed ?? this.changed,
      errorMessage: errorMessage,
    );
  }

  @override
  List<Object?> get props => [status, collections, selectedIds, busyIds, changed, errorMessage];
}

/// Bottom sheet "Thêm vào bộ sưu tập": toggling a checkbox adds/removes the repo immediately.
class AddToCollectionCubit extends Cubit<AddToCollectionState> {
  final CollectionRepository repository;
  final int repoId;

  AddToCollectionCubit(this.repository, {required this.repoId, required List<int> currentCollectionIds})
      : super(AddToCollectionState(selectedIds: currentCollectionIds.toSet()));

  Future<void> load() async {
    emit(state.copyWith(status: LoadStatus.loading));
    try {
      final result = await repository.getCollections();
      emit(state.copyWith(status: LoadStatus.success, collections: result.data));
    } catch (e) {
      emit(state.copyWith(status: LoadStatus.failure, errorMessage: e.toString()));
    }
  }

  Future<String?> toggle(int collectionId) async {
    if (state.busyIds.contains(collectionId)) return null;
    final wasSelected = state.selectedIds.contains(collectionId);
    emit(state.copyWith(busyIds: {...state.busyIds, collectionId}));
    try {
      if (wasSelected) {
        await repository.removeRepo(collectionId, repoId);
      } else {
        await repository.addRepo(collectionId, repoId);
      }
      final selected = {...state.selectedIds};
      wasSelected ? selected.remove(collectionId) : selected.add(collectionId);
      emit(state.copyWith(
        selectedIds: selected,
        busyIds: {...state.busyIds}..remove(collectionId),
        changed: true,
      ));
      return null;
    } catch (e) {
      emit(state.copyWith(busyIds: {...state.busyIds}..remove(collectionId)));
      return e.toString();
    }
  }

  /// Creates a collection and adds the repo to it.
  Future<String?> createAndAdd(String name) async {
    try {
      final created = await repository.createCollection(name: name.trim());
      await repository.addRepo(created.id, repoId);
      final result = await repository.getCollections();
      emit(state.copyWith(
        collections: result.data,
        selectedIds: {...state.selectedIds, created.id},
        changed: true,
      ));
      return null;
    } catch (e) {
      return e.toString();
    }
  }
}
