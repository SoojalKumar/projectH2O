import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/theme/app_theme.dart';
import 'providers/providers.dart';
import 'screens/chat/chat_panel.dart';
import 'screens/dashboard/dashboard_screen.dart';
import 'screens/onboarding/onboarding_screen.dart';
import 'screens/report/report_screen.dart';

class HydroSenseApp extends ConsumerWidget {
  const HydroSenseApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bootstrap = ref.watch(bootstrapProvider);
    return MaterialApp(
      title: 'Hydra',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      navigatorObservers: [appRouteObserver],
      home: bootstrap.when(
        loading: () => const _SplashScreen(),
        error: (_, __) => const OnboardingScreen(),
        data: (seen) => seen ? const RootShell() : const OnboardingScreen(),
      ),
    );
  }
}

class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                    colors: [AppColors.primary, AppColors.accent]),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(Icons.public_rounded,
                  color: Colors.white, size: 32),
            ),
            const SizedBox(height: 14),
            const Text('Hydra',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
          ],
        ),
      ),
    );
  }
}

class RootShell extends ConsumerWidget {
  const RootShell({super.key});

  /// Two primary tabs. Everything else lives on the dashboard as cards.
  static const List<Widget> _screens = [
    DashboardScreen(),
    ReportScreen(),
  ];

  static const List<NavigationDestination> _destinations = [
    NavigationDestination(
        icon: Icon(Icons.public_outlined),
        selectedIcon: Icon(Icons.public_rounded),
        label: 'Outlook'),
    NavigationDestination(
        icon: Icon(Icons.summarize_outlined),
        selectedIcon: Icon(Icons.summarize_rounded),
        label: 'Report'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rawIndex = ref.watch(selectedTabProvider);
    final index = rawIndex.clamp(0, _screens.length - 1);

    return Scaffold(
      body: Stack(
        children: [
          IndexedStack(index: index, children: _screens),
          Positioned(
            right: 16,
            bottom: 16,
            child: const ChatFab(),
          ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: (i) =>
            ref.read(selectedTabProvider.notifier).state = i,
        destinations: _destinations,
      ),
    );
  }
}
