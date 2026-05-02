import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../core/theme/app_theme.dart';
import '../models/models.dart';
import '../providers/providers.dart';

const Color _snowAccent = Color(0xFF7DD3FC);

/// 90-day outlook — leads with the next significant precipitation event from
/// the live 7-day forecast, then drought/flood risk classification, then a
/// small footer noting the closest historical analog. Pattern matching against
/// the 10-year record, not statistical forecasting.
class ForecastCard extends ConsumerWidget {
  const ForecastCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(predictiveOutlookProvider);
    return async.when(
      loading: () => const _Skeleton(),
      error: (e, _) => _ErrorBox(
          error: e, onRetry: () => ref.invalidate(predictiveOutlookProvider)),
      data: (outlook) => _Card(outlook: outlook),
    );
  }
}

class _Card extends StatelessWidget {
  final PredictiveOutlook outlook;
  const _Card({required this.outlook});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: cardBorder,
        boxShadow: cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: const Icon(Icons.insights_rounded,
                    color: AppColors.primary, size: 16),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  '90-day outlook',
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.1),
                ),
              ),
              const Text(
                'PATTERN MATCH',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.4,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _NextEventPanel(event: outlook.nextEvent),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                  child: _RiskTile(
                      label: 'Drought risk', risk: outlook.droughtRisk)),
              const SizedBox(width: 10),
              Expanded(
                  child:
                      _RiskTile(label: 'Flood risk', risk: outlook.floodRisk)),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            decoration: BoxDecoration(
              color: AppColors.surfaceAlt,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.10),
                    borderRadius: BorderRadius.circular(7),
                  ),
                  child: const Icon(Icons.short_text_rounded,
                      color: AppColors.primary, size: 12),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    outlook.aiNarrative,
                    style: const TextStyle(
                        fontSize: 12.5,
                        height: 1.5,
                        letterSpacing: -0.05),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          _AnalogFooter(analog: outlook.analog),
        ],
      ),
    );
  }
}

class _NextEventPanel extends StatelessWidget {
  final NextEvent event;
  const _NextEventPanel({required this.event});

  static (IconData, Color) _styleFor(EventType t) => switch (t) {
        EventType.snow => (Icons.ac_unit_rounded, _snowAccent),
        EventType.rain => (Icons.water_drop_rounded, AppColors.primary),
        EventType.mixed =>
          (Icons.thunderstorm_rounded, AppColors.warning),
        EventType.none => (Icons.wb_sunny_outlined, AppColors.textSecondary),
      };

  @override
  Widget build(BuildContext context) {
    final (icon, color) = _styleFor(event.type);
    final hasEvent = event.type != EventType.none && event.date != null;
    final whenLabel = !hasEvent
        ? 'Next 7 days'
        : event.daysAway == 0
            ? 'TODAY · ${DateFormat('MMM d').format(event.date!).toUpperCase()}'
            : event.daysAway == 1
                ? 'TOMORROW · ${DateFormat('MMM d').format(event.date!).toUpperCase()}'
                : DateFormat('EEE · MMM d').format(event.date!).toUpperCase();

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      decoration: BoxDecoration(
        color: color.withOpacity(0.07),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.22)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text(
                      'NEXT EVENT',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.4,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      whenLabel,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.8,
                        color: color,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  event.label,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  event.summary,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RiskTile extends StatelessWidget {
  final String label;
  final HazardRisk risk;
  const _RiskTile({required this.label, required this.risk});

  static (Color, String) _styleFor(RiskLevel level) => switch (level) {
        RiskLevel.low => (AppColors.success, 'LOW'),
        RiskLevel.moderate => (AppColors.primary, 'MODERATE'),
        RiskLevel.elevated => (AppColors.warning, 'ELEVATED'),
        RiskLevel.high => (AppColors.danger, 'HIGH'),
      };

  @override
  Widget build(BuildContext context) {
    final (color, levelLabel) = _styleFor(risk.level);
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  label.toUpperCase(),
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2,
                    color: AppColors.textSecondary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                '${risk.score}',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 8),
              Text(
                levelLabel,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: color,
                  letterSpacing: 0.4,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              value: (risk.score / 100).clamp(0.0, 1.0),
              minHeight: 4,
              backgroundColor: AppColors.divider,
              valueColor: AlwaysStoppedAnimation(color),
            ),
          ),
          const SizedBox(height: 8),
          if (risk.reasoning.isNotEmpty)
            Text(
              risk.reasoning.first,
              style: const TextStyle(
                fontSize: 11,
                color: AppColors.textSecondary,
                height: 1.45,
              ),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
        ],
      ),
    );
  }
}

class _AnalogFooter extends StatelessWidget {
  final AnalogMatch analog;
  const _AnalogFooter({required this.analog});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        children: [
          const Icon(Icons.history_rounded,
              size: 12, color: AppColors.textSecondary),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              'Closest historical analog: ${analog.label} '
              '(${analog.yearLabel.toLowerCase()} year, '
              '${(analog.similarity * 100).toStringAsFixed(0)}% match).',
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 11,
                height: 1.4,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class _Skeleton extends StatelessWidget {
  const _Skeleton();
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 240,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: cardBorder,
        boxShadow: cardShadow,
      ),
      child: const Center(
        child: SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
    );
  }
}

class _ErrorBox extends StatelessWidget {
  final Object error;
  final VoidCallback onRetry;
  const _ErrorBox({required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: cardBorder,
        boxShadow: cardShadow,
      ),
      child: Row(
        children: [
          const Icon(Icons.cloud_off_rounded,
              color: AppColors.textSecondary, size: 18),
          const SizedBox(width: 10),
          const Expanded(
            child: Text("Couldn't load outlook",
                style: TextStyle(fontSize: 13)),
          ),
          TextButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}
