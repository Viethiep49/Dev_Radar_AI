import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../state/repo/repo_bloc.dart';
import '../../state/repo/repo_event.dart';
import '../../state/repo/repo_state.dart';
import '../../widgets/glass/glass_container.dart';
import '../../widgets/glass/glass_search_bar.dart';
import '../../widgets/repo_card.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _searchController = TextEditingController();

  final List<String> _trendingTopics = [
    'Flutter',
    'FastAPI',
    'PyTorch',
    'Next.js',
    'Ollama',
    'Rust',
    'Docker',
    'Tailwind',
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onSearch(String query) {
    context.read<RepoBloc>().add(SearchReposRequested(query));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return SafeArea(
      bottom: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 8),
            child: Text(
              'Tìm kiếm & Khám phá',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                letterSpacing: -0.4,
              ),
            ),
          ),

          // Glass Search Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: GlassSearchBar(
              controller: _searchController,
              onSubmitted: _onSearch,
              onChanged: (val) {
                if (val.isEmpty) {
                  _onSearch('');
                }
              },
              onClear: () {
                _searchController.clear();
                _onSearch('');
              },
            ),
          ),

          // Trending Topics Carousel
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
            child: Text(
              'Chủ đề xu hướng:',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
              ),
            ),
          ),
          Container(
            height: 38,
            margin: const EdgeInsets.only(bottom: 6),
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              scrollDirection: Axis.horizontal,
              itemCount: _trendingTopics.length,
              separatorBuilder: (context, index) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final topic = _trendingTopics[index];
                return GestureDetector(
                  onTap: () {
                    _searchController.text = topic;
                    _onSearch(topic);
                  },
                  child: GlassContainer(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    borderRadius: 18,
                    child: Center(
                      child: Text(
                        '#$topic',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          // Search Results
          Expanded(
            child: BlocBuilder<RepoBloc, RepoState>(
              builder: (context, state) {
                if (state is RepoLoading) {
                  return const Center(
                    child: CircularProgressIndicator(color: AppColors.primary),
                  );
                }

                if (state is RepoFailure) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        state.message,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: AppColors.error),
                      ),
                    ),
                  );
                }

                if (state is RepoLoaded) {
                  if (state.repos.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.search_off_rounded,
                            size: 52,
                            color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                          ),
                          const SizedBox(height: 14),
                          const Text(
                            'Không tìm thấy repository phù hợp',
                            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Hãy thử từ khoá khác hoặc chọn chủ đề phía trên',
                            style: TextStyle(
                              fontSize: 12.5,
                              color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.only(top: 4, bottom: 90),
                    itemCount: state.repos.length,
                    itemBuilder: (context, index) {
                      final repo = state.repos[index];
                      return RepoCard(
                        repo: repo,
                        onTap: () {
                          context.push('/repo-detail', extra: repo);
                        },
                      );
                    },
                  );
                }

                return const SizedBox.shrink();
              },
            ),
          ),
        ],
      ),
    );
  }
}
