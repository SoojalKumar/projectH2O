import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme/app_theme.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import '../services/settings_repository.dart';

/// Global route observer — lets widgets detect when a route they live on
/// becomes the topmost route again (e.g. after the user pops back from
/// a pushed drawer screen). Used by the lifeline chart to replay its
/// sweep animation on return.
final RouteObserver<ModalRoute<void>> appRouteObserver =
    RouteObserver<ModalRoute<void>>();

final settingsRepositoryProvider = Provider<SettingsRepository>((ref) => SettingsRepository());

/// User's selected California region. Persisted across launches.
class RegionNotifier extends StateNotifier<String> {
  RegionNotifier(this._repo) : super('statewide') {
    _hydrate();
  }
  final SettingsRepository _repo;

  Future<void> _hydrate() async {
    state = await _repo.region();
  }

  Future<void> set(String region) async {
    state = region;
    await _repo.setRegion(region);
  }
}

final regionProvider = StateNotifierProvider<RegionNotifier, String>(
  (ref) => RegionNotifier(ref.watch(settingsRepositoryProvider)),
);

/// One conversation turn in the chat. Lives in a top-level provider so
/// history survives panel dismissal — no more "fresh chat every time."
class ChatTurn {
  final String role; // 'user' | 'assistant'
  final String content;
  const ChatTurn(this.role, this.content);
}

class ChatHistoryNotifier extends StateNotifier<List<ChatTurn>> {
  ChatHistoryNotifier() : super(const []);

  void add(ChatTurn turn) => state = [...state, turn];
  void replaceLast(ChatTurn turn) {
    if (state.isEmpty) {
      state = [turn];
    } else {
      state = [...state.sublist(0, state.length - 1), turn];
    }
  }

  void clear() => state = const [];
}

final chatHistoryProvider =
    StateNotifierProvider<ChatHistoryNotifier, List<ChatTurn>>(
        (ref) => ChatHistoryNotifier());

final apiServiceProvider = Provider<ApiService>((ref) => ApiService());

/// 0 home · 1 trends · 2 alerts · 3 historical · 4 report · 5 settings
final selectedTabProvider = StateProvider<int>((ref) => 0);

/// Whether the user has finished the intro. Frees the dashboard.
final bootstrapProvider = FutureProvider<bool>((ref) async {
  final repo = ref.watch(settingsRepositoryProvider);
  return repo.hasSeenOnboarding();
});

final dashboardProvider = FutureProvider.autoDispose<SupplyDashboard>((ref) async {
  return ref.watch(apiServiceProvider).fetchDashboard();
});

final trendProvider = FutureProvider.autoDispose
    .family<List<MetricReading>, String>((ref, metric) async {
  return ref.watch(apiServiceProvider).fetchTrend(metric, months: 60);
});

final historyProvider = FutureProvider.autoDispose<List<MetricReading>>((ref) async {
  return ref.watch(apiServiceProvider).fetchHistory(months: 60);
});

final alertsProvider = FutureProvider.autoDispose<List<MultiSignalAlert>>((ref) async {
  return ref.watch(apiServiceProvider).fetchAlerts(withAi: true);
});

final historicalComparisonProvider =
    FutureProvider.autoDispose<HistoricalComparison>((ref) async {
  return ref.watch(apiServiceProvider).fetchHistoricalComparison();
});

final reportProvider = FutureProvider.autoDispose<OutlookReport>((ref) async {
  return ref.watch(apiServiceProvider).fetchReport(windowMonths: 6);
});

final weatherProvider = FutureProvider.autoDispose<WeatherForecast>((ref) async {
  return ref.watch(apiServiceProvider).fetchWeather();
});

final predictiveOutlookProvider =
    FutureProvider.autoDispose<PredictiveOutlook>((ref) async {
  final region = ref.watch(regionProvider);
  return ref.watch(apiServiceProvider).fetchPredictiveOutlook(region: region);
});

// ---------- Severity → color helpers (used everywhere) -----------------------

Color colorForSeverity(Severity s) => switch (s) {
      Severity.good => AppColors.success,
      Severity.neutral => AppColors.primary,
      Severity.watch => AppColors.warning,
      Severity.concern => AppColors.danger,
    };
