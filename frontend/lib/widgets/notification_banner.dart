import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../core/theme/app_theme.dart';
import '../models/models.dart';
import '../providers/providers.dart';

/// Tracks which notification IDs the user has dismissed in the current session.
final dismissedNotificationsProvider =
    StateProvider<Set<String>>((ref) => <String>{});

/// Auto-surfacing precipitation notice. Appears at the top of the dashboard
/// when there's a significant snow/rain event in the next 3 days. Dismissible
/// (per session) and only shows when the upcoming event clears the threshold.
class PrecipitationNotificationBanner extends ConsumerWidget {
  const PrecipitationNotificationBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final weatherAsync = ref.watch(weatherProvider);
    final dismissed = ref.watch(dismissedNotificationsProvider);

    return weatherAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (forecast) {
        final notice = _findNotice(forecast);
        if (notice == null) return const SizedBox.shrink();
        if (dismissed.contains(notice.id)) return const SizedBox.shrink();

        return _Banner(
          notice: notice,
          onDismiss: () =>
              ref.read(dismissedNotificationsProvider.notifier).state =
                  {...dismissed, notice.id},
        );
      },
    );
  }

  _Notice? _findNotice(WeatherForecast f) {
    if (f.days.isEmpty) return null;
    // Anchor to dataset-time, not the system clock.
    final today = DateTime(f.today.year, f.today.month, f.today.day);

    for (final d in f.days) {
      final daysAhead = d.date.difference(today).inDays;
      if (daysAhead < 0 || daysAhead > 3) continue; // only flag near-term events

      // Significant event thresholds.
      if (d.snowfallInches >= 1.5) {
        final id = 'snow-${d.date.toIso8601String()}';
        return _Notice(
          id: id,
          icon: Icons.ac_unit_rounded,
          color: const Color(0xFF67B4D8),
          eyebrow: 'PRECIPITATION NOTICE',
          title: d.snowfallInches >= 4
              ? 'Heavy snow incoming'
              : 'Snow event ahead',
          detail: _whenLabel(daysAhead, d.date) +
              ' · ~${d.snowfallInches.toStringAsFixed(0)}" snow expected at the Sierra crest.',
        );
      }
      if (d.precipInches >= 0.6) {
        final id = 'rain-${d.date.toIso8601String()}';
        return _Notice(
          id: id,
          icon: Icons.water_drop_rounded,
          color: AppColors.primary,
          eyebrow: 'PRECIPITATION NOTICE',
          title: d.precipInches >= 1.5
              ? 'Heavy rain incoming'
              : 'Rain event ahead',
          detail: _whenLabel(daysAhead, d.date) +
              ' · ${d.precipInches.toStringAsFixed(1)}" precipitation expected.',
        );
      }
    }
    return null;
  }

  String _whenLabel(int daysAhead, DateTime date) {
    if (daysAhead == 0) return 'Today';
    if (daysAhead == 1) return 'Tomorrow';
    return DateFormat('EEEE').format(date);
  }
}

class _Notice {
  final String id;
  final IconData icon;
  final Color color;
  final String eyebrow;
  final String title;
  final String detail;
  const _Notice({
    required this.id,
    required this.icon,
    required this.color,
    required this.eyebrow,
    required this.title,
    required this.detail,
  });
}

class _Banner extends StatelessWidget {
  final _Notice notice;
  final VoidCallback onDismiss;
  const _Banner({required this.notice, required this.onDismiss});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(
          AppSpace.md + 2, AppSpace.md, AppSpace.sm, AppSpace.md),
      decoration: BoxDecoration(
        color: notice.color.withOpacity(0.06),
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: notice.color.withOpacity(0.22)),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: notice.color.withOpacity(0.14),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(notice.icon, color: notice.color, size: 16),
          ),
          const SizedBox(width: AppSpace.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  notice.eyebrow,
                  style: TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.6,
                    color: notice.color,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  notice.title,
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.1,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  notice.detail,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: onDismiss,
            iconSize: 16,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            icon: const Icon(Icons.close_rounded,
                color: AppColors.textTertiary),
            splashRadius: 18,
          ),
        ],
      ),
    );
  }
}
