import 'package:shared_preferences/shared_preferences.dart';

/// Lightweight settings persistence: onboarding-seen flag + the user's
/// chosen California region (statewide / north_coast / sacramento_valley /
/// san_joaquin_valley / tulare_basin / south_coast).
class SettingsRepository {
  static const _kSeenOnboarding = 'ss_seen_onboarding';
  static const _kRegion = 'ss_region';

  Future<bool> hasSeenOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_kSeenOnboarding) ?? false;
  }

  Future<void> markOnboardingSeen() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kSeenOnboarding, true);
  }

  Future<String> region() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_kRegion) ?? 'statewide';
  }

  Future<void> setRegion(String region) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kRegion, region);
  }

  Future<void> reset() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kSeenOnboarding);
    await prefs.remove(_kRegion);
  }
}
