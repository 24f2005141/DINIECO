import pytest
import sys, os
sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), "..")))
from app.services.nutrition_engine import NutritionEngine

def test_component_nutrition_calculation():
    # 320g of steamed rice (130 kcal/100g, 2.7g P, 28.2g C, 0.3g F)
    # Expected: 3.2 * 130 = 416 kcal, 3.2 * 2.7 = 8.6g P, 3.2 * 28.2 = 90.2g C
    res = NutritionEngine.calculate_component_nutrition("Steamed Rice", 320.0)
    assert res["weight_g"] == 320.0
    assert res["calories_kcal"] > 0
    assert res["protein_g"] > 0
    assert res["carbs_g"] > 0

def test_meal_nutrition_totals():
    components = [
        {"name": "Steamed Rice", "weight_g": 320.0},
        {"name": "Toor Dal Tadka", "weight_g": 120.0},
        {"name": "Mixed Vegetables", "weight_g": 80.0},
        {"name": "Paneer Cubes", "weight_g": 50.0},
        {"name": "Kachumber Salad", "weight_g": 26.0},
    ]
    totals = NutritionEngine.calculate_meal_totals(components)
    assert totals["total_calories"] > 500
    assert totals["total_protein_g"] > 15.0
    assert totals["total_carbs_g"] > 50.0
    assert totals["total_fat_g"] > 10.0
    assert len(totals["components"]) == 5
