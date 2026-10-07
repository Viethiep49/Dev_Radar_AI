import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../data/models/collection_model.dart';
import '../../../data/repositories/collection_repository.dart';
import '../../state/collections/collection_detail_cubit.dart';
import '../../state/load_status.dart';
import '../../widgets/common/ambient_background.dart';
import '../../widgets/common/state_views.dart';
import '../../widgets/glass/glass_container.dart';
import 'widgets/collection_widgets.dart';

/// One collection: its repos (tap -> repo detail), remove a repo, rename, delete.
/// Pops with `true` when the collection changed, so the list can refresh.
class CollectionDetailScreen extends StatelessWidget {
  final int collectionId;

  const CollectionDetailScreen({super.key, required this.collectionId});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (ctx) => CollectionDetailCubit(ctx.read<CollectionRepository>(), collectionId)..load(),
      child: const _CollectionDetailView(),
    );
  }
}

enum _MenuAction { edit, delete }

class _CollectionDetailView extends StatelessWidget {
  const _CollectionDetailView();

  Future<void> _edit(BuildContext context, CollectionModel collection) async {
    final cubit = context.read<CollectionDetailCubit>();
    final result = await showCollectionForm(
      context,
      title: 'Sửa bộ sưu tập',
      submitText: 'Lưu',
      initialName: collection.name,
      initialDescription: collection.description,
    );
    if (result == null) return;
    final error = await cubit.rename(name: result.name, description: result.description);
    if (!context.mounted) return;
    error != null ? showErrorSnack(context, error) : showSuccessSnack(context, 'Đã cập nhật bộ sưu tập');
  }

  Future<void> _delete(BuildContext context, CollectionModel collection) async {
    final cubit = context.read<CollectionDetailCubit>();
    final confirmed = await confirmDelete(
      context,
      title: 'Xoá bộ sưu tập?',
      message: 'Bộ sưu tập "${collection.name}" sẽ bị xoá. Các repo vẫn còn trong hệ thống.',
    );
    if (!confirmed) return;
    final error = await cubit.delete();
    if (error != null && context.mounted) showErrorSnack(context, error);
  }

  Future<void> _removeRepo(BuildContext context, CollectionRepoModel item) async {
    final cubit = context.read<CollectionDetailCubit>();
    final confirmed = await confirmDelete(
      context,
      title: 'Gỡ repo?',
      message: 'Gỡ ${item.repo.fullName} khỏi bộ sưu tập này?',
    );
    if (!confirmed) return;
    final error = await cubit.removeRepo(item.repo.id);
    if (error != null && context.mounted) showErrorSnack(context, error);
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<CollectionDetailCubit, CollectionDetailState>(
      listenWhen: (prev, curr) => !prev.deleted && curr.deleted,
      listener: (context, state) => context.pop(true),
      builder: (context, state) {
        final collection = state.detail?.collection;
        final cubit = context.read<CollectionDetailCubit>();
        return PopScope(
          canPop: false,
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop) context.pop(cubit.changed);
          },
          child: Scaffold(
            extendBodyBehindAppBar: true,
            backgroundColor: Colors.transparent,
            appBar: AppBar(
              backgroundColor: Colors.transparent,
              title: Text(collection?.name ?? 'Bộ sưu tập', maxLines: 1, overflow: TextOverflow.ellipsis),
              actions: [
                if (collection != null)
                  PopupMenuButton<_MenuAction>(
                    onSelected: (action) => action == _MenuAction.edit
                        ? _edit(context, collection)
                        : _delete(context, collection),
                    itemBuilder: (_) => const [
                      PopupMenuItem(
                        value: _MenuAction.edit,
                        child: ListTile(leading: Icon(Icons.edit_outlined), title: Text('Sửa tên / mô tả')),
                      ),
                      PopupMenuItem(
                        value: _MenuAction.delete,
                        child: ListTile(
                          leading: Icon(Icons.delete_outline_rounded, color: AppColors.error),
                          title: Text('Xoá bộ sưu tập'),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
            body: AmbientBackground(
              child: SafeArea(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: _buildBody(context, state),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildBody(BuildContext context, CollectionDetailState state) {
    final cubit = context.read<CollectionDetailCubit>();
    final detail = state.detail;
    if (detail == null) {
      if (state.status == LoadStatus.failure) {
        return ErrorRetryView(
          key: const ValueKey('error'),
          message: state.errorMessage ?? 'Không tải được bộ sưu tập',
          onRetry: cubit.load,
        );
      }
      return const SkeletonList(key: ValueKey('loading'), count: 5);
    }

    final collection = detail.collection;
    return RefreshIndicator(
      key: const ValueKey('content'),
      onRefresh: cubit.load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          if (state.fromCache)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: OfflineBanner(cachedAt: state.cachedAt, onRetry: cubit.load),
            ),
          GlassContainer(
            borderRadius: 20,
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withAlpha(35),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(Icons.folder_special_rounded, color: AppColors.primary, size: 28),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        collection.description?.isNotEmpty == true ? collection.description! : 'Không có mô tả',
                        style: TextStyle(fontSize: 13.5, color: textPrimary(context), height: 1.35),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '${detail.repos.length} repo · cập nhật ${formatDate(collection.updatedAt)}',
                        style: TextStyle(fontSize: 12, color: textMuted(context)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          if (detail.repos.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 32),
              child: EmptyView(
                icon: Icons.inventory_2_outlined,
                title: 'Bộ sưu tập đang trống',
                subtitle: 'Mở một repo và chọn "Thêm vào bộ sưu tập" để lưu vào đây.',
              ),
            )
          else
            for (final item in detail.repos)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: RepoBriefTile(
                  repo: item.repo,
                  onTap: () => context.push('/repo/${item.repo.id}', extra: item.repo.toRepoModel()),
                  footer: Text(
                    'Thêm vào ${formatDate(item.addedAt)}',
                    style: TextStyle(fontSize: 11.5, color: textMuted(context)),
                  ),
                  trailing: IconButton(
                    tooltip: 'Gỡ khỏi bộ sưu tập',
                    icon: const Icon(Icons.remove_circle_outline_rounded, color: AppColors.error),
                    onPressed: () => _removeRepo(context, item),
                  ),
                ),
              ),
        ],
      ),
    );
  }
}
