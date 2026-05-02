import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../providers/providers.dart';
import '../../widgets/section_card.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _refreshing = false;

  Future<void> _refreshDataset() async {
    setState(() => _refreshing = true);
    try {
      await ref.read(apiServiceProvider).refreshDataset();
      ref.invalidate(dashboardProvider);
      ref.invalidate(historyProvider);
      ref.invalidate(alertsProvider);
      ref.invalidate(historicalComparisonProvider);
      ref.invalidate(reportProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Dataset reloaded')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Refresh failed: $e')),
      );
    } finally {
      if (mounted) setState(() => _refreshing = false);
    }
  }

  Future<void> _resetIntro() async {
    await ref.read(settingsRepositoryProvider).reset();
    ref.invalidate(bootstrapProvider);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Intro will play on next launch')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('About Hydra')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          SectionCard(
            icon: Icons.info_rounded,
            title: 'What this app does',
            child: const Text(
              'Hydra classifies California snowpack, precipitation, and reservoir storage '
              'against the official thresholds, then combines them into one forward-looking outlook. '
              'Multi-signal alerts flag patterns no single metric reveals.',
              style: TextStyle(fontSize: 13, height: 1.5),
            ),
          ),
          const SizedBox(height: 14),
          SectionCard(
            icon: Icons.dataset_rounded,
            title: 'Data source',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'H2O Hackathon Challenge dataset · 120 monthly readings, 2016–2025.\n'
                  'Modeled on California DWR (Snow Surveys, CDEC) and NOAA climate normals.',
                  style: TextStyle(fontSize: 12, height: 1.5, color: AppColors.textSecondary),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: _refreshing ? null : _refreshDataset,
                  icon: _refreshing
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.refresh_rounded),
                  label: const Text('Reload dataset'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    side: const BorderSide(color: AppColors.divider),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          SectionCard(
            icon: Icons.menu_book_rounded,
            title: 'Threshold reference',
            child: const _Thresholds(),
          ),
          const SizedBox(height: 14),
          TextButton.icon(
            onPressed: _resetIntro,
            icon: const Icon(Icons.restart_alt_rounded, size: 16),
            label: const Text('Replay the intro on next launch'),
            style: TextButton.styleFrom(foregroundColor: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _Thresholds extends StatelessWidget {
  const _Thresholds();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _block('Snowpack (% of April 1 avg)', const [
          ('120%+', 'Excellent', AppColors.success),
          ('90–110', 'Average', AppColors.primary),
          ('70–90', 'Below average', AppColors.warning),
          ('<70', 'Concerning', AppColors.danger),
        ]),
        const SizedBox(height: 12),
        _block('Precipitation (% of avg)', const [
          ('110%+', 'Wet', AppColors.success),
          ('90–110', 'Normal', AppColors.primary),
          ('70–90', 'Dry', AppColors.warning),
          ('<70', 'Drought signal', AppColors.danger),
        ]),
        const SizedBox(height: 12),
        _block('Reservoir (% capacity)', const [
          ('85–100', 'Strong', AppColors.success),
          ('70–85', 'Healthy', AppColors.primary),
          ('50–70', 'Watch', AppColors.warning),
          ('<50', 'Concern', AppColors.danger),
        ]),
      ],
    );
  }

  Widget _block(String title, List<(String, String, Color)> rows) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title,
            style:
                const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
        const SizedBox(height: 6),
        for (final (range, label, color) in rows)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Row(
              children: [
                Container(
                  width: 56,
                  child: Text(range,
                      style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary)),
                ),
                StatusPill(label: label, color: color),
              ],
            ),
          ),
      ],
    );
  }
}
