import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../data/models/watchlist_item_model.dart';
import '../../../data/repositories/watchlist_repository.dart';

enum WatchlistStatus { initial, loading, loaded, failure }

class WatchlistState extends Equatable {
  final WatchlistStatus status;
  final List<WatchlistItemModel> items;
  final bool fromCache;
  final DateTime? cachedAt;
  final String? errorMessage;
  final String? actionError;

  const WatchlistState({
    this.status = WatchlistStatus.initial,
    this.items = const [],
    this.fromCache = false,
    this.cachedAt,
    this.errorMessage,
    this.actionError,
  });

  WatchlistState copyWith({
    WatchlistStatus? status,
    List<WatchlistItemModel>? items,
    bool? fromCache,
    DateTime? cachedAt,
    String? errorMessage,
    String? actionError,
  }) {
    return WatchlistState(
      status: status ?? this.status,
      items: items ?? this.items,
      fromCache: fromCache ?? this.fromCache,
      cachedAt: cachedAt ?? this.cachedAt,
      errorMessage: errorMessage,
      actionError: actionError,
    );
  }

  @override
  List<Object?> get props => [status, items, fromCache, cachedAt, errorMessage, actionError];
}

class WatchlistCubit extends Cubit<WatchlistState> {
  final WatchlistRepository watchlistRepository;

  WatchlistCubit(this.watchlistRepository) : super(const WatchlistState());

  Future<void> load() async {
    if (state.items.isEmpty) {
      emit(state.copyWith(status: WatchlistStatus.loading));
    }
    try {
      final result = await watchlistRepository.getWatchlist();
      emit(state.copyWith(
        status: WatchlistStatus.loaded,
        items: result.data,
        fromCache: result.fromCache,
        cachedAt: result.cachedAt,
      ));
    } catch (e) {
      emit(state.copyWith(status: WatchlistStatus.failure, errorMessage: e.toString()));
    }
  }

  /// Optimistic remove, restored if the call fails.
  Future<void> unwatch(int repoId) async {
    final before = state.items;
    emit(state.copyWith(items: before.where((item) => item.repo.id != repoId).toList()));
    try {
      await watchlistRepository.unwatch(repoId);
    } catch (e) {
      emit(state.copyWith(items: before, actionError: e.toString()));
    }
  }
}
