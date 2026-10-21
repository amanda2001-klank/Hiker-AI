
import os

from dotenv import load_dotenv
from fastapi import APIRouter, Depends, HTTPException, status
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from jose import jwt, JWTError
from pydantic import BaseModel
from sqlalchemy.orm import Session

from ..database import get_db
from ..models import DailyActivity
from ..schemas import EnvelopeResponse

load_dotenv()

SECRET_KEY = os.getenv("SECRET_KEY")
ALGORITHM = os.getenv("ALGORITHM", "HS256")

security = HTTPBearer()

router = APIRouter(
    prefix="/api/v1/activities",
    tags=["Activities"]
)


class ActivityCreate(BaseModel):
    date: str
    steps: int
    calories_burned: float
    distance_km: float
    avg_heart_rate: float


def get_current_user_id(
    credentials: HTTPAuthorizationCredentials = Depends(security),
    db: Session = Depends(get_db),
) -> str:
    if not SECRET_KEY:
        raise HTTPException(
            status_code=500,
            detail="JWT secret is not configured"
        )

    token = credentials.credentials

    try:
        payload = jwt.decode(
            token,
            SECRET_KEY,
            algorithms=[ALGORITHM]
        )

        user_id = payload.get("sub")

        if user_id is None:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Invalid authentication credentials"
            )

        return str(user_id)

    except JWTError:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Could not validate credentials"
        )


@router.post("", response_model=EnvelopeResponse)
def sync_activity(
    payload: ActivityCreate,
    user_id: str = Depends(get_current_user_id),
    db: Session = Depends(get_db),
):
    existing = db.query(DailyActivity).filter(
        DailyActivity.user_id == user_id,
        DailyActivity.date == payload.date
    ).first()

    if existing:
        existing.steps = payload.steps
        existing.calories_burned = payload.calories_burned
        existing.distance_km = payload.distance_km
        existing.avg_heart_rate = payload.avg_heart_rate
        act = existing
    else:
        act = DailyActivity(
            user_id=user_id,
            date=payload.date,
            steps=payload.steps,
            calories_burned=payload.calories_burned,
            distance_km=payload.distance_km,
            avg_heart_rate=payload.avg_heart_rate,
        )
        db.add(act)

    db.commit()
    db.refresh(act)

    return EnvelopeResponse(
        message="Daily activity synchronized successfully",
        data={
            "id": act.id,
            "date": act.date,
            "steps": act.steps,
            "calories_burned": act.calories_burned,
            "distance_km": act.distance_km,
        },
        meta={},
    )


@router.get("", response_model=EnvelopeResponse)
def get_activities(
    user_id: str = Depends(get_current_user_id),
    db: Session = Depends(get_db),
):
    activities = db.query(DailyActivity).filter(
        DailyActivity.user_id == user_id
    ).all()

    data = [
        {
            "id": a.id,
            "date": a.date,
            "steps": a.steps,
            "calories_burned": a.calories_burned,
            "distance_km": a.distance_km,
            "avg_heart_rate": a.avg_heart_rate,
        }
        for a in activities
    ]

    return EnvelopeResponse(
        message="Daily activities retrieved successfully",
        data=data,
        meta={},
    )
