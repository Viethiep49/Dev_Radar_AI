import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../../../data/models/watchlist_item_model.dart';
import '../../../data/repositories/watchlist_repository.dart';
import '../../state/watchlist/watchlist_cubit.dart';
import '../../widgets/common/glass_page_scaffold.dart';
import '../../widgets/common/state_views.dart';
import '../../widgets/glass/glass_card.dart';

/// Repos the user watches: they get a notification when a new release comes out.
class WatchlistScreen extends StatelessWidget {
  const WatchlistScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (ctx) => WatchlistCubit(ctx.read<WatchlistRepository>())..load(),
      child: const _WatchlistView(),
    );
  }
}

class _WatchlistView extends StatelessWidget {
  const _WatchlistView();

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<WatchlistCubit, WatchlistState>(
      listenWhen: (prev, curr) => curr.actionError != null && prev.actionError != curr.actionError,
      listener: (context, state) => ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(state.actionError!), backgroundColor: AppColors.error),
      ),
      builder: (context, state) {
        final cubit = context.read<WatchlistCubit>();
        return GlassPageScaffold(
          title: 'Repo đang theo dõi',
          subtitle: 'Nhận thông báo khi có phiên bản mới',
          body: AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: _buildBody(context, state, cubit),
          ),
        );
      },
    );
  }

  Widget _buildBody(BuildContext context, WatchlistState state, WatchlistCubit cubit) {
    if (state.status == WatchlistStatus.initial || state.status == WatchlistStatus.loading) {
      return const SkeletonList(key: ValueKey('loading'), itemHeight: 84);
    }
    if (state.status == WatchlistStatus.failure && state.items.isEmpty) {
      return ErrorRetryView(
        key: const ValueKey('error'),
        message: state.errorMessage ?? 'Không tải được danh sách theo dõi',
        onRetry: cubit.load,
      );
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
                  icon: Icons.visibility_outlined,
                  title: 'Bạn chưa theo dõi repo nào',
                  subtitle: 'Mở chi tiết một repo và bấm "Theo dõi" để nhận thông báo release mới.',
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
                return _WatchTile(
                  item: item,
                  onTap: () => context.push('/repo/${item.repo.id}', extra: item.repo.toRepoModel()),
                  onUnwatch: () => _confirmUnwatch(context, cubit, item),
                );
              },
            ),
    );
  }

  Future<void> _confirmUnwatch(BuildContext context, WatchlistCubit cubit, WatchlistItemModel item) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Bỏ theo dõi?'),
        content: Text('Bạn sẽ không nhận thông báo release mới của ${item.repo.fullName} nữa.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Huỷ')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Bỏ theo dõi')),
        ],
      ),
    );
    if (ok == true) {
      await cubit.unwatch(item.repo.id);
    }
  }
}

class _WatchTile extends StatelessWidget {
  final WatchlistItemModel item;
  final VoidCallback onTap;
  final VoidCallback onUnwatch;

  const _WatchTile({required this.item, required this.onTap, required this.onUnwatch});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final muted = isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted;
    final repo = item.repo;
    // Same image proxy as the other repo lists (github.com avatars have no CORS headers on web).
    final avatar = repo.toRepoModel().effectiveOwnerAvatarUrl;
    return GlassCard(
      onTap: onTap,
      padding: const EdgeInsets.all(14),
      borderRadius: 18,
      child: Row(
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: isDark ? AppColors.darkElevated : AppColors.lightElevated,
            foregroundImage: NetworkImage(avatar),
            child: Text(repo.owner.isEmpty ? '?' : repo.owner[0].toUpperCase()),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  repo.fullName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 10,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.star_rounded, size: 14, color: AppColors.warning),
                        const SizedBox(width: 3),
                        Text(NumberFormat.compact().format(repo.stars), style: TextStyle(fontSize: 12, color: muted)),
                      ],
                    ),
                    if (item.latestReleaseTag != null)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.success.withAlpha(35),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          item.latestReleaseTag!,
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.success),
                        ),
                      )
                    else
                      Text('Chưa có release', style: TextStyle(fontSize: 11.5, color: muted)),
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Bỏ theo dõi',
            onPressed: onUnwatch,
            icon: const Icon(Icons.visibility_off_outlined),
          ),
        ],
      ),
    );
  }
}
