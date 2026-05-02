import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../models/models.dart';
import '../../providers/providers.dart';
import '../../widgets/section_card.dart';

class AlertsScreen extends ConsumerWidget {
  const AlertsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(alertsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Multi-signal alerts')),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(alertsProvider),
        child: async.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Padding(
              padding: const EdgeInsets.all(24),
              child: Text('Error: $e',
                  style: const TextStyle(color: AppColors.textSecondary))),
          data: (alerts) => alerts.isEmpty
              ? const _EmptyState()
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
                  itemCount: alerts.length + 1,
                  separatorBuilder: (_, i) =>
                      SizedBox(height: i == 0 ? 16 : 12),
                  itemBuilder: (context, i) {
                    if (i == 0) {
                      return const Padding(
                        padding: EdgeInsets.only(left: 4),
                        child: Text(
                          "Patterns no single metric reveals. Each call is deterministic; the explanation underneath adds context.",
                          style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 13,
                              height: 1.5),
                        ),
                      );
                    }
                    return _AlertCard(alert: alerts[i - 1]);
                  },
                ),
        ),
      ),
    );
  }
}

class _AlertCard extends StatelessWidget {
  final MultiSignalAlert alert;
  const _AlertCard({required this.alert});

  @override
  Widget build(BuildContext context) {
    final color = colorForSeverity(alert.severity);
    return SectionCard(
      icon: Icons.warning_amber_rounded,
      title: alert.title,
      trailing: StatusPill(label: alert.severity.name.toUpperCase(), color: color),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(alert.description,
              style: const TextStyle(fontSize: 13, height: 1.45)),
          if (alert.aiContext != null && alert.aiContext!.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.07),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.short_text_rounded,
                      size: 16, color: AppColors.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      alert.aiContext!,
                      style: const TextStyle(fontSize: 12, height: 1.45),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check_circle_outline,
                size: 48, color: AppColors.success),
            const SizedBox(height: 12),
            Text('No active patterns',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            const Text(
                'The three signals are aligned — no multi-signal alerts to flag.',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
          ],
        ),
      ),
    );
  }
}
