import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';

/// Editorial premium minimal card. Hairline edge + barely-there shadow.
/// Generous padding. Icon (if provided) is rendered subtly inline with the
/// title — no chip background, no decoration.
class SectionCard extends StatelessWidget {
  final String title;
  final Widget child;
  final Widget? trailing;
  final IconData? icon;
  final EdgeInsets padding;
  final VoidCallback? onTap;

  const SectionCard({
    super.key,
    required this.title,
    required this.child,
    this.trailing,
    this.icon,
    this.padding = const EdgeInsets.fromLTRB(
        AppSpace.xxl, AppSpace.xl, AppSpace.xxl, AppSpace.xxl),
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final card = Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: cardBorder,
        boxShadow: cardShadow,
      ),
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              if (icon != null) ...[
                Icon(icon, color: AppColors.textTertiary, size: 14),
                const SizedBox(width: AppSpace.sm),
              ],
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    letterSpacing: -0.1,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              if (trailing != null) trailing!,
            ],
          ),
          const SizedBox(height: AppSpace.md + 2),
          child,
        ],
      ),
    );

    if (onTap == null) return card;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.card),
        child: card,
      ),
    );
  }
}

/// Minimal status pill. Tinted background + colored text.
class StatusPill extends StatelessWidget {
  final String label;
  final Color color;
  final bool solid;

  const StatusPill({
    super.key,
    required this.label,
    required this.color,
    this.solid = false,
  });

  @override
  Widget build(BuildContext context) {
    if (solid) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 9.5,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.6,
          ),
        ),
      );
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 9.5,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.6,
        ),
      ),
    );
  }
}
