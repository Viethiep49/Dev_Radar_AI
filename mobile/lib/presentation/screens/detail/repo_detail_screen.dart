import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/glass_theme.dart';
import '../../../data/models/learning_model.dart';
import '../../../data/models/repo_detail_model.dart';
import '../../../data/models/repo_model.dart';
import '../../../data/repositories/learning_repository.dart';
import '../../../data/repositories/repo_repository.dart';
import '../../../data/repositories/watchlist_repository.dart';
import '../../state/detail/repo_detail_cubit.dart';
import '../../state/detail/repo_detail_state.dart';
import '../../widgets/common/ambient_background.dart';
import '../../widgets/common/state_views.dart';
import '../../widgets/glass/glass_badge.dart';
import '../../widgets/glass/glass_button.dart';
import '../../widgets/glass/glass_card.dart';
import '../../widgets/glass/glass_container.dart';
import '../../widgets/glass/glass_icon_button.dart';
import '../../widgets/icons/github_logo.dart';
import '../collections/widgets/add_to_collection_sheet.dart';
import '../notes/widgets/repo_notes_section.dart';
import 'widgets/star_history_chart.dart';

/// Repo detail: header + stats, actions (watch, collection, learning status, GitHub),
/// sections Tổng quan · Tóm tắt AI · Quickstart · README, notes, chat button.
class RepoDetailScreen extends StatelessWidget {
  final int repoId;
  final RepoModel? initialRepo;

  const RepoDetailScreen({super.key, required this.repoId, this.initialRepo});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => RepoDetailCubit(
        repoId: repoId,
        initialRepo: initialRepo,
        repoRepository: context.read<RepoRepository>(),
        watchlistRepository: context.read<WatchlistRepository>(),
        learningRepository: context.read<LearningRepository>(),
      )..load(),
      child: const _RepoDetailView(),
    );
  }
}

enum _Section {
  overview('Tổng quan', Icons.insights_rounded),
  summary('Tóm tắt AI', Icons.auto_awesome_rounded),
  quickstart('Quickstart', Icons.terminal_rounded),
  readme('README', Icons.article_outlined);

  final String label;
  final IconData icon;

  const _Section(this.label, this.icon);
}

class _RepoDetailView extends StatefulWidget {
  const _RepoDetailView();

  @override
  State<_RepoDetailView> createState() => _RepoDetailViewState();
}

class _RepoDetailViewState extends State<_RepoDetailView> {
  _Section _section = _Section.overview;

  RepoDetailCubit get _cubit => context.read<RepoDetailCubit>();

  Future<void> _openGitHub(RepoModel repo) async {
    final uri = Uri.parse(repo.htmlUrl.isNotEmpty ? repo.htmlUrl : 'https://github.com/${repo.fullName}');
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Không mở được $uri')));
    }
  }

  Future<void> _addToCollection(RepoDetailModel detail) async {
    final changed = await showAddToCollectionSheet(
      context,
      repoId: detail.repo.id,
      currentCollectionIds: detail.collectionIds,
    );
    if (changed == true && mounted) await _cubit.refresh();
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<RepoDetailCubit, RepoDetailState>(
      listenWhen: (a, b) => b.feedback != null && a.feedback != b.feedback,
      listener: (context, state) {
        final feedback = state.feedback!;
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(
            content: Text(feedback.message),
            backgroundColor: feedback.isError ? AppColors.error : AppColors.success,
            duration: const Duration(seconds: 2),
          ));
      },
      builder: (context, state) {
        final repo = state.repo;
        return Scaffold(
          body: AmbientBackground(
            child: SafeArea(
              child: Column(
                children: [
                  _TopBar(repo: repo, onOpenGitHub: repo == null ? null : () => _openGitHub(repo)),
                  Expanded(child: _buildContent(state)),
                ],
              ),
            ),
          ),
          floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
          floatingActionButton: repo == null
              ? null
              : Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: GlassButton(
                    text: 'Hỏi đáp AI về repo này',
                    icon: Icons.chat_bubble_outline_rounded,
                    height: 54,
                    borderRadius: 27,
                    onPressed: () => context.push('/repo/${repo.id}/chat', extra: repo),
                  ),
                ),
        );
      },
    );
  }

  Widget _buildContent(RepoDetailState state) {
    final repo = state.repo;
    if (repo == null) {
      if (state.status == RepoDetailStatus.failure) {
        return ErrorRetryView(message: state.errorMessage ?? 'Không tải được repo', onRetry: _cubit.load);
      }
      return const SkeletonList(count: 4, itemHeight: 140);
    }

    final detail = state.detail;
    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: _cubit.refresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
        padding: const EdgeInsets.fromLTRB(18, 8, 18, 100),
        children: [
          if (state.fromCache) ...[
            OfflineBanner(cachedAt: state.cachedAt, onRetry: _cubit.refresh),
            const SizedBox(height: 12),
          ],
          _HeaderCard(repo: repo, detail: detail),
          const SizedBox(height: 14),
          if (detail == null)
            state.status == RepoDetailStatus.failure
                ? ErrorRetryView(message: state.errorMessage ?? 'Không tải được chi tiết', onRetry: _cubit.load)
                : const Column(
                    children: [
                      SkeletonBox(height: 52),
                      SizedBox(height: 14),
                      SkeletonBox(height: 60),
                      SizedBox(height: 14),
                      SkeletonBox(height: 220),
                    ],
                  )
          else ...[
            _ActionRow(
              detail: detail,
              watchBusy: state.watchBusy,
              onToggleWatch: _cubit.toggleWatch,
              onAddToCollection: () => _addToCollection(detail),
              onOpenGitHub: () => _openGitHub(repo),
            ),
            const SizedBox(height: 16),
            _SectionTitle('Trạng thái học tập'),
            const SizedBox(height: 8),
            _LearningSelector(
              status: detail.learningStatus,
              busy: state.learningBusy,
              onChanged: _cubit.setLearningStatus,
            ),
            const SizedBox(height: 16),
            _SectionTabs(selected: _section, onChanged: (s) => setState(() => _section = s)),
            const SizedBox(height: 14),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              transitionBuilder: (child, animation) => FadeTransition(
                opacity: animation,
                child: SlideTransition(
                  position: Tween(begin: const Offset(0, 0.04), end: Offset.zero).animate(animation),
                  child: child,
                ),
              ),
              child: KeyedSubtree(
                key: ValueKey(_section),
                child: _buildSection(state, detail),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSection(RepoDetailState state, RepoDetailModel detail) {
    switch (_section) {
      case _Section.overview:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            GlassContainer(
              padding: const EdgeInsets.all(18),
              borderRadius: 22,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.show_chart_rounded, color: AppColors.warning, size: 20),
                      SizedBox(width: 8),
                      Text('Số sao theo thời gian', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  state.starsLoading
                      ? const SkeletonBox(height: 170)
                      : StarHistoryChart(points: state.stars),
                ],
              ),
            ),
            const SizedBox(height: 16),
            RepoNotesSection(repoId: detail.repo.id, repoName: detail.repo.name),
          ],
        );
      case _Section.summary:
        return _SummaryCard(
          detail: detail,
          busy: state.summaryBusy,
          onGenerate: context.read<RepoDetailCubit>().generateSummary,
        );
      case _Section.quickstart:
        return _QuickstartCard(quickstart: detail.quickstart);
      case _Section.readme:
        return _ReadmeCard(detail: detail);
    }
  }
}

// ---------------------------------------------------------------------------
// Pieces
// ---------------------------------------------------------------------------

class _TopBar extends StatelessWidget {
  final RepoModel? repo;
  final VoidCallback? onOpenGitHub;

  const _TopBar({required this.repo, required this.onOpenGitHub});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          GlassIconButton(
            icon: Icons.arrow_back_ios_new_rounded,
            tooltip: 'Quay lại',
            onPressed: () => context.pop(),
          ),
          const Spacer(),
          if (repo?.isHot ?? false) ...[GlassBadge.hot(), const SizedBox(width: 8)],
          GlassIconButton(
            icon: Icons.open_in_new_rounded,
            tooltip: 'Mở trên GitHub',
            onPressed: onOpenGitHub,
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;

  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Text(
      text,
      style: TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.bold,
        color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
      ),
    );
  }
}

class _HeaderCard extends StatelessWidget {
  final RepoModel repo;
  final RepoDetailModel? detail;

  const _HeaderCard({required this.repo, required this.detail});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final number = NumberFormat.compact(locale: 'en');
    final updated = detail?.pushedAt;

    return GlassContainer(
      padding: const EdgeInsets.all(20),
      borderRadius: 24,
      enableGlow: true,
      glowColor: AppColors.primary.withAlpha(25),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Hero(
                tag: 'repo-avatar-${repo.id}',
                child: Container(
                  width: 54,
                  height: 54,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isDark ? Colors.white.withAlpha(40) : const Color(0xFFD0D7DE),
                      width: 1.5,
                    ),
                  ),
                  child: ClipOval(
                    child: Image.network(
                      repo.effectiveOwnerAvatarUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => Container(
                        color: const Color(0xFF21262D),
                        child: const Center(child: GithubLogo(size: 26, color: Colors.white)),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      repo.owner,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      repo.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w800, letterSpacing: -0.3),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (repo.description != null && repo.description!.isNotEmpty) ...[
            const SizedBox(height: 14),
            Text(
              repo.description!,
              style: TextStyle(
                fontSize: 14,
                height: 1.45,
                color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
              ),
            ),
          ],
          if (repo.topics.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: repo.topics
                  .take(8)
                  .map((t) => Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withAlpha(28),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text('#$t', style: const TextStyle(fontSize: 11, color: AppColors.primary)),
                      ))
                  .toList(),
            ),
          ],
          const SizedBox(height: 18),
          Row(
            children: [
              _Metric('Sao', number.format(repo.stars), Icons.star_rounded, const Color(0xFFFFB800)),
              _Metric('Fork', number.format(repo.forks), Icons.fork_right_rounded, AppColors.info),
              _Metric('Issue', number.format(repo.openIssues), Icons.bug_report_outlined, AppColors.warning),
              _Metric('Ngôn ngữ', repo.language ?? 'Khác', Icons.code_rounded, AppColors.primary),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 14,
            runSpacing: 6,
            children: [
              _InfoChip(Icons.balance_rounded, repo.license ?? 'Chưa rõ license'),
              _InfoChip(
                Icons.update_rounded,
                updated == null ? 'Chưa rõ lần cập nhật' : 'Cập nhật ${DateFormat('dd/MM/yyyy').format(updated.toLocal())}',
              ),
              if (repo.starsGained7d > 0) _InfoChip(Icons.trending_up_rounded, '+${repo.starsGained7d} sao / 7 ngày'),
            ],
          ),
        ],
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _Metric(this.label, this.value, this.icon, this.color);

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(height: 5),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
          ),
          Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
        ],
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String text;

  const _InfoChip(this.icon, this.text);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color = isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 4),
        Text(text, style: TextStyle(fontSize: 12, color: color)),
      ],
    );
  }
}

class _ActionRow extends StatelessWidget {
  final RepoDetailModel detail;
  final bool watchBusy;
  final VoidCallback onToggleWatch;
  final VoidCallback onAddToCollection;
  final VoidCallback onOpenGitHub;

  const _ActionRow({
    required this.detail,
    required this.watchBusy,
    required this.onToggleWatch,
    required this.onAddToCollection,
    required this.onOpenGitHub,
  });

  @override
  Widget build(BuildContext context) {
    final inCollections = detail.collectionIds.length;
    return Row(
      children: [
        Expanded(
          child: _ActionButton(
            icon: detail.isWatched ? Icons.notifications_active_rounded : Icons.notifications_none_rounded,
            label: detail.isWatched ? 'Đang theo dõi' : 'Theo dõi',
            active: detail.isWatched,
            busy: watchBusy,
            onTap: onToggleWatch,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _ActionButton(
            icon: inCollections > 0 ? Icons.bookmark_rounded : Icons.bookmark_add_outlined,
            label: inCollections > 0 ? 'Trong $inCollections BST' : 'Lưu vào BST',
            active: inCollections > 0,
            onTap: onAddToCollection,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _ActionButton(icon: Icons.open_in_new_rounded, label: 'GitHub', onTap: onOpenGitHub),
        ),
      ],
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final bool busy;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.active = false,
    this.busy = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color = active ? AppColors.primary : (isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary);
    return GlassCard(
      onTap: busy ? null : onTap,
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
      borderRadius: 16,
      enableGlow: active,
      glowColor: AppColors.primary.withAlpha(40),
      child: Column(
        children: [
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            transitionBuilder: (child, anim) => ScaleTransition(scale: anim, child: child),
            child: busy
                ? const SizedBox(
                    key: ValueKey('busy'),
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                  )
                : Icon(icon, key: ValueKey(icon), size: 20, color: color),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: color),
          ),
        ],
      ),
    );
  }
}

class _LearningSelector extends StatelessWidget {
  final LearningStatus? status;
  final bool busy;
  final ValueChanged<LearningStatus?> onChanged;

  const _LearningSelector({required this.status, required this.busy, required this.onChanged});

  static const _icons = {
    LearningStatus.wantToTry: Icons.bookmark_outline_rounded,
    LearningStatus.learning: Icons.auto_stories_rounded,
    LearningStatus.used: Icons.check_circle_outline_rounded,
  };

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GlassContainer(
      padding: const EdgeInsets.all(6),
      borderRadius: 18,
      child: Row(
        children: LearningStatus.values.map((item) {
          final isSelected = status == item;
          final color = isSelected ? Colors.black : (isDark ? Colors.white70 : Colors.black87);
          return Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              // Tapping the selected status again removes it.
              onTap: busy ? null : () => onChanged(isSelected ? null : item),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 2),
                decoration: BoxDecoration(
                  gradient: isSelected ? GlassTheme.primaryGradient : null,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
                  children: [
                    Icon(_icons[item], size: 17, color: color),
                    const SizedBox(height: 3),
                    Text(
                      item.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                        color: color,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _SectionTabs extends StatelessWidget {
  final _Section selected;
  final ValueChanged<_Section> onChanged;

  const _SectionTabs({required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _Section.values.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final section = _Section.values[index];
          return ChoiceChip(
            avatar: Icon(section.icon, size: 16),
            label: Text(section.label),
            selected: section == selected,
            onSelected: (_) => onChanged(section),
          );
        },
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final RepoDetailModel detail;
  final bool busy;
  final VoidCallback onGenerate;

  const _SummaryCard({required this.detail, required this.busy, required this.onGenerate});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GlassCard(
      borderRadius: 24,
      enableGlow: true,
      glowColor: const Color(0xFF6366F1),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              GlassBadge.ai(),
              const Spacer(),
              if (detail.summaryModel != null)
                Text(detail.summaryModel!, style: const TextStyle(fontSize: 10.5, color: Colors.grey)),
            ],
          ),
          const SizedBox(height: 14),
          const Text('Tóm tắt AI (đọc trong 1 phút)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          if (detail.hasSummary)
            MarkdownBody(
              data: detail.summary!,
              styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
                p: TextStyle(
                  fontSize: 13.5,
                  height: 1.5,
                  color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                ),
              ),
            )
          else ...[
            Text(
              busy
                  ? 'AI đang đọc README của repo này. Có thể mất tới 2 phút, bạn đừng rời màn hình nhé.'
                  : 'Repo này chưa có tóm tắt AI. Bạn có thể tạo ngay, hoặc đợi hệ thống tự tạo theo lịch.',
              style: TextStyle(
                fontSize: 13.5,
                height: 1.5,
                color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
              ),
            ),
            const SizedBox(height: 16),
            GlassButton(
              text: 'Tạo tóm tắt AI',
              icon: Icons.auto_awesome_rounded,
              isLoading: busy,
              onPressed: busy ? null : onGenerate,
            ),
          ],
        ],
      ),
    );
  }
}

class _QuickstartCard extends StatefulWidget {
  final String? quickstart;

  const _QuickstartCard({required this.quickstart});

  @override
  State<_QuickstartCard> createState() => _QuickstartCardState();
}

class _QuickstartCardState extends State<_QuickstartCard> {
  bool _copied = false;

  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: widget.quickstart!));
    HapticFeedback.lightImpact();
    if (!mounted) return;
    setState(() => _copied = true);
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _copied = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final text = widget.quickstart?.trim() ?? '';
    if (text.isEmpty) {
      return const GlassContainer(
        padding: EdgeInsets.all(20),
        borderRadius: 22,
        child: EmptyView(
          icon: Icons.terminal_rounded,
          title: 'Chưa có hướng dẫn nhanh',
          subtitle: 'Quickstart do AI tạo cùng với bản tóm tắt.',
        ),
      );
    }
    return GlassContainer(
      padding: const EdgeInsets.all(18),
      borderRadius: 22,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.terminal_rounded, size: 18, color: AppColors.primary),
              const SizedBox(width: 8),
              const Expanded(
                child: Text('Cài đặt nhanh (Quickstart)', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
              ),
              TextButton.icon(
                onPressed: _copy,
                icon: Icon(_copied ? Icons.check_rounded : Icons.copy_rounded, size: 16),
                label: Text(_copied ? 'Đã chép' : 'Sao chép'),
                style: TextButton.styleFrom(foregroundColor: _copied ? AppColors.success : AppColors.primary),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.black.withAlpha(160),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white.withAlpha(20)),
            ),
            child: SelectableText(
              text,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 12.5, color: Color(0xFF70F3FF), height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReadmeCard extends StatelessWidget {
  final RepoDetailModel detail;

  const _ReadmeCard({required this.detail});

  /// README images: relative paths and SVG badges cannot be shown, so they become their alt text.
  static Widget _buildReadmeImage(MarkdownImageConfig config) {
    final uri = config.uri;
    final altText = (config.alt == null || config.alt!.isEmpty)
        ? const SizedBox.shrink()
        : Text('[${config.alt}]', style: const TextStyle(fontSize: 12, color: Colors.grey));
    final isHttp = uri.scheme == 'http' || uri.scheme == 'https';
    if (!isHttp || uri.path.toLowerCase().endsWith('.svg')) return altText;
    return Image.network(
      uri.toString(),
      width: config.width,
      height: config.height,
      errorBuilder: (context, error, stackTrace) => altText,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final readme = detail.readme?.trim() ?? '';
    final primaryText = isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;

    return GlassContainer(
      padding: const EdgeInsets.all(20),
      borderRadius: 24,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.article_outlined, color: AppColors.primary, size: 20),
              const SizedBox(width: 10),
              Text('README.md', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: primaryText)),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(height: 1),
          const SizedBox(height: 14),
          if (readme.isEmpty)
            const EmptyView(
              icon: Icons.description_outlined,
              title: 'Repo này chưa có README',
              subtitle: 'Bạn có thể xem mã nguồn trực tiếp trên GitHub.',
            )
          else
            MarkdownBody(
              data: readme,
              selectable: true,
              sizedImageBuilder: _buildReadmeImage,
              styleSheet: MarkdownStyleSheet.fromTheme(theme).copyWith(
                p: TextStyle(
                  fontSize: 13.5,
                  height: 1.55,
                  color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                ),
                h1: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: primaryText),
                h2: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: primaryText),
                h3: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: primaryText),
                code: TextStyle(
                  backgroundColor: isDark ? const Color(0xFF161B22) : const Color(0xFFEAEEF2),
                  fontFamily: 'monospace',
                  fontSize: 12.0,
                  color: isDark ? const Color(0xFF70F3FF) : AppColors.primaryDark,
                ),
                codeblockDecoration: BoxDecoration(
                  color: isDark ? const Color(0xFF0D1117) : const Color(0xFFF6F8FA),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: isDark ? const Color(0xFF30363D) : const Color(0xFFD0D7DE)),
                ),
                codeblockPadding: const EdgeInsets.all(12),
                blockquoteDecoration: BoxDecoration(
                  border: const Border(left: BorderSide(color: AppColors.primary, width: 3)),
                  color: AppColors.primary.withAlpha(20),
                  borderRadius: const BorderRadius.horizontal(right: Radius.circular(8)),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
