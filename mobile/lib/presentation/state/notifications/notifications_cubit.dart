import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../data/models/notification_model.dart';
import '../../../data/repositories/notification_repository.dart';

enum NotificationsStatus { initial, loading, loaded, failure }

class NotificationsState extends Equatable {
  final NotificationsStatus status;
  final List<NotificationModel> items;
  final bool fromCache;
  final DateTime? cachedAt;

  /// Error of the initial load (full-screen error view).
  final String? errorMessage;

  /// Error of an action (mark read, delete...): shown in a snackbar, the list stays.
  final String? actionError;

  const NotificationsState({
    this.status = NotificationsStatus.initial,
    this.items = const [],
    this.fromCache = false,
    this.cachedAt,
    this.errorMessage,
    this.actionError,
  });

  int get unreadCount => items.where((n) => !n.isRead).length;

  NotificationsState copyWith({
    NotificationsStatus? status,
    List<NotificationModel>? items,
    bool? fromCache,
    DateTime? cachedAt,
    String? errorMessage,
    String? actionError,
  }) {
    return NotificationsState(
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

class NotificationsCubit extends Cubit<NotificationsState> {
  final NotificationRepository notificationRepository;

  NotificationsCubit(this.notificationRepository) : super(const NotificationsState());

  Future<void> load() async {
    if (state.items.isEmpty) {
      emit(state.copyWith(status: NotificationsStatus.loading));
    }
    try {
      final result = await notificationRepository.getNotifications();
      emit(state.copyWith(
        status: NotificationsStatus.loaded,
        items: result.data,
        fromCache: result.fromCache,
        cachedAt: result.cachedAt,
      ));
    } catch (e) {
      emit(state.copyWith(status: NotificationsStatus.failure, errorMessage: e.toString()));
    }
  }

  /// Optimistic: the item is shown as read at once, reverted if the call fails.
  Future<void> markRead(int id) async {
    final before = state.items;
    final target = before.where((n) => n.id == id).firstOrNull;
    if (target == null || target.isRead) return;
    emit(state.copyWith(items: [for (final n in before) n.id == id ? n.copyWith(isRead: true) : n]));
    try {
      await notificationRepository.markRead(id);
    } catch (e) {
      emit(state.copyWith(items: before, actionError: e.toString()));
    }
  }

  Future<void> markAllRead() async {
    final before = state.items;
    if (state.unreadCount == 0) return;
    emit(state.copyWith(items: [for (final n in before) n.copyWith(isRead: true)]));
    try {
      await notificationRepository.markAllRead();
    } catch (e) {
      emit(state.copyWith(items: before, actionError: e.toString()));
    }
  }

  Future<void> delete(int id) async {
    final before = state.items;
    emit(state.copyWith(items: before.where((n) => n.id != id).toList()));
    try {
      await notificationRepository.delete(id);
    } catch (e) {
      emit(state.copyWith(items: before, actionError: e.toString()));
    }
  }
}

/// Unread badge of the bell icon. Errors are ignored (the badge just keeps its value).
class UnreadCountCubit extends Cubit<int> {
  final NotificationRepository notificationRepository;

  UnreadCountCubit(this.notificationRepository) : super(0);

  Future<void> refresh() async {
    try {
      emit(await notificationRepository.getUnreadCount());
    } catch (_) {}
  }
}
