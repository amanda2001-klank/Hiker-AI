from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from ..database import get_db
from ..schemas import SignupRequest, LoginRequest, EnvelopeResponse, UserResponseData
from ..crud import get_user_by_email, create_user, authenticate_user
from ..security import create_access_token

router = APIRouter(prefix="/api/v1", tags=["Auth"])

@router.post("/signup", response_model=EnvelopeResponse)
def signup(payload: SignupRequest, db: Session = Depends(get_db)):
    existing = get_user_by_email(db, payload.email)
    if existing:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Email already registered",
        )
    user = create_user(db, payload)
    token = create_access_token(data={"sub": str(user.id), "email": user.email})

    data = {
        "user_id": str(user.id),
        "email": user.email,
        "username": user.username,
        "profile_image_url": user.profile_image_url,
        "fitness_score": 82.5,
        "token": token,
    }
    return EnvelopeResponse(
        message="Account created successfully",
        data=data,
        meta={},
    )

@router.post("/login", response_model=EnvelopeResponse)
def login(payload: LoginRequest, db: Session = Depends(get_db)):
    user = authenticate_user(db, payload.email, payload.password)
    if not user:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid email or password",
        )
    token = create_access_token(data={"sub": str(user.id), "email": user.email})

    data = {
        "user_id": str(user.id),
        "username": user.username,
        "email": user.email,
        "profile_image_url": user.profile_image_url,
        "fitness_score": 82.5,
        "token": token,
    }
    return EnvelopeResponse(
        message="Login successful",
        data=data,
        meta={},
    )
