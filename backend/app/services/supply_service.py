"""Loads the California water-supply dataset and applies the challenge's
metric bands deterministically.

The bands and combined-outlook logic come straight from the brief — no AI here.
"""
import json
from datetime import date, datetime
from functools import lru_cache
from typing import Iterable

from app.core.config import get_settings
from app.models.schemas import (
    CombinedOutlook,
    MetricBand,
    MetricReading,
)

DATASET_FILE = "california_supply.json"


def _parse_date(raw: str) -> date:
    # dataset is "M/D/YY" (e.g. "12/1/25")
    return datetime.strptime(raw, "%m/%d/%y").date()


@lru_cache
def load_readings() -> list[MetricReading]:
    settings = get_settings()
    raw = json.loads((settings.data_dir / DATASET_FILE).read_text(encoding="utf-8"))
    readings = [
        MetricReading(
            date=_parse_date(r["Date"]),
            snowpack_pct=float(r["Snowpack"]),
            precip_pct=float(r["Precip"]),
            reservoir_pct=float(r["Reservoir"]),
        )
        for r in raw
    ]
    readings.sort(key=lambda r: r.date)
    return readings


def reload_readings() -> int:
    """Bust the cache so a refreshed dataset file takes effect immediately."""
    load_readings.cache_clear()
    return len(load_readings())


def latest_reading() -> MetricReading:
    return load_readings()[-1]


def history(months: int | None = None) -> list[MetricReading]:
    rows = load_readings()
    if months is None:
        return rows
    return rows[-months:]


# ---------- Metric band classification (brief verbatim) -----------------------


def classify_snowpack(value: float) -> MetricBand:
    if value >= 120:
        label, severity = "Excellent", "good"
    elif value >= 90:
        label, severity = "Average", "neutral"
    elif value >= 70:
        label, severity = "Below average", "watch"
    else:
        label, severity = "Concerning", "concern"
    return MetricBand(value=value, label=label, severity=severity, metric="snowpack")


def classify_precip(value: float) -> MetricBand:
    if value >= 110:
        label, severity = "Wet", "good"
    elif value >= 90:
        label, severity = "Normal", "neutral"
    elif value >= 70:
        label, severity = "Dry", "watch"
    else:
        label, severity = "Drought signal", "concern"
    return MetricBand(value=value, label=label, severity=severity, metric="precip")


def classify_reservoir(value: float) -> MetricBand:
    if value >= 85:
        label, severity = "Strong", "good"
    elif value >= 70:
        label, severity = "Healthy", "neutral"
    elif value >= 50:
        label, severity = "Watch", "watch"
    else:
        label, severity = "Concern", "concern"
    return MetricBand(value=value, label=label, severity=severity, metric="reservoir")


def classify_reading(r: MetricReading) -> tuple[MetricBand, MetricBand, MetricBand]:
    return (
        classify_snowpack(r.snowpack_pct),
        classify_precip(r.precip_pct),
        classify_reservoir(r.reservoir_pct),
    )


# ---------- Combined outlook -------------------------------------------------

_SEVERITY_RANK = {"good": 3, "neutral": 2, "watch": 1, "concern": 0}


def _severity_score(*bands: MetricBand) -> float:
    return sum(_SEVERITY_RANK[b.severity] for b in bands) / len(bands)


def combined_outlook(
    snow: MetricBand, precip: MetricBand, reservoir: MetricBand
) -> CombinedOutlook:
    """Forward-looking call. Snowpack carries the most weight because it predicts
    next year's supply; reservoirs can buy time but can't fix a bad snow year alone.
    """
    severities = [snow.severity, precip.severity, reservoir.severity]

    # All three at "good" → Strong
    if all(s == "good" for s in severities):
        return CombinedOutlook(
            label="Strong",
            severity="good",
            rationale="All three signals are at or above their healthy bands.",
        )

    # Concern paths
    if snow.severity == "concern" and reservoir.severity in {"watch", "concern"}:
        return CombinedOutlook(
            label="Concern",
            severity="concern",
            rationale="Snowpack is concerning and reservoirs aren't strong enough to compensate.",
        )
    if reservoir.severity == "concern":
        return CombinedOutlook(
            label="Concern",
            severity="concern",
            rationale="Reservoir storage is below the 50% concern threshold.",
        )
    if severities.count("concern") >= 2:
        return CombinedOutlook(
            label="Concern",
            severity="concern",
            rationale="Multiple signals are deep in concern territory at the same time.",
        )

    # Snowpack concerning but reservoir not → Watch (today buffered, future at risk)
    if snow.severity == "concern":
        return CombinedOutlook(
            label="Watch",
            severity="watch",
            rationale="Snowpack is concerning; reservoirs are buying time but next year is at risk.",
        )

    # No concerns. Any "watch" signal → Watch.
    if any(s == "watch" for s in severities):
        return CombinedOutlook(
            label="Watch",
            severity="watch",
            rationale="At least one signal is below its healthy band — worth monitoring.",
        )

    # All neutral (or a mix of neutral and good) → Stable
    return CombinedOutlook(
        label="Stable",
        severity="neutral",
        rationale="Signals are in or above their healthy bands with no individual metric in concerning territory.",
    )
