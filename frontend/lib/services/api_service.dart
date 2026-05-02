import 'package:dio/dio.dart';

import '../core/constants/api_constants.dart';
import '../models/models.dart';

class ApiService {
  ApiService({Dio? dio})
      : _dio = dio ??
            Dio(BaseOptions(
              baseUrl: ApiConstants.baseUrl,
              connectTimeout: const Duration(seconds: 8),
              receiveTimeout: const Duration(seconds: 30),
              headers: {'Content-Type': 'application/json'},
            ));

  final Dio _dio;

  Future<SupplyDashboard> fetchDashboard() async {
    final res = await _dio.get<Map<String, dynamic>>(ApiConstants.dashboard);
    return SupplyDashboard.fromJson(res.data!);
  }

  Future<List<MetricReading>> fetchHistory({int months = 24}) async {
    final res = await _dio.get<List<dynamic>>(
      ApiConstants.history,
      queryParameters: {'months': months},
    );
    return (res.data ?? [])
        .map((e) => MetricReading.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<MetricReading>> fetchTrend(String metric, {int months = 24}) async {
    final res = await _dio.get<Map<String, dynamic>>(
      '${ApiConstants.trend}/$metric',
      queryParameters: {'months': months},
    );
    final points = (res.data?['points'] as List? ?? []);
    return points
        .map((e) => MetricReading.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<MultiSignalAlert>> fetchAlerts({bool withAi = true}) async {
    final res = await _dio.get<List<dynamic>>(
      ApiConstants.alerts,
      queryParameters: {'with_ai': withAi},
    );
    return (res.data ?? [])
        .map((e) => MultiSignalAlert.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<HistoricalComparison> fetchHistoricalComparison() async {
    final res = await _dio.get<Map<String, dynamic>>(ApiConstants.historicalComparison);
    return HistoricalComparison.fromJson(res.data!);
  }

  Future<OutlookReport> fetchReport({int windowMonths = 6}) async {
    final res = await _dio.get<Map<String, dynamic>>(
      ApiConstants.report,
      queryParameters: {'window_months': windowMonths},
    );
    return OutlookReport.fromJson(res.data!);
  }

  Future<void> refreshDataset() async {
    await _dio.post(ApiConstants.refresh);
  }

  Future<WeatherForecast> fetchWeather() async {
    final res = await _dio.get<Map<String, dynamic>>('/supply/weather');
    return WeatherForecast.fromJson(res.data!);
  }

  Future<PredictiveOutlook> fetchPredictiveOutlook({String region = 'statewide'}) async {
    final res = await _dio.get<Map<String, dynamic>>(
      '/supply/forecast',
      queryParameters: {'region': region},
    );
    return PredictiveOutlook.fromJson(res.data!);
  }

  /// Returns the assistant reply for a multi-turn conversation. The history
  /// is sent as `[{role: 'user'|'assistant', content: '...'}, ...]`.
  Future<String> chat(List<Map<String, String>> messages) async {
    final res = await _dio.post<Map<String, dynamic>>(
      '/supply/chat',
      data: {'messages': messages},
    );
    final m = res.data?['message'] as Map<String, dynamic>?;
    return (m?['content'] as String?) ?? '';
  }
}
