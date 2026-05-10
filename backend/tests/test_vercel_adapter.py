import sys
from pathlib import Path

from fastapi.testclient import TestClient

REPO_ROOT = Path(__file__).resolve().parents[2]
if str(REPO_ROOT) not in sys.path:
    sys.path.insert(0, str(REPO_ROOT))

from api.index import app as vercel_app  # noqa: E402


client = TestClient(vercel_app)


def test_vercel_root_route():
    res = client.get("/")
    assert res.status_code == 200
    assert res.json()["name"] == "Hydra API"


def test_vercel_api_health_route():
    res = client.get("/api/health")
    assert res.status_code == 200
    assert res.json()["status"] == "ok"


def test_vercel_api_docs_route():
    res = client.get("/api/docs")
    assert res.status_code == 200
    assert "Swagger UI" in res.text


def test_vercel_api_supply_latest_route():
    res = client.get("/api/supply/latest")
    assert res.status_code == 200
    assert res.json()["date"] == "2025-12-01"


def test_vercel_api_supply_dashboard_route():
    res = client.get("/api/supply/dashboard")
    assert res.status_code == 200
    assert res.json()["outlook"]["label"] == "Watch"
