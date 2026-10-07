import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../data/models/repo_filters_model.dart';

/// Line chart of the repo's star count per day (last 30 days).
class StarHistoryChart extends StatelessWidget {
  final List<StarPointModel> points;

  const StarHistoryChart({super.key, required this.points});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final muted = isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted;

    if (points.length < 2) {
      return SizedBox(
        height: 120,
        child: Center(
          child: Text(
            'Chưa đủ dữ liệu lịch sử sao.\nHệ thống ghi lại số sao mỗi ngày.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12.5, color: muted),
          ),
        ),
      );
    }

    final first = points.first.date;
    final spots = points
        .map((p) => FlSpot(p.date.difference(first).inDays.toDouble(), p.stars.toDouble()))
        .toList();
    final minY = points.map((p) => p.stars).reduce((a, b) => a < b ? a : b).toDouble();
    final maxY = points.map((p) => p.stars).reduce((a, b) => a > b ? a : b).toDouble();
    final padding = ((maxY - minY) * 0.15).clamp(1, double.infinity).toDouble();
    final gained = points.last.stars - points.first.stars;
    final compact = NumberFormat.compact(locale: 'en');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${gained >= 0 ? '+' : ''}${NumberFormat.decimalPattern('vi').format(gained)} sao trong ${points.length} ngày',
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
            color: gained >= 0 ? AppColors.success : AppColors.error,
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 170,
          child: LineChart(
            LineChartData(
              minY: minY - padding,
              maxY: maxY + padding,
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                getDrawingHorizontalLine: (_) => FlLine(color: muted.withAlpha(40), strokeWidth: 1),
              ),
              borderData: FlBorderData(show: false),
              titlesData: FlTitlesData(
                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 42,
                    getTitlesWidget: (value, meta) => Text(
                      compact.format(value),
                      style: TextStyle(fontSize: 10, color: muted),
                    ),
                  ),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 24,
                    interval: (spots.last.x / 4).clamp(1, double.infinity).toDouble(),
                    getTitlesWidget: (value, meta) => Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        DateFormat('dd/MM').format(first.add(Duration(days: value.round()))),
                        style: TextStyle(fontSize: 10, color: muted),
                      ),
                    ),
                  ),
                ),
              ),
              lineTouchData: LineTouchData(
                touchTooltipData: LineTouchTooltipData(
                  getTooltipItems: (touched) => touched
                      .map((spot) => LineTooltipItem(
                            '${DateFormat('dd/MM').format(first.add(Duration(days: spot.x.round())))}\n'
                            '${NumberFormat.decimalPattern('vi').format(spot.y.round())} ⭐',
                            const TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.w600),
                          ))
                      .toList(),
                ),
              ),
              lineBarsData: [
                LineChartBarData(
                  spots: spots,
                  isCurved: true,
                  preventCurveOverShooting: true,
                  color: AppColors.warning,
                  barWidth: 2.6,
                  dotData: const FlDotData(show: false),
                  belowBarData: BarAreaData(
                    show: true,
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [AppColors.warning.withAlpha(90), AppColors.warning.withAlpha(0)],
                    ),
                  ),
                ),
              ],
            ),
            duration: const Duration(milliseconds: 400),
          ),
        ),
      ],
    );
  }
}
