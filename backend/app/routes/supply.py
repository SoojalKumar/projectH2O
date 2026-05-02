from typing import Literal

from fastapi import APIRouter, HTTPException, Query

from app.models.schemas import (
    ChatMessage,
    ChatRequest,
    ChatResponse,
    HistoricalComparison,
    MetricBand,
    MetricReading,
    MultiSignalAlert,
    OutlookReport,
    PredictiveOutlook,
    SupplyDashboard,
    TrendSeries,
    WeatherForecast,
)
from app.services import (
    alert_service,
    historical_service,
    predictive_service,
    report_service,
    supply_service,
    weather_service,
)
from app.services.llm_service import get_llm_service

router = APIRouter(prefix="/supply", tags=["supply"])


@router.get("/dashboard", response_model=SupplyDashboard)
def get_dashboard() -> SupplyDashboard:
    latest = supply_service.latest_reading()
    snow, precip, res = supply_service.classify_reading(latest)
    outlook = supply_service.combined_outlook(snow, precip, res)
    alerts = alert_service.detect_alerts()

    llm = get_llm_service()
    summary = llm.outlook_explanation(
        {
            "as_of": latest.date,
            "snowpack": snow.model_dump(),
            "precip": precip.model_dump(),
            "reservoir": res.model_dump(),
            "outlook": outlook.model_dump(),
        }
    )

    return SupplyDashboard(
        as_of=latest.date,
        snowpack=snow,
        precip=precip,
        reservoir=res,
        outlook=outlook,
        alerts=alerts,
        ai_summary=summary,
    )


@router.get("/latest", response_model=MetricReading)
def get_latest() -> MetricReading:
    return supply_service.latest_reading()


@router.get("/history", response_model=list[MetricReading])
def get_history(months: int = Query(24, ge=1, le=240)) -> list[MetricReading]:
    return supply_service.history(months)


@router.get("/trends/{metric}", response_model=TrendSeries)
def get_trend(
    metric: Literal["snowpack", "precip", "reservoir"],
    months: int = Query(24, ge=1, le=240),
) -> TrendSeries:
    return TrendSeries(metric=metric, points=supply_service.history(months))


@router.get("/alerts", response_model=list[MultiSignalAlert])
def get_alerts(with_ai: bool = Query(True)) -> list[MultiSignalAlert]:
    alerts = alert_service.detect_alerts()
    if not with_ai:
        return alerts

    llm = get_llm_service()
    latest = supply_service.latest_reading()
    snow, precip, res = supply_service.classify_reading(latest)
    enriched: list[MultiSignalAlert] = []
    for a in alerts:
        ctx = llm.alert_context(
            {
                "title": a.title,
                "severity": a.severity,
                "description": a.description,
                "snowpack": snow.model_dump(),
                "precip": precip.model_dump(),
                "reservoir": res.model_dump(),
            }
        )
        enriched.append(a.model_copy(update={"ai_context": ctx}))
    return enriched


@router.get("/historical-comparison", response_model=HistoricalComparison)
def get_historical_comparison() -> HistoricalComparison:
    years = historical_service.compare_years()
    if not years:
        raise HTTPException(status_code=503, detail="No historical data loaded.")
    best, worst = historical_service.best_and_worst()
    current = years[-1].year

    llm = get_llm_service()
    summary = llm.historical_summary(
        {
            "years": [y.model_dump() for y in years],
            "best_year": best,
            "worst_year": worst,
            "current_year": current,
        }
    )

    return HistoricalComparison(
        years=years,
        best_year=best,
        worst_year=worst,
        current_year=current,
        ai_summary=summary,
    )


@router.get("/report", response_model=OutlookReport)
def get_report(window_months: int = Query(6, ge=1, le=24)) -> OutlookReport:
    return report_service.outlook_report(window_months)


@router.get("/weather", response_model=WeatherForecast)
def get_weather() -> WeatherForecast:
    return weather_service.fetch_forecast()


@router.get("/forecast", response_model=PredictiveOutlook)
def get_forecast(region: str = Query("statewide")) -> PredictiveOutlook:
    return predictive_service.predictive_outlook(region=region)


@router.post("/chat", response_model=ChatResponse)
def chat(req: ChatRequest) -> ChatResponse:
    llm = get_llm_service()
    text = llm.chat([m.model_dump() for m in req.messages])
    return ChatResponse(message=ChatMessage(role="assistant", content=text))


@router.post("/refresh", response_model=dict[str, int | str])
def refresh_dataset() -> dict[str, int | str]:
    """Bust the in-memory caches so a redeployed dataset file takes effect.
    Clears both the supply-readings cache and the LLM response cache.
    """
    rows = supply_service.reload_readings()
    cleared = get_llm_service().clear_cache()
    return {"status": "ok", "rows": rows, "ai_cache_cleared": cleared}
