import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';

/// Editorial "Why this matters" explainer surfaced on metric tap. Two short
/// paragraphs grounded in real California water-supply mechanics — addresses
/// the public-education gap the brief and the expert both flagged.
class MetricExplainer {
  static const Map<String, _Explainer> _byMetric = {
    'snowpack': _Explainer(
      title: 'Snowpack',
      tagline: "California's slow-release water bank.",
      body: [
        'Sierra Nevada snow accumulates through winter and melts gradually through spring, '
            "feeding rivers and reservoirs through the dry months. The April 1 reading is the "
            "benchmark — that's when snow is at peak depth before melt season begins.",
        'Reading well below 70% means rivers run lower through summer and reservoirs refill '
            "less. That's why even a wet December can't fully save a water year if precipitation "
            'falls as rain instead of snow.',
      ],
    ),
    'precip': _Explainer(
      title: 'Precipitation',
      tagline: 'Rain plus snow, measured against the 30-year normal.',
      body: [
        "Total precipitation captures both rain and snow falling across California, indexed "
            'against a 30-year average. Above 110% is wet, below 70% is the formal drought signal.',
        'A wet stretch helps, but rain runs off in days. Snow stretches the same water across '
            'months. When precipitation is high but snowpack stays low, the water arrived as rain '
            'and left fast — the brief\'s headline insight in one number.',
      ],
    ),
    'reservoir': _Explainer(
      title: 'Reservoir storage',
      tagline: "Today's water on hand.",
      body: [
        "California's major reservoirs (Shasta, Oroville, San Luis, and others) hold the water "
            'already collected. The percentage shown is current storage as a fraction of total '
            'capacity.',
        "Healthy reservoirs are a buffer against bad snow years. But too-full reservoirs are also "
            "a problem — when a major storm hits, dam managers must release water, which stresses "
            'downstream infrastructure and can affect short-term water quality.',
      ],
    ),
  };

  static void show(BuildContext context, String metric) {
    final e = _byMetric[metric];
    if (e == null) return;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withOpacity(0.40),
      isScrollControlled: true,
      builder: (_) => _Sheet(explainer: e),
    );
  }
}

class _Explainer {
  final String title;
  final String tagline;
  final List<String> body;
  const _Explainer({
    required this.title,
    required this.tagline,
    required this.body,
  });
}

class _Sheet extends StatelessWidget {
  final _Explainer explainer;
  const _Sheet({required this.explainer});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
              AppSpace.xxl, AppSpace.lg, AppSpace.xxl, AppSpace.xxl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: AppSpace.lg),
              const Text(
                'WHY THIS MATTERS',
                style: TextStyle(
                  fontSize: 10,
                  letterSpacing: 1.6,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textTertiary,
                ),
              ),
              const SizedBox(height: AppSpace.sm),
              Text(
                explainer.title,
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.6,
                  height: 1.1,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                explainer.tagline,
                style: const TextStyle(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: AppSpace.xl),
              for (final p in explainer.body) ...[
                Text(
                  p,
                  style: const TextStyle(
                    fontSize: 14,
                    height: 1.65,
                    color: AppColors.textPrimary,
                    letterSpacing: -0.05,
                  ),
                ),
                const SizedBox(height: AppSpace.md),
              ],
              const SizedBox(height: AppSpace.sm),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Got it'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
