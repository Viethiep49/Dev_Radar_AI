import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../data/repositories/collection_repository.dart';
import '../../../state/collections/add_to_collection_cubit.dart';
import '../../../state/load_status.dart';
import '../../../widgets/common/state_views.dart';
import '../../../widgets/glass/glass_modal_sheet.dart';
import 'collection_widgets.dart';

/// Bottom sheet "Thêm vào bộ sưu tập". Each checkbox adds/removes the repo
/// right away. Returns true if any collection changed.
Future<bool?> showAddToCollectionSheet(
  BuildContext context, {
  required int repoId,
  required List<int> currentCollectionIds,
}) async {
  final cubit = AddToCollectionCubit(
    context.read<CollectionRepository>(),
    repoId: repoId,
    currentCollectionIds: currentCollectionIds,
  )..load();
  await GlassModalSheet.show<void>(
    context: context,
    title: 'Thêm vào bộ sưu tập',
    maxHeightFactor: 0.75,
    child: BlocProvider.value(value: cubit, child: const _AddToCollectionView()),
  );
  final changed = cubit.state.changed;
  await cubit.close();
  return changed;
}

class _AddToCollectionView extends StatefulWidget {
  const _AddToCollectionView();

  @override
  State<_AddToCollectionView> createState() => _AddToCollectionViewState();
}

class _AddToCollectionViewState extends State<_AddToCollectionView> {
  final _nameController = TextEditingController();
  bool _creating = false;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    final name = _nameController.text.trim();
    if (name.isEmpty || _creating) return;
    setState(() => _creating = true);
    final error = await context.read<AddToCollectionCubit>().createAndAdd(name);
    if (!mounted) return;
    setState(() => _creating = false);
    if (error != null) {
      showErrorSnack(context, error);
    } else {
      _nameController.clear();
      FocusScope.of(context).unfocus();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: BlocBuilder<AddToCollectionCubit, AddToCollectionState>(
              builder: (context, state) {
                if (state.status == LoadStatus.loading || state.status == LoadStatus.initial) {
                  return const Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                  );
                }
                if (state.status == LoadStatus.failure) {
                  return ErrorRetryView(
                    message: state.errorMessage ?? 'Không tải được bộ sưu tập',
                    onRetry: context.read<AddToCollectionCubit>().load,
                  );
                }
                if (state.collections.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      'Bạn chưa có bộ sưu tập nào. Tạo bộ sưu tập đầu tiên bên dưới.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: textMuted(context)),
                    ),
                  );
                }
                return ListView.builder(
                  shrinkWrap: true,
                  itemCount: state.collections.length,
                  itemBuilder: (context, index) {
                    final collection = state.collections[index];
                    final busy = state.busyIds.contains(collection.id);
                    final selected = state.selectedIds.contains(collection.id);
                    return CheckboxListTile(
                      value: selected,
                      onChanged: busy
                          ? null
                          : (_) async {
                              final error =
                                  await context.read<AddToCollectionCubit>().toggle(collection.id);
                              if (error != null && context.mounted) showErrorSnack(context, error);
                            },
                      activeColor: AppColors.primary,
                      controlAffinity: ListTileControlAffinity.leading,
                      contentPadding: EdgeInsets.zero,
                      title: Text(collection.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                      subtitle: Text('${collection.itemCount} repo'),
                      secondary: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 200),
                        child: busy
                            ? const SizedBox(
                                key: ValueKey('busy'),
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : Icon(
                                selected ? Icons.folder_rounded : Icons.folder_outlined,
                                key: ValueKey(selected),
                                color: selected ? AppColors.primary : textMuted(context),
                              ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          const Divider(height: 20),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _nameController,
                  maxLength: 100,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _create(),
                  decoration: const InputDecoration(
                    hintText: 'Tạo bộ sưu tập mới...',
                    counterText: '',
                    prefixIcon: Icon(Icons.create_new_folder_outlined, color: AppColors.primary),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filled(
                tooltip: 'Tạo và thêm repo',
                onPressed: _creating ? null : _create,
                icon: _creating
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.add_rounded),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
