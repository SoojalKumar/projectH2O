"""Multi-signal alerts — patterns no single metric reveals on its own.

Refined per expert feedback into five product categories:
  1. drought_stress       — supply under pressure now
  2. allocation_uncertainty — outlook murky enough that planning is risky
  3. future_weak_signal   — buffer healthy now, snowpack weak for next year
  4. flood_pressure       — reservoirs near capacity + incoming storms
  5. mixed_watch          — signals disagree, monitor closely

Every alert sets a `category` so the UI can group/sort them. All triggers
remain deterministic — Gemini/LLM only enriches the description, never
classifies.
"""
from statistics import mean

from app.models.schemas import MultiSignalAlert
from app.services import supply_service


def detect_alerts() -> list[MultiSignalAlert]:
    readings = supply_service.load_readings()
    if not readings:
        return []

    latest = readings[-1]
    snow, precip, res = supply_service.classify_reading(latest)
    recent = readings[-6:]

    alerts: list[MultiSignalAlert] = []

    # 1) All three strong — explicitly call out the good case.
    if snow.severity == "good" and precip.severity == "good" and res.severity == "good":
        alerts.append(
            MultiSignalAlert(
                alert_id="all_strong",
                severity="good",
                title="All three signals are strong",
                description=(
                    f"Snowpack at {latest.snowpack_pct:.0f}%, precipitation at "
                    f"{latest.precip_pct:.0f}%, and reservoirs at {latest.reservoir_pct:.0f}% "
                    "all sit in their healthy bands. California is set up well heading into next season."
                ),
            )
        )

    # 2) Drought stress — formal precipitation shortage.
    if precip.severity == "concern":
        alerts.append(
            MultiSignalAlert(
                alert_id="drought_stress",
                severity="concern",
                title="Drought signal in current precipitation",
                description=(
                    f"Precipitation is at {latest.precip_pct:.0f}% of average — below "
                    "the 70% drought threshold. Combined with where snowpack sits, this "
                    "is the kind of pattern that triggers state-level water restrictions "
                    "and reduced agricultural allocations."
                ),
            )
        )

    # 3) Allocation uncertainty — snowpack low/borderline + reservoirs not strong.
    #    This is the signal farmers care about most.
    if snow.severity in {"watch", "concern"} and res.severity != "good":
        alerts.append(
            MultiSignalAlert(
                alert_id="allocation_uncertainty",
                severity="watch",
                title="Allocation uncertainty for the next water year",
                description=(
                    f"Snowpack at {latest.snowpack_pct:.0f}% and reservoirs at "
                    f"{latest.reservoir_pct:.0f}% don't yet support a full allocation. "
                    "Growers should expect a planning-uncertainty window — fallowing or "
                    "reduced acreage may be on the table depending on the rest of the wet season."
                ),
            )
        )

    # 4) Snowpack concerning despite normal precipitation — the brief's headline insight.
    if snow.severity == "concern" and precip.severity in {"neutral", "good"}:
        alerts.append(
            MultiSignalAlert(
                alert_id="snow_low_precip_normal",
                severity="watch",
                title="Snowpack is concerning despite normal precipitation",
                description=(
                    f"Precipitation is {latest.precip_pct:.0f}% of average, but snowpack is "
                    f"only {latest.snowpack_pct:.0f}% of the April 1 benchmark. Warmer storms "
                    "are falling as rain instead of snow — water that flows out fast rather "
                    "than banking for spring."
                ),
            )
        )

    # 5) Healthy current buffer but weak future signal — adequacy framing the expert called out.
    if res.severity in {"good", "neutral"} and snow.severity in {"watch", "concern"}:
        alerts.append(
            MultiSignalAlert(
                alert_id="future_weak_signal",
                severity="watch",
                title="Adequate buffer today, weak signal for next year",
                description=(
                    f"Reservoirs at {latest.reservoir_pct:.0f}% provide a comfortable cushion "
                    f"right now, but with snowpack at {latest.snowpack_pct:.0f}% there's less "
                    "spring melt coming to refill them. Today's adequacy can shrink quickly "
                    "without a strong snow year."
                ),
            )
        )

    # 6) Recent wet doesn't guarantee long-term supply.
    recent_precip_avg = mean(r.precip_pct for r in recent)
    if recent_precip_avg >= 110 and snow.severity in {"watch", "concern"}:
        alerts.append(
            MultiSignalAlert(
                alert_id="wet_but_snow_low",
                severity="watch",
                title="Recent wet conditions don't guarantee long-term supply",
                description=(
                    f"The last six months averaged {recent_precip_avg:.0f}% precipitation, but "
                    f"snowpack still sits at {latest.snowpack_pct:.0f}%. Rain runs off in weeks; "
                    "snow is what banks water for the dry season."
                ),
            )
        )

    # 7) Reservoir drawdown — fast loss of buffer.
    if len(readings) >= 6:
        six_months_ago = readings[-6]
        delta = latest.reservoir_pct - six_months_ago.reservoir_pct
        if delta <= -15:
            alerts.append(
                MultiSignalAlert(
                    alert_id="reservoir_drawdown",
                    severity="watch" if res.severity != "concern" else "concern",
                    title="Reservoir storage is drawing down quickly",
                    description=(
                        f"Reservoirs dropped from {six_months_ago.reservoir_pct:.0f}% to "
                        f"{latest.reservoir_pct:.0f}% over the last six months — a "
                        f"{abs(delta):.0f}-point swing that compresses the buffer faster than usual."
                    ),
                )
            )

    # 8) Flood / overflow pressure — reservoirs near capacity + recent wet stretch.
    if res.severity == "good" and latest.reservoir_pct >= 92 and recent_precip_avg >= 110:
        alerts.append(
            MultiSignalAlert(
                alert_id="flood_pressure",
                severity="watch",
                title="Reservoirs near capacity — flood pressure rising",
                description=(
                    f"Storage at {latest.reservoir_pct:.0f}% with a recent wet stretch "
                    "leaves little spare capacity. Incoming storms could force releases, "
                    "stressing downstream infrastructure and short-term water quality."
                ),
            )
        )

    # Fallback — if signals disagree but no specific pattern fired.
    if not alerts:
        sev_set = {snow.severity, precip.severity, res.severity}
        if len(sev_set) > 1:
            alerts.append(
                MultiSignalAlert(
                    alert_id="mixed_signals",
                    severity="watch",
                    title="Mixed signals — monitor closely",
                    description=(
                        "The three indicators aren't telling the same story. That's exactly when "
                        "single-metric reports get supply forecasting wrong."
                    ),
                )
            )

    return alerts
