import pytest
from fastapi.testclient import TestClient
import sys, os
sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), "..")))
from app.main import app
from app.services.vision_recognizer import FoodVisionRecognizer
from app.services.nutrition_engine import NutritionEngine

client = TestClient(app)

def test_mode_a_device_weight_tare_subtraction():
    """Mode A (Device): Net food weight must be gross minus plate tare (842 - 356 = 486)."""
    resp = client.post("/api/v1/vision/analyze", json={
        "pad_weight_g": 842.0,
        "weight_source": "device",
        "tare_weight_g": 356.0,
        "dish_hint": "Vegetable Rice Bowl"
    })
    assert resp.status_code == 200
    data = resp.json()
    assert data["weight_source"] == "device"
    assert data["total_weight_g"] == 842.0
    assert data["net_food_weight_g"] == 486.0
    assert len(data["components"]) > 0

    # Mathematical portion reconciliation check
    comp_sum = round(sum(c["weight_g"] for c in data["components"]), 1)
    assert comp_sum == 486.0, f"Component sum {comp_sum} does not match net food weight 486.0"

def test_mode_b_manual_weight_direct_entry():
    """Mode B (Manual): Net food weight is the direct user input without subtracting tare."""
    resp = client.post("/api/v1/vision/analyze", json={
        "pad_weight_g": 420.0,
        "weight_source": "manual",
        "dish_hint": "Paneer Roti Meal"
    })
    assert resp.status_code == 200
    data = resp.json()
    assert data["weight_source"] == "manual"
    assert data["net_food_weight_g"] == 420.0
    assert data["dish_name"] == "Paneer Roti Meal"

    # Component weights must sum to 420.0 exactly
    comp_sum = round(sum(c["weight_g"] for c in data["components"]), 1)
    assert comp_sum == 420.0, f"Component sum {comp_sum} does not match manual input 420.0"

def test_portion_reconciliation_odd_weights():
    """Test portion reconciliation across arbitrary floating point weights."""
    test_weights = [157.3, 345.8, 486.0, 789.2, 1120.5]
    for w in test_weights:
        result = FoodVisionRecognizer.analyze_food_image(
            total_weight_g=w,
            weight_source="manual",
            dish_hint="Vegetable Rice Bowl"
        )
        comp_sum = round(sum(c["weight_g"] for c in result["components"]), 1)
        assert comp_sum == round(w, 1), f"Discrepancy: components sum to {comp_sum} vs expected {round(w, 1)}"

def test_weight_validation_boundaries():
    """Server-side validation must reject invalid, negative, zero, and out-of-scale weights."""
    # Negative weight
    r_neg = client.post("/api/v1/vision/analyze", json={
        "pad_weight_g": -50.0,
        "weight_source": "manual"
    })
    assert r_neg.status_code == 422

    # Zero / gross equals tare (0 net food)
    r_zero = client.post("/api/v1/vision/analyze", json={
        "pad_weight_g": 356.0,
        "weight_source": "device",
        "tare_weight_g": 356.0
    })
    assert r_zero.status_code == 422

    # Below 10g threshold
    r_tiny = client.post("/api/v1/vision/analyze", json={
        "pad_weight_g": 5.0,
        "weight_source": "manual"
    })
    assert r_tiny.status_code == 422

    # Exceeding 2500g max limit
    r_huge = client.post("/api/v1/vision/analyze", json={
        "pad_weight_g": 3000.0,
        "weight_source": "manual"
    })
    assert r_huge.status_code == 422

def test_nutrition_uncertainty_bounds():
    """Every component must report valid uncertainty bounds (low, central, high)."""
    resp = client.post("/api/v1/vision/analyze", json={
        "pad_weight_g": 500.0,
        "weight_source": "manual",
        "dish_hint": "Vegetable Rice Bowl"
    })
    assert resp.status_code == 200
    data = resp.json()
    for comp in data["components"]:
        assert comp["uncertainty_min_kcal"] <= comp["calories_kcal"]
        assert comp["calories_kcal"] <= comp["uncertainty_max_kcal"]
        assert comp["portion_ratio"] > 0.0
        assert comp["preparation_style"] != ""

def test_meal_persistence_with_weight_source():
    """Saving and retrieving a meal session must persist weight_source (manual or device)."""
    # Register/login user for authenticated meal recording
    reg = client.post("/api/v1/auth/register", json={
        "email": "persistence_test_user@dinieco.com",
        "password": "password123",
        "full_name": "Persistence User"
    })
    token = reg.json().get("access_token") if reg.status_code == 200 else client.post("/api/v1/auth/login", json={
        "email": "persistence_test_user@dinieco.com",
        "password": "password123"
    }).json()["access_token"]
    headers = {"Authorization": f"Bearer {token}"}

    # 1. Analyze manual plate
    v_resp = client.post("/api/v1/vision/analyze", json={
        "pad_weight_g": 450.0,
        "weight_source": "manual",
        "dish_hint": "Paneer Roti Meal"
    }, headers=headers)
    assert v_resp.status_code == 200
    v_data = v_resp.json()

    # 2. Record meal with weight_source = "manual"
    m_resp = client.post("/api/v1/meals/", json={
        "meal_name": "Paneer Roti Meal",
        "initial_weight_g": 450.0,
        "remaining_weight_g": 50.0,
        "weight_source": "manual",
        "tare_weight_g": 0.0,
        "components": v_data["components"]
    }, headers=headers)
    assert m_resp.status_code == 200
    meal = m_resp.json()
    assert meal["weight_source"] == "manual"
    assert meal["initial_weight_g"] == 450.0
    assert meal["consumed_weight_g"] == 400.0
    meal_id = meal["id"]

    # 3. Retrieve meal by ID
    get_resp = client.get(f"/api/v1/meals/{meal_id}", headers=headers)
    assert get_resp.status_code == 200
    fetched = get_resp.json()
    assert fetched["id"] == meal_id
    assert fetched["weight_source"] == "manual"
    assert len(fetched["components"]) == len(v_data["components"])
