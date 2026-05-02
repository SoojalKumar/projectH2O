import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../providers/providers.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _pageController = PageController();
  int _step = 0;
  bool _saving = false;

  static const _totalSteps = 2;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _next() {
    if (_step == _totalSteps - 1) {
      _finish();
      return;
    }
    setState(() => _step += 1);
    _pageController.animateToPage(_step,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic);
  }

  void _back() {
    if (_step == 0) return;
    setState(() => _step -= 1);
    _pageController.animateToPage(_step,
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeOutCubic);
  }

  Future<void> _finish() async {
    setState(() => _saving = true);
    await ref.read(settingsRepositoryProvider).markOnboardingSeen();
    ref.invalidate(bootstrapProvider);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  AppSpace.xl, AppSpace.lg, AppSpace.xl, AppSpace.sm),
              child: Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                          colors: [AppColors.primary, AppColors.accent]),
                      borderRadius: BorderRadius.circular(AppRadius.chip),
                    ),
                    child: const Icon(Icons.public_rounded,
                        color: Colors.white, size: 18),
                  ),
                  const SizedBox(width: AppSpace.md - 2),
                  Text('Hydra',
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.w800)),
                  const Spacer(),
                  Text('${_step + 1} / $_totalSteps',
                      style: const TextStyle(
                          color: AppColors.textTertiary, fontSize: 12)),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpace.xl),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  minHeight: 3,
                  value: (_step + 1) / _totalSteps,
                  backgroundColor: AppColors.divider,
                  valueColor:
                      const AlwaysStoppedAnimation(AppColors.primary),
                ),
              ),
            ),
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                onPageChanged: (i) => setState(() => _step = i),
                children: const [
                  _StepNarrative(),
                  _StepThreeSignals(),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  AppSpace.xl, AppSpace.sm, AppSpace.xl, AppSpace.xl),
              child: Row(
                children: [
                  if (_step > 0)
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _saving ? null : _back,
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        child: const Text('Back'),
                      ),
                    ),
                  if (_step > 0) const SizedBox(width: AppSpace.md),
                  Expanded(
                    flex: 2,
                    child: FilledButton(
                      onPressed: _saving ? null : _next,
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: _saving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white))
                          : Text(_step == _totalSteps - 1
                              ? "See California's outlook"
                              : 'Continue'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StepHeader extends StatelessWidget {
  final String eyebrow;
  final String title;
  final String subtitle;
  const _StepHeader({
    required this.eyebrow,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          eyebrow.toUpperCase(),
          style: const TextStyle(
            fontSize: 11,
            letterSpacing: 1.6,
            fontWeight: FontWeight.w700,
            color: AppColors.primary,
          ),
        ),
        const SizedBox(height: AppSpace.md),
        Text(
          title,
          style: const TextStyle(
            fontSize: 30,
            fontWeight: FontWeight.w700,
            height: 1.15,
            letterSpacing: -0.8,
          ),
        ),
        const SizedBox(height: AppSpace.md),
        Text(
          subtitle,
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 14,
            height: 1.55,
          ),
        ),
      ],
    );
  }
}

class _StepNarrative extends StatelessWidget {
  const _StepNarrative();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          AppSpace.xxl, AppSpace.xxl, AppSpace.xxl, AppSpace.md),
      child: ListView(
        children: const [
          _StepHeader(
            eyebrow: 'Step 1 · The problem',
            title: 'Snowpack alone is no longer enough',
            subtitle:
                "For decades, water managers tracked Sierra Nevada snowpack as the single best predictor of California's water year. That doesn't work anymore.",
          ),
          SizedBox(height: AppSpace.xxl),
          _Bullet(
              text:
                  'Warmer storms drop rain instead of snow — water flows out fast instead of banking for spring.'),
          _Bullet(
              text:
                  'Atmospheric rivers can deliver a year of precipitation in days; drought can flip to flood in a season.'),
          _Bullet(
              text:
                  "Reading any one number in isolation gives you the wrong answer about California's supply."),
        ],
      ),
    );
  }
}

class _StepThreeSignals extends StatelessWidget {
  const _StepThreeSignals();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          AppSpace.xxl, AppSpace.xxl, AppSpace.xxl, AppSpace.md),
      child: ListView(
        children: const [
          _StepHeader(
            eyebrow: 'Step 2 · The approach',
            title: 'Three signals, one outlook',
            subtitle:
                "Hydra reads snowpack, precipitation, and reservoir storage together — and flags the patterns no single metric reveals.",
          ),
          SizedBox(height: AppSpace.xxl),
          _SignalRow(
            color: Color(0xFF67B4D8),
            label: 'Snowpack',
            sub: 'Future water — what feeds rivers next spring.',
          ),
          SizedBox(height: AppSpace.md - 2),
          _SignalRow(
            color: Color(0xFF4DD4B7),
            label: 'Precipitation',
            sub: 'Current conditions — the wet season as it unfolds.',
          ),
          SizedBox(height: AppSpace.md - 2),
          _SignalRow(
            color: Color(0xFFE5A540),
            label: 'Reservoir storage',
            sub: "Today's buffer — what we already have on hand.",
          ),
        ],
      ),
    );
  }
}

class _Bullet extends StatelessWidget {
  final String text;
  const _Bullet({required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child:
                Icon(Icons.circle, size: 5, color: AppColors.primary),
          ),
          const SizedBox(width: AppSpace.md),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 14, height: 1.55),
            ),
          ),
        ],
      ),
    );
  }
}

class _SignalRow extends StatelessWidget {
  final Color color;
  final String label;
  final String sub;
  const _SignalRow(
      {required this.color, required this.label, required this.sub});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(
          AppSpace.lg, AppSpace.md + 2, AppSpace.lg, AppSpace.md + 2),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.card),
        boxShadow: cardShadow,
      ),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 38,
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
                Text(label,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                      letterSpacing: -0.1,
                    )),
                const SizedBox(height: 2),
                Text(sub,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                      height: 1.45,
                    )),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
