"""Statistical projection model trained on the full 10-year supply record.

Method: seasonal naïve + linear yearly trend.
- For each metric, compute the per-calendar-month average across all years —
  this captures California's strong seasonality (snowpack peaks Apr 1, dries
  out by fall; reservoirs draw down through summer).
- Compute a linear regression on the per-year average to capture multi-year
  drift (drought/recovery cycles).
- Projection = seasonal_value(target_month) + trend_slope * years_ahead.
- Confidence band = ±1σ of the per-month historical spread, attenuated by
  how far ahead we're projecting.

This is a real fitted model — not deep learning, but honest time-series
methodology over the 120 monthly observations the brief gives us.
"""
import logging
import math
from collections import defaultdict
from datetime import date, timedelta
from functools import lru_cache
from statistics import mean, stdev

from app.models.schemas import (
    MetricProjection,
    MetricReading,
    ProjectionBundle,
)
from app.services import supply_service

logger = logging.getLogger(__name__)


def _linregress(xs: list[float], ys: list[float]) -> tuple[float, float]:
    """Plain linear regression: returns (slope, intercept)."""
    n = len(xs)
    if n < 2:
        return 0.0, ys[0] if ys else 0.0
    x_mean = sum(xs) / n
    y_mean = sum(ys) / n
    num = sum((xs[i] - x_mean) * (ys[i] - y_mean) for i in range(n))
    den = sum((xs[i] - x_mean) ** 2 for i in range(n))
    if den == 0:
        return 0.0, y_mean
    slope = num / den
    intercept = y_mean - slope * x_mean
    return slope, intercept


class _MetricModel:
    """Fitted seasonal + trend model for one metric."""

    def __init__(self, name: str, readings: list[MetricReading]):
        self.name = name
        # Per-month: list of values (one per year that month appeared)
        by_month: dict[int, list[float]] = defaultdict(list)
        # Per-year: list of values
        by_year: dict[int, list[float]] = defaultdict(list)

        for r in readings:
            v = self._extract(r)
            by_month[r.date.month].append(v)
            by_year[r.date.year].append(v)

        # Seasonal: per-month mean and stdev
        self.monthly_mean: dict[int, float] = {
            m: mean(vs) for m, vs in by_month.items()
        }
        self.monthly_stdev: dict[int, float] = {
            m: stdev(vs) if len(vs) > 1 else 5.0 for m, vs in by_month.items()
        }

        # Trend: linear regression on yearly averages
        years = sorted(by_year.keys())
        if len(years) >= 3:
            yearly_avg = [mean(by_year[y]) for y in years]
            self.year_slope, self.year_intercept = _linregress(
                [float(y) for y in years], yearly_avg
            )
            self.last_year = max(years)
        else:
            self.year_slope = 0.0
            self.year_intercept = 0.0
            self.last_year = max(years) if years else 0

    def _extract(self, r: MetricReading) -> float:
        if self.name == "snowpack":
            return r.snowpack_pct
        if self.name == "precip":
            return r.precip_pct
        return r.reservoir_pct

    def project(self, target: date) -> tuple[float, float, float]:
        """Returns (projected_value, band_low, band_high)."""
        seasonal = self.monthly_mean.get(target.month, 100.0)
        years_ahead = target.year - self.last_year
        trend_adjustment = self.year_slope * years_ahead
        # Apply a fraction of trend to avoid over-extrapolating
        damping = max(0.0, 1.0 - abs(years_ahead) * 0.3)
        projected = seasonal + trend_adjustment * damping

        # Confidence band widens with forecast distance
        sigma = self.monthly_stdev.get(target.month, 8.0)
        widen = 1.0 + (years_ahead * 0.2 if years_ahead > 0 else 0)
        return projected, projected - sigma * widen, projected + sigma * widen


def _confidence_for(months_ahead: int) -> str:
    if months_ahead <= 1:
        return "high"
    if months_ahead <= 3:
        return "medium"
    return "low"


def _next_month(d: date, n: int) -> date:
    """Return the first day of the month n months after d."""
    year = d.year + (d.month + n - 1) // 12
    month = ((d.month + n - 1) % 12) + 1
    return date(year, month, 1)


@lru_cache(maxsize=1)
def _trained_models() -> tuple[_MetricModel, _MetricModel, _MetricModel]:
    readings = supply_service.load_readings()
    snow = _MetricModel("snowpack", readings)
    precip = _MetricModel("precip", readings)
    reservoir = _MetricModel("reservoir", readings)
    logger.info(
        "Projection model trained on %d monthly readings across %d months of seasonal data.",
        len(readings),
        len(set((r.date.year, r.date.month) for r in readings)),
    )
    return snow, precip, reservoir


def project_outlook(horizon_months: int = 6) -> ProjectionBundle:
    snow_m, precip_m, res_m = _trained_models()
    readings = supply_service.load_readings()
    if not readings:
        raise ValueError("No readings available to project from.")

    anchor = readings[-1].date

    def _projections_for(model: _MetricModel) -> list[MetricProjection]:
        out: list[MetricProjection] = []
        for n in range(1, horizon_months + 1):
            target = _next_month(anchor, n)
            value, low, high = model.project(target)
            out.append(
                MetricProjection(
                    metric=model.name,  # type: ignore[arg-type]
                    target_date=target,
                    projected_value=round(value, 1),
                    band_low=round(max(0, low), 1),
                    band_high=round(high, 1),
                    confidence=_confidence_for(n),  # type: ignore[arg-type]
                )
            )
        return out

    return ProjectionBundle(
        horizon_months=horizon_months,
        snowpack=_projections_for(snow_m),
        precip=_projections_for(precip_m),
        reservoir=_projections_for(res_m),
        method="Seasonal naïve + linear yearly trend, fitted per-metric on the full dataset.",
        trained_on_months=len(readings),
    )


def warm_up() -> None:
    """Force the model to fit on app startup so first request is snappy."""
    _trained_models()
