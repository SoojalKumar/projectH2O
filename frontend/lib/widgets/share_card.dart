import 'dart:html' as html;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../core/theme/app_theme.dart';
import '../models/models.dart';
import '../providers/providers.dart';

/// Editorial 1080x1350 share card. Renders a clean infographic of the
/// current outlook + three metrics + headline alert and downloads it as a
/// PNG. Built specifically as a layout, not by snapshotting the dashboard,
/// so it reads as a finished publication asset.
class SharePane extends ConsumerStatefulWidget {
  final SupplyDashboard dashboard;
  const SharePane({super.key, required this.dashboard});

  @override
  ConsumerState<SharePane> createState() => _SharePaneState();
}

class _SharePaneState extends ConsumerState<SharePane> {
  final GlobalKey _captureKey = GlobalKey();
  bool _exporting = false;

  Future<void> _download() async {
    setState(() => _exporting = true);
    try {
      // Slight delay so the post-press animation settles before capture.
      await Future.delayed(const Duration(milliseconds: 60));
      final boundary = _captureKey.currentContext!.findRenderObject()
          as RenderRepaintBoundary;
      // 3x for crisp social-media output.
      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return;

      final bytes = byteData.buffer.asUint8List();
      final blob = html.Blob([bytes], 'image/png');
      final url = html.Url.createObjectUrlFromBlob(blob);
      final fileName =
          'hydra-${DateFormat('yyyy-MM').format(widget.dashboard.asOf)}.png';
      html.AnchorElement(href: url)
        ..download = fileName
        ..click();
      html.Url.revokeObjectUrl(url);
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
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
                'SHARE',
                style: TextStyle(
                  fontSize: 10,
                  letterSpacing: 1.6,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textTertiary,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Take this with you',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.4,
                  height: 1.1,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'A clean snapshot of California\'s current outlook, ready to post or send.',
                style: TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: AppSpace.xl),
              Center(
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(AppRadius.card),
                    border: cardBorder,
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(AppRadius.card),
                    child: AspectRatio(
                      aspectRatio: 1080 / 1350,
                      child: FittedBox(
                        fit: BoxFit.contain,
                        // The composition lays out at its natural design
                        // size (1080×1350). FittedBox scales the preview
                        // down to whatever space the modal gives it; the
                        // RepaintBoundary still captures at full size, so
                        // the PNG export is sharp regardless of preview width.
                        child: SizedBox(
                          width: 1080,
                          height: 1350,
                          child: RepaintBoundary(
                            key: _captureKey,
                            child: _Composition(d: widget.dashboard),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: AppSpace.xl),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _exporting
                          ? null
                          : () => Navigator.of(context).pop(),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: const Text('Close'),
                    ),
                  ),
                  const SizedBox(width: AppSpace.md),
                  Expanded(
                    flex: 2,
                    child: FilledButton.icon(
                      onPressed: _exporting ? null : _download,
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      icon: _exporting
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.download_rounded, size: 18),
                      label: Text(_exporting ? 'Exporting…' : 'Download PNG'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The actual visual composition that gets rendered to PNG. Designed as a
/// 1080x1350 portrait card — clean editorial typography, restrained color,
/// readable at thumbnail size on a feed.
class _Composition extends StatelessWidget {
  final SupplyDashboard d;
  const _Composition({required this.d});

  Color _severityColor(Severity s) => switch (s) {
        Severity.good => AppColors.success,
        Severity.neutral => AppColors.primary,
        Severity.watch => AppColors.warning,
        Severity.concern => AppColors.danger,
      };

  @override
  Widget build(BuildContext context) {
    final severity = _severityColor(d.outlook.severity);
    final hasAlert = d.alerts.isNotEmpty;
    final dateLabel = DateFormat('MMMM yyyy').format(d.asOf).toUpperCase();
    return _renderEditorial(severity, hasAlert, dateLabel);
  }

  Widget _renderEditorial(Color severity, bool hasAlert, String dateLabel) {
    return Container(
      color: const Color(0xFFFBFBFC),
      padding: const EdgeInsets.fromLTRB(64, 56, 64, 56),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Masthead — left aligned, no logo, just brand wordmark.
          Text(
            'HYDRA',
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              letterSpacing: 4.0,
              color: Color(0xFF0E1A24),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'California water-supply briefing · $dateLabel',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: Color(0xFF7C8B97),
              letterSpacing: 0.2,
            ),
          ),
          const SizedBox(height: 26),
          Container(height: 1, color: const Color(0xFFE6EAEE)),
          const SizedBox(height: 56),

          // Outlook section
          Text(
            'OUTLOOK',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.8,
              color: severity,
            ),
          ),
          const SizedBox(height: 18),
          Text(
            d.outlook.label,
            style: const TextStyle(
              fontSize: 96,
              fontWeight: FontWeight.w700,
              letterSpacing: -3.6,
              height: 0.95,
              color: Color(0xFF0E1A24),
            ),
          ),
          const SizedBox(height: 22),
          Text(
            d.outlook.rationale,
            style: const TextStyle(
              fontSize: 19,
              height: 1.5,
              color: Color(0xFF40505C),
              letterSpacing: -0.2,
              fontWeight: FontWeight.w400,
            ),
          ),
          const SizedBox(height: 56),
          Container(height: 1, color: const Color(0xFFE6EAEE)),
          const SizedBox(height: 38),

          // Three signals — table-like, editorial.
          _SignalRow(
            label: 'Snowpack',
            sub: '% of April 1 average',
            band: d.snowpack,
            color: AppColors.chartSnow,
          ),
          const SizedBox(height: 18),
          Container(height: 1, color: const Color(0xFFEEF1F4)),
          const SizedBox(height: 18),
          _SignalRow(
            label: 'Precipitation',
            sub: '% of seasonal average',
            band: d.precip,
            color: AppColors.chartPrecip,
          ),
          const SizedBox(height: 18),
          Container(height: 1, color: const Color(0xFFEEF1F4)),
          const SizedBox(height: 18),
          _SignalRow(
            label: 'Reservoir storage',
            sub: '% of capacity',
            band: d.reservoir,
            color: AppColors.chartReservoir,
          ),

          const Spacer(),

          if (hasAlert) ...[
            Container(height: 1, color: const Color(0xFFE6EAEE)),
            const SizedBox(height: 28),
            Text(
              'ACTIVE PATTERN',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.8,
                color: severity,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              d.alerts.first.title,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w600,
                letterSpacing: -0.4,
                color: Color(0xFF0E1A24),
                height: 1.3,
              ),
            ),
            const SizedBox(height: 30),
          ] else
            const SizedBox(height: 30),

          Container(height: 1, color: const Color(0xFFE6EAEE)),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Three signals · one outlook',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF7C8B97),
                  letterSpacing: -0.05,
                  fontStyle: FontStyle.italic,
                ),
              ),
              Text(
                'H2O HACKATHON · 2025',
                style: const TextStyle(
                  fontSize: 9.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.6,
                  color: Color(0xFFA8B3BD),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

}

/// One signal row in the editorial composition. Inline label + big value
/// + band, separated by a hairline. Reads like a wire-service data table.
class _SignalRow extends StatelessWidget {
  final String label;
  final String sub;
  final MetricBand band;
  final Color color;

  const _SignalRow({
    required this.label,
    required this.sub,
    required this.band,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 6,
          height: 6,
          decoration:
              BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.2,
                  color: Color(0xFF0E1A24),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                sub,
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF8E9AA4),
                ),
              ),
            ],
          ),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  band.value.toStringAsFixed(0),
                  style: const TextStyle(
                    fontSize: 44,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -1.6,
                    height: 1.0,
                    color: Color(0xFF0E1A24),
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.only(bottom: 6, left: 2),
                  child: Text(
                    '%',
                    style: TextStyle(
                      fontSize: 14,
                      color: Color(0xFF8E9AA4),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 3),
            Text(
              band.label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.4,
                color: color,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// Public entry — opens the share pane as a modal sheet.
void showSharePane(BuildContext context, SupplyDashboard d) {
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withOpacity(0.40),
    isScrollControlled: true,
    builder: (_) => SharePane(dashboard: d),
  );
}
