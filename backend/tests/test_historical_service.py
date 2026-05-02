"""Tests that year-by-year labeling and best/worst selection work correctly."""
from datetime import date

from app.models.schemas import MetricReading
from app.services import historical_service, supply_service


def _make_year(year: int, snow: float, precip: float, res: float) -> list[MetricReading]:
    return [
        MetricReading(
            date=date(year, m, 1),
            snowpack_pct=snow,
            precip_pct=precip,
            reservoir_pct=res,
        )
        for m in range(1, 13)
    ]


def test_strong_year_labeled_strong(monkeypatch):
    monkeypatch.setattr(
        supply_service,
        "load_readings",
        lambda: _make_year(2020, 120, 115, 90),
    )
    years = historical_service.compare_years()
    assert len(years) == 1
    assert years[0].label == "Strong"


def test_weak_year_labeled_weak(monkeypatch):
    monkeypatch.setattr(
        supply_service,
        "load_readings",
        lambda: _make_year(2021, 50, 60, 45),
    )
    years = historical_service.compare_years()
    assert years[0].label == "Weak"


def test_mixed_year_labeled_mixed(monkeypatch):
    monkeypatch.setattr(
        supply_service,
        "load_readings",
        lambda: _make_year(2022, 75, 95, 80),
    )
    years = historical_service.compare_years()
    assert years[0].label == "Mixed"


def test_best_and_worst_pick_extremes(monkeypatch):
    monkeypatch.setattr(
        supply_service,
        "load_readings",
        lambda: (
            _make_year(2018, 60, 65, 55)   # weak
            + _make_year(2019, 130, 120, 95)  # strong
            + _make_year(2020, 90, 95, 75)   # mid
        ),
    )
    best, worst = historical_service.best_and_worst()
    assert best == 2019
    assert worst == 2018


def test_compare_years_sorted_ascending(monkeypatch):
    """Years are returned in chronological order so charts render left-to-right."""
    monkeypatch.setattr(
        supply_service,
        "load_readings",
        lambda: _make_year(2020, 100, 100, 80) + _make_year(2018, 100, 100, 80),
    )
    years = historical_service.compare_years()
    assert [y.year for y in years] == [2018, 2020]
