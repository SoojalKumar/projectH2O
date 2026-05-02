# SierraSignal

**California water-supply intelligence — three signals, one clear outlook.**

Submission for the H2O Hackathon "Hacking the Supply" challenge.

---

## 1. The challenge

For decades, California water managers leaned on a single number — Sierra Nevada snowpack — as the primary predictor of the state's annual water supply. Snow accumulated through winter, melted slowly through spring, and fed rivers and reservoirs through the dry months.

That model is breaking down. Warmer storms drop rain instead of snow. Snowpack melts earlier and faster. Atmospheric rivers can deliver a year of precipitation in days. Drought can flip to flood in a single season.

The brief is explicit: **modern water supply forecasting requires multiple signals together — snowpack plus reservoir storage plus precipitation trends — not any one in isolation**.

---

## 2. Motivation

We started by asking a basic question: *given today's data, what would a curious, non-expert Californian actually want to know?*

The honest answer wasn't "more dashboards." It was three things:

1. **Is there enough water?** Right now, and for the next planting / planning cycle.
2. **What's coming?** A storm? A dry stretch? An atmospheric river that flips reservoirs from healthy to overflowing?
3. **What does any of this mean for me?** Should I conserve? Plan for fallow ground? Expect water restrictions?

Then we talked to a water-supply expert. Their feedback reshaped the product:

- Reservoir adequacy is a first-class concept — not just "how full" but **adequate / healthy / tight / overflow-pressure**.
- Reservoirs being too full is also a problem — it stresses infrastructure and water quality when storms hit.
- Farmers face binary, costly decisions — plant or fallow, water trees or let them die — and those decisions hinge on **state allocation %**, which varies year to year (5%–100% historically).
- Public education is the hardest piece. People don't engage with raw numbers; they engage with consequences.

That feedback turned what could have been a data viewer into something with stakes.

---

## 3. Problem statement

> **California's water-supply story can no longer be told by a single metric, and the people who need to act on it — citizens deciding whether to conserve, farmers deciding whether to plant, managers deciding allocations — don't have a tool that reads multiple signals together and translates them into something actionable.**

A good answer needs to do four things:

| Need | What it requires |
|---|---|
| **Awareness** | Read snowpack, precipitation, and reservoir storage *together*, classified against the state's official thresholds. |
| **Warning** | Surface multi-signal patterns no single metric reveals (e.g., *"healthy reservoirs but future risk rising"*) and flag upcoming precipitation events. |
| **Planning support** | Translate the data into specific guidance for citizens, farmers, and supply managers — including an estimated allocation %. |
| **Education** | Explain *why* it matters in plain language, so non-experts can engage with the science. |

---

## 4. Solution — SierraSignal

A polished, demo-ready Flutter + FastAPI app that classifies the three signals against the brief's exact thresholds, combines them into a single forward-looking outlook, projects the next 6 months with a model fitted on the full 10-year dataset, and translates everything into audience-specific planning guidance.

**One-line pitch:** *California's water supply at a glance — three signals, one clear outlook.*

### 4.1 Five product pillars

1. **Combined outlook** — Strong / Stable / Watch / Concern, derived deterministically from the three signal bands. Not an average; a rule-based classification that captures real water-supply mechanics (e.g., concerning snowpack with healthy reservoirs is *Watch*, because today is OK but next year is at risk).

2. **Multi-signal alerts** — five categories the expert called out:
   - *Drought stress* — formal precipitation shortage
   - *Allocation uncertainty* — farmers' planning trigger
   - *Future weak signal* — adequate buffer today, weak inputs for next year
   - *Flood / overflow pressure* — reservoirs near capacity with storms incoming
   - *Mixed-signal watch* — fallback for ambiguous setups

3. **Forward-looking outlook** — what's coming next:
   - **Next-event panel** that pulls the next significant precipitation event from the Sierra Nevada (Donner Summit) weather window
   - **Drought / flood risk scores** (0–100) combining current state, recent trend, and the upcoming weather window
   - **6-month statistical projection** trained on the full 120-month dataset
   - **Closest historical analog** with what played out in the 6 months that followed

4. **Planning implications card** — three audience tabs:
   - **Citizen** — "Conserve where you can" / "Business as usual" / "Be storm-aware"
   - **Farmer** — *"~58% allocation · plan reduced acreage"* with a deterministic allocation estimate (5–100%)
   - **Supply manager** — *"Adequate today · weak future signal"* / *"Reservoirs full · overflow pressure rising"*

5. **AI explanation layer** — purely for translation, never for classification. Every text surface has a deterministic offline fallback so the demo never depends on an external API for correctness.

---

## 5. Architecture

```
┌─────────────────────────────────────────────────────┐
│                Flutter (web/iOS/Android)            │
│  Riverpod · dio · fl_chart · Inter typography       │
│                                                      │
│  Dashboard · Trends · Alerts · Historical · Report  │
│  Notification banner · Planning card · Chat panel   │
└──────────────────────┬──────────────────────────────┘
                       │ JSON
┌──────────────────────▼──────────────────────────────┐
│              FastAPI · Python 3.14                  │
│                                                      │
│  Deterministic services (no AI in any of these):    │
│   ├── supply_service     band classification +     │
│   │                      combined outlook logic    │
│   ├── alert_service      5 multi-signal patterns   │
│   ├── historical_service per-year labeling         │
│   ├── projection_service seasonal-trend model      │
│   │                      fitted on 120 months      │
│   ├── planning_service   audience implications     │
│   ├── predictive_service stitches it all together  │
│   └── weather_service    21-day Sierra Nevada      │
│                          window anchored to dataset │
│                                                      │
│  Translation layer:                                 │
│   └── llm_service        Llama 3.3 70B via Groq —  │
│                          *only* for plain-language │
│                          explanation, never for    │
│                          classification or scoring │
└─────────────────────────────────────────────────────┘
                       │
                ┌──────▼──────┐
                │  Dataset    │
                │  120 months │
                │  2016–2025  │
                └─────────────┘
```

**Strict separation of concerns:** every numeric judgment is deterministic and auditable. The AI only speaks; it never decides.

---

## 6. The dataset-driven projection model

The brief gave us 120 monthly readings (snowpack %, precipitation %, reservoir %) covering Jan 2016 – Dec 2025. We fit a real time-series model on every metric:

**Method:** seasonal naïve + linear yearly trend.

- For each metric, compute the per-calendar-month mean across all years (this captures California's strong seasonality — snowpack peaks Apr 1, dries out by fall).
- Fit a linear regression on the per-year averages (this captures multi-year drift through drought / recovery cycles).
- Project: `value(target_month) = monthly_average(target_month) + trend_slope × years_ahead`.
- Confidence band: ±1σ of the per-month historical spread, attenuated by horizon.

It's not deep learning — the dataset doesn't support it. It is honest, defensible time-series methodology over the data we have. The card label says **PATTERN MATCH** so judges know we're not pretending.

The model trains in <50 ms at app boot and serves projections at request time with cached parameters.

---

## 7. The AI layer — what we use it for, and what we don't

| Concern | Where | AI involved? |
|---|---|---|
| Snowpack / precip / reservoir band classification | `supply_service.py` | **No** |
| Combined outlook label | `supply_service.py` | **No** |
| Multi-signal alert triggering | `alert_service.py` | **No** |
| Year-by-year labels | `historical_service.py` | **No** |
| 6-month metric projections | `projection_service.py` | **No** |
| Drought / flood risk scoring | `predictive_service.py` | **No** |
| Allocation % estimation | `planning_service.py` | **No** |
| Audience-specific planning guidance | `planning_service.py` | **No** |
| Plain-language outlook explanation | `llm_service.py` | Yes |
| Alert "why this matters" context | `llm_service.py` | Yes |
| Decade-in-context summary | `llm_service.py` | Yes |
| Outlook report synthesis | `llm_service.py` | Yes |
| Chat assistant grounded in the dataset | `llm_service.py` | Yes |

Every AI surface has a deterministic fallback that weaves the actual numbers into coherent text. If the model is unreachable, the demo still reads as a coherent product.

---

## 8. Demo walkthrough (≈ 2 minutes)

1. **Open the app — outlook hero reads "Watch"** with rationale: *"Snowpack is concerning; reservoirs are buying time but next year is at risk."* Three metric tiles below show 65% / 105% / 72% — the brief's headline insight in one glance.

2. **Precipitation notification banner** auto-surfaces at the top: *"Snow event ahead · Wednesday · ~6" snow expected."* — the dataset's anchor date is Dec 1, 2025, and a real storm sits 2 days out.

3. **"What this means" card** — tap through the three audiences:
   - *Citizen:* "Conserve where you can"
   - *Farmer:* "~58% allocation · plan reduced acreage"
   - *Supply:* "Adequate today · weak future signal"

4. **Multi-signal alerts** — three active patterns: snowpack-low-despite-normal-precip (the brief's own headline insight, lifted into a deterministic detector), allocation uncertainty, reservoir drawdown.

5. **Trends tab** — three colored lines on a single chart, hover any month to inspect exact values. Animation runs once on entry, no AI-slop sparkles.

6. **Forecast card** — 90-day outlook leading with the next storm, then drought + flood risk scores with reasoning, then a 3-sentence narrative tying current event → planning takeaway → model projection.

7. **Chat panel** (FAB, bottom-right) — multilingual; ask in Spanish, get a Spanish answer grounded in the dataset.

---

## 9. What makes this submission different

- **Data-truthful.** Every number on screen is either directly from the dataset, computed deterministically from it, or projected by a fitted model with declared method and confidence. The "today" in the app is the dataset's last reading (Dec 1, 2025) — there is no live API, no real-time clock dependency, no contradiction between what's shown and what's real.

- **Multi-signal by construction.** The brief's central thesis — "snowpack alone is no longer enough" — is not a tagline in the README; it's a deterministic detector that triggers a labeled alert when snowpack is concerning while precipitation is normal. Five such detectors, all auditable, all expert-informed.

- **Action-oriented.** The planning card answers the actual question Californians ask: *what does this mean for me?* Citizen, farmer, and supply manager each get a one-line headline backed by a one-sentence detail.

- **Honest about its limits.** The forecast card carries a "PATTERN MATCH" label. The narrative tells you it's pattern analysis on a 10-year record, not a calibrated meteorological forecast. Confidence bands widen with horizon. We don't dress up rule-based classification as ML.

- **AI as translator, not authority.** Every classification, every score, every alert is deterministic. The LLM only puts the data into plain English. If the API is down, the offline fallback says the same thing in slightly less polished words. The demo never breaks.

- **Polished, not bloated.** Two bottom-nav tabs (Outlook · Report). Everything else is a card or a push route. Editorial premium minimal — hairline edges, restrained color, typography-driven hierarchy. The app reads as one product, not a collection of features.

---

## 10. Closing

SierraSignal turns the brief's dataset into something a curious citizen, a planting-decision farmer, or a supply manager can act on. It doesn't predict the weather. It reads the three signals together — the way the brief asks — and translates that reading into language, alerts, and guidance that match how real people make decisions about water.

The pitch is simple: *if snowpack alone isn't enough, here's what is.*
