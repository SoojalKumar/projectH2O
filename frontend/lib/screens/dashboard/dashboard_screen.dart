import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_theme.dart';
import '../../models/models.dart';
import '../../providers/providers.dart';
import '../../widgets/animated_value.dart';
import '../../widgets/explainer_modal.dart';
import '../../widgets/notification_banner.dart';
import '../../widgets/planning_card.dart';
import '../../widgets/share_card.dart';
import '../../widgets/skeleton.dart';
import '../alerts/alerts_screen.dart';
import '../coming_up/coming_up_screen.dart';
import '../historical/historical_screen.dart';
import '../settings/settings_screen.dart';
import '../trends/trends_screen.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(dashboardProvider);

    return SafeArea(
      bottom: false,
      child: async.when(
        loading: () => const DashboardSkeleton(),
        error: (e, _) => _ErrorView(
            error: e, onRetry: () => ref.invalidate(dashboardProvider)),
        data: (d) {
          void goTab(int i) =>
              ref.read(selectedTabProvider.notifier).state = i;
          void push(Widget page) =>
              Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(dashboardProvider),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 96),
              children: [
                _Header(
                  asOf: d.asOf,
                  onShare: () => showSharePane(context, d),
                  onAbout: () => push(const SettingsScreen()),
                ),
                const SizedBox(height: 14),
                const PrecipitationNotificationBanner(),
                const SizedBox(height: 24),
                _OutlookHero(d: d),
                const SizedBox(height: 28),
                _MetricsStrip(d: d),
                const SizedBox(height: 32),
                _Divider(),
                const SizedBox(height: 24),
                const PlanningCard(),
                const SizedBox(height: 28),
                if (d.alerts.isNotEmpty) ...[
                  _SectionHeader(
                    label: 'Active patterns',
                    count: d.alerts.length,
                    onTap: () => push(const AlertsScreen()),
                  ),
                  const SizedBox(height: 12),
                  _AlertsList(
                    alerts: d.alerts,
                    onTap: () => push(const AlertsScreen()),
                  ),
                  const SizedBox(height: 28),
                ],
                _SectionHeader(label: 'What this means'),
                const SizedBox(height: 12),
                _SummaryBlock(text: d.aiSummary),
                const SizedBox(height: 28),
                _SectionHeader(label: 'Read more'),
                const SizedBox(height: 8),
                _LinkRow(
                  title: 'Coming up',
                  subtitle: 'Storm watch · 90-day outlook',
                  onTap: () => push(const ComingUpScreen()),
                ),
                _LinkRow(
                  title: '10-year trends',
                  subtitle: 'Three signals over time',
                  onTap: () => push(const TrendsScreen()),
                ),
                _LinkRow(
                  title: 'Year-by-year history',
                  subtitle: 'Strongest · weakest · current',
                  onTap: () => push(const HistoricalScreen()),
                ),
                _LinkRow(
                  title: 'Outlook report',
                  subtitle: 'Improved · worsened · still risky',
                  onTap: () => goTab(1),
                ),
                _LinkRow(
                  title: 'About Hydra',
                  subtitle: 'Data sources & thresholds',
                  onTap: () => push(const SettingsScreen()),
                  isLast: true,
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
// Header
// ─────────────────────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  final DateTime asOf;
  final VoidCallback onShare;
  final VoidCallback onAbout;
  const _Header(
      {required this.asOf, required this.onShare, required this.onAbout});

  @override
  Widget build(BuildContext context) {
    final dateLabel = DateFormat.yMMMM().format(asOf).toUpperCase();
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'HYDRA',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.8,
                    color: AppColors.textTertiary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  dateLabel,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.1,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
          _IconBtn(icon: Icons.ios_share_rounded, onTap: onShare),
          _IconBtn(icon: Icons.info_outline_rounded, onTap: onAbout),
        ],
      ),
    );
  }
}

class _IconBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _IconBtn({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Icon(icon, color: AppColors.textSecondary, size: 18),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
// Outlook hero — pure typography, no gradient block
// ─────────────────────────────────────────────────────────────────────────

class _OutlookHero extends StatelessWidget {
  final SupplyDashboard d;
  const _OutlookHero({required this.d});

  Color _severityColor(Severity s) => switch (s) {
        Severity.good => AppColors.success,
        Severity.neutral => AppColors.primary,
        Severity.watch => AppColors.warning,
        Severity.concern => AppColors.danger,
      };

  @override
  Widget build(BuildContext context) {
    final color = _severityColor(d.outlook.severity);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 8),
            Text(
              'COMBINED OUTLOOK',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.8,
                color: color,
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Text(
          d.outlook.label,
          style: const TextStyle(
            fontSize: 64,
            fontWeight: FontWeight.w700,
            letterSpacing: -2.2,
            height: 1.0,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 14),
        Text(
          d.outlook.rationale,
          style: const TextStyle(
            fontSize: 16,
            height: 1.5,
            color: AppColors.textSecondary,
            letterSpacing: -0.2,
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
// Metrics strip — three columns under the hero, tap to learn what each means
// ─────────────────────────────────────────────────────────────────────────

class _MetricsStrip extends StatelessWidget {
  final SupplyDashboard d;
  const _MetricsStrip({required this.d});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: _MetricColumn(
            metric: 'snowpack',
            label: 'Snowpack',
            sub: '% of Apr 1',
            band: d.snowpack,
            color: AppColors.chartSnow,
          ),
        ),
        Container(width: 1, height: 64, color: AppColors.border),
        Expanded(
          child: _MetricColumn(
            metric: 'precip',
            label: 'Precipitation',
            sub: '% of avg',
            band: d.precip,
            color: AppColors.chartPrecip,
          ),
        ),
        Container(width: 1, height: 64, color: AppColors.border),
        Expanded(
          child: _MetricColumn(
            metric: 'reservoir',
            label: 'Reservoir',
            sub: '% capacity',
            band: d.reservoir,
            color: AppColors.chartReservoir,
          ),
        ),
      ],
    );
  }
}

class _MetricColumn extends StatelessWidget {
  final String metric;
  final String label;
  final String sub;
  final MetricBand band;
  final Color color;

  const _MetricColumn({
    required this.metric,
    required this.label,
    required this.sub,
    required this.band,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => MetricExplainer.show(context, metric),
      borderRadius: BorderRadius.circular(8),
      splashFactory: NoSplash.splashFactory,
      highlightColor: Colors.transparent,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration:
                      BoxDecoration(color: color, shape: BoxShape.circle),
                ),
                const SizedBox(width: 5),
                Expanded(
                  child: Text(
                    label.toUpperCase(),
                    style: const TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.4,
                      color: AppColors.textTertiary,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                AnimatedValue(
                  value: band.value,
                  style: const TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w700,
                    height: 1.0,
                    letterSpacing: -1.4,
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.only(bottom: 5, left: 1),
                  child: Text(
                    '%',
                    style: TextStyle(
                        color: AppColors.textTertiary,
                        fontSize: 11,
                        fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              band.label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.4,
                color: color,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
// Section heading + summary block + dividers
// ─────────────────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String label;
  final int? count;
  final VoidCallback? onTap;
  const _SectionHeader({required this.label, this.count, this.onTap});

  @override
  Widget build(BuildContext context) {
    final row = Row(
      children: [
        Text(
          label.toUpperCase(),
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.6,
            color: AppColors.textTertiary,
          ),
        ),
        if (count != null) ...[
          const SizedBox(width: 6),
          Text(
            '$count',
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
              color: AppColors.textTertiary,
            ),
          ),
        ],
        const Spacer(),
        if (onTap != null)
          const Icon(Icons.chevron_right_rounded,
              size: 16, color: AppColors.textTertiary),
      ],
    );
    if (onTap == null) return row;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        splashFactory: NoSplash.splashFactory,
        highlightColor: Colors.transparent,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: row,
        ),
      ),
    );
  }
}

class _SummaryBlock extends StatelessWidget {
  final String text;
  const _SummaryBlock({required this.text});

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 14.5,
        height: 1.65,
        color: AppColors.textPrimary,
        letterSpacing: -0.05,
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) =>
      Container(height: 1, color: AppColors.border);
}

// ─────────────────────────────────────────────────────────────────────────
// Alerts list — text-first, no card chrome
// ─────────────────────────────────────────────────────────────────────────

class _AlertsList extends StatelessWidget {
  final List<MultiSignalAlert> alerts;
  final VoidCallback onTap;
  const _AlertsList({required this.alerts, required this.onTap});

  Color _color(Severity s) => switch (s) {
        Severity.good => AppColors.success,
        Severity.neutral => AppColors.primary,
        Severity.watch => AppColors.warning,
        Severity.concern => AppColors.danger,
      };

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.card),
        splashFactory: NoSplash.splashFactory,
        highlightColor: Colors.transparent,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var i = 0; i < alerts.length; i++) ...[
              _AlertRow(alert: alerts[i], color: _color(alerts[i].severity)),
              if (i < alerts.length - 1)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Container(
                      height: 1, color: AppColors.border),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _AlertRow extends StatelessWidget {
  final MultiSignalAlert alert;
  final Color color;
  const _AlertRow({required this.alert, required this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 6,
            height: 6,
            margin: const EdgeInsets.only(top: 7),
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  alert.title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.1,
                    color: AppColors.textPrimary,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  alert.description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12.5,
                    height: 1.5,
                    color: AppColors.textSecondary,
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

// ─────────────────────────────────────────────────────────────────────────
// Read-more link rows — clean list, hairline separators
// ─────────────────────────────────────────────────────────────────────────

class _LinkRow extends StatelessWidget {
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool isLast;

  const _LinkRow({
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        splashFactory: NoSplash.splashFactory,
        highlightColor: Colors.transparent,
        child: Container(
          decoration: BoxDecoration(
            border: Border(
              bottom: isLast
                  ? BorderSide.none
                  : const BorderSide(color: AppColors.border),
            ),
          ),
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        letterSpacing: -0.1,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textTertiary,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_rounded,
                  size: 16, color: AppColors.textTertiary),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────

class _ErrorView extends StatelessWidget {
  final Object error;
  final VoidCallback onRetry;
  const _ErrorView({required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.cloud_off_rounded,
              size: 32, color: AppColors.textTertiary),
          const SizedBox(height: 12),
          const Text("Couldn't reach the Hydra backend.",
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          Text(
            'Make sure the FastAPI server is running.\n\n$error',
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.textTertiary, fontSize: 12),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}
