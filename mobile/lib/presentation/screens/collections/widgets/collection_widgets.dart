import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../data/models/learning_model.dart';
import '../../../../data/models/repo_brief_model.dart';
import '../../../widgets/glass/glass_card.dart';
import '../../../widgets/glass/glass_modal_sheet.dart';

/// Small helpers shared by the collections / notes / learning screens.

String formatDate(DateTime date) => DateFormat('dd/MM/yyyy').format(date.toLocal());

Color textPrimary(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;

Color textMuted(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark ? AppColors.darkTextMuted : AppColors.lightTextMuted;

void showErrorSnack(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message), backgroundColor: AppColors.error));
}

void showSuccessSnack(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message), backgroundColor: AppColors.success));
}

/// "Are you sure?" dialog before deleting something. Returns true when confirmed.
Future<bool> confirmDelete(BuildContext context, {required String title, required String message}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Huỷ')),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: AppColors.error),
          onPressed: () => Navigator.of(ctx).pop(true),
          child: const Text('Xoá'),
        ),
      ],
    ),
  );
  return result ?? false;
}

/// Result of the create/edit collection form.
class CollectionFormResult {
  final String name;
  final String? description;

  const CollectionFormResult(this.name, this.description);
}

/// Bottom sheet with name + description fields. Returns null when cancelled.
Future<CollectionFormResult?> showCollectionForm(
  BuildContext context, {
  String title = 'Tạo bộ sưu tập mới',
  String submitText = 'Tạo',
  String? initialName,
  String? initialDescription,
}) {
  return GlassModalSheet.show<CollectionFormResult>(
    context: context,
    title: title,
    child: _CollectionForm(
      submitText: submitText,
      initialName: initialName,
      initialDescription: initialDescription,
    ),
  );
}

class _CollectionForm extends StatefulWidget {
  final String submitText;
  final String? initialName;
  final String? initialDescription;

  const _CollectionForm({required this.submitText, this.initialName, this.initialDescription});

  @override
  State<_CollectionForm> createState() => _CollectionFormState();
}

class _CollectionFormState extends State<_CollectionForm> {
  final _formKey = GlobalKey<FormState>();
  late final _nameController = TextEditingController(text: widget.initialName);
  late final _descController = TextEditingController(text: widget.initialDescription);

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final description = _descController.text.trim();
    Navigator.of(context).pop(
      CollectionFormResult(_nameController.text.trim(), description.isEmpty ? null : description),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _nameController,
              autofocus: widget.initialName == null,
              maxLength: 100,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'Tên bộ sưu tập',
                hintText: 'vd: Học Flutter',
                prefixIcon: Icon(Icons.folder_outlined, color: AppColors.primary),
              ),
              validator: (value) =>
                  (value == null || value.trim().isEmpty) ? 'Vui lòng nhập tên bộ sưu tập' : null,
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _descController,
              maxLength: 500,
              maxLines: 3,
              minLines: 1,
              decoration: const InputDecoration(
                labelText: 'Mô tả (không bắt buộc)',
                prefixIcon: Icon(Icons.notes_rounded, color: AppColors.secondary),
              ),
              onFieldSubmitted: (_) => _submit(),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _submit,
                icon: const Icon(Icons.check_rounded),
                label: Text(widget.submitText),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Color used for each learning status.
Color learningStatusColor(LearningStatus status) {
  switch (status) {
    case LearningStatus.wantToTry:
      return AppColors.warning;
    case LearningStatus.learning:
      return AppColors.primary;
    case LearningStatus.used:
      return AppColors.success;
  }
}

IconData learningStatusIcon(LearningStatus status) {
  switch (status) {
    case LearningStatus.wantToTry:
      return Icons.lightbulb_outline_rounded;
    case LearningStatus.learning:
      return Icons.menu_book_rounded;
    case LearningStatus.used:
      return Icons.verified_rounded;
  }
}

/// Compact repo row: avatar, full name, description, language and stars.
class RepoBriefTile extends StatelessWidget {
  final RepoBriefModel repo;
  final VoidCallback? onTap;
  final Widget? trailing;
  final Widget? footer;

  const RepoBriefTile({super.key, required this.repo, this.onTap, this.trailing, this.footer});

  @override
  Widget build(BuildContext context) {
    final avatar = repo.ownerAvatarUrl;
    return GlassCard(
      onTap: onTap,
      padding: const EdgeInsets.fromLTRB(12, 12, 4, 12),
      borderRadius: 18,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: AppColors.primary.withAlpha(40),
            foregroundImage: avatar != null && avatar.isNotEmpty ? NetworkImage(avatar) : null,
            child: Text(
              repo.owner.isNotEmpty ? repo.owner[0].toUpperCase() : '?',
              style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary),
            ),
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
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5, color: textPrimary(context)),
                ),
                if (repo.description != null && repo.description!.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    repo.description!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12.5, color: textMuted(context), height: 1.35),
                  ),
                ],
                const SizedBox(height: 6),
                Wrap(
                  spacing: 12,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    if (repo.language != null)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.circle, size: 9, color: AppColors.secondary),
                          const SizedBox(width: 4),
                          Text(repo.language!, style: TextStyle(fontSize: 12, color: textMuted(context))),
                        ],
                      ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.star_rounded, size: 14, color: AppColors.warning),
                        const SizedBox(width: 2),
                        Text(
                          NumberFormat.compact().format(repo.stars),
                          style: TextStyle(fontSize: 12, color: textMuted(context)),
                        ),
                      ],
                    ),
                  ],
                ),
                if (footer != null) ...[const SizedBox(height: 8), footer!],
              ],
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}
