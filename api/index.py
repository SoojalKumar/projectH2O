"""Vercel FastAPI entrypoint.

This adapter imports the existing backend app instead of duplicating API logic.
It mounts the same FastAPI application at both `/` and `/api` so Vercel rewrites
can serve `/api/docs`, `/api/health`, and `/api/supply/*` cleanly while local
backend development can keep using unprefixed routes such as `/docs`.
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
app.mount("/", backend_app)
