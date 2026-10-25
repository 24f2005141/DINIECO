import pytest
from fastapi.testclient import TestClient
import sys, os, io
sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), "..")))
from app.main import app

client = TestClient(app)

def get_auth_token(email="api_test_user@dinieco.com", password="password123"):
    # Register or login
    reg_resp = client.post("/api/v1/auth/register", json={
        "email": email,
        "password": password,
        "full_name": "API Test User"
    })
    if reg_resp.status_code == 200:
        return reg_resp.json()["access_token"]
    
    login_resp = client.post("/api/v1/auth/login", json={
        "email": email,
        "password": password
    })
    assert login_resp.status_code == 200
    return login_resp.json()["access_token"]

def test_health_and_root():
    r1 = client.get("/")
    assert r1.status_code == 200
    assert r1.json()["platform"] == "DINIECO"
    
    r2 = client.get("/health")
    assert r2.status_code == 200
    assert r2.json()["status"] == "healthy"

def test_device_status_and_stream():
    r = client.get("/api/v1/device/status")
    assert r.status_code == 200
    data = r.json()
    assert data["device_id"] == "DINIECO-PAD-001"
    assert data["battery_percent"] == 94
    assert data["is_connected"] is True
    
    stream = client.get("/api/v1/device/weight-stream")
    assert stream.status_code == 200
    assert "weight_g" in stream.json()

def test_calibration_endpoints():
    r = client.get("/api/v1/calibration/status")
    assert r.status_code == 200
    data = r.json()
    assert data["total_steps"] == 4
    
    step_resp = client.post("/api/v1/calibration/step", json={
        "device_id": "DINIECO-PAD-001",
        "step": 4,
        "confirm_action": True
    })
    assert step_resp.status_code == 200
    assert step_resp.json()["is_complete"] is True

def test_unauthenticated_requests_rejected():
    # Endpoints must reject without token
    r_meals = client.get("/api/v1/meals/")
    assert r_meals.status_code == 401

    r_analytics = client.get("/api/v1/analytics/summary")
    assert r_analytics.status_code == 401

    r_insights = client.get("/api/v1/insights/")
    assert r_insights.status_code == 401

    r_upload = client.post("/api/v1/vision/upload")
    assert r_upload.status_code == 401

def test_new_user_empty_states():
    # Register fresh user with unique email
    new_email = f"fresh_user_{os.urandom(4).hex()}@dinieco.com"
    token = get_auth_token(email=new_email)
    headers = {"Authorization": f"Bearer {token}"}

    # Verify meals list is legitimately empty (NO seed meals!)
    r = client.get("/api/v1/meals/", headers=headers)
    assert r.status_code == 200
    assert r.json() == []

    # Verify analytics returns legitimate zero/empty state
    r_analytics = client.get("/api/v1/analytics/summary", headers=headers)
    assert r_analytics.status_code == 200
    analytics_data = r_analytics.json()
    assert analytics_data["today_waste_g"] == 0.0
    assert analytics_data["weekly_waste_g"] == 0.0
    assert analytics_data["avg_calories"] == 0
    assert analytics_data["category_breakdown"] == []

def test_vision_upload_and_analyze():
    token = get_auth_token()
    headers = {"Authorization": f"Bearer {token}"}

    # 1. Invalid file format rejection
    invalid_file = io.BytesIO(b"fake text content")
    r_invalid = client.post(
        "/api/v1/vision/upload",
        headers=headers,
        files={"file": ("test.txt", invalid_file, "text/plain")}
    )
    assert r_invalid.status_code == 400

    # 2. Valid image upload
    from PIL import Image
    real_img = Image.new("RGB", (100, 100), color=(200, 100, 50))
    valid_jpeg = io.BytesIO()
    real_img.save(valid_jpeg, format="JPEG")
    valid_jpeg.seek(0)
    r_valid = client.post(
        "/api/v1/vision/upload",
        headers=headers,
        files={"file": ("meal_photo.jpg", valid_jpeg, "image/jpeg")}
    )
    assert r_valid.status_code == 200
    upload_data = r_valid.json()
    assert "image_id" in upload_data
    assert upload_data["image_url"].startswith("/uploads/")

    # 3. Analyze endpoint
    r_analyze = client.post("/api/v1/vision/analyze", headers=headers, json={
        "pad_weight_g": 842.0,
        "dish_hint": "Vegetable Rice Bowl"
    })
    assert r_analyze.status_code == 200
    analyze_data = r_analyze.json()
    assert "Rice" in analyze_data["dish_name"] or "Vegetable" in analyze_data["dish_name"]
    assert analyze_data["overall_confidence"] >= 0.85
    assert len(analyze_data["components"]) >= 2

def test_meal_session_crud_and_isolation():
    user1_email = f"user1_{os.urandom(4).hex()}@dinieco.com"
    user2_email = f"user2_{os.urandom(4).hex()}@dinieco.com"
    token1 = get_auth_token(email=user1_email)
    token2 = get_auth_token(email=user2_email)

    headers1 = {"Authorization": f"Bearer {token1}"}
    headers2 = {"Authorization": f"Bearer {token2}"}

    # User 1 creates a meal
    create_payload = {
        "meal_name": "Paneer Rice Meal",
        "initial_weight_g": 520.0,
        "remaining_weight_g": 40.0,
        "image_url": "/uploads/test_photo.jpg",
        "components": [
            {"name": "Steamed Rice", "weight_g": 320.0, "confidence": 0.95, "calories_kcal": 416, "protein_g": 8.6, "carbs_g": 90.2, "fat_g": 1.0},
            {"name": "Paneer Cubes", "weight_g": 200.0, "confidence": 0.94, "calories_kcal": 536, "protein_g": 36.6, "carbs_g": 6.8, "fat_g": 41.6}
        ]
    }
    r_create = client.post("/api/v1/meals/", headers=headers1, json=create_payload)
    assert r_create.status_code == 200
    created_meal = r_create.json()
    meal_id = created_meal["id"]
    assert created_meal["meal_name"] == "Paneer Rice Meal"
    assert created_meal["image_url"] == "/uploads/test_photo.jpg"

    # User 1 can view the meal
    r_get1 = client.get(f"/api/v1/meals/{meal_id}", headers=headers1)
    assert r_get1.status_code == 200

    # User 2 CANNOT access User 1's meal
    r_get2 = client.get(f"/api/v1/meals/{meal_id}", headers=headers2)
    assert r_get2.status_code == 404

    # User 1's analytics reflect the meal
    r_analytics = client.get("/api/v1/analytics/summary", headers=headers1)
    assert r_analytics.status_code == 200
    analytics = r_analytics.json()
    assert analytics["today_waste_g"] == 40.0
    assert analytics["weekly_waste_g"] == 40.0
    assert analytics["avg_calories"] > 0
    assert len(analytics["category_breakdown"]) > 0
