import os
import json
import logging
import urllib.request
import urllib.parse
from typing import Dict, Any, Optional
from pydantic import BaseModel, Field
from app.core.config import settings
from app.services.nutrition_cache import NutritionCache

logger = logging.getLogger(__name__)

class NutritionPer100g(BaseModel):
    name: str = Field(description="Canonical food name")
    calories_100g: float = Field(description="Kilocalories per 100 grams")
    protein_100g: float = Field(description="Grams of protein per 100g")
    carbs_100g: float = Field(description="Grams of carbohydrates per 100g")
    fat_100g: float = Field(description="Grams of total fat per 100g")
    fiber_100g: float = Field(default=0.0, description="Grams of dietary fiber per 100g")
    sodium_100g: float = Field(default=0.0, description="Milligrams of sodium per 100g")
    preparation: str = Field(default="Raw / Standard", description="Preparation style")
    icon: str = Field(default="restaurant", description="Material icon name")

class NutritionFetcher:
    """
    Retrieves verified nutritional content per 100g.
    Strategy:
    1. Local Cache Lookup (<1ms).
    2. USDA FoodData Central API.
    3. Gemini 3.1 Flash Lite structured text lookup.
    4. Heuristic category fallback.
    Results from internet/AI are automatically saved to the local persistent cache.
    """

    @classmethod
    def fetch_nutrition_for_item(cls, food_name: str) -> Dict[str, Any]:
        cache = NutritionCache.get_instance()
        
        # 1. Check local persistent cache first
        cached = cache.get(food_name)
        if cached:
            logger.debug(f"Cache HIT for '{food_name}'")
            return cached

        logger.info(f"Cache MISS for '{food_name}'. Querying internet API / AI...")

        # 2. Query USDA FoodData Central API
        usda_data = cls._fetch_from_usda(food_name)
        if usda_data:
            return cache.set(food_name, usda_data, source="usda_api")

        # 3. Query Gemini 3.1 Flash Lite
        gemini_data = cls._fetch_from_gemini(food_name)
        if gemini_data:
            return cache.set(food_name, gemini_data, source="gemini_api")

        # 4. Fallback estimation based on culinary keywords
        fallback_data = cls._heuristic_fallback(food_name)
        return cache.set(food_name, fallback_data, source="heuristic_fallback")

    @classmethod
    def _fetch_from_usda(cls, food_name: str) -> Optional[Dict[str, Any]]:
        clean_name = NutritionCache.normalize_key(food_name)
        if not clean_name:
            clean_name = food_name.strip()

        api_key = getattr(settings, "USDA_API_KEY", None) or os.environ.get("USDA_API_KEY", "DEMO_KEY")
        params = urllib.parse.urlencode([
            ("query", clean_name),
            ("api_key", api_key),
            ("pageSize", "1"),
            ("dataType", "Foundation"),
            ("dataType", "SR Legacy"),
        ])
        url = f"https://api.nal.usda.gov/fdc/v1/foods/search?{params}"

        try:
            req = urllib.request.Request(
                url,
                headers={"User-Agent": "DiniecoNutritionEngine/1.0", "Accept": "application/json"}
            )
            with urllib.request.urlopen(req, timeout=4.0) as resp:
                if resp.status == 200:
                    payload = json.loads(resp.read().decode("utf-8"))
                    foods = payload.get("foods", [])
                    if not foods:
                        return None

                    food = foods[0]
                    description = food.get("description", clean_name)
                    nutrients = food.get("foodNutrients", [])
                    
                    cal = 0.0
                    protein = 0.0
                    fat = 0.0
                    carbs = 0.0
                    fiber = 0.0
                    sodium = 0.0

                    for n in nutrients:
                        n_id = n.get("nutrientId")
                        n_name = (n.get("nutrientName") or "").lower()
                        unit = (n.get("unitName") or "").upper()
                        val = float(n.get("value", 0.0))

                        if "energy" in n_name or n_id == 1008:
                            if unit == "KCAL":
                                cal = val
                            elif unit == "KJ" and cal == 0.0:
                                cal = val / 4.184
                        elif n_id == 1003 or "protein" in n_name:
                            protein = val
                        elif n_id == 1004 or "total lipid" in n_name or n_name == "fat":
                            fat = val
                        elif n_id == 1005 or "carbohydrate" in n_name:
                            carbs = val
                        elif n_id == 1079 or "fiber" in n_name:
                            fiber = val
                        elif n_id == 1093 or "sodium" in n_name:
                            sodium = val

                    # Determine icon
                    lower_desc = description.lower()
                    icon = "restaurant"
                    if any(f in lower_desc for f in ["papaya", "cucumber", "fruit", "apple", "melon", "berry", "salad", "vegetable"]):
                        icon = "eco"
                    elif any(b in lower_desc for b in ["bread", "roti", "chapati", "naan"]):
                        icon = "bakery_dining"
                    elif any(r in lower_desc for r in ["rice", "grain", "oats"]):
                        icon = "rice_bowl"

                    logger.info(f"Successfully fetched USDA nutrition for '{food_name}': {cal} kcal/100g")
                    return {
                        "name": description.title() if len(description) < 40 else clean_name.title(),
                        "calories_100g": round(cal, 1),
                        "protein_100g": round(protein, 1),
                        "carbs_100g": round(carbs, 1),
                        "fat_100g": round(fat, 1),
                        "fiber_100g": round(fiber, 1),
                        "sodium_100g": round(sodium, 1),
                        "preparation": "USDA FoodData Central Reference",
                        "icon": icon,
                    }
        except Exception as e:
            logger.warning(f"USDA FoodData API lookup failed for '{clean_name}': {e}")
            return None

    @classmethod
    def _fetch_from_gemini(cls, food_name: str) -> Optional[Dict[str, Any]]:
        api_key = settings.GEMINI_API_KEY or os.environ.get("GEMINI_API_KEY")
        if not api_key:
            return None

        try:
            from google import genai
            from google.genai import types
            client = genai.Client(api_key=api_key, http_options=types.HttpOptions(timeout=10000))
            
            prompt = (
                f"Provide standard nutritional values per 100g (unprepared or standard serving) for: '{food_name}'. "
                f"Include calories (kcal), protein (g), carbs (g), fat (g), fiber (g), sodium (mg), and preparation description."
            )

            # Try active models
            for model_id in ["gemini-3.1-flash-lite", "gemini-3.8-flash"]:
                try:
                    response = client.models.generate_content(
                        model=model_id,
                        contents=[prompt],
                        config=types.GenerateContentConfig(
                            response_mime_type="application/json",
                            response_schema=NutritionPer100g,
                            temperature=0.1,
                        )
                    )
                    if response and response.text:
                        parsed = json.loads(response.text)
                        logger.info(f"Gemini {model_id} nutrition fetch succeeded for '{food_name}'")
                        return {
                            "name": parsed.get("name", food_name.title()),
                            "calories_100g": round(float(parsed.get("calories_100g", 0.0)), 1),
                            "protein_100g": round(float(parsed.get("protein_100g", 0.0)), 1),
                            "carbs_100g": round(float(parsed.get("carbs_100g", 0.0)), 1),
                            "fat_100g": round(float(parsed.get("fat_100g", 0.0)), 1),
                            "fiber_100g": round(float(parsed.get("fiber_100g", 0.0)), 1),
                            "sodium_100g": round(float(parsed.get("sodium_100g", 0.0)), 1),
                            "preparation": parsed.get("preparation", "Fresh / Standard"),
                            "icon": parsed.get("icon", "restaurant"),
                        }
                except Exception as inner_e:
                    logger.warning(f"Gemini {model_id} failed for '{food_name}': {inner_e}")
                    continue
        except Exception as e:
            logger.warning(f"Gemini client error for '{food_name}': {e}")

        return None

    @classmethod
    def _heuristic_fallback(cls, food_name: str) -> Dict[str, Any]:
        lower = food_name.lower()
        if any(f in lower for f in ["papaya", "melon", "watermelon", "cucumber", "fruit", "berries", "orange", "apple"]):
            return {
                "name": food_name.title(),
                "calories_100g": 35.0,
                "protein_100g": 0.6,
                "carbs_100g": 8.0,
                "fat_100g": 0.2,
                "fiber_100g": 1.2,
                "sodium_100g": 4.0,
                "preparation": "Fresh raw fruit/vegetable",
                "icon": "eco"
            }
        elif any(v in lower for v in ["salad", "lettuce", "greens", "spinach", "cabbage"]):
            return {
                "name": food_name.title(),
                "calories_100g": 25.0,
                "protein_100g": 1.2,
                "carbs_100g": 4.5,
                "fat_100g": 0.3,
                "fiber_100g": 1.8,
                "sodium_100g": 15.0,
                "preparation": "Fresh vegetable / salad",
                "icon": "grass"
            }
        elif any(p in lower for p in ["paneer", "chicken", "meat", "egg", "tofu", "fish"]):
            return {
                "name": food_name.title(),
                "calories_100g": 200.0,
                "protein_100g": 20.0,
                "carbs_100g": 2.0,
                "fat_100g": 12.0,
                "fiber_100g": 0.0,
                "sodium_100g": 60.0,
                "preparation": "Cooked protein item",
                "icon": "egg"
            }
        return {
            "name": food_name.title(),
            "calories_100g": 120.0,
            "protein_100g": 4.0,
            "carbs_100g": 18.0,
            "fat_100g": 3.5,
            "fiber_100g": 2.0,
            "sodium_100g": 100.0,
            "preparation": "Cooked food item",
            "icon": "restaurant"
        }
