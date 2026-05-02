# Hydra

California water-supply intelligence for the H2O Hackathon "Hacking the Supply" challenge. Reads snowpack + precipitation + reservoir storage together, classifies each against the official California Department of Water Resources thresholds, and surfaces multi-signal patterns no single metric reveals.

> **One-line pitch:** California's water supply at a glance — three signals, one clear outlook.

## Layout

```
projectH2O/
├── backend/    # FastAPI · deterministic classification + AI explanation
└── frontend/   # Flutter · 6-tab shell (Outlook · Trends · Alerts · History · Report · About)
```

## Run the backend

```bash
cd backend
python -m venv .venv && source .venv/bin/activate
pip install -r requirements.txt
cp .env.example .env       # add GEMINI_API_KEY for live AI; without it, fallbacks are used
uvicorn app.main:app --reload --port 8000
```

Health check: <http://localhost:8000/health> · Interactive docs: <http://localhost:8000/docs>.

The dataset is bundled at `backend/app/data/california_supply.json` (snapshot of <https://scoringapi.h2ohackathon.org/Challenge/json>) so the demo never depends on the live API. `POST /supply/refresh` re-reads the file.

## Run the frontend

```bash
cd frontend
flutter pub get
flutter run -d chrome --dart-define=HYDROSENSE_API_BASE_URL=http://localhost:8000
```

For the Android emulator use `http://10.0.2.2:8000` instead.

## Demo path (≈2 minutes)

1. **Outlook** — combined call (Strong / Stable / Watch / Concern) + three metric tiles + AI summary that ties them together.
2. **Multi-signal alerts** — patterns like "snowpack concerning despite normal precipitation" and "healthy reservoirs but future risk rising". Each is deterministic; the LLM adds the *why this matters* layer.
3. **Trends** — three line charts with the threshold bands marked, so the eye reads severity at a glance.
4. **History** — every year 2016–2025 labeled Strong / Mixed / Weak, best year and worst year called out.
5. **Report** — what improved, what worsened, what's still risky, what to watch next, plus an AI synthesis at the top.

## What is deterministic vs. AI

| Concern                         | Where                                          | AI? |
| ------------------------------- | ---------------------------------------------- | --- |
| Snowpack / precip / reservoir bands | `backend/app/services/supply_service.py`   | no  |
| Combined outlook label          | same                                           | no  |
| Multi-signal alert triggering   | `backend/app/services/alert_service.py`        | no  |
| Year-by-year labels (Strong/Mixed/Weak) | `backend/app/services/historical_service.py` | no |
| Outlook explanation             | `backend/app/services/llm_service.py`       | yes |
| Alert "why this matters" context | same                                          | yes |
| Decade-in-context summary        | same                                          | yes |
| Outlook report synthesis         | same                                          | yes |

Every AI method has an offline fallback that weaves the actual numbers into coherent text — the demo never breaks if the API key is missing or the call errors out.

## Tests

```bash
cd backend && source .venv/bin/activate && pytest tests/ -q
```

23 tests across `supply_service`, `alert_service`, and `historical_service` cover band classification, the combined-outlook logic for every relevant signal combination, and each multi-signal alert pattern.
