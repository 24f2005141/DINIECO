import pytest
import sys, os
from pathlib import Path

sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), "..")))

from fastapi.testclient import TestClient
from app.main import app
from app.services.nutrition_cache import NutritionCache
from app.services.nutrition_fetcher import NutritionFetcher
from app.services.vision_recognizer import FoodVisionRecognizer

client = TestClient(app)

def test_nutrition_cache_basic_operations(tmp_path):
    cache_file = tmp_path / "test_cache.json"
    cache = NutritionCache(cache_file_path=cache_file)
    
    # 1. Pre-seeded items should be present
    assert cache.has("papaya")
    assert cache.has("cucumber")
    
    # 2. Normalization test
    item = cache.get("fresh ripe papaya cubes")
    assert item is not None
    assert item["calories_100g"] == 43.0
    
    # 3. Add custom item
    cache.set("Blueberry", {
        "calories_100g": 57.0,
        "protein_100g": 0.7,
        "carbs_100g": 14.5,
        "fat_100g": 0.3,
        "fiber_100g": 2.4,
        "sodium_100g": 1.0,
    }, source="custom_test")
    
    # Check persistence
    assert cache_file.exists()
    
    # Reload from disk into new cache instance
    new_cache = NutritionCache(cache_file_path=cache_file)
    reloaded = new_cache.get("blueberry")
    assert reloaded is not None
    assert reloaded["calories_100g"] == 57.0

def test_nutrition_fetcher_cache_hit():
    cache = NutritionCache.get_instance()
    # Papaya is preseeded
    res = NutritionFetcher.fetch_nutrition_for_item("papaya")
    assert res is not None
    assert res["source"] == "local_cache"
    assert res["calories_100g"] == 43.0

def test_vision_pipeline_papaya_cucumber_image():
    # Use the test upload if available
    upload_path = Path(__file__).resolve().parent.parent / "uploads" / "e9babf6a-3a6a-4cb5-a49c-bcf3f0af1df7.jpg"
    if not upload_path.exists():
        pytest.skip("Test image e9babf6a-3a6a-4cb5-a49c-bcf3f0af1df7.jpg not found on disk")

    result = FoodVisionRecognizer.analyze_food_image(
        image_url="/uploads/e9babf6a-3a6a-4cb5-a49c-bcf3f0af1df7.jpg",
        total_weight_g=400.0,
        weight_source="manual",
    )

    assert result["net_food_weight_g"] == 400.0
    assert result["ai_verified"] is True
    
    # Ensure components accurately reflect Papaya and Cucumber, NOT Roti or Rice
    comp_names = [c["name"].lower() for c in result["components"]]
    assert any("papaya" in name for name in comp_names), f"Papaya should be detected, got: {comp_names}"
    assert any("cucumber" in name for name in comp_names), f"Cucumber should be detected, got: {comp_names}"
    assert not any("roti" in name for name in comp_names), f"Roti should NOT be detected in papaya/cucumber, got: {comp_names}"
    assert not any("rice" in name for name in comp_names), f"Rice should NOT be detected in papaya/cucumber, got: {comp_names}"

    # Verify portion weights sum exactly to net_food_weight_g
    total_weights = sum(c["weight_g"] for c in result["components"])
    assert round(total_weights, 1) == 400.0

def test_api_nutrition_lookup_and_cache():
    # Test GET /api/v1/nutrition/lookup
    resp = client.get("/api/v1/nutrition/lookup?query=papaya")
    assert resp.status_code == 200
    data = resp.json()
    assert "calories_100g" in data
    assert data["calories_100g"] > 0
    assert data["source"] in ["local_cache", "preseeded", "usda_api"]

    # Test GET /api/v1/nutrition/cache
    cache_resp = client.get("/api/v1/nutrition/cache")
    assert cache_resp.status_code == 200
    cache_data = cache_resp.json()
    assert "total_items" in cache_data
    assert cache_data["total_items"] > 0
    assert "hits" in cache_data
