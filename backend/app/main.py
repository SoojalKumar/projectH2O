from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.core.config import get_settings
from app.routes import supply
from app.services import projection_service


def create_app() -> FastAPI:
    settings = get_settings()
    app = FastAPI(
        title="Hydra API",
        description="California water-supply intelligence — three signals, one outlook.",
        version="1.0.0",
    )

    app.add_middleware(
        CORSMiddleware,
        allow_origins=["*"],
        allow_credentials=False,
        allow_methods=["*"],
        allow_headers=["*"],
    )

    @app.get("/health", tags=["meta"])
    def health() -> dict[str, str]:
        return {
            "status": "ok",
            "model": settings.llm_model,
            "llm_enabled": str(bool(settings.groq_api_key)),
        }

    app.include_router(supply.router)

    # Train the seasonal-trend projection model once at boot so first request
    # is snappy and the load happens at process start, not under demo pressure.
    @app.on_event("startup")
    def _warm_models() -> None:
        projection_service.warm_up()

    return app


app = create_app()


if __name__ == "__main__":
    import uvicorn

    settings = get_settings()
    uvicorn.run("app.main:app", host=settings.app_host, port=settings.app_port, reload=True)
