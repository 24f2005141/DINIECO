from typing import List, Dict, Any

# Authentic Indian & Global Dining nutritional reference values per 100g
# Grounded in ICMR (Indian Council of Medical Research) and USDA FoodData Central databases
NUTRITION_DB: Dict[str, Dict[str, Any]] = {
    "steamed rice": {
        "calories_100g": 130.0,
        "protein_100g": 2.7,
        "carbs_100g": 28.2,
        "fat_100g": 0.3,
        "fiber_100g": 0.4,
        "sodium_100g": 1.0,
        "state": "cooked",
        "preparation": "Steamed",
        "icon": "rice_bowl"
    },
    "toor dal tadka": {
        "calories_100g": 125.0,
        "protein_100g": 6.8,
        "carbs_100g": 18.0,
        "fat_100g": 2.9,
        "fiber_100g": 3.8,
        "sodium_100g": 240.0,
        "state": "cooked",
        "preparation": "Simmered with cumin tempering",
        "icon": "soup_kitchen"
    },
    "mixed vegetables": {
        "calories_100g": 65.0,
        "protein_100g": 2.6,
        "carbs_100g": 11.2,
        "fat_100g": 1.2,
        "fiber_100g": 3.5,
        "sodium_100g": 45.0,
        "state": "cooked",
        "preparation": "Sautéed with light spices",
        "icon": "eco"
    },
    "paneer cubes": {
        "calories_100g": 268.0,
        "protein_100g": 18.3,
        "carbs_100g": 3.4,
        "fat_100g": 20.8,
        "fiber_100g": 0.0,
        "sodium_100g": 22.0,
        "state": "cooked",
        "preparation": "Pan-tossed fresh curd cheese",
        "icon": "egg"
    },
    "kachumber salad": {
        "calories_100g": 22.0,
        "protein_100g": 0.9,
        "carbs_100g": 4.2,
        "fat_100g": 0.2,
        "fiber_100g": 1.4,
        "sodium_100g": 18.0,
        "state": "raw",
        "preparation": "Fresh chopped cucumber, tomato & onion",
        "icon": "grass"
    },
    "roti / chapati": {
        "calories_100g": 264.0,
        "protein_100g": 9.1,
        "carbs_100g": 46.2,
        "fat_100g": 3.7,
        "fiber_100g": 6.5,
        "sodium_100g": 190.0,
        "state": "cooked",
        "preparation": "Tawa-roasted whole wheat flatbread",
        "icon": "bakery_dining"
    },
    "idli / sambar": {
        "calories_100g": 140.0,
        "protein_100g": 4.5,
        "carbs_100g": 26.0,
        "fat_100g": 1.8,
        "fiber_100g": 2.9,
        "sodium_100g": 210.0,
        "state": "cooked",
        "preparation": "Steamed fermented rice cakes with lentil stew",
        "icon": "breakfast_dining"
    },
    "chicken breast / tikka": {
        "calories_100g": 165.0,
        "protein_100g": 31.0,
        "carbs_100g": 1.2,
        "fat_100g": 3.6,
        "fiber_100g": 0.0,
        "sodium_100g": 74.0,
        "state": "cooked",
        "preparation": "Charcoal grilled marinated lean breast",
        "icon": "kebab_dining"
    },
    "rajma masala": {
        "calories_100g": 138.0,
        "protein_100g": 7.4,
        "carbs_100g": 21.0,
        "fat_100g": 2.8,
        "fiber_100g": 5.2,
        "sodium_100g": 260.0,
        "state": "cooked",
        "preparation": "Slow cooked red kidney beans in onion-tomato gravy",
        "icon": "soup_kitchen"
    },
    "curd / yogurt": {
        "calories_100g": 61.0,
        "protein_100g": 3.5,
        "carbs_100g": 4.7,
        "fat_100g": 3.3,
        "fiber_100g": 0.0,
        "sodium_100g": 46.0,
        "state": "raw",
        "preparation": "Cultured whole milk curd",
        "icon": "local_cafe"
    }
}

class NutritionEngine:
    @staticmethod
    def calculate_component_nutrition(name: str, weight_g: float) -> Dict[str, Any]:
        """
        Calculates verified calories, macros, and uncertainty bounds for a component based on weight.
        Formula: N_i = (weight_g / 100.0) * N_100g
        Uncertainty bounds: +/- 10% on energy to account for cooking oil and culinary variations.
        """
        key = name.strip().lower()
        matched_item = None
        for db_name, item in NUTRITION_DB.items():
            if db_name in key or key in db_name:
                matched_item = item
                break
        
        if not matched_item:
            # Fallback average for unlisted cooked food: 120 kcal/100g, 4g P, 18g C, 3.5g F
            matched_item = {
                "calories_100g": 120.0,
                "protein_100g": 4.0,
                "carbs_100g": 18.0,
                "fat_100g": 3.5,
                "fiber_100g": 2.0,
                "sodium_100g": 100.0,
                "state": "cooked",
                "preparation": "Standard cooked preparation",
                "icon": "restaurant"
            }
        
        factor = max(0.0, weight_g) / 100.0
        cal = int(round(matched_item["calories_100g"] * factor))
        uncert_min = int(round(cal * 0.90))
        uncert_max = int(round(cal * 1.10))

        return {
            "name": name,
            "weight_g": round(weight_g, 1),
            "calories_kcal": cal,
            "uncertainty_min_kcal": uncert_min,
            "uncertainty_max_kcal": uncert_max,
            "protein_g": round(matched_item["protein_100g"] * factor, 1),
            "carbs_g": round(matched_item["carbs_100g"] * factor, 1),
            "fat_g": round(matched_item["fat_100g"] * factor, 1),
            "fiber_g": round(matched_item["fiber_100g"] * factor, 1),
            "sodium_mg": round(matched_item["sodium_100g"] * factor, 1),
            "preparation_style": matched_item.get("preparation", "Cooked"),
            "icon_name": matched_item.get("icon", "restaurant")
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
            nutri = cls.calculate_component_nutrition(comp.get("name", ""), weight)
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
