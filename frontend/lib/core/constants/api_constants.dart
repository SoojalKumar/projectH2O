class ApiConstants {
  // Android emulator: http://10.0.2.2:8000
  // iOS simulator / desktop / web: http://localhost:8000
  static const String baseUrl = String.fromEnvironment(
    'HYDROSENSE_API_BASE_URL',
    defaultValue: 'http://localhost:8000',
  );

  static const String dashboard = '/supply/dashboard';
  static const String history = '/supply/history';
  static const String trend = '/supply/trends';
  static const String alerts = '/supply/alerts';
  static const String historicalComparison = '/supply/historical-comparison';
  static const String report = '/supply/report';
  static const String refresh = '/supply/refresh';
}
