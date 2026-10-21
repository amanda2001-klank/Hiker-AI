from fastapi import APIRouter, Body
from ..schemas import EnvelopeResponse

router = APIRouter(prefix="/api/v1", tags=["Survey"])

@router.get("/survey", response_model=EnvelopeResponse)
def get_survey():
    questions = [
        {
            "code": "Q01",
            "title": "How many years of regular hiking experience do you have?",
            "hint": "Select your approximate duration of regular hiking.",
            "answers": ["< 1 year", "1 - 3 years", "3 - 5 years", "5+ years"]
        },
        {
            "code": "Q02",
            "title": "What is your preferred hiking terrain?",
            "hint": "Choose the terrain you hike most frequently.",
            "answers": ["Flat Walking Paths", "Hilly / Rolling Hills", "Steep Mountain Trails", "Rugged Backcountry"]
        },
        {
            "code": "Q03",
            "title": "What is the maximum distance you comfortably hike in a day?",
            "hint": "Estimate your average daily comfortable hiking range.",
            "answers": ["Under 5 km", "5 - 10 km", "10 - 20 km", "20+ km"]
        },
        {
            "code": "Q04",
            "title": "How often do you engage in strenuous cardio exercise?",
            "hint": "Weekly frequency of high-intensity cardiovascular training.",
            "answers": ["Rarely", "1-2 times a week", "3-4 times a week", "Daily"]
        }
    ]
    return EnvelopeResponse(
        message="Survey questions retrieved successfully",
        data=questions,
        meta={},
    )

@router.post("/survey", response_model=EnvelopeResponse)
def submit_survey(submissions: list = Body(...)):
    return EnvelopeResponse(
        message="Survey submitted and evaluated successfully",
        data={"evaluated": True, "count": len(submissions)},
        meta={},
    )
