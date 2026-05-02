"""Forward-looking analysis for the dashboard.

Two deterministic pieces:
- Analog-year matching: nearest historical month in (snowpack, precip, reservoir)
  space, plus what played out over the 6 months that followed.
- Hazard risk classification: rule-based drought + flood scores combining the
  current state, the recent 6-month trend, and the live 7-day weather forecast.

A small AI narrative ties them together at the end. The two scores never depend
on the model — only the narrative does.
"""
import math
from datetime import date
from statistics import mean, stdev
from typing import Iterable

from app.models.schemas import (
    AnalogMatch,
    EventType,
    HazardRisk,
    MetricReading,
    NextEvent,
    PredictiveOutlook,
    RiskLevel,
    WeatherForecast,
)
from app.services import (
    historical_service,
    planning_service,
    projection_service,
    supply_service,
    weather_service,
)


# ---------------------------------------------------------------------------
# Analog year matching
# ---------------------------------------------------------------------------


def _scaled_distance(
    a: MetricReading,
    b: MetricReading,
    snow_std: float,
    precip_std: float,
    res_std: float,
) -> float:
    ds = (a.snowpack_pct - b.snowpack_pct) / max(snow_std, 1.0)
    dp = (a.precip_pct - b.precip_pct) / max(precip_std, 1.0)
    dr = (a.reservoir_pct - b.reservoir_pct) / max(res_std, 1.0)
    return math.sqrt(ds * ds + dp * dp + dr * dr)


def _next_window_summary(
    anchor: MetricReading,
    all_readings: list[MetricReading],
    months: int = 6,
) -> str:
    """Plain-language description of the 6 months following the analog."""
    after = [r for r in all_readings if r.date > anchor.date][:months]
    if len(after) < 2:
        return "Limited history after this date — too close to the dataset edge."

    snow_end = after[-1].snowpack_pct
    precip_avg = mean(r.precip_pct for r in after)
    res_change = after[-1].reservoir_pct - anchor.reservoir_pct

    snow_word = (
        "stayed thin"
        if snow_end < 70
        else "recovered toward normal"
        if snow_end < 100
        else "rebuilt strongly"
    )
    res_word = (
        f"reservoirs gained {res_change:.0f} pts"
        if res_change > 5
        else f"reservoirs slipped {abs(res_change):.0f} pts"
        if res_change < -5
        else "reservoirs held roughly steady"
    )
    precip_word = (
        "dry"
        if precip_avg < 80
        else "near-normal"
        if precip_avg < 110
        else "wet"
    )

    return (
        f"In the {months} months that followed, snowpack {snow_word}, "
        f"precipitation averaged {precip_avg:.0f}% ({precip_word}), and {res_word}."
    )


def _year_label(year: int) -> str:
    for y in historical_service.compare_years():
        if y.year == year:
            return y.label
    return "Mixed"


def find_analog(current: MetricReading) -> AnalogMatch:
    all_readings = supply_service.load_readings()
    candidates = [r for r in all_readings if r.date != current.date]

    snows = [r.snowpack_pct for r in candidates]
    precips = [r.precip_pct for r in candidates]
    reservoirs = [r.reservoir_pct for r in candidates]
    snow_std = stdev(snows) if len(snows) > 1 else 1.0
    precip_std = stdev(precips) if len(precips) > 1 else 1.0
    res_std = stdev(reservoirs) if len(reservoirs) > 1 else 1.0

    best = min(
        candidates,
        key=lambda r: _scaled_distance(current, r, snow_std, precip_std, res_std),
    )
    dist = _scaled_distance(current, best, snow_std, precip_std, res_std)
    similarity = max(0.0, 1.0 - dist / 4.0)  # ~0..1, 4σ ≈ never-similar

    return AnalogMatch(
        date=best.date,
        label=best.date.strftime("%B %Y"),
        similarity=round(similarity, 3),
        snowpack_pct=best.snowpack_pct,
        precip_pct=best.precip_pct,
        reservoir_pct=best.reservoir_pct,
        year_label=_year_label(best.date.year),
        next_window_summary=_next_window_summary(best, all_readings),
    )


# ---------------------------------------------------------------------------
# Risk classification
# ---------------------------------------------------------------------------


def _level_for(score: int) -> RiskLevel:
    if score >= 70:
        return "high"
    if score >= 50:
        return "elevated"
    if score >= 25:
        return "moderate"
    return "low"


def _drought_risk(
    current: MetricReading,
    six_month_ago: MetricReading,
    forecast_precip_in: float,
) -> HazardRisk:
    score = 0
    reasons: list[str] = []

    # current snowpack
    if current.snowpack_pct < 70:
        score += 35
        reasons.append(
            f"Snowpack at {current.snowpack_pct:.0f}% — below the 70% concern threshold."
        )
    elif current.snowpack_pct < 90:
        score += 20
        reasons.append(
            f"Snowpack at {current.snowpack_pct:.0f}% — below average."
        )

    # current precip
    if current.precip_pct < 70:
        score += 30
        reasons.append(
            f"Precipitation at {current.precip_pct:.0f}% — formal drought signal."
        )
    elif current.precip_pct < 90:
        score += 12
        reasons.append(
            f"Precipitation at {current.precip_pct:.0f}% — slightly dry."
        )

    # reservoir trend
    res_delta = current.reservoir_pct - six_month_ago.reservoir_pct
    if res_delta <= -15:
        score += 20
        reasons.append(
            f"Reservoirs lost {abs(res_delta):.0f} pts in 6 months — fast drawdown."
        )
    elif res_delta <= -8:
        score += 10
        reasons.append(
            f"Reservoirs trending down ({res_delta:.0f} pts in 6 months)."
        )

    # forecast: dry near-term
    if forecast_precip_in < 0.2:
        score += 8
        reasons.append("7-day forecast shows minimal precipitation — no relief near-term.")

    if not reasons:
        reasons.append("All three signals are within or above their healthy bands.")

    return HazardRisk(level=_level_for(score), score=min(score, 100), reasoning=reasons)


def _flood_risk(
    current: MetricReading,
    six_month_ago: MetricReading,
    forecast_precip_in: float,
    forecast_max_high_f: float,
) -> HazardRisk:
    score = 0
    reasons: list[str] = []

    # reservoir capacity buffer
    if current.reservoir_pct >= 95:
        score += 30
        reasons.append(
            f"Reservoirs at {current.reservoir_pct:.0f}% — little spare capacity for runoff."
        )
    elif current.reservoir_pct >= 85:
        score += 15
        reasons.append(
            f"Reservoirs at {current.reservoir_pct:.0f}% — limited buffer if a storm hits."
        )

    # recent wet
    if current.precip_pct >= 130:
        score += 20
        reasons.append(
            f"Recent precipitation at {current.precip_pct:.0f}% — well above normal."
        )
    elif current.precip_pct >= 110:
        score += 10
        reasons.append(
            f"Recent precipitation at {current.precip_pct:.0f}% — wet pattern."
        )

    # near-term storm
    if forecast_precip_in >= 1.5:
        score += 25
        reasons.append(
            f"7-day forecast: {forecast_precip_in:.1f}\" precip expected — significant event."
        )
    elif forecast_precip_in >= 0.7:
        score += 10
        reasons.append(
            f"7-day forecast: {forecast_precip_in:.1f}\" precip expected."
        )

    # rapid melt risk: high snowpack + warm forecast
    if current.snowpack_pct >= 110 and forecast_max_high_f >= 60:
        score += 15
        reasons.append(
            f"Heavy snowpack ({current.snowpack_pct:.0f}%) plus warm forecast ({forecast_max_high_f:.0f}°F)"
            " raises rapid-melt risk."
        )

    if not reasons:
        reasons.append("Storage buffer healthy and no major precipitation event expected.")

    return HazardRisk(level=_level_for(score), score=min(score, 100), reasoning=reasons)


# ---------------------------------------------------------------------------
# Next significant precipitation event from the 7-day forecast
# ---------------------------------------------------------------------------


def _next_event(forecast: WeatherForecast) -> NextEvent:
    """Find the first day in the 7-day window with a significant precip event."""
    if not forecast.days:
        return NextEvent(
            type="none",
            date=None,
            days_away=None,
            precip_inches=0.0,
            snowfall_inches=0.0,
            label="Quiet week",
            summary="No significant precipitation expected in the next 7 days.",
        )

    today = forecast.days[0].date
    for d in forecast.days:
        # Significance thresholds — modest enough to surface real events but
        # not noise from trace amounts.
        if d.snowfall_inches >= 1.5 or d.precip_inches >= 0.4:
            days_away = (d.date - today).days
            day_word = "today" if days_away == 0 else (
                "tomorrow" if days_away == 1 else d.date.strftime("%a, %b %-d")
            )

            is_snow_dominant = d.snowfall_inches >= 1.0
            type_: EventType = (
                "snow" if d.snowfall_inches >= 1.5 and d.precip_inches < 0.6
                else "rain" if d.snowfall_inches < 1.0
                else "mixed"
            )

            if d.snowfall_inches >= 6:
                label = "Heavy snow event"
                summary = (
                    f"~{d.snowfall_inches:.0f}\" of snow {day_word} — major snowpack boost."
                )
            elif d.snowfall_inches >= 1.5:
                label = "Snow event"
                summary = (
                    f"~{d.snowfall_inches:.0f}\" of snow {day_word}; "
                    f"{d.precip_inches:.1f}\" precip total. Helps snowpack."
                )
            elif d.precip_inches >= 1.0:
                label = "Heavy rain event"
                summary = (
                    f"{d.precip_inches:.1f}\" of rain {day_word} — runs off fast, "
                    "minimal snowpack benefit."
                )
            else:
                label = "Rain"
                summary = f"{d.precip_inches:.1f}\" of rain {day_word}."

            return NextEvent(
                type=type_,
                date=d.date,
                days_away=days_away,
                precip_inches=d.precip_inches,
                snowfall_inches=d.snowfall_inches,
                label=label,
                summary=summary,
            )

    # Nothing significant in the window — describe what dry/cold/mild looks like.
    high = max(d.temp_high_f for d in forecast.days)
    return NextEvent(
        type="none",
        date=None,
        days_away=None,
        precip_inches=0.0,
        snowfall_inches=0.0,
        label="Quiet week",
        summary=f"No significant precipitation in the next 7 days (highs to {high:.0f}°F).",
    )


# ---------------------------------------------------------------------------
# Public entry point
# ---------------------------------------------------------------------------


def predictive_outlook(region: str = "statewide") -> PredictiveOutlook:
    from app.services.llm_service import get_llm_service

    readings = supply_service.load_readings()
    if len(readings) < 7:
        raise ValueError("Need at least 7 historical readings for predictions.")

    current = readings[-1]
    six_months_ago = readings[-7]

    # Live weather forecast (with cache + fallback already handled by service).
    weather = weather_service.fetch_forecast()
    forecast_precip = sum(d.precip_inches for d in weather.days)
    forecast_max_high = max((d.temp_high_f for d in weather.days), default=0.0)

    analog = find_analog(current)
    drought = _drought_risk(current, six_months_ago, forecast_precip)
    flood = _flood_risk(current, six_months_ago, forecast_precip, forecast_max_high)
    next_evt = _next_event(weather)

    snow_band, precip_band, res_band = supply_service.classify_reading(current)
    planning = planning_service.planning_implications(
        snow_band, precip_band, res_band, drought, flood,
        analog_year=analog.date.year,
        region=region,
    )
    projection = projection_service.project_outlook(horizon_months=6)

    llm = get_llm_service()
    narrative = llm.predictive_narrative(
        {
            "horizon": "Next 90 days",
            "current_as_of": current.date.isoformat(),
            "next_event": {
                "type": next_evt.type,
                "label": next_evt.label,
                "days_away": next_evt.days_away,
                "summary": next_evt.summary,
            },
            "drought": {"level": drought.level, "reasoning": drought.reasoning},
            "flood": {"level": flood.level, "reasoning": flood.reasoning},
            "analog": {
                "label": analog.label,
                "year_label": analog.year_label,
                "next_window": analog.next_window_summary,
            },
            "planning": {
                "estimated_ag_allocation_pct": planning.estimated_ag_allocation_pct,
                "citizen_headline": planning.citizen.headline,
                "farmer_headline": planning.farmer.headline,
                "supply_headline": planning.supply.headline,
            },
            "model_projection": {
                "snowpack_3mo": [
                    {"date": p.target_date.isoformat(), "value": p.projected_value}
                    for p in projection.snowpack[:3]
                ],
                "reservoir_3mo": [
                    {"date": p.target_date.isoformat(), "value": p.projected_value}
                    for p in projection.reservoir[:3]
                ],
            },
            "forecast_precip_inches": round(forecast_precip, 2),
        }
    )

    return PredictiveOutlook(
        horizon="Next 90 days",
        next_event=next_evt,
        drought_risk=drought,
        flood_risk=flood,
        analog=analog,
        projection=projection,
        planning=planning,
        ai_narrative=narrative,
    )
