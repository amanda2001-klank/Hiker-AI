from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from .database import engine, Base
from .routers import auth, survey, recommendations, activities

app = FastAPI(
    title="APP Venture Backend",
    version="1.0.0",
    description="REST API backend for APP Venture Fitness and Hiking Monitoring",
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(auth.router)
app.include_router(survey.router)
app.include_router(recommendations.router)
app.include_router(activities.router)

# STEP407J: Existing Component 3 weather adapter.
from .component3_weather_router import router as component3_weather_router
app.include_router(component3_weather_router)

@app.get("/", tags=["Health"])
def health_check():
    return {"status": "healthy", "service": "APP Venture API v1"}
