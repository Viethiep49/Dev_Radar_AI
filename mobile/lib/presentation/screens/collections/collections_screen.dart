import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../data/models/collection_model.dart';
import '../../../data/models/learning_model.dart';
import '../../../data/models/note_model.dart';
import '../../../data/repositories/collection_repository.dart';
import '../../../data/repositories/learning_repository.dart';
import '../../../data/repositories/note_repository.dart';
import '../../state/collections/collections_cubit.dart';
import '../../state/learning/learning_cubit.dart';
import '../../state/load_status.dart';
import '../../state/notes/notes_cubit.dart';
import '../../widgets/common/state_views.dart';
import '../../widgets/glass/glass_card.dart';
import '../../widgets/glass/glass_icon_button.dart';
import '../../widgets/glass/glass_search_bar.dart';
import '../notes/note_editor_screen.dart';
import 'widgets/collection_widgets.dart';

enum _Segment { collections, notes, learning }

/// "Thư viện" tab: my collections, my notes and my learning path.
class CollectionsScreen extends StatefulWidget {
  const CollectionsScreen({super.key});

  @override
  State<CollectionsScreen> createState() => _CollectionsScreenState();
}

class _CollectionsScreenState extends State<CollectionsScreen> {
  _Segment _segment = _Segment.collections;

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(create: (ctx) => CollectionsCubit(ctx.read<CollectionRepository>())..load()),
        BlocProvider(create: (ctx) => NotesCubit(ctx.read<NoteRepository>())..load()),
        BlocProvider(create: (ctx) => LearningCubit(ctx.read<LearningRepository>())..load()),
      ],
      child: Builder(
        builder: (context) => SafeArea(
          bottom: false,
          child: Column(
            children: [
              _Header(
                segment: _segment,
                onCreate: () => _CollectionsTab.create(context),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                child: SizedBox(
                  width: double.infinity,
                  child: SegmentedButton<_Segment>(
                    showSelectedIcon: false,
                    segments: const [
                      ButtonSegment(
                        value: _Segment.collections,
                        label: Text('Bộ sưu tập', overflow: TextOverflow.ellipsis),
                      ),
                      ButtonSegment(
                        value: _Segment.notes,
                        label: Text('Ghi chú', overflow: TextOverflow.ellipsis),
                      ),
                      ButtonSegment(
                        value: _Segment.learning,
                        label: Text('Lộ trình', overflow: TextOverflow.ellipsis),
                      ),
                    ],
                    selected: {_segment},
                    onSelectionChanged: (selection) {
                      final segment = selection.first;
                      setState(() => _segment = segment);
                      // Data may have changed elsewhere (e.g. repo detail): refresh quietly.
                      switch (segment) {
                        case _Segment.collections:
                          context.read<CollectionsCubit>().load();
                        case _Segment.notes:
                          context.read<NotesCubit>().load();
                        case _Segment.learning:
                          context.read<LearningCubit>().load();
                      }
                    },
                  ),
                ),
              ),
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 280),
                  switchInCurve: Curves.easeOutCubic,
                  transitionBuilder: (child, animation) => FadeTransition(
                    opacity: animation,
                    child: SlideTransition(
                      position: Tween(begin: const Offset(0.04, 0), end: Offset.zero).animate(animation),
                      child: child,
                    ),
                  ),
                  child: switch (_segment) {
                    _Segment.collections => const _CollectionsTab(key: ValueKey('collections')),
                    _Segment.notes => const _NotesTab(key: ValueKey('notes')),
                    _Segment.learning => const _LearningTab(key: ValueKey('learning')),
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final _Segment segment;
  final VoidCallback onCreate;

  const _Header({required this.segment, required this.onCreate});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Thư viện của tôi',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: textPrimary(context),
                    letterSpacing: -0.4,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Bộ sưu tập, ghi chú và lộ trình học của bạn',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 11.5, color: textMuted(context)),
                ),
              ],
            ),
          ),
          AnimatedScale(
            scale: segment == _Segment.collections ? 1 : 0,
            duration: const Duration(milliseconds: 200),
            child: GlassIconButton(
              icon: Icons.create_new_folder_outlined,
              tooltip: 'Tạo bộ sưu tập',
              onPressed: segment == _Segment.collections ? onCreate : () {},
            ),
          ),
        ],
      ),
    );
  }
}

/// Search box that calls [onSearch] 400 ms after the user stops typing.
class _DebouncedSearch extends StatefulWidget {
  final String hint;
  final ValueChanged<String> onSearch;

  const _DebouncedSearch({required this.hint, required this.onSearch});

  @override
  State<_DebouncedSearch> createState() => _DebouncedSearchState();
}

class _DebouncedSearchState extends State<_DebouncedSearch> {
  final _controller = TextEditingController();
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      child: GlassSearchBar(
        controller: _controller,
        hintText: widget.hint,
        onChanged: (value) {
          _debounce?.cancel();
          _debounce = Timer(const Duration(milliseconds: 400), () => widget.onSearch(value));
        },
        onSubmitted: (value) {
          _debounce?.cancel();
          widget.onSearch(value);
        },
        onClear: () {
          _debounce?.cancel();
          widget.onSearch('');
        },
      ),
    );
  }
}

// ---------------------------------------------------------------- Collections

class _CollectionsTab extends StatelessWidget {
  const _CollectionsTab({super.key});

  static Future<void> create(BuildContext context) async {
    final cubit = context.read<CollectionsCubit>();
    final result = await showCollectionForm(context);
    if (result == null) return;
    final error = await cubit.create(name: result.name, description: result.description);
    if (!context.mounted) return;
    error != null ? showErrorSnack(context, error) : showSuccessSnack(context, 'Đã tạo "${result.name}"');
  }

  Future<void> _open(BuildContext context, CollectionModel collection) async {
    final cubit = context.read<CollectionsCubit>();
    final changed = await context.push<bool>('/collections/${collection.id}');
    if (changed == true) await cubit.load();
  }

  Future<void> _showActions(BuildContext context, CollectionModel collection) async {
    final cubit = context.read<CollectionsCubit>();
    final action = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: const Text('Sửa tên / mô tả'),
              onTap: () => Navigator.of(ctx).pop('edit'),
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline_rounded, color: AppColors.error),
              title: const Text('Xoá bộ sưu tập'),
              onTap: () => Navigator.of(ctx).pop('delete'),
            ),
          ],
        ),
      ),
    );
    if (!context.mounted || action == null) return;

    String? error;
    if (action == 'edit') {
      final result = await showCollectionForm(
        context,
        title: 'Sửa bộ sưu tập',
        submitText: 'Lưu',
        initialName: collection.name,
        initialDescription: collection.description,
      );
      if (result == null) return;
      error = await cubit.update(collection.id, name: result.name, description: result.description);
    } else {
      final confirmed = await confirmDelete(
        context,
        title: 'Xoá bộ sưu tập?',
        message: 'Bộ sưu tập "${collection.name}" sẽ bị xoá. Các repo vẫn còn trong hệ thống.',
      );
      if (!confirmed) return;
      error = await cubit.delete(collection.id);
    }
    if (error != null && context.mounted) showErrorSnack(context, error);
  }

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<CollectionsCubit>();
    return Column(
      children: [
        _DebouncedSearch(hint: 'Tìm bộ sưu tập...', onSearch: cubit.search),
        Expanded(
          child: BlocBuilder<CollectionsCubit, CollectionsState>(
            builder: (context, state) {
              if (state.status == LoadStatus.initial ||
                  (state.status == LoadStatus.loading && state.collections.isEmpty)) {
                return const SkeletonList(count: 5, itemHeight: 76);
              }
              if (state.status == LoadStatus.failure && state.collections.isEmpty) {
                return ErrorRetryView(
                  message: state.errorMessage ?? 'Không tải được bộ sưu tập',
                  onRetry: cubit.load,
                );
              }
              return RefreshIndicator(
                onRefresh: cubit.load,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 110),
                  children: [
                    if (state.fromCache)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: OfflineBanner(cachedAt: state.cachedAt, onRetry: cubit.load),
                      ),
                    if (state.collections.isEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 40),
                        child: state.query.isNotEmpty
                            ? EmptyView(
                                icon: Icons.search_off_rounded,
                                title: 'Không tìm thấy bộ sưu tập',
                                subtitle: 'Không có kết quả cho "${state.query}"',
                              )
                            : EmptyView(
                                icon: Icons.folder_open_rounded,
                                title: 'Chưa có bộ sưu tập nào',
                                subtitle: 'Tạo bộ sưu tập để phân loại repo theo lộ trình học.',
                                action: FilledButton.icon(
                                  onPressed: () => create(context),
                                  icon: const Icon(Icons.add_rounded),
                                  label: const Text('Tạo bộ sưu tập đầu tiên'),
                                ),
                              ),
                      ),
                    for (var i = 0; i < state.collections.length; i++)
                      _AnimatedEntry(
                        key: ValueKey('collection-${state.collections[i].id}'),
                        index: i,
                        child: _CollectionCard(
                          collection: state.collections[i],
                          onTap: () => _open(context, state.collections[i]),
                          onMore: () => _showActions(context, state.collections[i]),
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

/// Fade + slide-in for list items, staggered by index.
class _AnimatedEntry extends StatelessWidget {
  final int index;
  final Widget child;

  const _AnimatedEntry({super.key, required this.index, required this.child});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 260 + 40 * index.clamp(0, 8)),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) => Opacity(
        opacity: value,
        child: Transform.translate(offset: Offset(0, 16 * (1 - value)), child: child),
      ),
      child: Padding(padding: const EdgeInsets.only(bottom: 10), child: child),
    );
  }
}

class _CollectionCard extends StatelessWidget {
  final CollectionModel collection;
  final VoidCallback onTap;
  final VoidCallback onMore;

  const _CollectionCard({required this.collection, required this.onTap, required this.onMore});

  static const _palette = [
    AppColors.primary,
    AppColors.secondary,
    AppColors.accent,
    AppColors.warning,
    AppColors.info,
  ];

  @override
  Widget build(BuildContext context) {
    final color = _palette[collection.id % _palette.length];
    return GestureDetector(
      onLongPress: onMore,
      child: GlassCard(
        onTap: onTap,
        padding: const EdgeInsets.fromLTRB(14, 12, 4, 12),
        borderRadius: 18,
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withAlpha(35),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(Icons.folder_rounded, color: color),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    collection.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: textPrimary(context)),
                  ),
                  if (collection.description?.isNotEmpty == true) ...[
                    const SizedBox(height: 2),
                    Text(
                      collection.description!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 12.5, color: textMuted(context)),
                    ),
                  ],
                  const SizedBox(height: 4),
                  Text(
                    '${collection.itemCount} repo · ${formatDate(collection.updatedAt)}',
                    style: TextStyle(fontSize: 11.5, color: textMuted(context)),
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: 'Tuỳ chọn',
              icon: const Icon(Icons.more_vert_rounded),
              onPressed: onMore,
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------- Notes

class _NotesTab extends StatelessWidget {
  const _NotesTab({super.key});

  Future<void> _edit(BuildContext context, NoteModel note) async {
    final cubit = context.read<NotesCubit>();
    final changed = await context.push<bool>('/notes/edit', extra: NoteEditorArgs(note: note));
    if (changed == true) await cubit.load();
  }

  Future<bool> _confirmAndDelete(BuildContext context, NoteModel note) async {
    final cubit = context.read<NotesCubit>();
    final confirmed = await confirmDelete(
      context,
      title: 'Xoá ghi chú?',
      message: 'Ghi chú về ${note.repo.fullName} sẽ bị xoá vĩnh viễn.',
    );
    if (!confirmed) return false;
    final error = await cubit.delete(note.id);
    if (error != null && context.mounted) showErrorSnack(context, error);
    return error == null;
  }

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<NotesCubit>();
    return Column(
      children: [
        _DebouncedSearch(hint: 'Tìm trong ghi chú...', onSearch: cubit.search),
        Expanded(
          child: BlocBuilder<NotesCubit, NotesState>(
            builder: (context, state) {
              if (state.status == LoadStatus.initial ||
                  (state.status == LoadStatus.loading && state.notes.isEmpty)) {
                return const SkeletonList(count: 4, itemHeight: 96);
              }
              if (state.status == LoadStatus.failure && state.notes.isEmpty) {
                return ErrorRetryView(
                  message: state.errorMessage ?? 'Không tải được ghi chú',
                  onRetry: cubit.load,
                );
              }
              return RefreshIndicator(
                onRefresh: cubit.load,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 110),
                  children: [
                    if (state.fromCache)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: OfflineBanner(cachedAt: state.cachedAt, onRetry: cubit.load),
                      ),
                    if (state.notes.isEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 40),
                        child: state.query.isNotEmpty
                            ? EmptyView(
                                icon: Icons.search_off_rounded,
                                title: 'Không tìm thấy ghi chú',
                                subtitle: 'Không có kết quả cho "${state.query}"',
                              )
                            : const EmptyView(
                                icon: Icons.sticky_note_2_outlined,
                                title: 'Chưa có ghi chú nào',
                                subtitle: 'Mở trang chi tiết một repo để thêm ghi chú cho repo đó.',
                              ),
                      ),
                    for (var i = 0; i < state.notes.length; i++)
                      _AnimatedEntry(
                        key: ValueKey('note-${state.notes[i].id}'),
                        index: i,
                        child: Dismissible(
                          key: ValueKey('dismiss-note-${state.notes[i].id}'),
                          direction: DismissDirection.endToStart,
                          confirmDismiss: (_) => _confirmAndDelete(context, state.notes[i]),
                          background: Container(
                            alignment: Alignment.centerRight,
                            padding: const EdgeInsets.only(right: 24),
                            decoration: BoxDecoration(
                              color: AppColors.error.withAlpha(50),
                              borderRadius: BorderRadius.circular(18),
                            ),
                            child: const Icon(Icons.delete_outline_rounded, color: AppColors.error),
                          ),
                          child: _NoteCard(note: state.notes[i], onTap: () => _edit(context, state.notes[i])),
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _NoteCard extends StatelessWidget {
  final NoteModel note;
  final VoidCallback onTap;

  const _NoteCard({required this.note, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      onTap: onTap,
      padding: const EdgeInsets.all(14),
      borderRadius: 18,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.book_outlined, size: 16, color: AppColors.primary),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  note.repo.fullName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppColors.primary),
                ),
              ),
              Text(formatDate(note.updatedAt), style: TextStyle(fontSize: 11.5, color: textMuted(context))),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            note.content,
            maxLines: 4,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 13.5, height: 1.4, color: textPrimary(context)),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------- Learning path

class _LearningTab extends StatelessWidget {
  const _LearningTab({super.key});

  Future<void> _changeStatus(BuildContext context, LearningItemModel item, LearningStatus? status) async {
    final cubit = context.read<LearningCubit>();
    if (status == null) {
      final confirmed = await confirmDelete(
        context,
        title: 'Bỏ khỏi lộ trình?',
        message: 'Bỏ ${item.repo.fullName} khỏi lộ trình học của bạn?',
      );
      if (!confirmed) return;
    }
    final error = await cubit.changeStatus(item.repoId, status);
    if (error != null && context.mounted) showErrorSnack(context, error);
  }

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<LearningCubit>();
    return BlocBuilder<LearningCubit, LearningState>(
      builder: (context, state) {
        return Column(
          children: [
            SizedBox(
              height: 44,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  _filterChip(context, null, 'Tất cả', state.filter),
                  for (final status in LearningStatus.values)
                    _filterChip(context, status, status.label, state.filter),
                ],
              ),
            ),
            const SizedBox(height: 6),
            Expanded(child: _buildList(context, cubit, state)),
          ],
        );
      },
    );
  }

  Widget _filterChip(BuildContext context, LearningStatus? status, String label, LearningStatus? selected) {
    final color = status == null ? AppColors.primary : learningStatusColor(status);
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        avatar: status == null ? null : Icon(learningStatusIcon(status), size: 16, color: color),
        selected: selected == status,
        selectedColor: color.withAlpha(45),
        onSelected: (_) => context.read<LearningCubit>().setFilter(status),
      ),
    );
  }

  Widget _buildList(BuildContext context, LearningCubit cubit, LearningState state) {
    if (state.status == LoadStatus.initial || (state.status == LoadStatus.loading && state.items.isEmpty)) {
      return const SkeletonList(count: 4);
    }
    if (state.status == LoadStatus.failure && state.items.isEmpty) {
      return ErrorRetryView(message: state.errorMessage ?? 'Không tải được lộ trình học', onRetry: cubit.load);
    }
    return RefreshIndicator(
      onRefresh: cubit.load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 110),
        children: [
          if (state.fromCache)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: OfflineBanner(cachedAt: state.cachedAt, onRetry: cubit.load),
            ),
          if (state.items.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 40),
              child: EmptyView(
                icon: Icons.route_outlined,
                title: state.filter == null
                    ? 'Lộ trình học đang trống'
                    : 'Chưa có repo "${state.filter!.label}"',
                subtitle: 'Trong trang chi tiết repo, chọn trạng thái học tập để thêm vào lộ trình.',
              ),
            ),
          for (var i = 0; i < state.items.length; i++)
            _AnimatedEntry(
              key: ValueKey('learning-${state.items[i].id}'),
              index: i,
              child: _learningTile(context, state.items[i]),
            ),
        ],
      ),
    );
  }

  Widget _learningTile(BuildContext context, LearningItemModel item) {
    final color = learningStatusColor(item.status);
    final dates = <String>[
      if (item.startedAt != null) 'Bắt đầu ${formatDate(item.startedAt!)}',
      if (item.completedAt != null) 'Xong ${formatDate(item.completedAt!)}',
    ];
    return RepoBriefTile(
      repo: item.repo,
      onTap: () => context.push('/repo/${item.repoId}', extra: item.repo.toRepoModel()),
      footer: Wrap(
        spacing: 8,
        runSpacing: 4,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(color: color.withAlpha(40), borderRadius: BorderRadius.circular(10)),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(learningStatusIcon(item.status), size: 13, color: color),
                const SizedBox(width: 4),
                Text(item.status.label, style: TextStyle(fontSize: 11.5, color: color, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
          if (dates.isNotEmpty)
            Text(dates.join(' · '), style: TextStyle(fontSize: 11, color: textMuted(context))),
        ],
      ),
      trailing: PopupMenuButton<String>(
        tooltip: 'Đổi trạng thái',
        icon: const Icon(Icons.more_vert_rounded),
        // PopupMenuButton ignores null values, so "remove" is a string too.
        onSelected: (value) => _changeStatus(context, item, LearningStatus.fromApi(value)),
        itemBuilder: (_) => [
          for (final status in LearningStatus.values)
            if (status != item.status)
              PopupMenuItem<String>(
                value: status.apiValue,
                child: ListTile(
                  leading: Icon(learningStatusIcon(status), color: learningStatusColor(status)),
                  title: Text('Chuyển sang "${status.label}"'),
                ),
              ),
          const PopupMenuItem<String>(
            value: 'remove',
            child: ListTile(
              leading: Icon(Icons.remove_circle_outline_rounded, color: AppColors.error),
              title: Text('Bỏ khỏi lộ trình'),
            ),
          ),
        ],
      ),
    );
  }
}
