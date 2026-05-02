"""Planning implications — translates the deterministic outlook into guidance
for three real audiences the brief calls out: citizens, farmers, supply
managers.

Grounded in expert feedback:
- Reservoir adequacy is first-class.
- Farmers care about allocation %; some years it's 100%, some years it isn't.
- "Plant or fallow" is a real decision triggered by these numbers.
- Public education is hard — the citizen panel uses plain language.

Allocation estimates are anchored to actual California State Water Project
Table A allocations (final or near-final figures from DWR public record),
mapped via the analog-year match. This replaces the earlier rule-based
heuristic with historical fact.
"""
from app.models.schemas import (
    HazardRisk,
    MetricBand,
    PlanningImplication,
    PlanningImplications,
    Severity,
)


# Final / near-final SWP Table A allocations as announced by DWR for each
# water year in our dataset. These are real numbers, used to ground the
# "estimated allocation" the farmer panel surfaces.
_HISTORICAL_SWP_ALLOCATIONS: dict[int, int] = {
    2016: 60,
    2017: 85,
    2018: 35,
    2019: 75,
    2020: 20,
    2021: 5,
    2022: 5,
    2023: 100,
    2024: 40,
    2025: 50,
}

# Regional contract priority — historically junior contractors (south of
# delta) often see lower allocations than senior north-of-delta contractors.
# Multipliers are conservative and applied to the analog-year base figure.
_REGION_MULTIPLIERS: dict[str, float] = {
    "statewide": 1.00,
    "north_coast": 1.10,
    "sacramento_valley": 1.05,
    "san_joaquin_valley": 0.92,
    "tulare_basin": 0.85,
    "south_coast": 0.95,
}


def _ag_allocation_estimate(
    snow: MetricBand,
    precip: MetricBand,
    reservoir: MetricBand,
    analog_year: int | None = None,
    region: str = "statewide",
) -> tuple[int, str]:
    """Returns (allocation_pct, basis_label).

    Approach:
    1. Always compute a heuristic from current signal bands.
    2. If the analog year is in our DWR allocation table, compute an
       analog-anchored value too.
    3. If the two roughly agree, use the analog-anchored value (most
       historically grounded). If they diverge sharply (current signals
       weaker than the analog year ended up), blend them — this keeps the
       farmer panel coherent with the rest of the outlook when carryover
       effects from prior years would otherwise overstate allocations.
    4. Apply a regional multiplier reflecting contract priority.
    """
    multiplier = _REGION_MULTIPLIERS.get(region, 1.0)

    # 1. Heuristic baseline
    score = 0
    score += {"good": 35, "neutral": 28, "watch": 18, "concern": 5}[snow.severity]
    score += {"good": 30, "neutral": 25, "watch": 14, "concern": 4}[precip.severity]
    score += {"good": 35, "neutral": 28, "watch": 16, "concern": 5}[reservoir.severity]
    heuristic = round(score * multiplier)

    # 2-3. Analog-anchored, with coherence guard
    if analog_year and analog_year in _HISTORICAL_SWP_ALLOCATIONS:
        base = _HISTORICAL_SWP_ALLOCATIONS[analog_year]
        anchored = round(base * multiplier)
        if abs(anchored - heuristic) <= 12:
            # Analog and current signals agree — use the historical anchor.
            return (
                max(5, min(100, anchored)),
                f"based on {analog_year} actual allocation ({base}%)",
            )
        blend = round((anchored + heuristic) / 2)
        return (
            max(5, min(100, blend)),
            f"blended from {analog_year} actual allocation ({base}%) and current signals",
        )

    return max(5, min(100, heuristic)), "estimated from current signal bands"


def _citizen(
    snow: MetricBand,
    precip: MetricBand,
    reservoir: MetricBand,
    drought_risk: HazardRisk,
    flood_risk: HazardRisk,
) -> PlanningImplication:
    if drought_risk.level in {"elevated", "high"}:
        return PlanningImplication(
            audience="citizen",
            headline="Conserve where you can",
            detail=(
                "California is heading into a tight water year. Cutting outdoor "
                "watering and fixing leaks now keeps reservoirs deeper through summer."
            ),
            severity="watch",
        )
    if flood_risk.level in {"elevated", "high"}:
        return PlanningImplication(
            audience="citizen",
            headline="Be storm-aware",
            detail=(
                "Reservoirs are full and storms are coming. Watch local advisories — "
                "fast-moving water and infrastructure stress can affect tap-water quality."
            ),
            severity="watch",
        )
    if reservoir.severity == "good" and snow.severity in {"good", "neutral"}:
        return PlanningImplication(
            audience="citizen",
            headline="Business as usual",
            detail=(
                "Supply looks healthy — no immediate need to change daily habits. "
                "Conservation always helps long-term."
            ),
            severity="good",
        )
    return PlanningImplication(
        audience="citizen",
        headline="Stay aware",
        detail=(
            "Conditions are mixed. No emergency, but the snow that falls in the "
            "next few weeks will set the tone for next summer's supply."
        ),
        severity="neutral",
    )


def _farmer(
    snow: MetricBand,
    precip: MetricBand,
    reservoir: MetricBand,
    allocation_pct: int,
) -> PlanningImplication:
    if allocation_pct >= 80:
        return PlanningImplication(
            audience="farmer",
            headline=f"~{allocation_pct}% allocation likely · plant normally",
            detail=(
                "Reservoirs and snowpack support a strong allocation outlook. "
                "Standard planting acreage and irrigation should be feasible."
            ),
            severity="good",
        )
    if allocation_pct >= 50:
        return PlanningImplication(
            audience="farmer",
            headline=f"~{allocation_pct}% allocation · plan reduced acreage",
            detail=(
                "Allocation will likely come in below full. Consider reducing "
                "annual crop acreage; permanent crops should be priority for water."
            ),
            severity="neutral",
        )
    if allocation_pct >= 25:
        return PlanningImplication(
            audience="farmer",
            headline=f"~{allocation_pct}% allocation · prepare to fallow",
            detail=(
                "Allocations look tight. Plan for fallowing rotational ground "
                "and prioritize water for established orchards and vines."
            ),
            severity="watch",
        )
    return PlanningImplication(
        audience="farmer",
        headline=f"~{allocation_pct}% allocation · drought protocols",
        detail=(
            "Drought-year decisions ahead. Some growers may need to let "
            "lower-priority trees go. Track district announcements closely."
        ),
        severity="concern",
    )


def _supply(
    snow: MetricBand,
    reservoir: MetricBand,
    drought_risk: HazardRisk,
    flood_risk: HazardRisk,
) -> PlanningImplication:
    # Adequacy framing the expert called out.
    if reservoir.severity == "good" and snow.severity == "good":
        return PlanningImplication(
            audience="supply_manager",
            headline="Reservoirs adequate · long-term outlook strong",
            detail=(
                "Storage and snowpack both healthy — supply buffer is comfortable "
                "through the dry season."
            ),
            severity="good",
        )
    if flood_risk.level in {"elevated", "high"} and reservoir.severity == "good":
        return PlanningImplication(
            audience="supply_manager",
            headline="Reservoirs full · overflow pressure rising",
            detail=(
                "Storage is at the upper end of healthy. Incoming storms could "
                "force releases, stressing infrastructure and downstream water quality."
            ),
            severity="watch",
        )
    if reservoir.severity in {"good", "neutral"} and snow.severity in {"watch", "concern"}:
        return PlanningImplication(
            audience="supply_manager",
            headline="Adequate today · weak future signal",
            detail=(
                "Buffer holds for now, but with snowpack below normal, expect a "
                "faster drawdown next summer and tighter conditions a year out."
            ),
            severity="watch",
        )
    if drought_risk.level in {"elevated", "high"}:
        return PlanningImplication(
            audience="supply_manager",
            headline="Supply stress · plan for cuts",
            detail=(
                "Multiple signals weak. Coordinate allocation reductions with "
                "districts and prepare drought messaging for the public."
            ),
            severity="concern",
        )
    return PlanningImplication(
        audience="supply_manager",
        headline="Mixed signals · monitor closely",
        detail=(
            "Buffer and inflow both moderate. Watch April 1 snowpack — that "
            "reading will set the trajectory for summer."
        ),
        severity="neutral",
    )


def planning_implications(
    snow: MetricBand,
    precip: MetricBand,
    reservoir: MetricBand,
    drought_risk: HazardRisk,
    flood_risk: HazardRisk,
    analog_year: int | None = None,
    region: str = "statewide",
) -> PlanningImplications:
    allocation, basis = _ag_allocation_estimate(
        snow, precip, reservoir, analog_year=analog_year, region=region
    )
    return PlanningImplications(
        citizen=_citizen(snow, precip, reservoir, drought_risk, flood_risk),
        farmer=_farmer(snow, precip, reservoir, allocation),
        supply=_supply(snow, reservoir, drought_risk, flood_risk),
        estimated_ag_allocation_pct=allocation,
        allocation_basis=basis,
        region=region,
    )
