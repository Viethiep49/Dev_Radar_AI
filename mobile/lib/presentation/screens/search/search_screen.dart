import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../data/models/repo_filters_model.dart';
import '../../../data/repositories/repo_repository.dart';
import '../../state/search/search_bloc.dart';
import '../../state/search/search_event.dart';
import '../../state/search/search_state.dart';
import '../../widgets/common/fade_slide_in.dart';
import '../../widgets/common/state_views.dart';
import '../../widgets/glass/glass_container.dart';
import '../../widgets/glass/glass_modal_sheet.dart';
import '../../widgets/glass/glass_search_bar.dart';
import '../../widgets/repo_card.dart';

/// Search tab: text search (debounced) + language/topic filters + sort, paginated.
class SearchScreen extends StatelessWidget {
  const SearchScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => SearchBloc(repoRepository: context.read<RepoRepository>())..add(const SearchStarted()),
      child: const _SearchView(),
    );
  }
}

class _SearchView extends StatefulWidget {
  const _SearchView();

  @override
  State<_SearchView> createState() => _SearchViewState();
}

class _SearchViewState extends State<_SearchView> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  SearchBloc get _bloc => context.read<SearchBloc>();

  void _applyFilters({String? language, String? topic, RepoSort? sort}) {
    _bloc.add(SearchFiltersChanged(language: language, topic: topic, sort: sort ?? _bloc.state.sort));
  }

  Future<void> _openFilterSheet() async {
    final state = _bloc.state;
    final result = await GlassModalSheet.show<SearchFiltersChanged>(
      context: context,
      title: 'Bộ lọc & sắp xếp',
      child: _FilterSheet(filters: state.filters, language: state.language, topic: state.topic, sort: state.sort),
    );
    if (result != null && mounted) _bloc.add(result);
  }

  bool _onScrollNotification(ScrollNotification notification) {
    if (notification.metrics.axis == Axis.vertical && notification.metrics.extentAfter < 400) {
      _bloc.add(const SearchLoadMoreRequested());
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SafeArea(
      bottom: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Row(
              children: [
                Expanded(
                  child: GlassSearchBar(
                    controller: _searchController,
                    onChanged: (value) => _bloc.add(SearchQueryChanged(value)),
                    onSubmitted: (value) => _bloc.add(SearchSubmitted(value)),
                    onClear: () {
                      _searchController.clear();
                      _bloc.add(const SearchSubmitted(''));
                    },
                  ),
                ),
                const SizedBox(width: 8),
                BlocBuilder<SearchBloc, SearchState>(
                  buildWhen: (a, b) => a.activeFilterCount != b.activeFilterCount,
                  builder: (context, state) =>
                      _FilterButton(count: state.activeFilterCount, onPressed: _openFilterSheet),
                ),
              ],
            ),
          ),
          BlocBuilder<SearchBloc, SearchState>(
            buildWhen: (a, b) => a.language != b.language || a.topic != b.topic || a.sort != b.sort,
            builder: (context, state) => _ActiveFilters(
              state: state,
              onRemoveLanguage: () => _applyFilters(topic: state.topic),
              onRemoveTopic: () => _applyFilters(language: state.language),
              onResetSort: () => _applyFilters(language: state.language, topic: state.topic, sort: RepoSort.stars),
            ),
          ),
          Expanded(
            child: NotificationListener<ScrollNotification>(
              onNotification: _onScrollNotification,
              child: BlocBuilder<SearchBloc, SearchState>(
                builder: (context, state) =>
                    AnimatedSwitcher(duration: const Duration(milliseconds: 220), child: _buildBody(state, isDark)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(SearchState state, bool isDark) {
    switch (state.status) {
      case SearchStatus.idle:
        return _Suggestions(
          key: const ValueKey('idle'),
          filters: state.filters,
          isDark: isDark,
          onTopic: (topic) => _applyFilters(language: state.language, topic: topic),
          onLanguage: (language) => _applyFilters(language: language, topic: state.topic),
        );
      case SearchStatus.loading:
        return const SkeletonList(key: ValueKey('loading'), itemHeight: 150);
      case SearchStatus.failure:
        return ErrorRetryView(
          key: const ValueKey('error'),
          message: state.errorMessage ?? 'Tìm kiếm thất bại',
          onRetry: () => _bloc.add(const SearchRetried()),
        );
      case SearchStatus.success:
        if (state.results.isEmpty) {
          return const EmptyView(
            key: ValueKey('empty'),
            icon: Icons.search_off_rounded,
            title: 'Không tìm thấy repository phù hợp',
            subtitle: 'Hãy thử từ khoá khác hoặc bỏ bớt bộ lọc',
          );
        }
        final extra = state.fromCache ? 2 : 1; // header (+ offline banner)
        return ListView.builder(
          key: const ValueKey('results'),
          padding: const EdgeInsets.only(top: 4, bottom: 96),
          itemCount: state.results.length + extra + 1,
          itemBuilder: (context, index) {
            if (index == 0) {
              return Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 4),
                child: Text(
                  'Tìm thấy ${state.total} repository · ${state.sort.label}',
                  style: TextStyle(fontSize: 12, color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted),
                ),
              );
            }
            if (state.fromCache && index == 1) {
              return Padding(
                padding: const EdgeInsets.fromLTRB(16, 2, 16, 6),
                child: OfflineBanner(cachedAt: state.cachedAt, onRetry: () => _bloc.add(const SearchRetried())),
              );
            }
            final i = index - extra;
            if (i == state.results.length) return _SearchFooter(state: state);
            final repo = state.results[i];
            return FadeSlideIn(
              key: ValueKey('search-${repo.id}'),
              index: i,
              child: RepoCard(
                repo: repo,
                onTap: () => context.push('/repo/${repo.id}', extra: repo),
              ),
            );
          },
        );
    }
  }
}

class _FilterButton extends StatelessWidget {
  final int count;
  final VoidCallback onPressed;

  const _FilterButton({required this.count, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Badge(
      isLabelVisible: count > 0,
      label: Text('$count'),
      backgroundColor: AppColors.primary,
      child: GestureDetector(
        onTap: onPressed,
        child: const GlassContainer(
          width: 50,
          height: 50,
          borderRadius: 16,
          padding: EdgeInsets.zero,
          child: Center(child: Icon(Icons.tune_rounded, color: AppColors.primary)),
        ),
      ),
    );
  }
}

class _ActiveFilters extends StatelessWidget {
  final SearchState state;
  final VoidCallback onRemoveLanguage;
  final VoidCallback onRemoveTopic;
  final VoidCallback onResetSort;

  const _ActiveFilters({
    required this.state,
    required this.onRemoveLanguage,
    required this.onRemoveTopic,
    required this.onResetSort,
  });

  @override
  Widget build(BuildContext context) {
    final chips = <Widget>[
      if (state.language != null)
        InputChip(
          label: Text(state.language!),
          avatar: const Icon(Icons.code_rounded, size: 16),
          onDeleted: onRemoveLanguage,
        ),
      if (state.topic != null) InputChip(label: Text('#${state.topic}'), onDeleted: onRemoveTopic),
      if (state.sort != RepoSort.stars)
        InputChip(
          label: Text(state.sort.label),
          avatar: const Icon(Icons.sort_rounded, size: 16),
          onDeleted: onResetSort,
        ),
    ];
    return AnimatedSize(
      duration: const Duration(milliseconds: 200),
      child: chips.isEmpty
          ? const SizedBox(width: double.infinity)
          : SizedBox(
              height: 44,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: chips.length,
                separatorBuilder: (_, _) => const SizedBox(width: 6),
                itemBuilder: (_, i) => chips[i],
              ),
            ),
    );
  }
}

/// Shown before anything is searched: popular topics and languages.
class _Suggestions extends StatelessWidget {
  final RepoFiltersModel filters;
  final bool isDark;
  final ValueChanged<String> onTopic;
  final ValueChanged<String> onLanguage;

  const _Suggestions({
    super.key,
    required this.filters,
    required this.isDark,
    required this.onTopic,
    required this.onLanguage,
  });

  @override
  Widget build(BuildContext context) {
    final muted = isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted;
    if (filters.topics.isEmpty && filters.languages.isEmpty) {
      return const EmptyView(
        icon: Icons.manage_search_rounded,
        title: 'Tìm repository theo tên hoặc từ khoá',
        subtitle: 'Ví dụ: flutter, fastapi, ollama',
      );
    }
    Widget section(String title, List<FilterOption> options, String prefix, ValueChanged<String> onTap) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 12, 4, 8),
            child: Text(
              title,
              style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: muted),
            ),
          ),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: options.take(16).map((option) {
              return GestureDetector(
                onTap: () => onTap(option.name),
                child: GlassContainer(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  borderRadius: 18,
                  child: Text(
                    '$prefix${option.name} · ${option.count}',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.primary),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
      children: [
        if (filters.topics.isNotEmpty) section('Chủ đề xu hướng', filters.topics, '#', onTopic),
        if (filters.languages.isNotEmpty) section('Ngôn ngữ phổ biến', filters.languages, '', onLanguage),
      ],
    );
  }
}

class _SearchFooter extends StatelessWidget {
  final SearchState state;

  const _SearchFooter({required this.state});

  @override
  Widget build(BuildContext context) {
    Widget child;
    if (state.isLoadingMore) {
      child = const SizedBox(
        width: 22,
        height: 22,
        child: CircularProgressIndicator(strokeWidth: 2.2, color: AppColors.primary),
      );
    } else if (state.loadMoreError != null && state.hasMore) {
      child = TextButton.icon(
        onPressed: () => context.read<SearchBloc>().add(const SearchLoadMoreRequested()),
        icon: const Icon(Icons.refresh_rounded),
        label: const Text('Tải thêm thất bại – thử lại'),
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

/// Bottom sheet: pick language, topic and sort. Pops a [SearchFiltersChanged].
class _FilterSheet extends StatefulWidget {
  final RepoFiltersModel filters;
  final String? language;
  final String? topic;
  final RepoSort sort;

  const _FilterSheet({required this.filters, required this.language, required this.topic, required this.sort});

  @override
  State<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<_FilterSheet> {
  late String? _language = widget.language;
  late String? _topic = widget.topic;
  late RepoSort _sort = widget.sort;

  Widget _title(String text) => Padding(
    padding: const EdgeInsets.only(top: 12, bottom: 8),
    child: Text(text, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
  );

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _title('Sắp xếp theo'),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: RepoSort.values
                .map(
                  (sort) => ChoiceChip(
                    label: Text(sort.label),
                    selected: _sort == sort,
                    onSelected: (_) => setState(() => _sort = sort),
                  ),
                )
                .toList(),
          ),
          _title('Ngôn ngữ'),
          _OptionWrap(
            options: widget.filters.languages,
            selected: _language,
            onSelected: (value) => setState(() => _language = value),
          ),
          _title('Chủ đề'),
          _OptionWrap(
            options: widget.filters.topics,
            selected: _topic,
            prefix: '#',
            onSelected: (value) => setState(() => _topic = value),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => setState(() {
                    _language = null;
                    _topic = null;
                    _sort = RepoSort.stars;
                  }),
                  child: const Text('Đặt lại'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: () =>
                      Navigator.of(context).pop(SearchFiltersChanged(language: _language, topic: _topic, sort: _sort)),
                  child: const Text('Áp dụng'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _OptionWrap extends StatelessWidget {
  final List<FilterOption> options;
  final String? selected;
  final String prefix;
  final ValueChanged<String?> onSelected;

  const _OptionWrap({required this.options, required this.selected, required this.onSelected, this.prefix = ''});

  @override
  Widget build(BuildContext context) {
    if (options.isEmpty) {
      return const Text('Chưa có dữ liệu', style: TextStyle(fontSize: 12.5, color: Colors.grey));
    }
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: options.take(20).map((option) {
        final isSelected = option.name == selected;
        return FilterChip(
          label: Text('$prefix${option.name} (${option.count})'),
          selected: isSelected,
          onSelected: (value) => onSelected(value ? option.name : null),
        );
      }).toList(),
    );
  }
}
