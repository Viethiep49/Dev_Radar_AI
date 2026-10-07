import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../data/models/note_model.dart';
import '../../../data/repositories/note_repository.dart';
import '../../state/notes/note_editor_cubit.dart';
import '../../widgets/common/ambient_background.dart';
import '../../widgets/glass/glass_container.dart';
import '../collections/widgets/collection_widgets.dart';

/// Arguments of the '/notes/edit' route.
/// [note] == null -> create a note for [repoId]; otherwise edit/delete [note].
class NoteEditorArgs {
  final NoteModel? note;
  final int? repoId;
  final String? repoName;

  const NoteEditorArgs({this.note, this.repoId, this.repoName});
}

/// Create / edit / delete one note. Pops with `true` when something changed.
class NoteEditorScreen extends StatelessWidget {
  final NoteEditorArgs args;

  const NoteEditorScreen({super.key, required this.args});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (ctx) => NoteEditorCubit(
        ctx.read<NoteRepository>(),
        note: args.note,
        repoId: args.repoId,
      ),
      child: _NoteEditorView(args: args),
    );
  }
}

class _NoteEditorView extends StatefulWidget {
  final NoteEditorArgs args;

  const _NoteEditorView({required this.args});

  @override
  State<_NoteEditorView> createState() => _NoteEditorViewState();
}

class _NoteEditorViewState extends State<_NoteEditorView> {
  late final _controller = TextEditingController(text: widget.args.note?.content ?? '');

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _delete() async {
    final confirmed = await confirmDelete(
      context,
      title: 'Xoá ghi chú?',
      message: 'Ghi chú này sẽ bị xoá vĩnh viễn.',
    );
    if (confirmed && mounted) {
      await context.read<NoteEditorCubit>().delete();
    }
  }

  @override
  Widget build(BuildContext context) {
    final note = widget.args.note;
    final repoName = note?.repo.fullName ?? widget.args.repoName ?? '';

    return BlocConsumer<NoteEditorCubit, NoteEditorState>(
      listener: (context, state) {
        if (state.done) {
          context.pop(true);
        } else if (state.errorMessage != null) {
          showErrorSnack(context, state.errorMessage!);
        }
      },
      builder: (context, state) {
        return Scaffold(
          extendBodyBehindAppBar: true,
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            title: Text(note == null ? 'Ghi chú mới' : 'Sửa ghi chú'),
            actions: [
              if (note != null)
                IconButton(
                  tooltip: 'Xoá ghi chú',
                  icon: const Icon(Icons.delete_outline_rounded, color: AppColors.error),
                  onPressed: state.saving ? null : _delete,
                ),
            ],
          ),
          body: AmbientBackground(
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (repoName.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12, left: 4),
                        child: Row(
                          children: [
                            const Icon(Icons.book_outlined, size: 18, color: AppColors.primary),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                repoName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontWeight: FontWeight.w600),
                              ),
                            ),
                          ],
                        ),
                      ),
                    if (note != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8, left: 4),
                        child: Text(
                          'Tạo ${formatDate(note.createdAt)} · Sửa ${formatDate(note.updatedAt)}',
                          style: TextStyle(fontSize: 12, color: textMuted(context)),
                        ),
                      ),
                    Expanded(
                      child: GlassContainer(
                        borderRadius: 20,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                        child: TextField(
                          controller: _controller,
                          autofocus: note == null,
                          expands: true,
                          maxLines: null,
                          minLines: null,
                          maxLength: 5000,
                          textAlignVertical: TextAlignVertical.top,
                          keyboardType: TextInputType.multiline,
                          decoration: const InputDecoration(
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            filled: false,
                            hintText: 'Viết ghi chú: cách cài đặt, điều cần nhớ, ý tưởng dùng cho đồ án...',
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: FilledButton.icon(
                        onPressed: state.saving
                            ? null
                            : () => context.read<NoteEditorCubit>().save(_controller.text),
                        icon: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 200),
                          child: state.saving
                              ? const SizedBox(
                                  key: ValueKey('saving'),
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                )
                              : const Icon(Icons.save_rounded, key: ValueKey('save')),
                        ),
                        label: Text(note == null ? 'Lưu ghi chú' : 'Cập nhật'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
