import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../core/theme/app_theme.dart';
import '../models/models.dart';
import '../providers/providers.dart';

const Color _snowAccent = Color(0xFF67B4D8);
const Color _sunAccent = Color(0xFFD89230);

class WeatherCard extends ConsumerStatefulWidget {
  const WeatherCard({super.key});

  @override
  ConsumerState<WeatherCard> createState() => _WeatherCardState();
}

class _WeatherCardState extends ConsumerState<WeatherCard> {
  /// Day-of-week within the currently visible week (0..6).
  int _selectedDayInWeek = 0;

  /// -1 = last week, 0 = this week (default), 1 = next week.
  int _weekIndex = 0;

  int _findTodayIndex(List<WeatherDay> days, DateTime today) {
    final t = DateTime(today.year, today.month, today.day);
    for (var i = 0; i < days.length; i++) {
      final d = days[i].date;
      if (DateTime(d.year, d.month, d.day) == t) return i;
    }
    return 7.clamp(0, days.length - 1);
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(weatherProvider);
    return async.when(
      loading: () => const _Skeleton(),
      error: (e, _) =>
          _ErrorBox(error: e, onRetry: () => ref.invalidate(weatherProvider)),
      data: (forecast) {
        final allDays = forecast.days;
        final todayIdx = _findTodayIndex(allDays, forecast.today);

        final viewStart =
            (todayIdx + _weekIndex * 7).clamp(0, allDays.length);
        final viewEnd = (viewStart + 7).clamp(0, allDays.length);
        final visible = allDays.sublist(viewStart, viewEnd);

        final canPrev = todayIdx + (_weekIndex - 1) * 7 >= 0;
        final canNext = todayIdx + (_weekIndex + 1) * 7 < allDays.length;

        if (visible.isEmpty) {
          return _ErrorBox(
            error: 'No forecast available',
            onRetry: () => ref.invalidate(weatherProvider),
          );
        }

        // Clamp selected day if visible window changed size.
        final selected = _selectedDayInWeek.clamp(0, visible.length - 1);
        final selectedDay = visible[selected];
        final selectedIsToday = _isSameDay(selectedDay.date, forecast.today);
        final showCurrent = selectedIsToday && forecast.current != null;

        return _Card(
          forecast: forecast,
          today: forecast.today,
          visibleDays: visible,
          selectedIndex: selected,
          weekLabel: _weekRangeLabel(visible, _weekIndex),
          canPrev: canPrev,
          canNext: canNext,
          onPrev: () => setState(() {
            _weekIndex -= 1;
            _selectedDayInWeek = 0;
          }),
          onNext: () => setState(() {
            _weekIndex += 1;
            _selectedDayInWeek = 0;
          }),
          onSelectDay: (i) => setState(() => _selectedDayInWeek = i),
          onRefresh: () => ref.invalidate(weatherProvider),
          selectedDay: selectedDay,
          selectedIsToday: selectedIsToday,
          currentConditions: showCurrent ? forecast.current : null,
        );
      },
    );
  }

  static bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
  static bool isSameDay(DateTime a, DateTime b) => _isSameDay(a, b);

  static String _weekRangeLabel(List<WeatherDay> days, int weekIndex) {
    if (days.isEmpty) return '';
    final fmt = DateFormat('MMM d');
    final range = '${fmt.format(days.first.date)} – ${fmt.format(days.last.date)}';
    final tag = weekIndex == 0
        ? 'This week'
        : weekIndex < 0
            ? 'Last week'
            : weekIndex == 1
                ? 'Next week'
                : null;
    return tag != null ? '$range · $tag' : range;
  }
}

class _Card extends StatelessWidget {
  final WeatherForecast forecast;
  final DateTime today;
  final List<WeatherDay> visibleDays;
  final int selectedIndex;
  final String weekLabel;
  final bool canPrev;
  final bool canNext;
  final VoidCallback onPrev;
  final VoidCallback onNext;
  final ValueChanged<int> onSelectDay;
  final VoidCallback onRefresh;
  final WeatherDay selectedDay;
  final bool selectedIsToday;
  final CurrentConditions? currentConditions;

  const _Card({
    required this.forecast,
    required this.today,
    required this.visibleDays,
    required this.selectedIndex,
    required this.weekLabel,
    required this.canPrev,
    required this.canNext,
    required this.onPrev,
    required this.onNext,
    required this.onSelectDay,
    required this.onRefresh,
    required this.selectedDay,
    required this.selectedIsToday,
    required this.currentConditions,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(
          AppSpace.xl, AppSpace.lg, AppSpace.lg, AppSpace.xl),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: cardBorder,
        boxShadow: cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.cloud_outlined,
                  color: AppColors.textTertiary, size: 14),
              const SizedBox(width: AppSpace.sm),
              const Expanded(
                child: Text(
                  'Storm watch · Sierra Nevada',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.1,
                  ),
                ),
              ),
              _DatasetTag(today: today),
            ],
          ),
          const SizedBox(height: AppSpace.md),
          Text(
            forecast.headline,
            style: const TextStyle(
              fontSize: 13,
              height: 1.55,
              color: AppColors.textPrimary,
              letterSpacing: -0.05,
            ),
          ),
          const SizedBox(height: AppSpace.lg),
          // Week navigation row
          Row(
            children: [
              _NavBtn(
                icon: Icons.chevron_left_rounded,
                enabled: canPrev,
                onTap: canPrev ? onPrev : null,
              ),
              Expanded(
                child: Center(
                  child: Text(
                    weekLabel,
                    style: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.1,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
              ),
              _NavBtn(
                icon: Icons.chevron_right_rounded,
                enabled: canNext,
                onTap: canNext ? onNext : null,
              ),
            ],
          ),
          const SizedBox(height: AppSpace.md),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = 0; i < visibleDays.length; i++) ...[
                  Expanded(
                    child: _DayCell(
                      day: visibleDays[i],
                      isToday: _WeatherCardState.isSameDay(
                          visibleDays[i].date, today),
                      isSelected: i == selectedIndex,
                      onTap: () => onSelectDay(i),
                    ),
                  ),
                  if (i < visibleDays.length - 1) const SizedBox(width: 6),
                ],
              ],
            ),
          ),
          const SizedBox(height: AppSpace.md + 2),
          _DetailPanel(
            day: selectedDay,
            isToday: selectedIsToday,
            current: currentConditions,
          ),
          const SizedBox(height: AppSpace.sm + 2),
          Padding(
            padding: const EdgeInsets.only(left: 2),
            child: Text(
              '${forecast.location} · ${forecast.elevationFt} ft',
              style: const TextStyle(
                color: AppColors.textTertiary,
                fontSize: 10,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NavBtn extends StatelessWidget {
  final IconData icon;
  final bool enabled;
  final VoidCallback? onTap;
  const _NavBtn({required this.icon, required this.enabled, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        splashFactory: NoSplash.splashFactory,
        highlightColor: Colors.transparent,
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Icon(
            icon,
            size: 18,
            color: enabled ? AppColors.textPrimary : AppColors.textTertiary,
          ),
        ),
      ),
    );
  }
}

/// Small label showing the dataset-time anchor — replaces the "live/cached"
/// badge from the API-driven version. Always reads "as of <month> <year>".
class _DatasetTag extends StatelessWidget {
  final DateTime today;
  const _DatasetTag({required this.today});

  @override
  Widget build(BuildContext context) {
    final label = DateFormat.yMMM().format(today).toUpperCase();
    return Text(
      'AS OF $label',
      style: const TextStyle(
        color: AppColors.textTertiary,
        fontSize: 9,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.8,
      ),
    );
  }
}

class _DayCell extends StatelessWidget {
  final WeatherDay day;
  final bool isToday;
  final bool isSelected;
  final VoidCallback onTap;
  const _DayCell({
    required this.day,
    required this.isToday,
    required this.isSelected,
    required this.onTap,
  });

  static (IconData, Color) _iconAndColor(WeatherCondition c) => switch (c) {
        WeatherCondition.clear => (Icons.wb_sunny_rounded, _sunAccent),
        WeatherCondition.partlyCloudy =>
          (Icons.wb_cloudy_outlined, AppColors.textTertiary),
        WeatherCondition.cloudy =>
          (Icons.cloud_rounded, AppColors.textTertiary),
        WeatherCondition.rain =>
          (Icons.water_drop_rounded, AppColors.primary),
        WeatherCondition.snow => (Icons.ac_unit_rounded, _snowAccent),
        WeatherCondition.storm =>
          (Icons.thunderstorm_rounded, AppColors.danger),
        WeatherCondition.fog =>
          (Icons.cloud_outlined, AppColors.textTertiary),
      };

  @override
  Widget build(BuildContext context) {
    final (icon, color) = _iconAndColor(day.condition);
    final dayLabel =
        isToday ? 'TODAY' : DateFormat.E().format(day.date).toUpperCase();
    final hasSnow = day.snowfallInches >= 0.5;
    final hasRain = !hasSnow && day.precipInches >= 0.1;

    Color bg;
    Border? border;
    if (isSelected) {
      bg = AppColors.surfaceAlt;
      border = Border.all(
          color: AppColors.primary.withOpacity(0.55), width: 1.2);
    } else if (isToday) {
      bg = AppColors.primary.withOpacity(0.04);
      border = Border.all(color: AppColors.primary.withOpacity(0.18));
    } else {
      bg = AppColors.surface;
      border = Border.all(color: AppColors.border);
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.chip),
        splashFactory: NoSplash.splashFactory,
        highlightColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(AppRadius.chip),
            border: border,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                dayLabel,
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                  color: isSelected || isToday
                      ? AppColors.primary
                      : AppColors.textTertiary,
                ),
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 6),
              Icon(icon, color: color, size: 17),
              const SizedBox(height: 6),
              Text(
                '${day.tempHighF.toStringAsFixed(0)}°',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                  letterSpacing: -0.2,
                ),
              ),
              Text(
                '${day.tempLowF.toStringAsFixed(0)}°',
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.textTertiary,
                ),
              ),
              const SizedBox(height: 4),
              if (hasSnow)
                Text(
                  '${day.snowfallInches.toStringAsFixed(0)}"',
                  style: const TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    color: _snowAccent,
                    letterSpacing: 0.2,
                  ),
                )
              else if (hasRain)
                Text(
                  '${day.precipInches.toStringAsFixed(1)}"',
                  style: const TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                    letterSpacing: 0.2,
                  ),
                )
              else
                const SizedBox(height: 11),
            ],
          ),
        ),
      ),
    );
  }
}

class _DetailPanel extends StatelessWidget {
  final WeatherDay day;
  final bool isToday;
  final CurrentConditions? current;

  const _DetailPanel({
    required this.day,
    required this.isToday,
    required this.current,
  });

  static String _conditionLabel(WeatherCondition c) => switch (c) {
        WeatherCondition.clear => 'Clear skies',
        WeatherCondition.partlyCloudy => 'Partly cloudy',
        WeatherCondition.cloudy => 'Overcast',
        WeatherCondition.rain => 'Rain',
        WeatherCondition.snow => 'Snow',
        WeatherCondition.storm => 'Thunderstorm',
        WeatherCondition.fog => 'Fog',
      };

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('EEEE · MMM d');
    final dateLabel = isToday
        ? 'TODAY · ${DateFormat('MMM d').format(day.date).toUpperCase()}'
        : fmt.format(day.date).toUpperCase();

    return Container(
      padding: const EdgeInsets.fromLTRB(
          AppSpace.lg, AppSpace.md, AppSpace.lg, AppSpace.md + 2),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(AppRadius.chip + 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            dateLabel,
            style: const TextStyle(
              fontSize: 9.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.6,
              color: AppColors.textTertiary,
            ),
          ),
          const SizedBox(height: AppSpace.sm),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${day.tempHighF.toStringAsFixed(0)}°',
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w600,
                  height: 1.0,
                  letterSpacing: -1.0,
                ),
              ),
              const SizedBox(width: 6),
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  '/ ${day.tempLowF.toStringAsFixed(0)}°',
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textTertiary,
                  ),
                ),
              ),
              const Spacer(),
              Text(
                _conditionLabel(day.condition),
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpace.sm + 2),
          Row(
            children: [
              _DetailStat(
                icon: Icons.water_drop_outlined,
                label: 'Precip',
                value: '${day.precipInches.toStringAsFixed(2)}"',
              ),
              const SizedBox(width: AppSpace.lg + 2),
              _DetailStat(
                icon: Icons.ac_unit_rounded,
                label: 'Snow',
                value: '${day.snowfallInches.toStringAsFixed(1)}"',
                valueColor: day.snowfallInches > 0 ? _snowAccent : null,
              ),
            ],
          ),
          if (current != null) ...[
            const SizedBox(height: AppSpace.md),
            Container(
              padding: const EdgeInsets.fromLTRB(
                  AppSpace.md, AppSpace.sm + 2, AppSpace.md, AppSpace.sm + 2),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(AppRadius.chip),
                border: Border.all(
                    color: AppColors.success.withOpacity(0.22)),
              ),
              child: _LiveNowRow(c: current!),
            ),
          ],
        ],
      ),
    );
  }
}

class _DetailStat extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;

  const _DetailStat({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 12, color: AppColors.textTertiary),
        const SizedBox(width: 5),
        Text(label,
            style: const TextStyle(
              fontSize: 11,
              color: AppColors.textSecondary,
            )),
        const SizedBox(width: 6),
        Text(
          value,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: valueColor ?? AppColors.textPrimary,
          ),
        ),
      ],
    );
  }
}

class _LiveNowRow extends StatelessWidget {
  final CurrentConditions c;
  const _LiveNowRow({required this.c});

  @override
  Widget build(BuildContext context) {
    final pieces = <String>[];
    if (c.feelsLikeF != null) {
      pieces.add('feels ${c.feelsLikeF!.toStringAsFixed(0)}°');
    }
    if (c.windMph != null) {
      pieces.add('${c.windMph!.toStringAsFixed(0)} mph wind');
    }
    if (c.humidityPct != null) {
      pieces.add('${c.humidityPct}% humidity');
    }
    return Row(
      children: [
        Container(
          width: 5,
          height: 5,
          decoration: const BoxDecoration(
            color: AppColors.success,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 8),
        const Text('CURRENT',
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w700,
              color: AppColors.success,
              letterSpacing: 1.2,
            )),
        const SizedBox(width: 10),
        Text('${c.tempF.toStringAsFixed(0)}°',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.2,
            )),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            pieces.join(' · '),
            style: const TextStyle(
              fontSize: 11,
              color: AppColors.textSecondary,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

class _Skeleton extends StatelessWidget {
  const _Skeleton();
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 280,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: cardBorder,
        boxShadow: cardShadow,
      ),
      child: const Center(
        child: SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
    );
  }
}

class _ErrorBox extends StatelessWidget {
  final Object error;
  final VoidCallback onRetry;
  const _ErrorBox({required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpace.lg),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: cardBorder,
        boxShadow: cardShadow,
      ),
      child: Row(
        children: [
          const Icon(Icons.cloud_off_rounded,
              color: AppColors.textTertiary, size: 16),
          const SizedBox(width: 10),
          const Expanded(
            child: Text("Couldn't load forecast",
                style: TextStyle(fontSize: 13)),
          ),
          TextButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}
