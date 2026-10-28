from typing import Dict, Any, List
from fastapi import APIRouter, Query, HTTPException, status
from app.schemas.schemas import (
    NutritionCalculateRequest,
    NutritionResponse,
    NutritionLookupResponse,
    NutritionCacheStatsResponse,
)
from app.services.nutrition_engine import NutritionEngine
from app.services.nutrition_fetcher import NutritionFetcher
from app.services.nutrition_cache import NutritionCache

router = APIRouter(prefix="/nutrition", tags=["Nutritional Analysis"])

@router.post("/calculate", response_model=NutritionResponse)
def calculate_nutrition(req: NutritionCalculateRequest):
    comp_dicts = [
        {
            "name": c.name,
            "weight_g": c.weight_g,
            "calories_100g": c.calories_100g,
            "protein_100g": c.protein_100g,
            "carbs_100g": c.carbs_100g,
            "fat_100g": c.fat_100g,
            "fiber_100g": c.fiber_100g,
            "sodium_100g": c.sodium_100g,
            "preparation_style": c.preparation_style,
            "icon": c.icon_name,
        }
        for c in req.components
    ]
    totals = NutritionEngine.calculate_meal_totals(comp_dicts)
    return NutritionResponse(
        total_calories=totals["total_calories"],
        total_protein_g=totals["total_protein_g"],
        total_carbs_g=totals["total_carbs_g"],
        total_fat_g=totals["total_fat_g"],
        total_fiber_g=totals["total_fiber_g"],
        total_sodium_mg=totals["total_sodium_mg"]
    )

@router.get("/lookup", response_model=NutritionLookupResponse)
def lookup_food_nutrition(query: str = Query(..., description="Food item name to look up")):
    """
    Looks up verified nutritional data per 100g for a given food.
    Checks the local persistent cache first (<1ms latency).
    If missing, fetches from USDA FoodData Central API or Gemini AI and stores in local cache.
    """
    clean_query = query.strip()
    if not clean_query:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Query parameter cannot be empty"
        )
    data = NutritionFetcher.fetch_nutrition_for_item(clean_query)
    return NutritionLookupResponse(
        name=data.get("name", clean_query.title()),
        calories_100g=float(data.get("calories_100g", 0.0)),
        protein_100g=float(data.get("protein_100g", 0.0)),
        carbs_100g=float(data.get("carbs_100g", 0.0)),
        fat_100g=float(data.get("fat_100g", 0.0)),
        fiber_100g=float(data.get("fiber_100g", 0.0)),
        sodium_100g=float(data.get("sodium_100g", 0.0)),
        preparation=data.get("preparation", "Standard"),
        icon=data.get("icon", "restaurant"),
        source=data.get("source", "local_cache")
    )

@router.get("/cache", response_model=NutritionCacheStatsResponse)
def get_cache_stats():
    """
    Returns metrics and statistics for the local persistent nutrition cache.
    """
    stats = NutritionCache.get_instance().stats()
    return NutritionCacheStatsResponse(**stats)
