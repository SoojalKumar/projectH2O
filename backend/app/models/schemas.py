from datetime import date
from typing import Literal, Optional

from pydantic import BaseModel


Severity = Literal["good", "neutral", "watch", "concern"]
OverallLabel = Literal["Strong", "Stable", "Watch", "Concern"]


class MetricBand(BaseModel):
    value: float
    label: str           # e.g. "Excellent", "Below average", "Drought signal"
    severity: Severity
    metric: Literal["snowpack", "precip", "reservoir"]


class MetricReading(BaseModel):
    date: date
    snowpack_pct: float
    precip_pct: float
    reservoir_pct: float


class CombinedOutlook(BaseModel):
    label: OverallLabel
    severity: Severity
    rationale: str       # short deterministic phrase explaining the call


class MultiSignalAlert(BaseModel):
    alert_id: str
    severity: Severity
    title: str
    description: str         # deterministic, fact-based
    ai_context: Optional[str] = None  # filled by the AI when requested


class SupplyDashboard(BaseModel):
    as_of: date
    snowpack: MetricBand
    precip: MetricBand
    reservoir: MetricBand
    outlook: CombinedOutlook
    alerts: list[MultiSignalAlert]
    ai_summary: str          # AI outlook explanation (or fallback)


class HistoricalYear(BaseModel):
    year: int
    avg_snowpack: float
    avg_precip: float
    avg_reservoir: float
    label: Literal["Strong", "Mixed", "Weak"]
    severity: Severity


class HistoricalComparison(BaseModel):
    years: list[HistoricalYear]
    best_year: int
    worst_year: int
    current_year: int
    ai_summary: str


class OutlookReport(BaseModel):
    period_label: str
    improved: list[str]
    worsened: list[str]
    still_risky: list[str]
    watch_next: list[str]
    ai_summary: str


class TrendSeries(BaseModel):
    metric: Literal["snowpack", "precip", "reservoir"]
    points: list[MetricReading]


class ChatMessage(BaseModel):
    role: Literal["user", "assistant"]
    content: str


class ChatRequest(BaseModel):
    messages: list[ChatMessage]


class ChatResponse(BaseModel):
    message: ChatMessage


WeatherCondition = Literal[
    "clear", "partly_cloudy", "cloudy", "rain", "snow", "storm", "fog"
]


class WeatherDay(BaseModel):
    date: date
    temp_high_f: float
    temp_low_f: float
    precip_inches: float
    snowfall_inches: float
    condition: WeatherCondition


class CurrentConditions(BaseModel):
    temp_f: float
    feels_like_f: float | None = None
    humidity_pct: int | None = None
    wind_mph: float | None = None
    condition: WeatherCondition
    observed_at: str  # ISO datetime string from Open-Meteo


class WeatherForecast(BaseModel):
    location: str
    elevation_ft: int
    today: date          # dataset-time anchor — "today" for the whole app
    days: list[WeatherDay]
    current: CurrentConditions | None = None
    headline: str
    source: Literal["dataset"]


RiskLevel = Literal["low", "moderate", "elevated", "high"]


class HazardRisk(BaseModel):
    level: RiskLevel
    score: int           # 0-100
    reasoning: list[str]  # bullet points, deterministic


class AnalogMatch(BaseModel):
    date: date
    label: str           # e.g. "January 2018"
    similarity: float    # 0..1, 1 = identical
    snowpack_pct: float
    precip_pct: float
    reservoir_pct: float
    year_label: str      # "Strong" / "Mixed" / "Weak"
    next_window_summary: str  # what the next 6 months looked like


EventType = Literal["snow", "rain", "mixed", "none"]


class NextEvent(BaseModel):
    type: EventType
    date: date | None
    days_away: int | None
    precip_inches: float
    snowfall_inches: float
    label: str       # "Heavy snow event", "Rain", "Quiet week"
    summary: str     # one-line plain-language description


class MetricProjection(BaseModel):
    """One month's projected value for a single metric, with confidence band."""
    metric: Literal["snowpack", "precip", "reservoir"]
    target_date: date
    projected_value: float
    band_low: float
    band_high: float
    confidence: Literal["low", "medium", "high"]


class ProjectionBundle(BaseModel):
    """Projections for the next N months across all three metrics, plus a
    headline summary. Trained on the 10-year monthly record using a seasonal
    naïve + linear yearly trend model."""
    horizon_months: int
    snowpack: list[MetricProjection]
    precip: list[MetricProjection]
    reservoir: list[MetricProjection]
    method: str
    trained_on_months: int


PlanningAudience = Literal["citizen", "farmer", "supply_manager"]


class PlanningImplication(BaseModel):
    audience: PlanningAudience
    headline: str         # e.g. "Plan for reduced allocation"
    detail: str           # one-sentence explanation
    severity: Severity


class PlanningImplications(BaseModel):
    citizen: PlanningImplication
    farmer: PlanningImplication
    supply: PlanningImplication
    estimated_ag_allocation_pct: int  # 0-100, deterministic estimate
    allocation_basis: str             # e.g. "based on 2017 actual allocation (85%)"
    region: str                        # selected region key


class PredictiveOutlook(BaseModel):
    horizon: str             # "Next 90 days"
    next_event: NextEvent
    drought_risk: HazardRisk
    flood_risk: HazardRisk
    analog: AnalogMatch
    projection: ProjectionBundle
    planning: PlanningImplications
    ai_narrative: str
