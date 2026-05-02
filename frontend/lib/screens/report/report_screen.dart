import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../providers/providers.dart';
import '../../widgets/section_card.dart';

class ReportScreen extends ConsumerWidget {
  const ReportScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(reportProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Outlook report')),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(reportProvider),
        child: async.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Padding(
              padding: const EdgeInsets.all(24),
              child: Text('Error: $e',
                  style: const TextStyle(color: AppColors.textSecondary))),
          data: (r) => ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
            children: [
              Container(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(20),
                  border: cardBorder,
                  boxShadow: cardShadow,
                ),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.10),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.summarize_rounded,
                          color: AppColors.primary, size: 18),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Outlook',
                              style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 16,
                                  letterSpacing: -0.2)),
                          const SizedBox(height: 2),
                          Text(r.periodLabel,
                              style: const TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 12)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              SectionCard(
                icon: Icons.short_text_rounded,
                title: 'Overview',
                child: Text(r.aiSummary,
                    style: const TextStyle(fontSize: 14, height: 1.5)),
              ),
              const SizedBox(height: 14),
              _ListSection(
                title: 'What improved',
                icon: Icons.trending_up_rounded,
                color: AppColors.success,
                items: r.improved,
                emptyText: 'No metrics improved over this window.',
              ),
              const SizedBox(height: 12),
              _ListSection(
                title: 'What worsened',
                icon: Icons.trending_down_rounded,
                color: AppColors.warning,
                items: r.worsened,
                emptyText: 'No metrics worsened over this window.',
              ),
              const SizedBox(height: 12),
              _ListSection(
                title: 'Still risky',
                icon: Icons.priority_high_rounded,
                color: AppColors.danger,
                items: r.stillRisky,
                emptyText: 'Nothing currently in watch or concern bands.',
              ),
              const SizedBox(height: 12),
              _ListSection(
                title: 'Watch next',
                icon: Icons.visibility_rounded,
                color: AppColors.primary,
                items: r.watchNext,
                emptyText: '—',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ListSection extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final List<String> items;
  final String emptyText;

  const _ListSection({
    required this.title,
    required this.icon,
    required this.color,
    required this.items,
    required this.emptyText,
  });

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      icon: icon,
      title: title,
      trailing: Text('${items.length}',
          style: TextStyle(
              fontWeight: FontWeight.w800, fontSize: 14, color: color)),
      child: items.isEmpty
          ? Text(emptyText,
              style: const TextStyle(
                  color: AppColors.textSecondary, fontSize: 12, height: 1.4))
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final s in items)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(top: 5),
                          child: Icon(Icons.circle, size: 6, color: color),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(s,
                              style: const TextStyle(fontSize: 13, height: 1.45)),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
    );
  }
}
