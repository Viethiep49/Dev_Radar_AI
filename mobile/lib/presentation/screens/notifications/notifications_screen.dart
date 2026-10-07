import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../../../data/models/notification_model.dart';
import '../../../data/repositories/notification_repository.dart';
import '../../state/notifications/notifications_cubit.dart';
import '../../widgets/common/glass_page_scaffold.dart';
import '../../widgets/common/state_views.dart';
import '../../widgets/glass/glass_card.dart';

/// List of notifications received (new releases of watched repos...).
class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (ctx) => NotificationsCubit(ctx.read<NotificationRepository>())..load(),
      child: const _NotificationsView(),
    );
  }
}

class _NotificationsView extends StatelessWidget {
  const _NotificationsView();

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<NotificationsCubit, NotificationsState>(
      listenWhen: (prev, curr) => curr.actionError != null && prev.actionError != curr.actionError,
      listener: (context, state) => ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(state.actionError!), backgroundColor: AppColors.error),
      ),
      builder: (context, state) {
        final cubit = context.read<NotificationsCubit>();
        return GlassPageScaffold(
          title: 'Thông báo',
          subtitle: state.unreadCount > 0 ? '${state.unreadCount} chưa đọc' : 'Bạn đã đọc hết',
          actions: [
            if (state.unreadCount > 0)
              TextButton.icon(
                onPressed: cubit.markAllRead,
                icon: const Icon(Icons.done_all_rounded, size: 18),
                label: const Text('Đọc hết'),
              ),
          ],
          body: AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: _buildBody(context, state, cubit),
          ),
        );
      },
    );
  }

  Widget _buildBody(BuildContext context, NotificationsState state, NotificationsCubit cubit) {
    switch (state.status) {
      case NotificationsStatus.initial:
      case NotificationsStatus.loading:
        return const SkeletonList(key: ValueKey('loading'), itemHeight: 76);
      case NotificationsStatus.failure:
        if (state.items.isEmpty) {
          return ErrorRetryView(
            key: const ValueKey('error'),
            message: state.errorMessage ?? 'Không tải được thông báo',
            onRetry: cubit.load,
          );
        }
      case NotificationsStatus.loaded:
        break;
    }
    return RefreshIndicator(
      key: const ValueKey('list'),
      onRefresh: cubit.load,
      child: state.items.isEmpty
          ? ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: const [
                SizedBox(height: 80),
                EmptyView(
                  icon: Icons.notifications_none_rounded,
                  title: 'Chưa có thông báo nào',
                  subtitle: 'Theo dõi một repo để được báo khi có phiên bản mới.',
                ),
              ],
            )
          : ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
              itemCount: state.items.length + (state.fromCache ? 1 : 0),
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                if (state.fromCache) {
                  if (index == 0) return OfflineBanner(cachedAt: state.cachedAt, onRetry: cubit.load);
                  index--;
                }
                final item = state.items[index];
                return Dismissible(
                  key: ValueKey('notification-${item.id}'),
                  direction: DismissDirection.endToStart,
                  background: Container(
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 24),
                    decoration: BoxDecoration(
                      color: AppColors.error.withAlpha(60),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: const Icon(Icons.delete_outline_rounded, color: AppColors.error),
                  ),
                  onDismissed: (_) => cubit.delete(item.id),
                  child: _NotificationTile(
                    item: item,
                    onTap: () {
                      cubit.markRead(item.id);
                      if (item.repoId != null) {
                        context.push('/repo/${item.repoId}');
                      }
                    },
                  ),
                );
              },
            ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  final NotificationModel item;
  final VoidCallback onTap;

  const _NotificationTile({required this.item, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isRelease = item.type == 'release';
    final color = isRelease ? AppColors.success : AppColors.primary;
    return GlassCard(
      onTap: onTap,
      padding: const EdgeInsets.all(14),
      borderRadius: 18,
      enableGlow: !item.isRead,
      glowColor: AppColors.primary.withAlpha(25),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(color: color.withAlpha(35), shape: BoxShape.circle),
            child: Icon(isRelease ? Icons.new_releases_rounded : Icons.notifications_rounded, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: item.isRead ? FontWeight.w500 : FontWeight.bold,
                  ),
                ),
                if (item.body != null && item.body!.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    item.body!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12.5,
                      color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                    ),
                  ),
                ],
                const SizedBox(height: 6),
                Text(
                  _relativeTime(item.createdAt),
                  style: TextStyle(fontSize: 11, color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted),
                ),
              ],
            ),
          ),
          if (!item.isRead)
            Container(
              margin: const EdgeInsets.only(left: 8, top: 4),
              width: 9,
              height: 9,
              decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
            ),
        ],
      ),
    );
  }

  static String _relativeTime(DateTime time) {
    final diff = DateTime.now().difference(time.toLocal());
    if (diff.inMinutes < 1) return 'Vừa xong';
    if (diff.inHours < 1) return '${diff.inMinutes} phút trước';
    if (diff.inDays < 1) return '${diff.inHours} giờ trước';
    if (diff.inDays < 7) return '${diff.inDays} ngày trước';
    return DateFormat('dd/MM/yyyy').format(time.toLocal());
  }
}
