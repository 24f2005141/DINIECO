import logging
from typing import List, Dict, Any, Optional
from app.services.nutrition_fetcher import NutritionFetcher
from app.services.nutrition_cache import NutritionCache

logger = logging.getLogger(__name__)

class NutritionEngine:
    """
    Core nutritional computation engine.
    Integrates with NutritionCache (local persistent cache) and NutritionFetcher (USDA / Gemini)
    to calculate dynamic nutritional values for any detected or manual food item.
    """

    @classmethod
    def calculate_component_nutrition(
        cls,
        name: str,
        weight_g: float,
        precomputed_nutrients_100g: Optional[Dict[str, float]] = None
    ) -> Dict[str, Any]:
        """
        Calculates verified calories, macros, and uncertainty bounds for a component based on weight.
        Formula: N_i = (weight_g / 100.0) * N_100g
        Uncertainty bounds: +/- 10% on energy to account for cooking oil and culinary variations.
        """
        factor = max(0.0, weight_g) / 100.0

        # If vision analysis already provided verified per-100g nutrients (e.g. from Gemini Vision), use them
        if precomputed_nutrients_100g and precomputed_nutrients_100g.get("calories_100g", 0) > 0:
            c100 = precomputed_nutrients_100g["calories_100g"]
            p100 = precomputed_nutrients_100g.get("protein_100g", 0.0)
            cb100 = precomputed_nutrients_100g.get("carbs_100g", 0.0)
            f100 = precomputed_nutrients_100g.get("fat_100g", 0.0)
            fb100 = precomputed_nutrients_100g.get("fiber_100g", 0.0)
            s100 = precomputed_nutrients_100g.get("sodium_100g", 0.0)
            prep = precomputed_nutrients_100g.get("preparation", "Fresh / Cooked")
            icon = precomputed_nutrients_100g.get("icon", "restaurant")
            source = precomputed_nutrients_100g.get("source", "vision_model")
            
            # Cache it locally for future lookups
            NutritionCache.get_instance().set(name, {
                "name": name,
                "calories_100g": c100,
                "protein_100g": p100,
                "carbs_100g": cb100,
                "fat_100g": f100,
                "fiber_100g": fb100,
                "sodium_100g": s100,
                "preparation": prep,
                "icon": icon,
            }, source=source)
        else:
            # Query NutritionFetcher (Checks Cache -> USDA API -> Gemini AI -> Heuristic)
            item = NutritionFetcher.fetch_nutrition_for_item(name)
            c100 = item.get("calories_100g", 120.0)
            p100 = item.get("protein_100g", 4.0)
            cb100 = item.get("carbs_100g", 18.0)
            f100 = item.get("fat_100g", 3.5)
            fb100 = item.get("fiber_100g", 2.0)
            s100 = item.get("sodium_100g", 50.0)
            prep = item.get("preparation", "Cooked")
            icon = item.get("icon", "restaurant")
            source = item.get("source", "local_cache")

        cal = int(round(c100 * factor))
        uncert_min = int(round(cal * 0.90))
        uncert_max = int(round(cal * 1.10))

        return {
            "name": name,
            "weight_g": round(weight_g, 1),
            "calories_kcal": cal,
            "uncertainty_min_kcal": uncert_min,
            "uncertainty_max_kcal": uncert_max,
            "protein_g": round(p100 * factor, 1),
            "carbs_g": round(cb100 * factor, 1),
            "fat_g": round(f100 * factor, 1),
            "fiber_g": round(fb100 * factor, 1),
            "sodium_mg": round(s100 * factor, 1),
            "calories_100g": round(c100, 1),
            "protein_100g": round(p100, 1),
            "carbs_100g": round(cb100, 1),
            "fat_100g": round(f100, 1),
            "fiber_100g": round(fb100, 1),
            "sodium_100g": round(s100, 1),
            "source": source,
            "preparation_style": prep,
            "icon_name": icon,
        }

    @classmethod
    def calculate_meal_totals(cls, components: List[Dict[str, Any]]) -> Dict[str, Any]:
        """Aggregates all components into overall nutritional totals with portion ratios."""
        total_calories = 0
        total_protein = 0.0
        total_carbs = 0.0
        total_fat = 0.0
        total_fiber = 0.0
        total_sodium = 0.0
        total_food_weight = sum(c.get("weight_g", 0.0) for c in components)
        processed_components = []

        for comp in components:
            weight = comp.get("weight_g", 0.0)
            precomputed = None
            if "calories_100g" in comp and comp["calories_100g"] > 0:
                precomputed = {
                    "calories_100g": comp["calories_100g"],
                    "protein_100g": comp.get("protein_100g", 0.0),
                    "carbs_100g": comp.get("carbs_100g", 0.0),
                    "fat_100g": comp.get("fat_100g", 0.0),
                    "fiber_100g": comp.get("fiber_100g", 0.0),
                    "sodium_100g": comp.get("sodium_100g", 0.0),
                    "preparation": comp.get("preparation_style", "Fresh"),
                    "icon": comp.get("icon", "restaurant"),
                    "source": comp.get("source", "vision_analysis")
                }

            nutri = cls.calculate_component_nutrition(comp.get("name", ""), weight, precomputed)
            
            # Retain confidence and portion ratio
            confidence = comp.get("confidence", 0.92)
            ratio = round(weight / total_food_weight, 3) if total_food_weight > 0 else 0.0
            nutri["confidence"] = confidence
            nutri["portion_ratio"] = ratio
            
            processed_components.append(nutri)
            total_calories += nutri["calories_kcal"]
            total_protein += nutri["protein_g"]
            total_carbs += nutri["carbs_g"]
            total_fat += nutri["fat_g"]
            total_fiber += nutri["fiber_g"]
            total_sodium += nutri["sodium_mg"]

        return {
            "total_calories": total_calories,
            "total_protein_g": round(total_protein, 1),
            "total_carbs_g": round(total_carbs, 1),
            "total_fat_g": round(total_fat, 1),
            "total_fiber_g": round(total_fiber, 1),
            "total_sodium_mg": round(total_sodium, 1),
            "components": processed_components
        }
