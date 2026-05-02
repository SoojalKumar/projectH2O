import sys
from pathlib import Path

import pytest

BACKEND_ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(BACKEND_ROOT))

from app.models.schemas import MetricReading  # noqa: E402


@pytest.fixture
def reading_factory():
    from datetime import date

    def make(snow: float = 100, precip: float = 100, reservoir: float = 80,
             d: date = date(2025, 12, 1)) -> MetricReading:
        return MetricReading(date=d, snowpack_pct=snow, precip_pct=precip, reservoir_pct=reservoir)
    return make
