import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme/app_theme.dart';
import '../models/models.dart';
import '../providers/providers.dart';

/// "What this means for planning" — translates the deterministic outlook
/// into guidance for citizens, farmers, and supply managers. Pulls from
/// the predictiveOutlookProvider so it stays in lockstep with risk scoring.
class PlanningCard extends ConsumerStatefulWidget {
  const PlanningCard({super.key});

  @override
  ConsumerState<PlanningCard> createState() => _PlanningCardState();
}

enum _Audience { citizen, farmer, supply }

const Map<String, String> _regionLabels = {
  'statewide': 'Statewide',
  'north_coast': 'North Coast',
  'sacramento_valley': 'Sacramento Valley',
  'san_joaquin_valley': 'San Joaquin Valley',
  'tulare_basin': 'Tulare Basin',
  'south_coast': 'South Coast',
};

class _PlanningCardState extends ConsumerState<PlanningCard> {
  _Audience _selected = _Audience.citizen;

  void _openRegionPicker() {
    final current = ref.read(regionProvider);
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withOpacity(0.40),
      builder: (_) => _RegionPickerSheet(
        current: current,
        onSelect: (key) {
          ref.read(regionProvider.notifier).set(key);
          Navigator.of(context).pop();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(predictiveOutlookProvider);
    return async.when(
      loading: () => const _Skeleton(),
      error: (_, __) => const SizedBox.shrink(),
      data: (outlook) => _Card(
        planning: outlook.planning,
        selected: _selected,
        onSelect: (a) => setState(() => _selected = a),
        onChangeRegion: _openRegionPicker,
      ),
    );
  }
}

class _Card extends StatelessWidget {
  final PlanningImplications planning;
  final _Audience selected;
  final ValueChanged<_Audience> onSelect;
  final VoidCallback onChangeRegion;

  const _Card({
    required this.planning,
    required this.selected,
    required this.onSelect,
    required this.onChangeRegion,
  });

  PlanningImplication _implication() {
    switch (selected) {
      case _Audience.citizen:
        return planning.citizen;
      case _Audience.farmer:
        return planning.farmer;
      case _Audience.supply:
        return planning.supply;
    }
  }

  Color _severityColor(Severity s) => switch (s) {
        Severity.good => AppColors.success,
        Severity.neutral => AppColors.primary,
        Severity.watch => AppColors.warning,
        Severity.concern => AppColors.danger,
      };

  @override
  Widget build(BuildContext context) {
    final imp = _implication();
    final color = _severityColor(imp.severity);

    return Container(
      padding: const EdgeInsets.fromLTRB(
          AppSpace.xl, AppSpace.lg, AppSpace.xl, AppSpace.xl),
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
              const Icon(Icons.lightbulb_outline_rounded,
                  color: AppColors.textTertiary, size: 14),
              const SizedBox(width: AppSpace.sm),
              const Expanded(
                child: Text(
                  'What this means',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.1,
                  ),
                ),
              ),
              _RegionChip(region: planning.region, onTap: onChangeRegion),
            ],
          ),
          const SizedBox(height: AppSpace.md + 2),
          // Audience selector
          Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: AppColors.surfaceAlt,
              borderRadius: BorderRadius.circular(AppRadius.chip),
            ),
            child: Row(
              children: [
                _Tab(
                  label: 'Citizen',
                  active: selected == _Audience.citizen,
                  onTap: () => onSelect(_Audience.citizen),
                ),
                _Tab(
                  label: 'Farmer',
                  active: selected == _Audience.farmer,
                  onTap: () => onSelect(_Audience.farmer),
                ),
                _Tab(
                  label: 'Supply',
                  active: selected == _Audience.supply,
                  onTap: () => onSelect(_Audience.supply),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpace.md + 2),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 3,
                height: 36,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: AppSpace.md + 2),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      imp.headline,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      imp.detail,
                      style: const TextStyle(
                        fontSize: 13,
                        height: 1.55,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    if (selected == _Audience.farmer &&
                        planning.allocationBasis.isNotEmpty) ...[
                      const SizedBox(height: AppSpace.sm),
                      Text(
                        planning.allocationBasis,
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.textTertiary,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RegionChip extends StatelessWidget {
  final String region;
  final VoidCallback onTap;
  const _RegionChip({required this.region, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final label = _regionLabels[region] ?? 'Statewide';
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: AppColors.surfaceAlt,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.place_outlined,
                  size: 12, color: AppColors.textSecondary),
              const SizedBox(width: 5),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                  letterSpacing: -0.05,
                ),
              ),
              const SizedBox(width: 3),
              const Icon(Icons.expand_more_rounded,
                  size: 14, color: AppColors.textTertiary),
            ],
          ),
        ),
      ),
    );
  }
}

class _RegionPickerSheet extends StatelessWidget {
  final String current;
  final ValueChanged<String> onSelect;
  const _RegionPickerSheet({required this.current, required this.onSelect});

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
                'YOUR REGION',
                style: TextStyle(
                  fontSize: 10,
                  letterSpacing: 1.6,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textTertiary,
                ),
              ),
              const SizedBox(height: AppSpace.sm),
              const Text(
                'Allocations and adequacy vary by district contract priority. Pick the region closest to you for a more grounded estimate.',
                style: TextStyle(
                  fontSize: 13,
                  height: 1.55,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: AppSpace.lg),
              for (final entry in _regionLabels.entries)
                _RegionRow(
                  keyName: entry.key,
                  label: entry.value,
                  selected: entry.key == current,
                  onTap: () => onSelect(entry.key),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RegionRow extends StatelessWidget {
  final String keyName;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _RegionRow({
    required this.keyName,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.chip),
        child: Container(
          padding: const EdgeInsets.symmetric(
              horizontal: AppSpace.md, vertical: AppSpace.md + 2),
          margin: const EdgeInsets.only(bottom: 6),
          decoration: BoxDecoration(
            color: selected ? AppColors.primary.withOpacity(0.06) : AppColors.surface,
            borderRadius: BorderRadius.circular(AppRadius.chip),
            border: Border.all(
              color: selected
                  ? AppColors.primary.withOpacity(0.5)
                  : AppColors.border,
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              if (selected)
                const Icon(Icons.check_rounded,
                    color: AppColors.primary, size: 18),
            ],
          ),
        ),
      ),
    );
  }
}

class _Tab extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;
  const _Tab({required this.label, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: active ? AppColors.surface : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: active
                ? Border.all(color: AppColors.border)
                : null,
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                color:
                    active ? AppColors.textPrimary : AppColors.textSecondary,
                letterSpacing: -0.05,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Skeleton extends StatelessWidget {
  const _Skeleton();
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 168,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: cardBorder,
        boxShadow: cardShadow,
      ),
      child: const Center(
        child: SizedBox(
            width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
      ),
    );
  }
}
