import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../models/models.dart';
import '../providers/providers.dart';

/// Premium minimal lifeline chart — no glow effects, clean strokes,
/// borderless legend, dark matte canvas. Three signals overlaid on a single
/// shared y-axis so crossings tell the story.
///
/// - Animation runs once on mount; replays on bottom-nav return or drawer
///   pop-back. Tap the card to replay.
/// - Hover (web) or tap/drag (touch) anywhere to surface a crosshair tooltip
///   with the three values + month for that point.
class LifelineChart extends ConsumerStatefulWidget {
  final List<MetricReading> readings;
  final String title;
  final Duration sweepDuration;
  final double aspectRatio;

  const LifelineChart({
    super.key,
    required this.readings,
    this.title = 'California supply pulse',
    this.sweepDuration = const Duration(milliseconds: 4500),
    this.aspectRatio = 2.3,
  });

  @override
  ConsumerState<LifelineChart> createState() => _LifelineChartState();
}

class _LifelineChartState extends ConsumerState<LifelineChart>
    with SingleTickerProviderStateMixin, RouteAware {
  late final AnimationController _ctrl;
  int? _cursorIndex;

  late final List<List<double>> _series;
  late final double _minV;
  late final double _maxV;

  @override
  void initState() {
    super.initState();
    _series = [
      widget.readings.map((r) => r.snowpackPct).toList(),
      widget.readings.map((r) => r.precipPct).toList(),
      widget.readings.map((r) => r.reservoirPct).toList(),
    ];
    final all = <double>[for (final s in _series) ...s];
    var minV = all.reduce(math.min);
    var maxV = all.reduce(math.max);
    final span = math.max(maxV - minV, 1.0);
    final pad = span * 0.12;
    _minV = minV - pad;
    _maxV = maxV + pad;

    _ctrl = AnimationController(vsync: this, duration: widget.sweepDuration);
    _ctrl.forward();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route is ModalRoute<void>) {
      appRouteObserver.subscribe(this, route);
    }
  }

  @override
  void didPopNext() => _replay();

  @override
  void dispose() {
    appRouteObserver.unsubscribe(this);
    _ctrl.dispose();
    super.dispose();
  }

  void _replay() {
    _ctrl.stop();
    _ctrl.value = 0;
    _ctrl.forward();
    if (mounted) setState(() => _cursorIndex = null);
  }

  void _setCursorFrom(Offset localPos, Size size) {
    final n = _series.first.length;
    final dx = size.width / (n - 1);
    final idx = (localPos.dx / dx).round().clamp(0, n - 1);
    if (_cursorIndex != idx) setState(() => _cursorIndex = idx);
  }

  void _clearCursor() {
    if (_cursorIndex != null) setState(() => _cursorIndex = null);
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<int>(selectedTabProvider, (prev, next) {
      if (prev != null && prev != 0 && next == 0) _replay();
    });

    final readings = widget.readings;
    if (readings.length < 2) return const SizedBox.shrink();

    final n = readings.length;
    const colors = [_snowColor, _precipColor, _resColor];

    return GestureDetector(
      onTap: _replay,
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
        decoration: BoxDecoration(
          color: const Color(0xFF0A1620),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withOpacity(0.06)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _Header(title: widget.title, monthCount: n, ctrl: _ctrl),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: _LegendChip(
                    label: 'Snowpack',
                    sub: '% of Apr 1 avg',
                    value: _series[0].last,
                    color: _snowColor,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _LegendChip(
                    label: 'Precip',
                    sub: '% of avg',
                    value: _series[1].last,
                    color: _precipColor,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _LegendChip(
                    label: 'Reservoir',
                    sub: '% capacity',
                    value: _series[2].last,
                    color: _resColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            AspectRatio(
              aspectRatio: widget.aspectRatio,
              child: LayoutBuilder(builder: (_, constraints) {
                final size = constraints.biggest;
                return MouseRegion(
                  onHover: (e) => _setCursorFrom(e.localPosition, size),
                  onExit: (_) => _clearCursor(),
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTapDown: (d) => _setCursorFrom(d.localPosition, size),
                    onPanUpdate: (d) => _setCursorFrom(d.localPosition, size),
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        AnimatedBuilder(
                          animation: _ctrl,
                          builder: (_, __) => CustomPaint(
                            size: size,
                            painter: _LifelinePainter(
                              series: _series,
                              colors: colors,
                              minV: _minV,
                              maxV: _maxV,
                              progress: _ctrl.value,
                              cursorIndex: _cursorIndex,
                            ),
                          ),
                        ),
                        if (_cursorIndex != null)
                          _PositionedTooltip(
                            size: size,
                            n: n,
                            cursorIndex: _cursorIndex!,
                            reading: readings[_cursorIndex!],
                          ),
                      ],
                    ),
                  ),
                );
              }),
            ),
          ],
        ),
      ),
    );
  }
}

// Snowpack = ice blue, Precip = mint, Reservoir = amber.
const Color _snowColor = Color(0xFF7DD3FC);
const Color _precipColor = Color(0xFF4DD4B7);
const Color _resColor = Color(0xFFF5B544);
const Color _gridColor = Color(0x0DFFFFFF);

class _Header extends StatelessWidget {
  final String title;
  final int monthCount;
  final AnimationController ctrl;
  const _Header(
      {required this.title, required this.monthCount, required this.ctrl});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title.toUpperCase(),
            style: const TextStyle(
              color: Color(0xFFB6D2CB),
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.6,
            ),
          ),
        ),
        AnimatedBuilder(
          animation: ctrl,
          builder: (_, __) {
            final running = ctrl.value > 0 && ctrl.value < 1;
            return Text(
              running ? 'reading · $monthCount mo' : '$monthCount months',
              style: const TextStyle(
                color: Color(0xFF7E96A0),
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            );
          },
        ),
      ],
    );
  }
}

class _LegendChip extends StatelessWidget {
  final String label;
  final String sub;
  final double value;
  final Color color;

  const _LegendChip({
    required this.label,
    required this.sub,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 11, 12, 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.025),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label.toUpperCase(),
                  style: const TextStyle(
                    color: Color(0xFFC7D5DA),
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.1,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                value.toStringAsFixed(0),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.w600,
                  height: 1.0,
                  letterSpacing: -0.7,
                ),
              ),
              const SizedBox(width: 2),
              const Padding(
                padding: EdgeInsets.only(bottom: 3),
                child: Text('%',
                    style: TextStyle(
                        color: Color(0xFF7E96A0), fontSize: 11)),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            sub,
            style: const TextStyle(color: Color(0xFF6B8088), fontSize: 10),
          ),
        ],
      ),
    );
  }
}

class _PositionedTooltip extends StatelessWidget {
  final Size size;
  final int n;
  final int cursorIndex;
  final MetricReading reading;

  const _PositionedTooltip({
    required this.size,
    required this.n,
    required this.cursorIndex,
    required this.reading,
  });

  @override
  Widget build(BuildContext context) {
    const tooltipW = 188.0;
    final dx = size.width / (n - 1);
    final cursorX = cursorIndex * dx;

    var x = cursorX + 14;
    if (x + tooltipW > size.width) {
      x = cursorX - tooltipW - 14;
    }
    x = x.clamp(0.0, size.width - tooltipW);

    return Positioned(
      left: x,
      top: 6,
      child: SizedBox(
        width: tooltipW,
        child: _TooltipCard(reading: reading),
      ),
    );
  }
}

class _TooltipCard extends StatelessWidget {
  final MetricReading reading;
  const _TooltipCard({required this.reading});

  @override
  Widget build(BuildContext context) {
    final dateLabel = DateFormat.yMMM().format(reading.date);
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      decoration: BoxDecoration(
        color: const Color(0xF2050E16),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            dateLabel.toUpperCase(),
            style: const TextStyle(
              color: Color(0xFFC7D5DA),
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.4,
            ),
          ),
          const SizedBox(height: 8),
          _row(_snowColor, 'Snowpack', reading.snowpackPct),
          _row(_precipColor, 'Precip', reading.precipPct),
          _row(_resColor, 'Reservoir', reading.reservoirPct),
        ],
      ),
    );
  }

  Widget _row(Color color, String label, double value) {
    return Padding(
      padding: const EdgeInsets.only(top: 5),
      child: Row(
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(label,
                style: const TextStyle(
                    color: Color(0xFF8FA3AC), fontSize: 11)),
          ),
          Text(
            '${value.toStringAsFixed(0)}%',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _LifelinePainter extends CustomPainter {
  final List<List<double>> series;
  final List<Color> colors;
  final double minV;
  final double maxV;
  final double progress;
  final int? cursorIndex;

  _LifelinePainter({
    required this.series,
    required this.colors,
    required this.minV,
    required this.maxV,
    required this.progress,
    required this.cursorIndex,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (series.isEmpty || series.first.length < 2) return;

    _drawGrid(canvas, size);

    for (var i = 0; i < series.length; i++) {
      _drawSeries(canvas, size, series[i], colors[i]);
    }

    if (cursorIndex != null) _drawCrosshair(canvas, size);
  }

  void _drawSeries(Canvas canvas, Size size, List<double> values, Color color) {
    final n = values.length;
    if (n < 2) return;
    final dx = size.width / (n - 1);
    final yScale = size.height / (maxV - minV);

    final path = Path();
    for (var i = 0; i < n; i++) {
      final x = i * dx;
      final y = size.height - (values[i] - minV) * yScale;
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    // Dim baseline — full path, always visible.
    canvas.drawPath(
      path,
      Paint()
        ..color = color.withOpacity(0.18)
        ..strokeWidth = 1.2
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );

    // Bright sweep — clean stroke, no glow halo.
    final metrics = path.computeMetrics().toList();
    if (metrics.isEmpty) return;
    final metric = metrics.first;
    final length = metric.length;
    final headDist = (progress * length).clamp(0.0, length);
    final partial = metric.extractPath(0, headDist);

    canvas.drawPath(
      partial,
      Paint()
        ..color = color
        ..strokeWidth = 2.4
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );

    // Head dot only during the sweep — small, clean, no halo.
    if (progress > 0 && progress < 1.0) {
      final tangent = metric.getTangentForOffset(headDist);
      if (tangent != null) {
        final pos = tangent.position;
        canvas.drawCircle(pos, 3.5, Paint()..color = Colors.white);
        canvas.drawCircle(pos, 2.2, Paint()..color = color);
      }
    }
  }

  void _drawCrosshair(Canvas canvas, Size size) {
    final n = series.first.length;
    final dx = size.width / (n - 1);
    final cx = cursorIndex! * dx;
    final yScale = size.height / (maxV - minV);

    canvas.drawLine(
      Offset(cx, 0),
      Offset(cx, size.height),
      Paint()
        ..color = Colors.white.withOpacity(0.18)
        ..strokeWidth = 1,
    );

    for (var i = 0; i < series.length; i++) {
      final v = series[i][cursorIndex!];
      final y = size.height - (v - minV) * yScale;
      final color = colors[i];
      canvas.drawCircle(Offset(cx, y), 4.2, Paint()..color = Colors.white);
      canvas.drawCircle(Offset(cx, y), 2.6, Paint()..color = color);
    }
  }

  void _drawGrid(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = _gridColor
      ..strokeWidth = 1;
    for (var i = 1; i < 4; i++) {
      final y = size.height * i / 4;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
    for (var i = 1; i < 8; i++) {
      final x = size.width * i / 8;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _LifelinePainter old) =>
      old.progress != progress || old.cursorIndex != cursorIndex;
}
