"""Component 3 testing-only weather adapter.

Returns provider-supplied current model weather, not an on-site measurement.
"""
import asyncio
import json
import math
from datetime import date, datetime, timezone, timedelta
from urllib.parse import urlencode
from urllib.request import urlopen

from fastapi import APIRouter, HTTPException, Query

router = APIRouter()


def fetch_weather(latitude: float, longitude: float):
    params = urlencode({
        "latitude": latitude,
        "longitude": longitude,
        "current": "temperature_2m,relative_humidity_2m",
        "timezone": "UTC",
        "forecast_days": 1,
    })
    url = "https://api.open-meteo.com/v1/forecast?" + params

    with urlopen(url, timeout=12) as response:
        body = json.load(response)

    current = body.get("current")
    if not isinstance(current, dict):
        raise ValueError("Missing provider current weather")

    temperature = current.get("temperature_2m")
    humidity = current.get("relative_humidity_2m")
    observation_time = current.get("time")

    if (
        type(temperature) not in (int, float)
        or type(humidity) not in (int, float)
        or not math.isfinite(temperature)
        or not math.isfinite(humidity)
        or not -60 <= temperature <= 60
        or not 0 <= humidity <= 100
        or not isinstance(observation_time, str)
    ):
        raise ValueError("Invalid provider weather response")

    observed = datetime.fromisoformat(
        observation_time.replace("Z", "+00:00")
    )
    if observed.tzinfo is None:
        observed = observed.replace(tzinfo=timezone.utc)

    age = datetime.now(timezone.utc) - observed

    if age < timedelta(minutes=-10) or age > timedelta(hours=2):
        raise ValueError("Provider weather timestamp is stale")

    return {
        "data": {
            "temperature": float(temperature),
            "humidity": float(humidity),
            "source": "Open-Meteo current model weather",
            "source_time_utc": observed.isoformat(),
        }
    }


@router.get("/weather")
@router.get("/api/v1/weather", include_in_schema=False)
async def component3_weather(
    lat: float = Query(..., ge=-90, le=90),
    lon: float = Query(..., ge=-180, le=180),
    date_value: str | None = Query(None, alias="date"),
):
    if not math.isfinite(lat) or not math.isfinite(lon):
        raise HTTPException(status_code=422, detail="Invalid coordinates")

    if date_value is not None:
        try:
            requested_date = date.fromisoformat(date_value)
        except ValueError:
            raise HTTPException(status_code=422, detail="Invalid date")

        # Flutter supplies the phone-local date; allow UTC day rollover.
        if abs((requested_date - datetime.now(timezone.utc).date()).days) > 1:
            raise HTTPException(
                status_code=422,
                detail="This endpoint provides current weather only",
            )

    try:
        return await asyncio.wait_for(
            asyncio.to_thread(fetch_weather, lat, lon),
            timeout=15,
        )
    except Exception:
        raise HTTPException(
            status_code=503,
            detail="Current weather temporarily unavailable",
        )