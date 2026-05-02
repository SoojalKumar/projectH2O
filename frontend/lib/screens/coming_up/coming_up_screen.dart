import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../widgets/forecast_card.dart';
import '../../widgets/weather_card.dart';

/// Forward-looking destination — weather window + 90-day pattern outlook.
/// Pulled out of the dashboard so the home screen can stay editorial.
class ComingUpScreen extends StatelessWidget {
  const ComingUpScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Coming up')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        children: const [
          Padding(
            padding: EdgeInsets.only(left: 4, bottom: 14),
            child: Text(
              "Sierra Nevada weather window and the 90-day supply outlook. Storm watch first, then the longer-term pattern read.",
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
                height: 1.55,
              ),
            ),
          ),
          WeatherCard(),
          SizedBox(height: 14),
          ForecastCard(),
        ],
      ),
    );
  }
}
