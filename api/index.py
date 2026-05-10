"""Vercel FastAPI entrypoint.

This adapter imports the existing backend app instead of duplicating API logic.
The public website is the Flutter static build at `/`; API traffic is mounted
only under `/api` for Vercel rewrites such as `/api/health` and `/api/docs`.
"""

from pathlib import Path
import sys

from fastapi import FastAPI

ROOT_DIR = Path(__file__).resolve().parent.parent
BACKEND_DIR = ROOT_DIR / "backend"

if str(BACKEND_DIR) not in sys.path:
    sys.path.insert(0, str(BACKEND_DIR))

from app.main import app as backend_app  # noqa: E402

app = FastAPI(
    title="Hydra API",
    description="Vercel adapter for the Hydra FastAPI backend.",
    docs_url=None,
    redoc_url=None,
    openapi_url=None,
)

app.mount("/api", backend_app)
