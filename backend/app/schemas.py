from typing import Any, Optional
from pydantic import BaseModel, EmailStr

class SignupRequest(BaseModel):
    email: EmailStr
    password: str
    username: str
    profile_image_url: Optional[str] = None

class LoginRequest(BaseModel):
    email: EmailStr
    password: str

class UserResponseData(BaseModel):
    user_id: str
    email: str
    username: str
    profile_image_url: Optional[str] = None
    fitness_score: Optional[float] = 82.5
    token: Optional[str] = None

class EnvelopeResponse(BaseModel):
    message: str
    data: Any
    meta: Optional[dict] = {}
