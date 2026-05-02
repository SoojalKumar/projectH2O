enum Severity { good, neutral, watch, concern }

Severity severityFromString(String s) => switch (s) {
      'good' => Severity.good,
      'neutral' => Severity.neutral,
      'watch' => Severity.watch,
      'concern' => Severity.concern,
      _ => Severity.neutral,
    };

class MetricBand {
  final double value;
  final String label;
  final Severity severity;
  final String metric; // 'snowpack' | 'precip' | 'reservoir'

  MetricBand({
    required this.value,
    required this.label,
    required this.severity,
    required this.metric,
  });

  factory MetricBand.fromJson(Map<String, dynamic> j) => MetricBand(
        value: (j['value'] as num).toDouble(),
        label: j['label'] as String,
        severity: severityFromString(j['severity'] as String),
        metric: j['metric'] as String,
      );
}

class MetricReading {
  final DateTime date;
  final double snowpackPct;
  final double precipPct;
  final double reservoirPct;

  MetricReading({
    required this.date,
    required this.snowpackPct,
    required this.precipPct,
    required this.reservoirPct,
  });

  factory MetricReading.fromJson(Map<String, dynamic> j) => MetricReading(
        date: DateTime.parse(j['date'] as String),
        snowpackPct: (j['snowpack_pct'] as num).toDouble(),
        precipPct: (j['precip_pct'] as num).toDouble(),
        reservoirPct: (j['reservoir_pct'] as num).toDouble(),
      );

  double valueFor(String metric) => switch (metric) {
        'snowpack' => snowpackPct,
        'precip' => precipPct,
        'reservoir' => reservoirPct,
        _ => 0.0,
      };
}

class CombinedOutlook {
  final String label; // Strong | Stable | Watch | Concern
  final Severity severity;
  final String rationale;

  CombinedOutlook({required this.label, required this.severity, required this.rationale});

  factory CombinedOutlook.fromJson(Map<String, dynamic> j) => CombinedOutlook(
        label: j['label'] as String,
        severity: severityFromString(j['severity'] as String),
        rationale: j['rationale'] as String,
      );
}

class MultiSignalAlert {
  final String alertId;
  final Severity severity;
  final String title;
  final String description;
  final String? aiContext;

  MultiSignalAlert({
    required this.alertId,
    required this.severity,
    required this.title,
    required this.description,
    this.aiContext,
  });

  factory MultiSignalAlert.fromJson(Map<String, dynamic> j) => MultiSignalAlert(
        alertId: j['alert_id'] as String,
        severity: severityFromString(j['severity'] as String),
        title: j['title'] as String,
        description: j['description'] as String,
        aiContext: j['ai_context'] as String?,
      );
}

class SupplyDashboard {
  final DateTime asOf;
  final MetricBand snowpack;
  final MetricBand precip;
  final MetricBand reservoir;
  final CombinedOutlook outlook;
  final List<MultiSignalAlert> alerts;
  final String aiSummary;

  SupplyDashboard({
    required this.asOf,
    required this.snowpack,
    required this.precip,
    required this.reservoir,
    required this.outlook,
    required this.alerts,
    required this.aiSummary,
  });

  factory SupplyDashboard.fromJson(Map<String, dynamic> j) => SupplyDashboard(
        asOf: DateTime.parse(j['as_of'] as String),
        snowpack: MetricBand.fromJson(j['snowpack'] as Map<String, dynamic>),
        precip: MetricBand.fromJson(j['precip'] as Map<String, dynamic>),
        reservoir: MetricBand.fromJson(j['reservoir'] as Map<String, dynamic>),
        outlook: CombinedOutlook.fromJson(j['outlook'] as Map<String, dynamic>),
        alerts: (j['alerts'] as List)
            .map((e) => MultiSignalAlert.fromJson(e as Map<String, dynamic>))
            .toList(),
        aiSummary: j['ai_summary'] as String,
      );
}

class HistoricalYear {
  final int year;
  final double avgSnowpack;
  final double avgPrecip;
  final double avgReservoir;
  final String label; // Strong | Mixed | Weak
  final Severity severity;

  HistoricalYear({
    required this.year,
    required this.avgSnowpack,
    required this.avgPrecip,
    required this.avgReservoir,
    required this.label,
    required this.severity,
  });

  factory HistoricalYear.fromJson(Map<String, dynamic> j) => HistoricalYear(
        year: j['year'] as int,
        avgSnowpack: (j['avg_snowpack'] as num).toDouble(),
        avgPrecip: (j['avg_precip'] as num).toDouble(),
        avgReservoir: (j['avg_reservoir'] as num).toDouble(),
        label: j['label'] as String,
        severity: severityFromString(j['severity'] as String),
      );
}

class HistoricalComparison {
  final List<HistoricalYear> years;
  final int bestYear;
  final int worstYear;
  final int currentYear;
  final String aiSummary;

  HistoricalComparison({
    required this.years,
    required this.bestYear,
    required this.worstYear,
    required this.currentYear,
    required this.aiSummary,
  });

  factory HistoricalComparison.fromJson(Map<String, dynamic> j) => HistoricalComparison(
        years: (j['years'] as List)
            .map((e) => HistoricalYear.fromJson(e as Map<String, dynamic>))
            .toList(),
        bestYear: j['best_year'] as int,
        worstYear: j['worst_year'] as int,
        currentYear: j['current_year'] as int,
        aiSummary: j['ai_summary'] as String,
      );
}

enum WeatherCondition { clear, partlyCloudy, cloudy, rain, snow, storm, fog }

WeatherCondition weatherFromString(String s) => switch (s) {
      'clear' => WeatherCondition.clear,
      'partly_cloudy' => WeatherCondition.partlyCloudy,
      'cloudy' => WeatherCondition.cloudy,
      'rain' => WeatherCondition.rain,
      'snow' => WeatherCondition.snow,
      'storm' => WeatherCondition.storm,
      'fog' => WeatherCondition.fog,
      _ => WeatherCondition.cloudy,
    };

class WeatherDay {
  final DateTime date;
  final double tempHighF;
  final double tempLowF;
  final double precipInches;
  final double snowfallInches;
  final WeatherCondition condition;

  WeatherDay({
    required this.date,
    required this.tempHighF,
    required this.tempLowF,
    required this.precipInches,
    required this.snowfallInches,
    required this.condition,
  });

  factory WeatherDay.fromJson(Map<String, dynamic> j) => WeatherDay(
        date: DateTime.parse(j['date'] as String),
        tempHighF: (j['temp_high_f'] as num).toDouble(),
        tempLowF: (j['temp_low_f'] as num).toDouble(),
        precipInches: (j['precip_inches'] as num).toDouble(),
        snowfallInches: (j['snowfall_inches'] as num).toDouble(),
        condition: weatherFromString(j['condition'] as String),
      );
}

class CurrentConditions {
  final double tempF;
  final double? feelsLikeF;
  final int? humidityPct;
  final double? windMph;
  final WeatherCondition condition;
  final DateTime observedAt;

  CurrentConditions({
    required this.tempF,
    required this.feelsLikeF,
    required this.humidityPct,
    required this.windMph,
    required this.condition,
    required this.observedAt,
  });

  factory CurrentConditions.fromJson(Map<String, dynamic> j) {
    final raw = j['observed_at'] as String;
    DateTime parsed;
    try {
      parsed = DateTime.parse(raw);
    } catch (_) {
      parsed = DateTime.now();
    }
    return CurrentConditions(
      tempF: (j['temp_f'] as num).toDouble(),
      feelsLikeF: (j['feels_like_f'] as num?)?.toDouble(),
      humidityPct: j['humidity_pct'] as int?,
      windMph: (j['wind_mph'] as num?)?.toDouble(),
      condition: weatherFromString(j['condition'] as String),
      observedAt: parsed,
    );
  }
}

enum RiskLevel { low, moderate, elevated, high }

RiskLevel riskLevelFromString(String s) => switch (s) {
      'low' => RiskLevel.low,
      'moderate' => RiskLevel.moderate,
      'elevated' => RiskLevel.elevated,
      'high' => RiskLevel.high,
      _ => RiskLevel.low,
    };

class HazardRisk {
  final RiskLevel level;
  final int score; // 0-100
  final List<String> reasoning;

  HazardRisk({required this.level, required this.score, required this.reasoning});

  factory HazardRisk.fromJson(Map<String, dynamic> j) => HazardRisk(
        level: riskLevelFromString(j['level'] as String),
        score: j['score'] as int,
        reasoning: (j['reasoning'] as List).cast<String>(),
      );
}

class AnalogMatch {
  final DateTime date;
  final String label;
  final double similarity;
  final double snowpackPct;
  final double precipPct;
  final double reservoirPct;
  final String yearLabel;
  final String nextWindowSummary;

  AnalogMatch({
    required this.date,
    required this.label,
    required this.similarity,
    required this.snowpackPct,
    required this.precipPct,
    required this.reservoirPct,
    required this.yearLabel,
    required this.nextWindowSummary,
  });

  factory AnalogMatch.fromJson(Map<String, dynamic> j) => AnalogMatch(
        date: DateTime.parse(j['date'] as String),
        label: j['label'] as String,
        similarity: (j['similarity'] as num).toDouble(),
        snowpackPct: (j['snowpack_pct'] as num).toDouble(),
        precipPct: (j['precip_pct'] as num).toDouble(),
        reservoirPct: (j['reservoir_pct'] as num).toDouble(),
        yearLabel: j['year_label'] as String,
        nextWindowSummary: j['next_window_summary'] as String,
      );
}

enum EventType { snow, rain, mixed, none }

EventType eventTypeFromString(String s) => switch (s) {
      'snow' => EventType.snow,
      'rain' => EventType.rain,
      'mixed' => EventType.mixed,
      'none' => EventType.none,
      _ => EventType.none,
    };

class NextEvent {
  final EventType type;
  final DateTime? date;
  final int? daysAway;
  final double precipInches;
  final double snowfallInches;
  final String label;
  final String summary;

  NextEvent({
    required this.type,
    required this.date,
    required this.daysAway,
    required this.precipInches,
    required this.snowfallInches,
    required this.label,
    required this.summary,
  });

  factory NextEvent.fromJson(Map<String, dynamic> j) => NextEvent(
        type: eventTypeFromString(j['type'] as String),
        date: j['date'] == null ? null : DateTime.parse(j['date'] as String),
        daysAway: j['days_away'] as int?,
        precipInches: (j['precip_inches'] as num).toDouble(),
        snowfallInches: (j['snowfall_inches'] as num).toDouble(),
        label: j['label'] as String,
        summary: j['summary'] as String,
      );
}

class MetricProjection {
  final String metric;
  final DateTime targetDate;
  final double projectedValue;
  final double bandLow;
  final double bandHigh;
  final String confidence;

  MetricProjection({
    required this.metric,
    required this.targetDate,
    required this.projectedValue,
    required this.bandLow,
    required this.bandHigh,
    required this.confidence,
  });

  factory MetricProjection.fromJson(Map<String, dynamic> j) => MetricProjection(
        metric: j['metric'] as String,
        targetDate: DateTime.parse(j['target_date'] as String),
        projectedValue: (j['projected_value'] as num).toDouble(),
        bandLow: (j['band_low'] as num).toDouble(),
        bandHigh: (j['band_high'] as num).toDouble(),
        confidence: j['confidence'] as String,
      );
}

class ProjectionBundle {
  final int horizonMonths;
  final List<MetricProjection> snowpack;
  final List<MetricProjection> precip;
  final List<MetricProjection> reservoir;
  final String method;
  final int trainedOnMonths;

  ProjectionBundle({
    required this.horizonMonths,
    required this.snowpack,
    required this.precip,
    required this.reservoir,
    required this.method,
    required this.trainedOnMonths,
  });

  factory ProjectionBundle.fromJson(Map<String, dynamic> j) => ProjectionBundle(
        horizonMonths: j['horizon_months'] as int,
        snowpack: (j['snowpack'] as List)
            .map((e) => MetricProjection.fromJson(e as Map<String, dynamic>))
            .toList(),
        precip: (j['precip'] as List)
            .map((e) => MetricProjection.fromJson(e as Map<String, dynamic>))
            .toList(),
        reservoir: (j['reservoir'] as List)
            .map((e) => MetricProjection.fromJson(e as Map<String, dynamic>))
            .toList(),
        method: j['method'] as String,
        trainedOnMonths: j['trained_on_months'] as int,
      );
}

class PlanningImplication {
  final String audience;
  final String headline;
  final String detail;
  final Severity severity;

  PlanningImplication({
    required this.audience,
    required this.headline,
    required this.detail,
    required this.severity,
  });

  factory PlanningImplication.fromJson(Map<String, dynamic> j) => PlanningImplication(
        audience: j['audience'] as String,
        headline: j['headline'] as String,
        detail: j['detail'] as String,
        severity: severityFromString(j['severity'] as String),
      );
}

class PlanningImplications {
  final PlanningImplication citizen;
  final PlanningImplication farmer;
  final PlanningImplication supply;
  final int estimatedAgAllocationPct;
  final String allocationBasis;
  final String region;

  PlanningImplications({
    required this.citizen,
    required this.farmer,
    required this.supply,
    required this.estimatedAgAllocationPct,
    required this.allocationBasis,
    required this.region,
  });

  factory PlanningImplications.fromJson(Map<String, dynamic> j) => PlanningImplications(
        citizen: PlanningImplication.fromJson(j['citizen'] as Map<String, dynamic>),
        farmer: PlanningImplication.fromJson(j['farmer'] as Map<String, dynamic>),
        supply: PlanningImplication.fromJson(j['supply'] as Map<String, dynamic>),
        estimatedAgAllocationPct: j['estimated_ag_allocation_pct'] as int,
        allocationBasis: j['allocation_basis'] as String? ?? '',
        region: j['region'] as String? ?? 'statewide',
      );
}

class PredictiveOutlook {
  final String horizon;
  final NextEvent nextEvent;
  final HazardRisk droughtRisk;
  final HazardRisk floodRisk;
  final AnalogMatch analog;
  final ProjectionBundle projection;
  final PlanningImplications planning;
  final String aiNarrative;

  PredictiveOutlook({
    required this.horizon,
    required this.nextEvent,
    required this.droughtRisk,
    required this.floodRisk,
    required this.analog,
    required this.projection,
    required this.planning,
    required this.aiNarrative,
  });

  factory PredictiveOutlook.fromJson(Map<String, dynamic> j) => PredictiveOutlook(
        horizon: j['horizon'] as String,
        nextEvent: NextEvent.fromJson(j['next_event'] as Map<String, dynamic>),
        droughtRisk: HazardRisk.fromJson(j['drought_risk'] as Map<String, dynamic>),
        floodRisk: HazardRisk.fromJson(j['flood_risk'] as Map<String, dynamic>),
        analog: AnalogMatch.fromJson(j['analog'] as Map<String, dynamic>),
        projection: ProjectionBundle.fromJson(j['projection'] as Map<String, dynamic>),
        planning: PlanningImplications.fromJson(j['planning'] as Map<String, dynamic>),
        aiNarrative: j['ai_narrative'] as String,
      );
}

class WeatherForecast {
  final String location;
  final int elevationFt;
  final DateTime today; // dataset-time anchor
  final List<WeatherDay> days;
  final CurrentConditions? current;
  final String headline;
  final String source; // always 'dataset' now

  WeatherForecast({
    required this.location,
    required this.elevationFt,
    required this.today,
    required this.days,
    required this.current,
    required this.headline,
    required this.source,
  });

  factory WeatherForecast.fromJson(Map<String, dynamic> j) => WeatherForecast(
        location: j['location'] as String,
        elevationFt: j['elevation_ft'] as int,
        today: DateTime.parse(j['today'] as String),
        days: (j['days'] as List)
            .map((e) => WeatherDay.fromJson(e as Map<String, dynamic>))
            .toList(),
        current: j['current'] == null
            ? null
            : CurrentConditions.fromJson(j['current'] as Map<String, dynamic>),
        headline: j['headline'] as String,
        source: j['source'] as String,
      );
}

class OutlookReport {
  final String periodLabel;
  final List<String> improved;
  final List<String> worsened;
  final List<String> stillRisky;
  final List<String> watchNext;
  final String aiSummary;

  OutlookReport({
    required this.periodLabel,
    required this.improved,
    required this.worsened,
    required this.stillRisky,
    required this.watchNext,
    required this.aiSummary,
  });

  factory OutlookReport.fromJson(Map<String, dynamic> j) => OutlookReport(
        periodLabel: j['period_label'] as String,
        improved: (j['improved'] as List).cast<String>(),
        worsened: (j['worsened'] as List).cast<String>(),
        stillRisky: (j['still_risky'] as List).cast<String>(),
        watchNext: (j['watch_next'] as List).cast<String>(),
        aiSummary: j['ai_summary'] as String,
      );
}
