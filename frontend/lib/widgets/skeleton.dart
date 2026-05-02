import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';

/// Subtle pulsing placeholder. Premium-style: soft, cool gray, no shimmer.
class SkeletonBox extends StatefulWidget {
  final double? width;
  final double height;
  final BorderRadius? borderRadius;

  const SkeletonBox({
    super.key,
    this.width,
    required this.height,
    this.borderRadius,
  });

  @override
  State<SkeletonBox> createState() => _SkeletonBoxState();
}

class _SkeletonBoxState extends State<SkeletonBox>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1300),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (_, __) {
        final t = _controller.value;
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            color: Color.lerp(AppColors.surfaceAlt, AppColors.divider, t),
            borderRadius: widget.borderRadius ?? BorderRadius.circular(8),
          ),
        );
      },
    );
  }
}

class DashboardSkeleton extends StatelessWidget {
  const DashboardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      children: [
        const _Header(),
        const SizedBox(height: 22),
        const _HeroSkeleton(),
        const SizedBox(height: 28),
        const _LabelSkeleton(),
        const SizedBox(height: 12),
        Row(
          children: const [
            Expanded(child: _MetricSkeleton()),
            SizedBox(width: 10),
            Expanded(child: _MetricSkeleton()),
            SizedBox(width: 10),
            Expanded(child: _MetricSkeleton()),
          ],
        ),
        const SizedBox(height: 28),
        const _LabelSkeleton(),
        const SizedBox(height: 12),
        const _BodySkeleton(height: 130),
      ],
    );
  }
}

class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const SkeletonBox(width: 36, height: 36, borderRadius: BorderRadius.all(Radius.circular(10))),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            SkeletonBox(width: 88, height: 10),
            SizedBox(height: 6),
            SkeletonBox(width: 130, height: 16),
          ],
        ),
      ],
    );
  }
}

class _LabelSkeleton extends StatelessWidget {
  const _LabelSkeleton();
  @override
  Widget build(BuildContext context) =>
      const SkeletonBox(width: 100, height: 10);
}

class _HeroSkeleton extends StatelessWidget {
  const _HeroSkeleton();
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        border: cardBorder,
        boxShadow: cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          SkeletonBox(width: 120, height: 12),
          SizedBox(height: 28),
          SkeletonBox(width: 180, height: 50),
          SizedBox(height: 14),
          SkeletonBox(width: double.infinity, height: 12),
          SizedBox(height: 6),
          SkeletonBox(width: 220, height: 12),
        ],
      ),
    );
  }
}

class _MetricSkeleton extends StatelessWidget {
  const _MetricSkeleton();
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: cardBorder,
        boxShadow: cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          SkeletonBox(width: 28, height: 28, borderRadius: BorderRadius.all(Radius.circular(8))),
          SizedBox(height: 14),
          SkeletonBox(width: 70, height: 28),
          SizedBox(height: 10),
          SkeletonBox(width: 60, height: 11),
          SizedBox(height: 4),
          SkeletonBox(width: 50, height: 9),
          SizedBox(height: 12),
          SkeletonBox(width: 70, height: 11),
        ],
      ),
    );
  }
}

class _BodySkeleton extends StatelessWidget {
  final double height;
  const _BodySkeleton({required this.height});
  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: cardBorder,
        boxShadow: cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          SkeletonBox(width: 120, height: 12),
          SizedBox(height: 14),
          SkeletonBox(width: double.infinity, height: 11),
          SizedBox(height: 6),
          SkeletonBox(width: 240, height: 11),
          SizedBox(height: 6),
          SkeletonBox(width: 180, height: 11),
        ],
      ),
    );
  }
}
