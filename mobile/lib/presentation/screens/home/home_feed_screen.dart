import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../data/models/repo_model.dart';
import '../../../data/repositories/repo_repository.dart';
import '../../state/feed/feed_bloc.dart';
import '../../state/feed/feed_event.dart';
import '../../state/feed/feed_state.dart';
import '../../widgets/common/fade_slide_in.dart';
import '../../widgets/common/state_views.dart';
import '../../widgets/icons/github_logo.dart';
import '../../widgets/repo_card.dart';
import '../notifications/widgets/notification_bell.dart';

/// Home tab: personalised trending feed, language chips, pull-to-refresh, infinite scroll.
class HomeFeedScreen extends StatelessWidget {
  const HomeFeedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => FeedBloc(repoRepository: context.read<RepoRepository>())..add(const FeedStarted()),
      child: const _HomeFeedView(),
    );
  }
}

class _HomeFeedView extends StatefulWidget {
  const _HomeFeedView();

  @override
  State<_HomeFeedView> createState() => _HomeFeedViewState();
}

class _HomeFeedViewState extends State<_HomeFeedView> {
  bool _isHeaderVisible = true;

  Future<void> _refresh() async {
    final bloc = context.read<FeedBloc>();
    bloc.add(const FeedRefreshed());
    await bloc.stream.first.timeout(const Duration(seconds: 30), onTimeout: () => bloc.state);
  }

  void _openRepo(RepoModel repo) => context.push('/repo/${repo.id}', extra: repo);

  void _selectLanguage(String? language) {
    context.read<FeedBloc>().add(FeedLanguageSelected(language));
  }

  bool _onScrollNotification(ScrollNotification notification) {
    // Infinite scroll: ask for the next page when close to the end.
    if (notification.metrics.axis == Axis.vertical && notification.metrics.extentAfter < 400) {
      context.read<FeedBloc>().add(const FeedLoadMoreRequested());
    }
    if (notification is UserScrollNotification) {
      if (notification.direction == ScrollDirection.reverse && _isHeaderVisible) {
        setState(() => _isHeaderVisible = false);
      } else if (notification.direction == ScrollDirection.forward && !_isHeaderVisible) {
        setState(() => _isHeaderVisible = true);
      }
    } else if (notification.metrics.pixels <= 10 && !_isHeaderVisible) {
      setState(() => _isHeaderVisible = true);
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SafeArea(
      bottom: false,
      child: Column(
        children: [
          // Header + chips slide away while scrolling down.
          ClipRect(
            child: AnimatedAlign(
              alignment: Alignment.topCenter,
              duration: const Duration(milliseconds: 260),
              curve: Curves.easeInOutCubic,
              heightFactor: _isHeaderVisible ? 1.0 : 0.0,
              child: AnimatedOpacity(
                opacity: _isHeaderVisible ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 200),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _FeedHeader(isDark: isDark),
                    BlocBuilder<FeedBloc, FeedState>(
                      buildWhen: (a, b) => a.language != b.language || a.languages != b.languages,
                      builder: (context, state) => _LanguageChips(
                        languages: state.languages,
                        selected: state.language,
                        isDark: isDark,
                        onSelected: _selectLanguage,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: NotificationListener<ScrollNotification>(
              onNotification: _onScrollNotification,
              child: BlocConsumer<FeedBloc, FeedState>(
                listenWhen: (a, b) => b.loadMoreError != null && a.loadMoreError != b.loadMoreError && b.repos.isNotEmpty,
                listener: (context, state) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(state.loadMoreError!), backgroundColor: AppColors.error),
                  );
                },
                builder: (context, state) {
                  return AnimatedSwitcher(
                    duration: const Duration(milliseconds: 250),
                    child: _buildBody(context, state),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(BuildContext context, FeedState state) {
    switch (state.status) {
      case FeedStatus.initial:
      case FeedStatus.loading:
        return const SkeletonList(key: ValueKey('loading'), itemHeight: 150);
      case FeedStatus.failure:
        return ErrorRetryView(
          key: const ValueKey('error'),
          message: state.errorMessage ?? 'Không tải được danh sách repo',
          onRetry: () => context.read<FeedBloc>().add(const FeedRefreshed()),
        );
      case FeedStatus.success:
        if (state.repos.isEmpty) {
          return RefreshIndicator(
            key: const ValueKey('empty'),
            color: AppColors.primary,
            onRefresh: _refresh,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                const SizedBox(height: 60),
                EmptyView(
                  icon: Icons.inbox_outlined,
                  title: state.language == null
                      ? 'Chưa có repo phù hợp với sở thích của bạn'
                      : 'Chưa có repo nào viết bằng ${state.language}',
                  subtitle: 'Kéo xuống để làm mới hoặc chọn ngôn ngữ khác',
                ),
              ],
            ),
          );
        }
        final showBanner = state.fromCache;
        final itemCount = state.repos.length + 1 + (showBanner ? 1 : 0);
        return RefreshIndicator(
          key: ValueKey('list-${state.language}'),
          color: AppColors.primary,
          onRefresh: _refresh,
          child: ListView.builder(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.only(top: 4, bottom: 96),
            itemCount: itemCount,
            itemBuilder: (context, index) {
              if (showBanner) {
                if (index == 0) {
                  return Padding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 6),
                    child: OfflineBanner(
                      cachedAt: state.cachedAt,
                      onRetry: () => context.read<FeedBloc>().add(const FeedRefreshed()),
                    ),
                  );
                }
                index -= 1;
              }
              if (index == state.repos.length) return _FeedFooter(state: state);
              final repo = state.repos[index];
              return FadeSlideIn(
                key: ValueKey('repo-${repo.id}'),
                index: index,
                child: RepoCard(
                  repo: repo,
                  heroTag: 'repo-avatar-${repo.id}',
                  onTap: () => _openRepo(repo),
                ),
              );
            },
          ),
        );
    }
  }
}

class _FeedHeader extends StatelessWidget {
  final bool isDark;

  const _FeedHeader({required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 12, 8),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: const Color(0xFF21262D),
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFF30363D), width: 1.2),
              boxShadow: [
                BoxShadow(color: Colors.black.withAlpha(50), blurRadius: 8, offset: const Offset(0, 2)),
              ],
            ),
            child: const Center(child: GithubLogo(size: 22, color: Colors.white)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        'DevRadar',
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.w800,
                          color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                          letterSpacing: -0.4,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withAlpha(30),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: AppColors.primary.withAlpha(80), width: 0.8),
                      ),
                      child: const Text(
                        'GitHub',
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.primary),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 1),
                Text(
                  'Xu hướng mã nguồn mở & Trợ lý AI',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11.5,
                    color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                  ),
                ),
              ],
            ),
          ),
          const NotificationBellButton(),
        ],
      ),
    );
  }
}

class _LanguageChips extends StatelessWidget {
  final List<String> languages;
  final String? selected;
  final bool isDark;
  final ValueChanged<String?> onSelected;

  const _LanguageChips({
    required this.languages,
    required this.selected,
    required this.isDark,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final chips = <String?>[null, ...languages];
    return Container(
      height: 42,
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        itemCount: chips.length,
        separatorBuilder: (context, index) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final language = chips[index];
          final isSelected = language == selected;
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: isSelected ? null : () => onSelected(language),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 7),
              decoration: BoxDecoration(
                color: isSelected
                    ? AppColors.primaryDark
                    : (isDark ? const Color(0xFF21262D) : const Color(0xFFEAEEF2)),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isSelected
                      ? AppColors.primary
                      : (isDark ? const Color(0xFF30363D) : const Color(0xFFD0D7DE)),
                ),
              ),
              child: Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (language == null) ...[
                      Icon(
                        Icons.auto_awesome_rounded,
                        size: 14,
                        color: isSelected ? Colors.white : AppColors.primary,
                      ),
                      const SizedBox(width: 5),
                    ],
                    Text(
                      language ?? 'Dành cho bạn',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                        color: isSelected
                            ? Colors.white
                            : (isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _FeedFooter extends StatelessWidget {
  final FeedState state;

  const _FeedFooter({required this.state});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    Widget child;
    if (state.isLoadingMore) {
      child = const SizedBox(
        width: 22,
        height: 22,
        child: CircularProgressIndicator(strokeWidth: 2.2, color: AppColors.primary),
      );
    } else if (state.loadMoreError != null && state.hasMore) {
      child = TextButton.icon(
        onPressed: () => context.read<FeedBloc>().add(const FeedLoadMoreRequested()),
        icon: const Icon(Icons.refresh_rounded),
        label: const Text('Tải thêm thất bại – thử lại'),
      );
    } else if (!state.hasMore) {
      child = Text(
        state.fromCache ? 'Đang xem dữ liệu offline' : 'Bạn đã xem hết danh sách',
        style: TextStyle(fontSize: 12, color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted),
      );
    } else {
      child = const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Center(child: child),
    );
  }
}
