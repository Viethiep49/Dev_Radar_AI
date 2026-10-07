import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/storage_service.dart';
import '../../../data/models/preferences_model.dart';
import '../../../data/repositories/auth_repository.dart';
import '../../../data/repositories/preferences_repository.dart';
import '../../state/onboarding/onboarding_cubit.dart';
import '../../widgets/common/glass_page_scaffold.dart';
import '../../widgets/common/state_views.dart';
import '../../widgets/glass/glass_button.dart';
import '../../widgets/glass/glass_card.dart';

/// Choose the languages and topics to follow. Shown once after the first login
/// ([isEditing] = false) and from Settings > Sở thích ([isEditing] = true).
class OnboardingScreen extends StatelessWidget {
  final bool isEditing;

  const OnboardingScreen({super.key, this.isEditing = false});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (ctx) => OnboardingCubit(
        preferencesRepository: ctx.read<PreferencesRepository>(),
        authRepository: ctx.read<AuthRepository>(),
        storage: ctx.read<StorageService>(),
      )..load(),
      child: _OnboardingView(isEditing: isEditing),
    );
  }
}

class _OnboardingView extends StatelessWidget {
  final bool isEditing;

  const _OnboardingView({required this.isEditing});

  void _leave(BuildContext context) {
    if (isEditing) {
      Navigator.of(context).maybePop(true);
    } else {
      context.go('/home');
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<OnboardingCubit, OnboardingState>(
      listenWhen: (prev, curr) =>
          (curr.isDone && !prev.isDone) || (curr.actionError != null && curr.actionError != prev.actionError),
      listener: (context, state) {
        if (state.actionError != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(state.actionError!), backgroundColor: AppColors.error),
          );
          return;
        }
        if (isEditing) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Đã lưu sở thích, bảng tin sẽ được cá nhân hoá lại')),
          );
        }
        _leave(context);
      },
      builder: (context, state) {
        final cubit = context.read<OnboardingCubit>();
        return GlassPageScaffold(
          title: isEditing ? 'Sở thích của bạn' : 'Chào mừng đến DevRadar 👋',
          subtitle: 'Chọn ngôn ngữ & lĩnh vực bạn quan tâm',
          showBack: isEditing,
          actions: [
            if (!isEditing)
              TextButton(onPressed: state.isSaving ? null : cubit.skip, child: const Text('Bỏ qua')),
          ],
          body: AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: switch (state.status) {
              OnboardingStatus.initial || OnboardingStatus.loading => const SkeletonList(
                  key: ValueKey('loading'),
                  count: 4,
                  itemHeight: 120,
                ),
              OnboardingStatus.failure => ErrorRetryView(
                  key: const ValueKey('error'),
                  message: state.errorMessage ?? 'Không tải được danh sách lựa chọn',
                  onRetry: cubit.load,
                ),
              OnboardingStatus.ready => _Picker(key: const ValueKey('picker'), state: state, isEditing: isEditing),
            },
          ),
        );
      },
    );
  }
}

class _Picker extends StatelessWidget {
  final OnboardingState state;
  final bool isEditing;

  const _Picker({super.key, required this.state, required this.isEditing});

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<OnboardingCubit>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
            children: [
              TextField(
                onChanged: cubit.setQuery,
                decoration: InputDecoration(
                  hintText: 'Tìm ngôn ngữ hoặc chủ đề (vd: dart, ai)...',
                  prefixIcon: const Icon(Icons.search_rounded),
                  filled: true,
                  fillColor: isDark ? AppColors.darkCard.withAlpha(180) : Colors.white.withAlpha(200),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 16),
              _ChipSection(
                title: 'Ngôn ngữ lập trình',
                icon: Icons.code_rounded,
                options: state.visibleLanguages,
                selected: state.selectedLanguages,
                onToggle: cubit.toggleLanguage,
              ),
              const SizedBox(height: 16),
              _ChipSection(
                title: 'Lĩnh vực / chủ đề',
                icon: Icons.category_rounded,
                options: state.visibleTopics,
                selected: state.selectedTopics,
                onToggle: cubit.toggleTopic,
              ),
            ],
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
            child: GlassButton(
              text: state.selectedCount == 0
                  ? (isEditing ? 'Lưu (xem repo phổ biến)' : 'Tiếp tục với repo phổ biến')
                  : 'Lưu ${state.selectedCount} lựa chọn',
              icon: Icons.check_rounded,
              isLoading: state.isSaving,
              onPressed: state.isSaving ? null : cubit.save,
            ),
          ),
        ),
      ],
    );
  }
}

class _ChipSection extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<FilterOptionModel> options;
  final Set<String> selected;
  final ValueChanged<String> onToggle;

  const _ChipSection({
    required this.title,
    required this.icon,
    required this.options,
    required this.selected,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.all(16),
      borderRadius: 20,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: AppColors.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
              ),
              if (selected.isNotEmpty)
                Text('Đã chọn ${selected.length}', style: const TextStyle(fontSize: 12, color: AppColors.primary)),
            ],
          ),
          const SizedBox(height: 12),
          if (options.isEmpty)
            const Text('Không có lựa chọn phù hợp')
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final option in options)
                  FilterChip(
                    label: Text(option.count > 0 ? '${option.name} · ${option.count}' : option.name),
                    selected: selected.contains(option.name),
                    onSelected: (_) => onToggle(option.name),
                    selectedColor: AppColors.primary.withAlpha(60),
                    checkmarkColor: AppColors.primary,
                  ),
              ],
            ),
        ],
      ),
    );
  }
}
