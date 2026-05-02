import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../providers/providers.dart';
import '../../widgets/lifeline_chart.dart';

class TrendsScreen extends ConsumerWidget {
  const TrendsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final history = ref.watch(historyProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Trends')),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(historyProvider),
        child: history.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Padding(
            padding: const EdgeInsets.all(24),
            child: Text('Error: $e',
                style: const TextStyle(color: AppColors.textSecondary)),
          ),
          data: (rows) => ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
            children: [
              const Padding(
                padding: EdgeInsets.only(left: 4, bottom: 14),
                child: Text(
                  'Three signals over the last decade. Hover any month to inspect the exact readings.',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                    height: 1.5,
                  ),
                ),
              ),
              LifelineChart(readings: rows),
            ],
          ),
        ),
      ),
    );
  }
}
