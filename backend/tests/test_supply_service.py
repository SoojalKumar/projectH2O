"""Tests for the deterministic core: metric bands and combined outlook."""
from app.services import supply_service


# ---------------------- Band classification (brief verbatim) ------------------

def test_snowpack_bands():
    assert supply_service.classify_snowpack(125).label == "Excellent"
    assert supply_service.classify_snowpack(120).label == "Excellent"
    assert supply_service.classify_snowpack(100).label == "Average"
    assert supply_service.classify_snowpack(90).label == "Average"
    assert supply_service.classify_snowpack(80).label == "Below average"
    assert supply_service.classify_snowpack(70).label == "Below average"
    assert supply_service.classify_snowpack(65).label == "Concerning"
    assert supply_service.classify_snowpack(0).label == "Concerning"


def test_precip_bands():
    assert supply_service.classify_precip(120).label == "Wet"
    assert supply_service.classify_precip(110).label == "Wet"
    assert supply_service.classify_precip(105).label == "Normal"
    assert supply_service.classify_precip(90).label == "Normal"
    assert supply_service.classify_precip(85).label == "Dry"
    assert supply_service.classify_precip(70).label == "Dry"
    assert supply_service.classify_precip(50).label == "Drought signal"


def test_reservoir_bands():
    assert supply_service.classify_reservoir(95).label == "Strong"
    assert supply_service.classify_reservoir(85).label == "Strong"
    assert supply_service.classify_reservoir(75).label == "Healthy"
    assert supply_service.classify_reservoir(70).label == "Healthy"
    assert supply_service.classify_reservoir(60).label == "Watch"
    assert supply_service.classify_reservoir(50).label == "Watch"
    assert supply_service.classify_reservoir(40).label == "Concern"


def test_severity_consistency():
    assert supply_service.classify_snowpack(50).severity == "concern"
    assert supply_service.classify_precip(50).severity == "concern"
    assert supply_service.classify_reservoir(40).severity == "concern"
    assert supply_service.classify_snowpack(125).severity == "good"
    assert supply_service.classify_precip(120).severity == "good"
    assert supply_service.classify_reservoir(95).severity == "good"


# ---------------------- Combined outlook --------------------------------------

def _bands(snow_v, precip_v, res_v):
    return (
        supply_service.classify_snowpack(snow_v),
        supply_service.classify_precip(precip_v),
        supply_service.classify_reservoir(res_v),
    )


def test_outlook_strong_when_all_three_good():
    o = supply_service.combined_outlook(*_bands(125, 115, 90))
    assert o.label == "Strong"
    assert o.severity == "good"


def test_outlook_concern_when_snow_concern_and_reservoir_low():
    o = supply_service.combined_outlook(*_bands(60, 80, 55))
    assert o.label == "Concern"
    assert o.severity == "concern"


def test_outlook_watch_when_snow_concern_but_reservoir_strong():
    """The brief's headline insight: today is OK, future is at risk."""
    o = supply_service.combined_outlook(*_bands(60, 100, 90))
    assert o.label == "Watch"
    assert "snowpack is concerning" in o.rationale.lower()


def test_outlook_concern_when_reservoir_below_50():
    o = supply_service.combined_outlook(*_bands(100, 100, 40))
    assert o.label == "Concern"


def test_outlook_stable_when_signals_mixed_but_none_concerning():
    o = supply_service.combined_outlook(*_bands(100, 95, 75))
    assert o.label == "Stable"


# ---------------------- Live dataset sanity -----------------------------------

def test_dataset_loads_and_is_sorted():
    rows = supply_service.load_readings()
    assert rows, "dataset must not be empty"
    assert all(rows[i].date <= rows[i + 1].date for i in range(len(rows) - 1)), \
        "readings should be in chronological order"


def test_history_window_caps_at_dataset_size():
    rows = supply_service.load_readings()
    assert len(supply_service.history(months=12)) == min(12, len(rows))
    assert len(supply_service.history(months=999)) == len(rows)
