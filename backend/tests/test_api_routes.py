from fastapi.testclient import TestClient

from app.core.config import get_settings
from app.main import app
from app.services.llm_service import get_llm_service


client = TestClient(app)


def test_root_health_message():
    res = client.get("/")
    assert res.status_code == 200
    assert res.json() == {"name": "Hydra API", "status": "ok", "docs": "/api/docs"}


def test_health_route_reports_llm_status():
    res = client.get("/health")
    assert res.status_code == 200
    body = res.json()
    assert body["status"] == "ok"
    assert "llm_enabled" in body


def test_latest_supply_route():
    res = client.get("/supply/latest")
    assert res.status_code == 200
    body = res.json()
    assert body["date"] == "2025-12-01"
    assert body["snowpack_pct"] == 65.0
    assert body["precip_pct"] == 105.0
    assert body["reservoir_pct"] == 72.0


def test_dashboard_route():
    res = client.get("/supply/dashboard")
    assert res.status_code == 200
    body = res.json()
    assert body["outlook"]["label"] == "Watch"
    assert body["snowpack"]["severity"] == "concern"
    assert body["alerts"]


def test_chat_route_falls_back_without_groq_key(monkeypatch):
    monkeypatch.delenv("GROQ_API_KEY", raising=False)
    get_settings.cache_clear()
    get_llm_service.cache_clear()

    res = client.post(
        "/supply/chat",
        json={"messages": [{"role": "user", "content": "How are reservoirs doing?"}]},
    )

    assert res.status_code == 200
    assert "Chat is offline" in res.json()["message"]["content"]

    get_settings.cache_clear()
    get_llm_service.cache_clear()
