import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../models/models.dart';
import '../../providers/providers.dart';
import '../../widgets/section_card.dart';

class HistoricalScreen extends ConsumerWidget {
  const HistoricalScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(historicalComparisonProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Historical comparison')),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(historicalComparisonProvider),
        child: async.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Padding(
              padding: const EdgeInsets.all(24),
              child: Text('Error: $e',
                  style: const TextStyle(color: AppColors.textSecondary))),
          data: (h) => ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
            children: [
              _HighlightStrip(h: h),
              const SizedBox(height: 18),
              SectionCard(
                icon: Icons.short_text_rounded,
                title: 'Decade in context',
                child: Text(h.aiSummary,
                    style: const TextStyle(fontSize: 14, height: 1.55)),
              ),
              const SizedBox(height: 24),
              const SectionLabel('Year by year'),
              const SizedBox(height: 12),
              for (final y in h.years.reversed) ...[
                _YearRow(year: y, isCurrent: y.year == h.currentYear),
                const SizedBox(height: 8),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _HighlightStrip extends StatelessWidget {
  final HistoricalComparison h;
  const _HighlightStrip({required this.h});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
            child: _HighlightTile(
                year: h.bestYear,
                label: 'Strongest',
                color: AppColors.success,
                icon: Icons.trending_up_rounded)),
        const SizedBox(width: 10),
        Expanded(
            child: _HighlightTile(
                year: h.worstYear,
                label: 'Weakest',
                color: AppColors.danger,
                icon: Icons.trending_down_rounded)),
        const SizedBox(width: 10),
        Expanded(
            child: _HighlightTile(
                year: h.currentYear,
                label: 'Current',
                color: AppColors.primary,
                icon: Icons.adjust_rounded)),
      ],
    );
  }
}

class _HighlightTile extends StatelessWidget {
  final int year;
  final String label;
  final Color color;
  final IconData icon;
  const _HighlightTile(
      {required this.year, required this.label, required this.color, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 16, 14, 16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: cardBorder,
        boxShadow: cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: color.withOpacity(0.10),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 16),
          ),
          const SizedBox(height: 12),
          Text('$year',
              style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w700,
                  height: 1.0,
                  letterSpacing: -0.6)),
          const SizedBox(height: 4),
          Text(label.toUpperCase(),
              style: TextStyle(
                  fontSize: 10,
                  letterSpacing: 1.4,
                  fontWeight: FontWeight.w600,
                  color: color)),
        ],
      ),
    );
  }
}

class _YearRow extends StatelessWidget {
  final HistoricalYear year;
  final bool isCurrent;
  const _YearRow({required this.year, required this.isCurrent});

  @override
  Widget build(BuildContext context) {
    final color = colorForSeverity(year.severity);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: isCurrent
            ? Border.all(color: AppColors.primary.withOpacity(0.55), width: 1.5)
            : cardBorder,
        boxShadow: cardShadow,
      ),
      child: Row(
        children: [
          SizedBox(
            width: 56,
            child: Text('${year.year}',
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
          ),
          Expanded(
            child: Row(
              children: [
                _miniStat('❄', year.avgSnowpack),
                const SizedBox(width: 14),
                _miniStat('💧', year.avgPrecip),
                const SizedBox(width: 14),
                _miniStat('🏞', year.avgReservoir),
              ],
            ),
          ),
          StatusPill(label: year.label.toUpperCase(), color: color),
        ],
      ),
    );
  }

  Widget _miniStat(String emoji, double v) {
    return Row(
      children: [
        Text(emoji, style: const TextStyle(fontSize: 12)),
        const SizedBox(width: 4),
        Text('${v.toStringAsFixed(0)}%',
            style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary)),
      ],
    );
  }
}
