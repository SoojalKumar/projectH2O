"""Outlook report — what improved, what worsened, what's still risky, what to watch."""
from app.models.schemas import OutlookReport
from app.services import alert_service, supply_service
from app.services.llm_service import get_llm_service


METRIC_LABELS = {
    "snowpack": "Snowpack",
    "precip": "Precipitation",
    "reservoir": "Reservoir storage",
}


def _delta_text(name: str, current: float, prior: float) -> str:
    delta = current - prior
    direction = "rose" if delta > 0 else "fell"
    return f"{METRIC_LABELS[name]} {direction} from {prior:.0f}% to {current:.0f}%"


def outlook_report(window_months: int = 6) -> OutlookReport:
    readings = supply_service.load_readings()
    if len(readings) < window_months + 1:
        raise ValueError("Not enough history for an outlook report.")

    current = readings[-1]
    prior = readings[-1 - window_months]

    cur_snow, cur_precip, cur_res = supply_service.classify_reading(current)
    pri_snow, pri_precip, pri_res = supply_service.classify_reading(prior)

    rank = {"good": 3, "neutral": 2, "watch": 1, "concern": 0}

    improved: list[str] = []
    worsened: list[str] = []
    still_risky: list[str] = []

    pairs = [
        ("snowpack", current.snowpack_pct, prior.snowpack_pct, cur_snow, pri_snow),
        ("precip", current.precip_pct, prior.precip_pct, cur_precip, pri_precip),
        ("reservoir", current.reservoir_pct, prior.reservoir_pct, cur_res, pri_res),
    ]
    for name, cur_v, pri_v, cur_band, pri_band in pairs:
        if rank[cur_band.severity] > rank[pri_band.severity]:
            improved.append(_delta_text(name, cur_v, pri_v) + f" — now {cur_band.label}.")
        elif rank[cur_band.severity] < rank[pri_band.severity]:
            worsened.append(_delta_text(name, cur_v, pri_v) + f" — now {cur_band.label}.")
        if cur_band.severity in {"watch", "concern"}:
            still_risky.append(
                f"{METRIC_LABELS[name]} sits at {cur_v:.0f}% — {cur_band.label}."
            )

    watch_next: list[str] = []
    if cur_snow.severity in {"watch", "concern"}:
        watch_next.append(
            "April 1 snowpack reading — that's the benchmark for how much melt feeds rivers and reservoirs through summer."
        )
    if cur_res.severity == "watch" and cur_snow.severity in {"watch", "concern"}:
        watch_next.append(
            "Reservoir drawdown rate over the next 60 days — without a strong snow year there's less coming to refill."
        )
    if cur_precip.severity in {"watch", "concern"}:
        watch_next.append(
            "Precipitation totals for the rest of the wet season — atmospheric rivers can still flip the year."
        )
    if not watch_next:
        watch_next.append(
            "Next month's snowpack reading — the trajectory matters more than any single point."
        )

    period_label = f"Last {window_months} months · through {current.date.strftime('%b %Y')}"

    llm = get_llm_service()
    alerts = [a.title for a in alert_service.detect_alerts()]
    summary = llm.outlook_report_summary(
        {
            "improved": improved,
            "worsened": worsened,
            "still_risky": still_risky,
            "watch_next": watch_next,
            "active_alerts": alerts,
            "period_label": period_label,
        }
    )

    return OutlookReport(
        period_label=period_label,
        improved=improved,
        worsened=worsened,
        still_risky=still_risky,
        watch_next=watch_next,
        ai_summary=summary,
    )
