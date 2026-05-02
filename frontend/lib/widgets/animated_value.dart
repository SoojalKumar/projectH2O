import 'package:flutter/material.dart';

/// Counts up from 0 to [value] over [duration] when first built or when
/// [value] changes. Premium-feel touch on metric tiles.
class AnimatedValue extends StatelessWidget {
  final double value;
  final TextStyle? style;
  final int decimals;
  final Duration duration;
  final String? suffix;

  const AnimatedValue({
    super.key,
    required this.value,
    this.style,
    this.decimals = 0,
    this.duration = const Duration(milliseconds: 900),
    this.suffix,
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: value),
      duration: duration,
      curve: Curves.easeOutCubic,
      builder: (_, v, __) {
        final text = decimals == 0
            ? v.toStringAsFixed(0)
            : v.toStringAsFixed(decimals);
        return Text('${text}${suffix ?? ''}', style: style);
      },
    );
  }
}

/// Gentle fade + slide-up on first paint. Used for screen sections so
/// content lands rather than pops.
class FadeSlideIn extends StatefulWidget {
  final Widget child;
  final Duration delay;
  final Duration duration;
  final double offset;

  const FadeSlideIn({
    super.key,
    required this.child,
    this.delay = Duration.zero,
    this.duration = const Duration(milliseconds: 380),
    this.offset = 12,
  });

  @override
  State<FadeSlideIn> createState() => _FadeSlideInState();
}

class _FadeSlideInState extends State<FadeSlideIn>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: widget.duration);
    Future.delayed(widget.delay, () {
      if (mounted) _c.forward();
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final curve = CurvedAnimation(parent: _c, curve: Curves.easeOutCubic);
    return AnimatedBuilder(
      animation: curve,
      child: widget.child,
      builder: (_, child) => Opacity(
        opacity: curve.value,
        child: Transform.translate(
          offset: Offset(0, widget.offset * (1 - curve.value)),
          child: child,
        ),
      ),
    );
  }
}
