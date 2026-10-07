import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../data/models/learning_model.dart';
import '../../../data/repositories/learning_repository.dart';
import '../load_status.dart';

class LearningState extends Equatable {
  final LoadStatus status;
  final List<LearningItemModel> items;

  /// null = all statuses.
  final LearningStatus? filter;
  final bool fromCache;
  final DateTime? cachedAt;
  final String? errorMessage;

  const LearningState({
    this.status = LoadStatus.initial,
    this.items = const [],
    this.filter,
    this.fromCache = false,
    this.cachedAt,
    this.errorMessage,
  });

  LearningState copyWith({
    LoadStatus? status,
    List<LearningItemModel>? items,
    LearningStatus? Function()? filter,
    bool? fromCache,
    DateTime? cachedAt,
    String? errorMessage,
  }) {
    return LearningState(
      status: status ?? this.status,
      items: items ?? this.items,
      filter: filter != null ? filter() : this.filter,
      fromCache: fromCache ?? this.fromCache,
      cachedAt: cachedAt ?? this.cachedAt,
      errorMessage: errorMessage,
    );
  }

  @override
  List<Object?> get props => [status, items, filter, fromCache, cachedAt, errorMessage];
}

/// Learning path: repos by status (Muốn thử / Đang tìm hiểu / Đã sử dụng).
class LearningCubit extends Cubit<LearningState> {
  final LearningRepository repository;

  LearningCubit(this.repository) : super(const LearningState());

  Future<void> load() async {
    final filter = state.filter;
    emit(state.copyWith(status: state.items.isEmpty ? LoadStatus.loading : state.status));
    try {
      final result = await repository.getItems(status: filter);
      if (filter != state.filter) return; // filter changed meanwhile
      emit(state.copyWith(
        status: LoadStatus.success,
        items: result.data,
        fromCache: result.fromCache,
        cachedAt: result.cachedAt,
      ));
    } catch (e) {
      if (filter != state.filter) return;
      emit(state.copyWith(status: LoadStatus.failure, errorMessage: e.toString()));
    }
  }

  Future<void> setFilter(LearningStatus? filter) async {
    if (filter == state.filter && state.status == LoadStatus.success) return;
    emit(state.copyWith(filter: () => filter, items: const [], status: LoadStatus.loading));
    await load();
  }

  /// Change the status of a repo; null removes it from the learning path.
  Future<String?> changeStatus(int repoId, LearningStatus? status) async {
    try {
      await repository.setStatus(repoId, status);
      await load();
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  Future<String?> remove(int repoId) => changeStatus(repoId, null);
}
