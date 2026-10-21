from fastapi import APIRouter, Query
from ..schemas import EnvelopeResponse

router = APIRouter(prefix="/api/v1/recommendations", tags=["Recommendations"])

@router.get("/trails", response_model=EnvelopeResponse)
def get_trails():
    trails = [
        {
            "title": "Pine Mountain Trail",
            "image_url": "https://images.unsplash.com/photo-1551632811-561732d1e306",
            "distance": "8.5 km",
            "level": "Moderate",
            "time": "2h 30m",
            "location": "Pine Ridge Reserve"
        },
        {
            "title": "Echo Valley Ridge",
            "image_url": "https://images.unsplash.com/photo-1464822759023-fed622ff2c3b",
            "distance": "12.0 km",
            "level": "Hard",
            "time": "4h 00m",
            "location": "Echo National Park"
        }
    ]
    return EnvelopeResponse(
        message="Trail recommendations retrieved successfully",
        data=trails,
        meta={},
    )

@router.get("/pre-hike", response_model=EnvelopeResponse)
def get_pre_hike(date: str = Query("2026-03-15")):
    pre_hike = {
        "recommendations": [
            "Pack at least 2.5L of water and electrolyte tablets.",
            "Wear moisture-wicking apparel and broken-in hiking boots.",
            "Ensure fully charged smartphone and offline navigation maps."
        ],
        "special_notes": [
            f"Forecast for date {date}: Optimal conditions with mild wind.",
            "Leave No Trace principles apply across all reserve trails."
        ],
        "from_trail_recommendation": True
    }
    return EnvelopeResponse(
        message="Pre-hike recommendations retrieved successfully",
        data=pre_hike,
        meta={"date": date},
    )
