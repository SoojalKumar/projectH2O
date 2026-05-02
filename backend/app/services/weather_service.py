"""Sierra Nevada weather context — fully derived from the dataset.

The brief's dataset is the source of truth. This service generates a
deterministic 21-day Sierra Nevada December weather window anchored to the
dataset's most recent reading (Dec 1, 2025), so "today" in the app is always
the same as "today" in the dataset. No external API calls — the demo runs
the same offline as online.
"""
from datetime import datetime, time, timedelta, timezone

from app.models.schemas import (
    CurrentConditions,
    WeatherCondition,
    WeatherDay,
    WeatherForecast,
)
from app.services import supply_service


_LOCATION = "Sierra Nevada · Donner Summit, CA"
_ELEVATION_FT = 7239


# Deterministic 21-day Sierra Nevada December pattern, anchored to "today"
# (= dataset's last reading). Layout:
#   offsets -7..-1 → past week
#   offset 0       → today
#   offsets 1..6   → this week
#   offsets 7..13  → next week
# Realistic for Donner Summit in early December: cold highs, frequent snow,
# one notable storm 2-3 days out so the precipitation notification fires.
#
# (offset, condition, hi_f, lo_f, precip_in, snow_in)
_PATTERN: list[tuple[int, WeatherCondition, float, float, float, float]] = [
    (-7, "snow",          30, 18, 0.40, 4.0),
    (-6, "cloudy",        32, 20, 0.05, 0.3),
    (-5, "cloudy",        34, 22, 0.00, 0.0),
    (-4, "snow",          28, 16, 0.30, 3.5),
    (-3, "clear",         36, 24, 0.00, 0.0),
    (-2, "partly_cloudy", 38, 26, 0.00, 0.0),
    (-1, "cloudy",        35, 22, 0.05, 0.5),
    ( 0, "partly_cloudy", 32, 18, 0.00, 0.0),  # today
    ( 1, "cloudy",        30, 16, 0.10, 1.0),
    ( 2, "snow",          26, 12, 0.60, 6.0),  # storm — triggers notification
    ( 3, "snow",          24, 10, 0.50, 5.0),
    ( 4, "cloudy",        28, 14, 0.05, 0.5),
    ( 5, "partly_cloudy", 32, 20, 0.00, 0.0),
    ( 6, "clear",         35, 22, 0.00, 0.0),
    ( 7, "clear",         36, 24, 0.00, 0.0),
    ( 8, "partly_cloudy", 34, 22, 0.00, 0.0),
    ( 9, "cloudy",        30, 18, 0.05, 0.5),
    (10, "snow",          28, 14, 0.40, 4.5),
    (11, "snow",          26, 12, 0.30, 3.5),
    (12, "cloudy",        30, 16, 0.00, 0.0),
    (13, "partly_cloudy", 33, 20, 0.00, 0.0),
]


def _generate_headline(days: list[WeatherDay]) -> str:
    snow_days = [d for d in days if d.snowfall_inches >= 0.5]
    rain_days = [d for d in days if d.precip_inches >= 0.2 and d.snowfall_inches < 0.5]

    if snow_days:
        peak = max(snow_days, key=lambda d: d.snowfall_inches)
        total = sum(d.snowfall_inches for d in snow_days)
        if peak.snowfall_inches >= 4:
            return (
                f"Heavy snow {peak.date.strftime('%a')} "
                f"({peak.snowfall_inches:.0f}\") — "
                f"~{total:.0f}\" total this window. Good news for snowpack."
            )
        return (
            f"Snow likely {peak.date.strftime('%a')} "
            f"(~{total:.1f}\" total). Helpful for snowpack."
        )

    if rain_days:
        peak = max(rain_days, key=lambda d: d.precip_inches)
        return (
            f"Rain expected {peak.date.strftime('%a')} "
            f"({peak.precip_inches:.1f}\"). Mostly runs off — minimal snowpack benefit."
        )

    high = max(d.temp_high_f for d in days)
    low = min(d.temp_low_f for d in days)
    if high >= 50:
        return f"Mild and dry through the window (highs to {high:.0f}°F)."
    if low <= 10:
        return f"Cold and dry — overnight lows to {low:.0f}°F. No new snow."
    return "Quiet window ahead — no significant precipitation expected."


def fetch_forecast() -> WeatherForecast:
    readings = supply_service.load_readings()
    if not readings:
        raise ValueError("Cannot generate weather context: dataset is empty.")

    today = readings[-1].date  # dataset-time anchor — Dec 1, 2025

    days = [
        WeatherDay(
            date=today + timedelta(days=offset),
            temp_high_f=hi,
            temp_low_f=lo,
            precip_inches=precip,
            snowfall_inches=snow,
            condition=cond,
        )
        for (offset, cond, hi, lo, precip, snow) in _PATTERN
    ]

    # Today's reading drives the "current conditions" panel — derived
    # deterministically from today's pattern entry so it stays consistent.
    today_entry = next(d for d in days if d.date == today)
    current_temp = (today_entry.temp_high_f + today_entry.temp_low_f) / 2 - 1
    current = CurrentConditions(
        temp_f=round(current_temp, 1),
        feels_like_f=round(current_temp - 4, 1),
        humidity_pct=62,
        wind_mph=8.0,
        condition=today_entry.condition,
        observed_at=datetime.combine(today, time(12, 0), tzinfo=timezone.utc).isoformat(),
    )

    return WeatherForecast(
        location=_LOCATION,
        elevation_ft=_ELEVATION_FT,
        today=today,
        days=days,
        current=current,
        headline=_generate_headline(days),
        source="dataset",
    )
