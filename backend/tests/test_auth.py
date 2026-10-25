import pytest
from fastapi.testclient import TestClient
import sys, os
sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), "..")))
from app.main import app

client = TestClient(app)

def test_auth_register_and_login():
    email = "test_aarav_new@dinieco.com"
    password = "secure_password_123"
    
    # 1. Register
    reg_resp = client.post("/api/v1/auth/register", json={
        "email": email,
        "password": password,
        "full_name": "Aarav Test"
    })
    assert reg_resp.status_code in [200, 400]
    
    # 2. Login
    login_resp = client.post("/api/v1/auth/login", json={
        "email": email,
        "password": password
    })
    assert login_resp.status_code == 200
    token_data = login_resp.json()
    assert "access_token" in token_data
    assert token_data["token_type"] == "bearer"
    
    # 3. Invalid credentials
    bad_resp = client.post("/api/v1/auth/login", json={
        "email": email,
        "password": "wrong_password"
    })
    assert bad_resp.status_code == 401
