"""Year-over-year comparison — labels each calendar year as Strong / Mixed / Weak
based on the average of its three signals."""
from collections import defaultdict
from statistics import mean

from app.models.schemas import HistoricalYear
from app.services import supply_service


def _label_for(avg_snow: float, avg_precip: float, avg_res: float) -> tuple[str, str]:
    snow = supply_service.classify_snowpack(avg_snow).severity
    precip = supply_service.classify_precip(avg_precip).severity
    res = supply_service.classify_reservoir(avg_res).severity

    severities = [snow, precip, res]
    if severities.count("good") >= 2 and "concern" not in severities:
        return "Strong", "good"
    if severities.count("concern") >= 2 or (
        snow == "concern" and res == "concern"
    ):
        return "Weak", "concern"
    if severities.count("good") >= 1 and "concern" not in severities:
        return "Mixed", "neutral"
    return "Mixed", "watch"


def compare_years() -> list[HistoricalYear]:
    readings = supply_service.load_readings()
    by_year: dict[int, list] = defaultdict(list)
    for r in readings:
        by_year[r.date.year].append(r)

    years: list[HistoricalYear] = []
    for year in sorted(by_year):
        rows = by_year[year]
        avg_snow = mean(r.snowpack_pct for r in rows)
        avg_precip = mean(r.precip_pct for r in rows)
        avg_res = mean(r.reservoir_pct for r in rows)
        label, severity = _label_for(avg_snow, avg_precip, avg_res)
        years.append(
            HistoricalYear(
                year=year,
                avg_snowpack=round(avg_snow, 1),
                avg_precip=round(avg_precip, 1),
                avg_reservoir=round(avg_res, 1),
                label=label,  # type: ignore[arg-type]
                severity=severity,  # type: ignore[arg-type]
            )
        )
    return years


def best_and_worst() -> tuple[int, int]:
    years = compare_years()
    if not years:
        return 0, 0
    score = lambda y: (y.avg_snowpack + y.avg_precip + y.avg_reservoir) / 3  # noqa: E731
    best = max(years, key=score)
    worst = min(years, key=score)
    return best.year, worst.year
