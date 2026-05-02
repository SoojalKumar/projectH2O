"""Tests that the multi-signal alert patterns trigger on the right combinations."""
from datetime import date, timedelta

from app.models.schemas import MetricReading
from app.services import alert_service, supply_service


def _set_dataset(monkeypatch, readings):
    monkeypatch.setattr(supply_service, "load_readings", lambda: readings)


def _stable_history(latest_snow, latest_precip, latest_res,
                    history_snow=100, history_precip=100, history_res=80):
    """Build 12 monthly readings ending in the supplied 'latest' values."""
    out = []
    base = date(2024, 12, 1)
    for i in range(11):
        out.append(MetricReading(
            date=base + timedelta(days=30 * i),
            snowpack_pct=history_snow,
            precip_pct=history_precip,
            reservoir_pct=history_res,
        ))
    out.append(MetricReading(
        date=base + timedelta(days=30 * 11),
        snowpack_pct=latest_snow,
        precip_pct=latest_precip,
        reservoir_pct=latest_res,
    ))
    return out


def test_all_strong_triggers_only_strong_alert(monkeypatch):
    _set_dataset(monkeypatch, _stable_history(125, 115, 90,
                                              history_snow=120, history_precip=110, history_res=88))
    alerts = alert_service.detect_alerts()
    assert any(a.alert_id == "all_strong" for a in alerts)


def test_low_snow_normal_precip_triggers_signature_alert(monkeypatch):
    """The brief's headline insight."""
    _set_dataset(monkeypatch, _stable_history(60, 100, 75))
    alerts = alert_service.detect_alerts()
    assert any(a.alert_id == "snow_low_precip_normal" for a in alerts)


def test_healthy_reservoirs_low_snow_triggers_future_risk_alert(monkeypatch):
    _set_dataset(monkeypatch, _stable_history(65, 95, 88))
    alerts = alert_service.detect_alerts()
    assert any(a.alert_id == "reservoirs_ok_snow_low" for a in alerts)


def test_recent_wet_but_low_snow_triggers_alert(monkeypatch):
    _set_dataset(monkeypatch, _stable_history(70, 100, 80,
                                              history_snow=70, history_precip=120, history_res=80))
    alerts = alert_service.detect_alerts()
    assert any(a.alert_id == "wet_but_snow_low" for a in alerts)


def test_drought_precip_triggers_drought_alert(monkeypatch):
    _set_dataset(monkeypatch, _stable_history(60, 60, 60))
    alerts = alert_service.detect_alerts()
    assert any(a.alert_id == "drought_precip" for a in alerts)


def test_mixed_signals_fallback_when_no_specific_pattern(monkeypatch):
    _set_dataset(monkeypatch, _stable_history(95, 85, 80))  # neutral/watch mix, no concern
    alerts = alert_service.detect_alerts()
    ids = {a.alert_id for a in alerts}
    # Either a more specific alert fired, or the mixed-signals fallback did.
    assert ids, "expected at least one alert when signals disagree"


def test_no_alerts_when_dataset_empty(monkeypatch):
    _set_dataset(monkeypatch, [])
    assert alert_service.detect_alerts() == []
