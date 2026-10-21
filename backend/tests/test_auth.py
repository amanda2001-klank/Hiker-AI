import pytest
from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from app.main import app
from app.database import Base, get_db
from app.security import get_password_hash, verify_password

SQLALCHEMY_DATABASE_URL = "sqlite:///./test.db"

engine = create_engine(
    SQLALCHEMY_DATABASE_URL, connect_args={"check_same_thread": False}
)
TestingSessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)

Base.metadata.create_all(bind=engine)

def override_get_db():
    try:
        db = TestingSessionLocal()
        yield db
    finally:
        db.close()

app.dependency_overrides[get_db] = override_get_db

client = TestClient(app)

def test_password_hashing():
    pwd = "SecurePassword123!"
    hashed = get_password_hash(pwd)
    assert verify_password(pwd, hashed) is True
    assert verify_password("WrongPassword", hashed) is False

def test_signup_and_login():
    payload = {
        "email": "testuser@venture.com",
        "password": "SecurePassword123!",
        "username": "TestHiker"
    }

    # Signup
    response = client.post("/api/v1/signup", json=payload)
    assert response.status_code == 200
    data = response.json()
    assert data["message"] == "Account created successfully"
    assert data["data"]["email"] == payload["email"]
    assert "token" in data["data"]

    # Duplicate Signup
    response_dup = client.post("/api/v1/signup", json=payload)
    assert response_dup.status_code == 400

    # Login
    login_payload = {
        "email": "testuser@venture.com",
        "password": "SecurePassword123!"
    }
    login_res = client.post("/api/v1/login", json=login_payload)
    assert login_res.status_code == 200
    login_data = login_res.json()
    assert login_data["message"] == "Login successful"
    assert login_data["data"]["email"] == payload["email"]
    assert "token" in login_data["data"]

    # Incorrect Password Login
    bad_login = {
        "email": "testuser@venture.com",
        "password": "WrongPassword"
    }
    bad_res = client.post("/api/v1/login", json=bad_login)
    assert bad_res.status_code == 401
