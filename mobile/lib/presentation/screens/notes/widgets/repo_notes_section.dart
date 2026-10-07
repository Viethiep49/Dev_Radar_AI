import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../data/models/note_model.dart';
import '../../../../data/repositories/note_repository.dart';
import '../../../state/load_status.dart';
import '../../../state/notes/notes_cubit.dart';
import '../../../widgets/glass/glass_card.dart';
import '../../../widgets/common/state_views.dart';
import '../../collections/widgets/collection_widgets.dart';
import '../note_editor_screen.dart';

/// "Ghi chú của bạn" section for the repo detail screen: notes of one repo
/// with add / edit / delete. Has its own NotesCubit; no Scaffold, no own scrolling.
class RepoNotesSection extends StatelessWidget {
  final int repoId;
  final String repoName;

  const RepoNotesSection({super.key, required this.repoId, required this.repoName});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (ctx) => NotesCubit(ctx.read<NoteRepository>(), repoId: repoId)..load(),
      child: _RepoNotesView(repoId: repoId, repoName: repoName),
    );
  }
}

class _RepoNotesView extends StatelessWidget {
  final int repoId;
  final String repoName;

  const _RepoNotesView({required this.repoId, required this.repoName});

  Future<void> _openEditor(BuildContext context, {NoteModel? note}) async {
    final cubit = context.read<NotesCubit>();
    final changed = await context.push<bool>(
      '/notes/edit',
      extra: NoteEditorArgs(note: note, repoId: repoId, repoName: repoName),
    );
    if (changed == true) await cubit.load();
  }

  Future<void> _delete(BuildContext context, NoteModel note) async {
    final cubit = context.read<NotesCubit>();
    final confirmed = await confirmDelete(
      context,
      title: 'Xoá ghi chú?',
      message: 'Ghi chú này sẽ bị xoá vĩnh viễn.',
    );
    if (!confirmed) return;
    final error = await cubit.delete(note.id);
    if (error != null && context.mounted) showErrorSnack(context, error);
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<NotesCubit, NotesState>(
      builder: (context, state) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(Icons.sticky_note_2_outlined, size: 20, color: AppColors.secondary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    state.notes.isEmpty ? 'Ghi chú của bạn' : 'Ghi chú của bạn (${state.notes.length})',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: textPrimary(context)),
                  ),
                ),
                TextButton.icon(
                  onPressed: () => _openEditor(context),
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: const Text('Thêm'),
                ),
              ],
            ),
            if (state.fromCache)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: OfflineBanner(cachedAt: state.cachedAt, onRetry: context.read<NotesCubit>().load),
              ),
            AnimatedSize(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOut,
              alignment: Alignment.topCenter,
              child: _buildBody(context, state),
            ),
          ],
        );
      },
    );
  }

  Widget _buildBody(BuildContext context, NotesState state) {
    switch (state.status) {
      case LoadStatus.initial:
      case LoadStatus.loading:
        return const Padding(
          padding: EdgeInsets.symmetric(vertical: 8),
          child: SkeletonBox(height: 64),
        );
      case LoadStatus.failure:
        if (state.notes.isEmpty) {
          return Row(
            children: [
              Expanded(
                child: Text(
                  state.errorMessage ?? 'Không tải được ghi chú',
                  style: const TextStyle(fontSize: 13, color: AppColors.error),
                ),
              ),
              TextButton(onPressed: context.read<NotesCubit>().load, child: const Text('Thử lại')),
            ],
          );
        }
        return _list(context, state.notes);
      case LoadStatus.success:
        if (state.notes.isEmpty) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              'Chưa có ghi chú. Bấm "Thêm" để lưu lại điều cần nhớ về repo này.',
              style: TextStyle(fontSize: 13, color: textMuted(context)),
            ),
          );
        }
        return _list(context, state.notes);
    }
  }

  Widget _list(BuildContext context, List<NoteModel> notes) {
    return Column(
      children: [
        for (final note in notes)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: GlassCard(
              onTap: () => _openEditor(context, note: note),
              padding: const EdgeInsets.fromLTRB(14, 12, 4, 12),
              borderRadius: 16,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          note.content,
                          maxLines: 4,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 13.5, height: 1.4, color: textPrimary(context)),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Cập nhật ${formatDate(note.updatedAt)}',
                          style: TextStyle(fontSize: 11.5, color: textMuted(context)),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Xoá',
                    icon: const Icon(Icons.delete_outline_rounded, size: 20),
                    color: AppColors.error,
                    onPressed: () => _delete(context, note),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
