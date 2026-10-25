import pytest
import sys, os
sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), "..")))
from app.services.waste_calculator import WasteCalculator

def test_waste_metrics_exact_reference():
    # 842g initial plate, 210g remaining
    # Consumed = 632g (75.1%)
    # Remaining = 210g (24.9%)
    res = WasteCalculator.calculate_waste_metrics(842.0, 210.0)
    assert res["initial_weight_g"] == 842.0
    assert res["consumed_weight_g"] == 632.0
    assert res["remaining_weight_g"] == 210.0
    assert res["consumed_pct"] == 75.1
    assert res["waste_pct"] == 24.9
    assert res["waste_score"] == 82
    assert res["score_label"] == "Optimal"
    assert len(res["category_breakdown"]) == 5
    assert "lunch" in res["observation"].lower() or "rice" in res["observation"].lower()

def test_waste_metrics_clean_plate():
    res = WasteCalculator.calculate_waste_metrics(500.0, 0.0)
    assert res["consumed_weight_g"] == 500.0
    assert res["waste_pct"] == 0.0
    assert res["waste_score"] == 100
    assert res["score_label"] == "Optimal"

def test_waste_metrics_sensor_anomaly_clamping():
    # If remaining exceeds initial due to plate replacement
    res = WasteCalculator.calculate_waste_metrics(400.0, 450.0)
    assert res["consumed_weight_g"] == 0.0
    assert res["waste_pct"] == 100.0
