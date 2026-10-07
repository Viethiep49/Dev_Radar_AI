import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../state/repo/repo_bloc.dart';
import '../../state/repo/repo_event.dart';
import '../../state/repo/repo_state.dart';
import '../../widgets/glass/glass_button.dart';
import '../../widgets/glass/glass_container.dart';
import '../../widgets/icons/github_logo.dart';
import '../../widgets/repo_card.dart';

class HomeFeedScreen extends StatefulWidget {
  const HomeFeedScreen({super.key});

  @override
  State<HomeFeedScreen> createState() => _HomeFeedScreenState();
}

class _HomeFeedScreenState extends State<HomeFeedScreen> {
  final ScrollController _scrollController = ScrollController();
  final List<String> _languages = [
    'Tất cả',
    'Dart',
    'Python',
    'TypeScript',
    'JavaScript',
    'Go',
    'Rust',
  ];
  String _selectedLang = 'Tất cả';
  bool _isHeaderVisible = true;

  @override
  void initState() {
    super.initState();
    _loadRepos();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _loadRepos({bool isRefresh = false}) {
    final lang = _selectedLang == 'Tất cả' ? null : _selectedLang;
    context.read<RepoBloc>().add(
          FetchTrendingReposRequested(language: lang, isRefresh: isRefresh),
        );
  }

  Widget _buildTopHeader(bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: const Color(0xFF21262D),
              shape: BoxShape.circle,
              border: Border.all(
                color: const Color(0xFF30363D),
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(50),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: const Center(
              child: GithubLogo(size: 22, color: Colors.white),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'DevRadar',
                      style: TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w800,
                        color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                        letterSpacing: -0.4,
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
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 1),
                Text(
                  'Xu hướng mã nguồn mở & Trợ lý AI',
                  style: TextStyle(
                    fontSize: 11.5,
                    color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: const Color(0xFF21262D),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFF30363D)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 7.5,
                  height: 7.5,
                  decoration: BoxDecoration(
                    color: AppColors.success,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.success.withAlpha(150),
                        blurRadius: 6,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  'AI Online',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLanguageChips(bool isDark) {
    return Container(
      height: 42,
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        itemCount: _languages.length,
        separatorBuilder: (context, index) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final lang = _languages[index];
          final isSelected = lang == _selectedLang;

          return MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {
                if (!isSelected) {
                  setState(() {
                    _selectedLang = lang;
                  });
                  if (_scrollController.hasClients) {
                    _scrollController.animateTo(
                      0,
                      duration: const Duration(milliseconds: 250),
                      curve: Curves.easeOut,
                    );
                  }
                  _loadRepos();
                }
              },
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
                    width: 1.0,
                  ),
                ),
                child: Center(
                  child: Text(
                    lang,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                      color: isSelected
                          ? Colors.white
                          : (isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return SafeArea(
      bottom: false,
      child: Column(
        children: [
          // Smooth slide-up collapsible header on scroll
          ClipRect(
            child: AnimatedAlign(
              alignment: Alignment.topCenter,
              duration: const Duration(milliseconds: 260),
              curve: Curves.easeInOutCubic,
              heightFactor: _isHeaderVisible ? 1.0 : 0.0,
              child: AnimatedOpacity(
                opacity: _isHeaderVisible ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeInOut,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildTopHeader(isDark),
                    _buildLanguageChips(isDark),
                  ],
                ),
              ),
            ),
          ),

          // Repo List with scroll listener for header collapse
          Expanded(
            child: NotificationListener<ScrollNotification>(
              onNotification: (notification) {
                if (notification is UserScrollNotification) {
                  if (notification.direction == ScrollDirection.reverse) {
                    // Scrolling down -> slide up and hide top header
                    if (_isHeaderVisible) {
                      setState(() {
                        _isHeaderVisible = false;
                      });
                    }
                  } else if (notification.direction == ScrollDirection.forward) {
                    // Scrolling up -> slide down and reveal top header
                    if (!_isHeaderVisible) {
                      setState(() {
                        _isHeaderVisible = true;
                      });
                    }
                  }
                } else if (notification.metrics.pixels <= 10 && !_isHeaderVisible) {
                  // At the very top -> always reveal top header
                  setState(() {
                    _isHeaderVisible = true;
                  });
                }
                return false;
              },
              child: BlocBuilder<RepoBloc, RepoState>(
                builder: (context, state) {
                  if (state is RepoLoading) {
                    return const Center(
                      child: CircularProgressIndicator(color: AppColors.primary),
                    );
                  }

                  if (state is RepoFailure) {
                    final is401 = state.message.contains('401') ||
                        state.message.toLowerCase().contains('unauthorized') ||
                        state.message.toLowerCase().contains('hết hạn');

                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(28),
                        child: GlassContainer(
                          padding: const EdgeInsets.all(24),
                          borderRadius: 24,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                is401 ? Icons.lock_clock_rounded : Icons.cloud_off_rounded,
                                size: 48,
                                color: is401 ? AppColors.warning : AppColors.error,
                              ),
                              const SizedBox(height: 14),
                              Text(
                                is401 ? 'Phiên đăng nhập đã hết hạn' : 'Không thể kết nối đến máy chủ',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                is401
                                    ? 'Vui lòng đăng nhập lại để tiếp tục sử dụng DevRadar.'
                                    : state.message,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 12.5,
                                  color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                                ),
                              ),
                              const SizedBox(height: 18),
                              GlassButton(
                                text: is401 ? 'Đăng nhập ngay' : 'Thử lại ngay',
                                icon: is401 ? Icons.login_rounded : Icons.refresh_rounded,
                                height: 44,
                                onPressed: () {
                                  if (is401) {
                                    context.go('/login');
                                  } else {
                                    _loadRepos();
                                  }
                                },
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }

                  if (state is RepoLoaded) {
                    final displayRepos = _selectedLang == 'Tất cả'
                        ? state.repos
                        : state.repos
                            .where((r) => r.language?.toLowerCase() == _selectedLang.toLowerCase())
                            .toList();

                    if (displayRepos.isEmpty) {
                      return Center(
                        child: GlassContainer(
                          margin: const EdgeInsets.all(32),
                          padding: const EdgeInsets.all(28),
                          borderRadius: 24,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.inbox_outlined,
                                size: 48,
                                color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                              ),
                              const SizedBox(height: 12),
                              Text(
                                _selectedLang == 'Tất cả'
                                    ? 'Chưa có repository nào'
                                    : 'Không có repository nào viết bằng $_selectedLang',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      );
                    }

                    return RefreshIndicator(
                      color: AppColors.primary,
                      onRefresh: () async => _loadRepos(isRefresh: true),
                      child: ListView.builder(
                        controller: _scrollController,
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.only(top: 4, bottom: 96),
                        itemCount: displayRepos.length,
                        itemBuilder: (context, index) {
                          final repo = displayRepos[index];
                          return RepoCard(
                            repo: repo,
                            onTap: () {
                              context.push('/repo-detail', extra: repo);
                            },
                          );
                        },
                      ),
                    );
                  }

                  return const SizedBox.shrink();
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}
