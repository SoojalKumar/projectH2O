"""LLM integration via Groq. Used ONLY for explanation — never for
classification, band assignment, or alert triggering. Every method has an
offline fallback so the demo never breaks when the API key is missing or the
call errors out.

Responses are cached in-process by (prompt + payload) hash so identical inputs
don't re-burn the rate-limit budget. Cleared by `clear_cache()` (called on
dataset refresh).
"""
import hashlib
import json
import logging
from functools import lru_cache
from pathlib import Path
from typing import Any

from groq import Groq

from app.core.config import get_settings

logger = logging.getLogger(__name__)


@lru_cache
def _load_prompt(name: str) -> str:
    settings = get_settings()
    path: Path = settings.prompts_dir / f"{name}.txt"
    return path.read_text(encoding="utf-8")


class LlmService:
    def __init__(self) -> None:
        settings = get_settings()
        self.enabled = bool(settings.groq_api_key)
        self.model_name = settings.llm_model
        self._cache: dict[str, str] = {}
        if self.enabled:
            self._client = Groq(api_key=settings.groq_api_key)
        else:
            self._client = None
            logger.warning("GROQ_API_KEY not set — LLM calls will return offline fallbacks.")

    def clear_cache(self) -> int:
        n = len(self._cache)
        self._cache.clear()
        return n

    def _cache_key(self, system_prompt: str, payload: dict[str, Any]) -> str:
        blob = system_prompt + "::" + json.dumps(payload, default=str, sort_keys=True)
        return hashlib.sha1(blob.encode("utf-8")).hexdigest()

    def _generate(self, system_prompt: str, payload: dict[str, Any]) -> str:
        if not self.enabled:
            return ""

        key = self._cache_key(system_prompt, payload)
        cached = self._cache.get(key)
        if cached:
            return cached

        try:
            completion = self._client.chat.completions.create(
                model=self.model_name,
                messages=[
                    {"role": "system", "content": system_prompt},
                    {
                        "role": "user",
                        "content": f"INPUT:\n{json.dumps(payload, default=str)}",
                    },
                ],
                temperature=0.3,
                max_tokens=400,
            )
            text = (completion.choices[0].message.content or "").strip()
        except Exception as exc:
            msg = str(exc)
            if "429" in msg or "rate" in msg.lower() or "quota" in msg.lower():
                logger.warning("LLM rate-limited; serving offline fallback.")
            else:
                logger.exception("LLM generation failed: %s", exc)
            return ""

        # Drift guard — reject output where the model invented percentages
        # that don't appear in the input within ±5 points.
        if text and not self._numbers_consistent(text, payload):
            logger.warning(
                "LLM output rejected for drift (numbers not in input ±5)."
            )
            return ""

        if text:
            self._cache[key] = text
        return text

    @staticmethod
    def _flatten_numbers(obj: Any) -> list[float]:
        """Walk the input payload collecting every numeric leaf."""
        out: list[float] = []
        if isinstance(obj, (int, float)):
            out.append(float(obj))
        elif isinstance(obj, dict):
            for v in obj.values():
                out.extend(LlmService._flatten_numbers(v))
        elif isinstance(obj, list):
            for v in obj:
                out.extend(LlmService._flatten_numbers(v))
        return out

    @staticmethod
    def _numbers_consistent(text: str, payload: dict[str, Any]) -> bool:
        """Every percentage the model writes must be within 5 points of a
        number actually present in the input. Tolerates years (4-digit
        integers) which are not percentages.
        """
        import re

        # Match standalone percentages: "65%", "100%", "5.5%"
        matches = re.findall(r"\b(\d+(?:\.\d+)?)\s*%", text)
        if not matches:
            return True

        sources = LlmService._flatten_numbers(payload)
        # Allow years and small ints (counts) to pass through unchecked.
        for raw in matches:
            v = float(raw)
            if 1900 <= v <= 2100:
                continue
            if any(abs(v - s) <= 5.0 for s in sources):
                continue
            return False
        return True

    # ------------------------------------------------------------------
    # Chat — multi-turn assistant grounded in the current dataset context.
    # System prompt is built fresh each call so the model always answers
    # against the latest deterministic state.
    # ------------------------------------------------------------------
    def chat(self, messages: list[dict[str, str]]) -> str:
        # Lazy imports avoid circulars (these services import from us-adjacent code).
        from app.services import alert_service, supply_service

        latest = supply_service.latest_reading()
        snow, precip, res = supply_service.classify_reading(latest)
        outlook = supply_service.combined_outlook(snow, precip, res)
        alerts = [a.title for a in alert_service.detect_alerts()]
        alerts_str = "; ".join(alerts) if alerts else "none active"

        system = (
            "You are Hydra, an assistant focused exclusively on California "
            "water supply: snowpack, precipitation, reservoirs, multi-signal alerts, "
            "and historical patterns.\n\n"
            f"CURRENT DATA (as of {latest.date.strftime('%B %Y')}):\n"
            f"- Snowpack: {snow.value:.0f}% of April 1 average ({snow.label})\n"
            f"- Precipitation: {precip.value:.0f}% of normal ({precip.label})\n"
            f"- Reservoirs: {res.value:.0f}% of capacity ({res.label})\n"
            f"- Combined outlook: {outlook.label} — {outlook.rationale}\n"
            f"- Active multi-signal alerts: {alerts_str}\n\n"
            "RULES:\n"
            "- Answer in 2-4 short sentences max. No bullet lists, no preamble, "
            "no greetings. Start directly with the answer.\n"
            "- Match the user's language. If they ask in Spanish, answer in "
            "Spanish; in French, answer in French; etc.\n"
            "- Plain language. No alarmism. No emojis.\n"
            "- Reference real California water-supply mechanics (snowmelt timing, "
            "atmospheric rivers, runoff vs storage) when relevant.\n"
            "- ONLY when a question is clearly off-topic (not about California "
            "water supply at all), reply with a single short redirect sentence "
            "in the user's language pointing them back to snowpack, precipitation, "
            "reservoirs, or how they connect. Never include this redirect when "
            "the question is on-topic.\n"
            "- Don't invent numbers. Use only the data above."
        )

        if not self.enabled:
            return ("Chat is offline (no LLM key configured). Once configured, ask "
                    "me about snowpack, precipitation, reservoirs, alerts, or trends.")

        chat_msgs: list[dict[str, str]] = [{"role": "system", "content": system}]
        chat_msgs.extend(messages)

        try:
            completion = self._client.chat.completions.create(
                model=self.model_name,
                messages=chat_msgs,
                temperature=0.4,
                max_tokens=320,
            )
            return (completion.choices[0].message.content or "").strip()
        except Exception as exc:
            msg = str(exc)
            if "429" in msg or "rate" in msg.lower():
                return "I'm rate-limited for a moment — try again in a few seconds."
            logger.exception("Chat call failed: %s", exc)
            return "Something went wrong reaching the model. Try again."

    # ------------------------------------------------------------------
    # Outlook explanation — single paragraph that ties the three signals
    # together for the dashboard hero.
    # ------------------------------------------------------------------
    def outlook_explanation(self, payload: dict[str, Any]) -> str:
        raw = self._generate(_load_prompt("outlook_explainer"), payload)
        if raw:
            return raw

        snow = payload.get("snowpack", {})
        precip = payload.get("precip", {})
        res = payload.get("reservoir", {})
        outlook = payload.get("outlook", {})
        return (
            f"Snowpack is at {snow.get('value', 0):.0f}% of the April 1 average ({snow.get('label', '')}), "
            f"precipitation is {precip.get('value', 0):.0f}% of normal ({precip.get('label', '')}), "
            f"and reservoirs are {res.get('value', 0):.0f}% full ({res.get('label', '')}). "
            f"Combined outlook: {outlook.get('label', 'Stable')}. {outlook.get('rationale', '')}"
        )

    # ------------------------------------------------------------------
    # Alert context — explain *why* this multi-signal pattern matters.
    # ------------------------------------------------------------------
    def alert_context(self, payload: dict[str, Any]) -> str:
        raw = self._generate(_load_prompt("alert_explainer"), payload)
        if raw:
            return raw

        title = payload.get("title", "")
        if "snowpack is concerning despite normal precipitation" in title.lower():
            return (
                "When rain comes but snow doesn't, water shows up in rivers fast and leaves "
                "fast. There's no slow-melt buffer to feed reservoirs through summer."
            )
        if "healthy reservoirs" in title.lower():
            return (
                "Reservoirs reflect the water year that just happened. Snowpack is the leading "
                "indicator for next year — today's buffer can shrink quickly if snow doesn't deliver."
            )
        if "wet conditions" in title.lower():
            return (
                "A wet recent stretch is good news, but precipitation alone doesn't translate to "
                "long-term storage. Snow is what stretches a season's water through the dry months."
            )
        if "all three" in title.lower():
            return "All three signals aligned in the healthy bands is the cleanest setup California can have heading into a new water year."
        if "drought" in title.lower():
            return (
                "Sub-70% precipitation is the formal drought-signal threshold. Combined with the "
                "current snowpack situation, this is the kind of pattern that triggers state-level water restrictions."
            )
        if "drawing down" in title.lower():
            return (
                "Reservoirs that lose 15+ points in six months without a strong snow year ahead are "
                "the textbook setup for late-summer supply pressure."
            )
        return "Multi-signal patterns matter because each metric tells a different part of the story — supply forecasts that read just one are routinely wrong."

    # ------------------------------------------------------------------
    # Historical synthesis — describe the year-by-year picture.
    # ------------------------------------------------------------------
    def historical_summary(self, payload: dict[str, Any]) -> str:
        raw = self._generate(_load_prompt("historical_explainer"), payload)
        if raw:
            return raw

        years = payload.get("years", [])
        best = payload.get("best_year")
        worst = payload.get("worst_year")
        current = payload.get("current_year")
        if not years:
            return ""
        strong = [y["year"] for y in years if y.get("label") == "Strong"]
        weak = [y["year"] for y in years if y.get("label") == "Weak"]
        bits = [
            f"Across {years[0]['year']}–{years[-1]['year']}, California's water years swung between extremes."
        ]
        if strong:
            bits.append(f"Strong years: {', '.join(str(y) for y in strong)}.")
        if weak:
            bits.append(f"Weak years: {', '.join(str(y) for y in weak)}.")
        if best and worst:
            bits.append(
                f"{best} was the strongest year on the record, {worst} the weakest."
            )
        if current:
            bits.append(
                f"{current} is tracking closer to the {next((y['label'] for y in years if y['year'] == current), 'mixed').lower()} side of the range."
            )
        return " ".join(bits)

    # ------------------------------------------------------------------
    # Predictive narrative — analog year + risk classifications.
    # ------------------------------------------------------------------
    def predictive_narrative(self, payload: dict[str, Any]) -> str:
        raw = self._generate(_load_prompt("predictive_narrative"), payload)
        if raw:
            return raw

        evt = payload.get("next_event") or {}
        drought = payload.get("drought") or {}
        flood = payload.get("flood") or {}

        bits: list[str] = []

        evt_type = evt.get("type", "none")
        if evt_type != "none" and evt.get("summary"):
            bits.append(evt["summary"])
        else:
            bits.append("No significant precipitation event in the 7-day window.")

        d_level = drought.get("level", "low")
        f_level = flood.get("level", "low")
        if d_level in {"elevated", "high"} and f_level in {"low", "moderate"}:
            bits.append(
                f"Drought risk over the 90-day horizon is {d_level}; flood risk is contained."
            )
        elif f_level in {"elevated", "high"} and d_level in {"low", "moderate"}:
            bits.append(
                f"Flood risk runs {f_level} near-term, with drought concerns secondary."
            )
        elif d_level == "low" and f_level == "low":
            bits.append("Both drought and flood risks read low — a quieter window ahead.")
        else:
            bits.append(
                f"Drought risk is {d_level}; flood risk is {f_level}. Snowpack remains the swing factor."
            )
        return " ".join(bits)

    # ------------------------------------------------------------------
    # Outlook report — synthesize improved/worsened/risky/watch lists.
    # ------------------------------------------------------------------
    def outlook_report_summary(self, payload: dict[str, Any]) -> str:
        raw = self._generate(_load_prompt("outlook_report").strip(), payload)
        if raw:
            return raw

        improved = payload.get("improved") or []
        worsened = payload.get("worsened") or []
        risky = payload.get("still_risky") or []
        bits = []
        if improved and worsened:
            bits.append(
                f"Mixed picture over the period: {len(improved)} signal{'s' if len(improved) != 1 else ''} "
                f"improved, {len(worsened)} got worse."
            )
        elif improved:
            bits.append(f"Trajectory is positive — {len(improved)} signal(s) improved with none worsening.")
        elif worsened:
            bits.append(f"Trajectory is negative — {len(worsened)} signal(s) deteriorated.")
        else:
            bits.append("Conditions held steady across the window.")
        if risky:
            bits.append(
                f"{len(risky)} signal(s) still sit in watch or concern territory."
            )
        bits.append(
            "Snowpack remains the leading indicator for next year — keep an eye on the April 1 reading."
        )
        return " ".join(bits)


@lru_cache
def get_llm_service() -> LlmService:
    return LlmService()
