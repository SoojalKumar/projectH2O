import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import '../models/models.dart';

/// Line chart for one of the three signals over time, with horizontal
/// reference bands so the viewer can read severity at a glance.
class MetricsLineChart extends StatelessWidget {
  final String metric;       // 'snowpack' | 'precip' | 'reservoir'
  final List<MetricReading> readings;
  final Color lineColor;

  const MetricsLineChart({
    super.key,
    required this.metric,
    required this.readings,
    required this.lineColor,
  });

  // Brief's threshold values per metric.
  static const _bands = <String, List<double>>{
    'snowpack':  [70, 90, 120], // concern | watch | neutral | good
    'precip':    [70, 90, 110],
    'reservoir': [50, 70, 85],
  };

  @override
  Widget build(BuildContext context) {
    if (readings.isEmpty) {
      return const SizedBox(
        height: 180,
        child: Center(child: Text('No data.')),
      );
    }

    final spots = <FlSpot>[
      for (var i = 0; i < readings.length; i++)
        FlSpot(i.toDouble(), readings[i].valueFor(metric)),
    ];

    final values = readings.map((r) => r.valueFor(metric)).toList();
    final maxY = (values.reduce((a, b) => a > b ? a : b) * 1.15).clamp(60, 200).toDouble();
    final minY = (values.reduce((a, b) => a < b ? a : b) * 0.85).clamp(0, 50).toDouble();

    final bands = _bands[metric] ?? const [70, 90, 110];

    return SizedBox(
      height: 200,
      child: LineChart(
        LineChartData(
          minY: minY,
          maxY: maxY,
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            getDrawingHorizontalLine: (_) =>
                const FlLine(color: AppColors.divider, strokeWidth: 1),
          ),
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 36,
                interval: 30,
                getTitlesWidget: (v, _) => Padding(
                  padding: const EdgeInsets.only(right: 4),
                  child: Text('${v.toInt()}',
                      style: const TextStyle(
                          fontSize: 10, color: AppColors.textSecondary)),
                ),
              ),
            ),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 22,
                interval: (readings.length / 5).ceilToDouble().clamp(1, 24),
                getTitlesWidget: (v, _) {
                  final i = v.toInt();
                  if (i < 0 || i >= readings.length) return const SizedBox.shrink();
                  final d = readings[i].date;
                  return Text(
                    '${d.month}/${d.year % 100}',
                    style: const TextStyle(fontSize: 10, color: AppColors.textSecondary),
                  );
                },
              ),
            ),
          ),
          borderData: FlBorderData(show: false),
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              curveSmoothness: 0.25,
              color: lineColor,
              barWidth: 3,
              dotData: FlDotData(
                show: true,
                checkToShowDot: (s, _) => s.x == spots.length - 1,
                getDotPainter: (s, _, __, ___) => FlDotCirclePainter(
                  radius: 5,
                  color: lineColor,
                  strokeWidth: 3,
                  strokeColor: Colors.white,
                ),
              ),
              belowBarData: BarAreaData(
                show: true,
                gradient: LinearGradient(
                  colors: [lineColor.withOpacity(0.22), lineColor.withOpacity(0)],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
          ],
          extraLinesData: ExtraLinesData(
            horizontalLines: [
              for (final b in bands)
                HorizontalLine(
                  y: b.toDouble(),
                  color: AppColors.divider,
                  strokeWidth: 1,
                  dashArray: [4, 4],
                  label: HorizontalLineLabel(
                    show: true,
                    alignment: Alignment.centerRight,
                    style: const TextStyle(
                        color: AppColors.textSecondary, fontSize: 9),
                    labelResolver: (_) => '${b.toInt()}%',
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
