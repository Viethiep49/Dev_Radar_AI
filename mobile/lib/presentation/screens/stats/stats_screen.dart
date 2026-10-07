import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../../../data/models/stats_model.dart';
import '../../../data/repositories/stats_repository.dart';
import '../../state/stats/stats_cubit.dart';
import '../../widgets/common/state_views.dart';
import '../../widgets/glass/glass_card.dart';

/// Stats tab: personal learning statistics (the course's core "Quản lý cá nhân" feature).
class StatsScreen extends StatelessWidget {
  const StatsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(create: (ctx) => StatsCubit(ctx.read<StatsRepository>())..load(), child: const _StatsView());
  }
}

class _StatsView extends StatelessWidget {
  const _StatsView();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return SafeArea(
      bottom: false,
      child: BlocBuilder<StatsCubit, StatsState>(
        builder: (context, state) {
          final cubit = context.read<StatsCubit>();
          final Widget body;
          if (state.status == StatsStatus.initial || state.status == StatsStatus.loading) {
            body = const _StatsSkeleton(key: ValueKey('loading'));
          } else if (state.status == StatsStatus.failure && state.overview == null) {
            body = ErrorRetryView(
              key: const ValueKey('error'),
              message: state.errorMessage ?? 'Không tải được thống kê',
              onRetry: cubit.load,
            );
          } else {
            body = RefreshIndicator(
              key: const ValueKey('content'),
              onRefresh: cubit.load,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 110),
                children: [
                  _Header(isDark: isDark),
                  if (state.fromCache) ...[
                    OfflineBanner(cachedAt: state.cachedAt, onRetry: cubit.load),
                    const SizedBox(height: 12),
                  ],
                  if (state.isEmpty)
                    const Padding(
                      padding: EdgeInsets.only(top: 40),
                      child: EmptyView(
                        icon: Icons.insights_rounded,
                        title: 'Chưa có dữ liệu thống kê',
                        subtitle:
                            'Mở một repo và chọn trạng thái "Muốn thử", "Đang tìm hiểu" hoặc "Đã sử dụng" để bắt đầu lộ trình.',
                      ),
                    )
                  else ...[
                    _MetricGrid(overview: state.overview!),
                    const SizedBox(height: 22),
                    _SectionTitle('Phân bố trạng thái học tập', isDark: isDark),
                    const SizedBox(height: 10),
                    _StatusPieCard(overview: state.overview!),
                    const SizedBox(height: 22),
                    Row(
                      children: [
                        Expanded(child: _SectionTitle('Hoạt động theo tuần', isDark: isDark)),
                        _WeeksToggle(selected: state.weeks, onChanged: cubit.changeWeeks),
                      ],
                    ),
                    const SizedBox(height: 10),
                    _WeeklyBarCard(weekly: state.weekly),
                    const SizedBox(height: 22),
                    _SectionTitle('Ngôn ngữ bạn tìm hiểu nhiều nhất', isDark: isDark),
                    const SizedBox(height: 10),
                    _LanguagesCard(languages: state.languages),
                  ],
                ],
              ),
            );
          }
          return AnimatedSwitcher(duration: const Duration(milliseconds: 300), child: body);
        },
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final bool isDark;

  const _Header({required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Thống kê học tập',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
              letterSpacing: -0.4,
            ),
          ),
          Text(
            'Theo dõi lộ trình tìm hiểu công nghệ & repo',
            style: TextStyle(fontSize: 11.5, color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;
  final bool isDark;

  const _SectionTitle(this.text, {required this.isDark});

  @override
  Widget build(BuildContext context) {
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

class _MetricGrid extends StatelessWidget {
  final StatsOverviewModel overview;

  const _MetricGrid({required this.overview});

  @override
  Widget build(BuildContext context) {
    final cards = [
      _MetricCard(
        title: 'Repo trong lộ trình',
        value: overview.totalRepos,
        subtext: '${overview.learning} đang tìm hiểu',
        icon: Icons.bookmark_added_rounded,
        color: AppColors.primary,
      ),
      _MetricCard(
        title: 'Đã sử dụng',
        value: overview.used,
        subtext: '+${overview.completedThisWeek} tuần này',
        icon: Icons.verified_rounded,
        color: AppColors.success,
      ),
      _MetricCard(
        title: 'Bộ sưu tập',
        value: overview.collectionsCount,
        subtext: 'Nhóm repo của bạn',
        icon: Icons.folder_special_rounded,
        color: AppColors.secondary,
      ),
      _MetricCard(
        title: 'Ghi chú',
        value: overview.notesCount,
        subtext: 'Ghi chú đã viết',
        icon: Icons.sticky_note_2_rounded,
        color: AppColors.warning,
      ),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        // 2 columns on phones, 4 on wide screens.
        final columns = constraints.maxWidth >= 640 ? 4 : 2;
        const spacing = 12.0;
        final width = (constraints.maxWidth - spacing * (columns - 1)) / columns;
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [for (final card in cards) SizedBox(width: width, child: card)],
        );
      },
    );
  }
}

class _MetricCard extends StatelessWidget {
  final String title;
  final int value;
  final String subtext;
  final IconData icon;
  final Color color;

  const _MetricCard({
    required this.title,
    required this.value,
    required this.subtext,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GlassCard(
      padding: const EdgeInsets.all(16),
      borderRadius: 22,
      enableGlow: true,
      glowColor: color.withAlpha(30),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: color.withAlpha(35), borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(height: 10),
          // Count-up animation.
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: value.toDouble()),
            duration: const Duration(milliseconds: 700),
            curve: Curves.easeOutCubic,
            builder: (context, v, _) =>
                Text(v.round().toString(), style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold)),
          ),
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 12, color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
          ),
          const SizedBox(height: 4),
          Text(
            subtext,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color),
          ),
        ],
      ),
    );
  }
}

class _StatusPieCard extends StatefulWidget {
  final StatsOverviewModel overview;

  const _StatusPieCard({required this.overview});

  @override
  State<_StatusPieCard> createState() => _StatusPieCardState();
}

class _StatusPieCardState extends State<_StatusPieCard> {
  int _touchedIndex = -1;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final o = widget.overview;
    final slices = [
      ('Muốn thử', o.wantToTry, AppColors.primary),
      ('Đang tìm hiểu', o.learning, AppColors.secondary),
      ('Đã sử dụng', o.used, AppColors.success),
    ];
    final total = slices.fold<int>(0, (sum, s) => sum + s.$2);

    return GlassCard(
      padding: const EdgeInsets.all(20),
      borderRadius: 24,
      child: Column(
        children: [
          SizedBox(
            height: 190,
            child: total == 0
                ? const Center(child: Text('Chưa có repo nào trong lộ trình'))
                : PieChart(
                    duration: const Duration(milliseconds: 600),
                    curve: Curves.easeOutCubic,
                    PieChartData(
                      pieTouchData: PieTouchData(
                        touchCallback: (event, response) {
                          setState(() {
                            if (!event.isInterestedForInteractions || response?.touchedSection == null) {
                              _touchedIndex = -1;
                              return;
                            }
                            _touchedIndex = response!.touchedSection!.touchedSectionIndex;
                          });
                        },
                      ),
                      sectionsSpace: 4,
                      centerSpaceRadius: 42,
                      sections: [
                        // Only non-empty slices; touchedSectionIndex refers to this list.
                        for (final (i, s) in slices.where((s) => s.$2 > 0).indexed)
                          PieChartSectionData(
                            value: s.$2.toDouble(),
                            title: '${(s.$2 * 100 / total).round()}%',
                            color: s.$3,
                            radius: _touchedIndex == i ? 48 : 40,
                            titleStyle: const TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.bold,
                              color: Colors.black,
                            ),
                          ),
                      ],
                    ),
                  ),
          ),
          const SizedBox(height: 18),
          Wrap(
            alignment: WrapAlignment.spaceAround,
            spacing: 14,
            runSpacing: 8,
            children: [for (final s in slices) _Legend('${s.$1} (${s.$2})', s.$3, isDark: isDark)],
          ),
        ],
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  final String title;
  final Color color;
  final bool isDark;

  const _Legend(this.title, this.color, {required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 9,
          height: 9,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            boxShadow: [BoxShadow(color: color.withAlpha(120), blurRadius: 4)],
          ),
        ),
        const SizedBox(width: 6),
        Text(
          title,
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w500,
            color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
          ),
        ),
      ],
    );
  }
}

class _WeeksToggle extends StatelessWidget {
  final int selected;
  final ValueChanged<int> onChanged;

  const _WeeksToggle({required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<int>(
      showSelectedIcon: false,
      style: const ButtonStyle(visualDensity: VisualDensity.compact, tapTargetSize: MaterialTapTargetSize.shrinkWrap),
      segments: const [
        ButtonSegment(value: 4, label: Text('4T')),
        ButtonSegment(value: 8, label: Text('8T')),
        ButtonSegment(value: 12, label: Text('12T')),
      ],
      selected: {selected},
      onSelectionChanged: (values) => onChanged(values.first),
    );
  }
}

class _WeeklyBarCard extends StatelessWidget {
  final List<WeeklyStatModel> weekly;

  const _WeeklyBarCard({required this.weekly});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final muted = isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted;
    final maxValue = weekly.fold<int>(0, (m, w) => math.max(m, math.max(w.started, w.completed)));
    final maxY = math.max(4, maxValue + 1).toDouble();
    final dateFormat = DateFormat('dd/MM');
    // Thin bars when many weeks are shown, so 12 weeks still fit on a small phone.
    final rodWidth = weekly.length > 8 ? 5.0 : 8.0;

    return GlassCard(
      padding: const EdgeInsets.fromLTRB(12, 20, 16, 12),
      borderRadius: 24,
      child: Column(
        children: [
          SizedBox(
            height: 210,
            child: weekly.isEmpty
                ? const Center(child: Text('Chưa có hoạt động'))
                : BarChart(
                    duration: const Duration(milliseconds: 500),
                    curve: Curves.easeOutCubic,
                    BarChartData(
                      alignment: BarChartAlignment.spaceAround,
                      maxY: maxY,
                      barTouchData: BarTouchData(
                        touchTooltipData: BarTouchTooltipData(
                          getTooltipItem: (group, groupIndex, rod, rodIndex) {
                            final w = weekly[group.x];
                            final label = rodIndex == 0 ? 'Bắt đầu' : 'Hoàn thành';
                            return BarTooltipItem(
                              'Tuần ${dateFormat.format(w.weekStart)}\n$label: ${rod.toY.toInt()}',
                              const TextStyle(color: Colors.white, fontSize: 12),
                            );
                          },
                        ),
                      ),
                      titlesData: FlTitlesData(
                        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 26,
                            interval: math.max(1, (maxY / 4).ceil()).toDouble(),
                            getTitlesWidget: (value, meta) =>
                                Text(value.toInt().toString(), style: TextStyle(fontSize: 11, color: muted)),
                          ),
                        ),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 24,
                            getTitlesWidget: (value, meta) {
                              final i = value.toInt();
                              // Label every other week when the chart is crowded.
                              if (i < 0 || i >= weekly.length || (weekly.length > 8 && i.isOdd)) {
                                return const SizedBox.shrink();
                              }
                              return Padding(
                                padding: const EdgeInsets.only(top: 6),
                                child: Text(
                                  dateFormat.format(weekly[i].weekStart),
                                  style: TextStyle(fontSize: 10, color: muted),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                      gridData: FlGridData(
                        drawVerticalLine: false,
                        getDrawingHorizontalLine: (value) => FlLine(
                          color: isDark ? Colors.white.withAlpha(15) : Colors.black.withAlpha(10),
                          strokeWidth: 1,
                        ),
                      ),
                      borderData: FlBorderData(show: false),
                      barGroups: [
                        for (var i = 0; i < weekly.length; i++)
                          BarChartGroupData(
                            x: i,
                            barsSpace: 3,
                            barRods: [
                              _rod(weekly[i].started.toDouble(), AppColors.primary, rodWidth),
                              _rod(weekly[i].completed.toDouble(), AppColors.success, rodWidth),
                            ],
                          ),
                      ],
                    ),
                  ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 16,
            children: [
              _Legend('Bắt đầu tìm hiểu', AppColors.primary, isDark: isDark),
              _Legend('Hoàn thành', AppColors.success, isDark: isDark),
            ],
          ),
        ],
      ),
    );
  }

  static BarChartRodData _rod(double y, Color color, double width) {
    return BarChartRodData(
      toY: y,
      width: width,
      gradient: LinearGradient(
        begin: Alignment.bottomCenter,
        end: Alignment.topCenter,
        colors: [color.withAlpha(120), color],
      ),
      borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
    );
  }
}

class _LanguagesCard extends StatelessWidget {
  final List<LanguageStatModel> languages;

  const _LanguagesCard({required this.languages});

  static const _palette = [
    AppColors.primary,
    AppColors.secondary,
    AppColors.accent,
    AppColors.warning,
    AppColors.langDart,
    AppColors.langPython,
  ];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    if (languages.isEmpty) {
      return const GlassCard(child: Text('Chưa có repo nào có ngôn ngữ trong lộ trình của bạn'));
    }
    final top = languages.take(6).toList();
    final total = languages.fold<int>(0, (sum, l) => sum + l.count);
    return GlassCard(
      padding: const EdgeInsets.all(18),
      borderRadius: 24,
      child: Column(
        children: [
          for (var i = 0; i < top.length; i++) ...[
            if (i > 0) const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Text(
                    top[i].language,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                ),
                Text(
                  '${top[i].count} repo · ${(top[i].count * 100 / total).round()}%',
                  style: TextStyle(fontSize: 11.5, color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted),
                ),
              ],
            ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: top[i].count / top.first.count),
                duration: Duration(milliseconds: 500 + i * 100),
                curve: Curves.easeOutCubic,
                builder: (context, v, _) => LinearProgressIndicator(
                  value: v,
                  minHeight: 8,
                  color: _palette[i % _palette.length],
                  backgroundColor: isDark ? AppColors.darkElevated : AppColors.lightElevated,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _StatsSkeleton extends StatelessWidget {
  const _StatsSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 70, 16, 16),
      children: const [
        Row(
          children: [
            Expanded(child: SkeletonBox(height: 130, radius: 22)),
            SizedBox(width: 12),
            Expanded(child: SkeletonBox(height: 130, radius: 22)),
          ],
        ),
        SizedBox(height: 22),
        SkeletonBox(height: 250, radius: 24),
        SizedBox(height: 22),
        SkeletonBox(height: 250, radius: 24),
      ],
    );
  }
}
