"""Local FastAPI entrypoint.

Keeps the common `uvicorn main:app` workflow working from the backend folder
while the actual application factory stays in `app/main.py`.
"""

from app.main import app, create_app

__all__ = ["app", "create_app"]
