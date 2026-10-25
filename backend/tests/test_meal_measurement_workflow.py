import sys, os
sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), "..")))
import pytest
from fastapi.testclient import TestClient
from app.main import app

client = TestClient(app)

@pytest.fixture
def auth_headers():
    unique_email = f"workflow_tester_{pytest.__version__}@dinieco.com"
    reg_res = client.post("/api/v1/auth/register", json={
        "email": unique_email,
        "password": "Password123!",
        "full_name": "Measurement Workflow Tester"
    })
    if reg_res.status_code == 200:
        token = reg_res.json()["access_token"]
    else:
        login_res = client.post("/api/v1/auth/login", json={
            "email": unique_email,
            "password": "Password123!"
        })
        token = login_res.json()["access_token"]
    return {"Authorization": f"Bearer {token}"}

def test_meal_session_with_measured_plate_weight(auth_headers):
    payload = {
        "meal_name": "Measured Bowl Lunch",
        "start_gross_weight_g": 650.0,
        "end_gross_weight_g": 350.0,
        "plate_weight_g": 250.0,
        "plate_weight_mode": "measured",
        "weight_source": "device",
        "start_image_url": "/uploads/start_plate.jpg",
        "end_image_url": "/uploads/end_plate.jpg",
        "start_image_source": "app_camera",
        "end_image_source": "app_camera",
        "device_id": "DINIECO_PAD_TEST",
        "is_calibrated": True,
        "readings_history": '[{"t": 0, "w": 650.0}, {"t": 120, "w": 350.0}]',
        "components": [
            {
                "name": "Steamed Rice",
                "weight_g": 250.0,
                "confidence": 0.95,
                "calories_kcal": 325,
                "protein_g": 6.5,
                "carbs_g": 70.0,
                "fat_g": 1.0,
            },
            {
                "name": "Dal",
                "weight_g": 150.0,
                "confidence": 0.90,
                "calories_kcal": 180,
                "protein_g": 10.0,
                "carbs_g": 25.0,
                "fat_g": 4.0,
            }
        ]
    }

    res = client.post("/api/v1/meals/", json=payload, headers=auth_headers)
    assert res.status_code == 200
    data = res.json()

    # Net food calculations:
    # start_food = 650.0 - 250.0 = 400.0g
    # end_food = 350.0 - 250.0 = 100.0g
    # weight_reduction = 400.0 - 100.0 = 300.0g
    assert data["start_gross_weight_g"] == 650.0
    assert data["end_gross_weight_g"] == 350.0
    assert data["plate_weight_g"] == 250.0
    assert data["plate_weight_mode"] == "measured"
    assert data["start_food_weight_g"] == 400.0
    assert data["end_food_weight_g"] == 100.0
    assert data["weight_reduction_g"] == 300.0
    assert data["start_image_url"] == "/uploads/start_plate.jpg"
    assert data["end_image_url"] == "/uploads/end_plate.jpg"
    assert data["device_id"] == "DINIECO_PAD_TEST"
    assert data["is_calibrated"] is True
    assert data["is_flagged_increase"] is False

def test_meal_session_with_skipped_plate_weight(auth_headers):
    # When plate weight is skipped (gross mode), does not invent 0g plate weight
    payload = {
        "meal_name": "Skipped Plate Meal",
        "start_gross_weight_g": 520.0,
        "end_gross_weight_g": 120.0,
        "plate_weight_g": None,
        "plate_weight_mode": "none",
        "weight_source": "device",
        "device_id": "DINIECO-PAD-001",
        "components": []
    }

    res = client.post("/api/v1/meals/", json=payload, headers=auth_headers)
    assert res.status_code == 200
    data = res.json()

    assert data["start_gross_weight_g"] == 520.0
    assert data["end_gross_weight_g"] == 120.0
    assert data["plate_weight_g"] is None
    assert data["plate_weight_mode"] == "none"
    assert data["weight_reduction_g"] == 400.0
    assert data["is_flagged_increase"] is False

def test_meal_session_flags_unexpected_weight_increase(auth_headers):
    # If food was added or user pressed on the scale, end weight > start weight
    payload = {
        "meal_name": "Suspicious Increase Meal",
        "start_gross_weight_g": 300.0,
        "end_gross_weight_g": 450.0,
        "plate_weight_g": 150.0,
        "plate_weight_mode": "manual",
        "weight_source": "device",
        "components": []
    }

    res = client.post("/api/v1/meals/", json=payload, headers=auth_headers)
    assert res.status_code == 200
    data = res.json()

    # start_food = 150.0, end_food = 300.0 -> flagged increase!
    assert data["is_flagged_increase"] is True

def test_user_data_isolation(auth_headers):
    # Create a meal for user 1
    create_res = client.post("/api/v1/meals/", json={
        "meal_name": "User 1 Secret Meal",
        "initial_weight_g": 500.0,
        "remaining_weight_g": 100.0,
        "components": []
    }, headers=auth_headers)
    meal_id = create_res.json()["id"]

    import uuid
    # Register user 2 with unique email
    u2_email = f"user2_{uuid.uuid4().hex[:8]}@dinieco.com"
    u2_res = client.post("/api/v1/auth/register", json={
        "email": u2_email,
        "password": "Password123!",
        "full_name": "Second User"
    })
    token2 = u2_res.json()["access_token"]
    u2_headers = {"Authorization": f"Bearer {token2}"}

    # User 2 cannot access User 1's meal
    get_res = client.get(f"/api/v1/meals/{meal_id}", headers=u2_headers)
    assert get_res.status_code == 404

    # User 2 meal list does not contain User 1's meal
    list_res = client.get("/api/v1/meals/", headers=u2_headers)
    assert all(m["id"] != meal_id for m in list_res.json())
