import os
import io
import json
import logging
from pathlib import Path
from typing import Dict, Any, List, Optional
from pydantic import BaseModel, Field
from PIL import Image

from app.core.config import settings
from app.services.nutrition_engine import NutritionEngine
from app.services.nutrition_cache import NutritionCache
from app.services.image_normalizer import (
    ImageNormalizer,
    CorruptedImageError,
    DecompressionBombException,
    EmptyImageError,
    UnsupportedFormatError,
)

logger = logging.getLogger(__name__)

# Structured Pydantic schema for live Gemini inference
class LiveDetectedComponent(BaseModel):
    name: str = Field(description="Name of the food item or dish component (e.g. 'Papaya Cubes', 'Cucumber Slices')")
    portion_ratio: float = Field(description="Visual portion ratio between 0.0 and 1.0 (all ratios should sum to ~1.0)")
    confidence: float = Field(default=0.92, description="Detection confidence score between 0.0 and 1.0")
    preparation_style: str = Field(default="Fresh / Cooked", description="Cooking or preparation method")
    calories_100g: float = Field(default=0.0, description="Approximate kcal per 100g")
    protein_100g: float = Field(default=0.0, description="Approximate grams protein per 100g")
    carbs_100g: float = Field(default=0.0, description="Approximate grams carbs per 100g")
    fat_100g: float = Field(default=0.0, description="Approximate grams fat per 100g")
    fiber_100g: float = Field(default=0.0, description="Approximate grams fiber per 100g")
    sodium_100g: float = Field(default=0.0, description="Approximate milligrams sodium per 100g")

class LiveDishAnalysis(BaseModel):
    dish_name: str = Field(description="Overall identified name of the dish, meal, or fruit/salad bowl")
    overall_confidence: float = Field(default=0.92, description="Overall classification confidence")
    components: List[LiveDetectedComponent] = Field(description="List of detected food components in the image")

# Presets for manual selection / explicit dish hints
CATALOG_TEMPLATES: Dict[str, Dict[str, Any]] = {
    "vegetable rice bowl": {
        "dish_name": "Vegetable Rice Bowl",
        "overall_confidence": 0.92,
        "components": [
            {"name": "Steamed Rice", "ratio": 0.46, "confidence": 0.95, "icon": "rice_bowl"},
            {"name": "Toor Dal Tadka", "ratio": 0.24, "confidence": 0.91, "icon": "soup_kitchen"},
            {"name": "Mixed Vegetables", "ratio": 0.16, "confidence": 0.89, "icon": "eco"},
            {"name": "Paneer Cubes", "ratio": 0.10, "confidence": 0.94, "icon": "egg"},
            {"name": "Kachumber Salad", "ratio": 0.04, "confidence": 0.88, "icon": "grass"}
        ]
    },
    "paneer roti meal": {
        "dish_name": "Paneer Roti Meal",
        "overall_confidence": 0.93,
        "components": [
            {"name": "Roti / Chapati", "ratio": 0.40, "confidence": 0.96, "icon": "bakery_dining"},
            {"name": "Paneer Cubes", "ratio": 0.32, "confidence": 0.94, "icon": "egg"},
            {"name": "Mixed Vegetables", "ratio": 0.18, "confidence": 0.89, "icon": "eco"},
            {"name": "Kachumber Salad", "ratio": 0.10, "confidence": 0.91, "icon": "grass"}
        ]
    },
    "south indian breakfast": {
        "dish_name": "South Indian Breakfast",
        "overall_confidence": 0.94,
        "components": [
            {"name": "Idli / Sambar", "ratio": 0.65, "confidence": 0.96, "icon": "breakfast_dining"},
            {"name": "Toor Dal Tadka", "ratio": 0.25, "confidence": 0.92, "icon": "soup_kitchen"},
            {"name": "Kachumber Salad", "ratio": 0.10, "confidence": 0.88, "icon": "grass"}
        ]
    },
    "high protein salad bowl": {
        "dish_name": "High Protein Salad Bowl",
        "overall_confidence": 0.90,
        "components": [
            {"name": "Paneer Cubes", "ratio": 0.40, "confidence": 0.94, "icon": "egg"},
            {"name": "Mixed Vegetables", "ratio": 0.35, "confidence": 0.90, "icon": "eco"},
            {"name": "Kachumber Salad", "ratio": 0.25, "confidence": 0.89, "icon": "grass"}
        ]
    },
    "fruit bowl": {
        "dish_name": "Fresh Fruit Bowl",
        "overall_confidence": 0.95,
        "components": [
            {"name": "Papaya", "ratio": 0.70, "confidence": 0.95, "icon": "eco"},
            {"name": "Cucumber", "ratio": 0.30, "confidence": 0.92, "icon": "eco"}
        ]
    }
}

class FoodVisionRecognizer:
    @staticmethod
    def optimize_image_for_ai(raw_bytes: bytes, max_dim: int = 768) -> bytes:
        """
        Downscales image to max_dim (768px) and compresses to 80% JPEG quality.
        Reduces payload from ~300KB-15MB to ~40KB-70KB, avoiding DEADLINE_EXCEEDED errors.
        """
        try:
            img = Image.open(io.BytesIO(raw_bytes))
            if img.mode not in ("RGB", "L"):
                img = img.convert("RGB")
            if max(img.width, img.height) > max_dim:
                img.thumbnail((max_dim, max_dim), Image.Resampling.LANCZOS)
            out = io.BytesIO()
            img.save(out, format="JPEG", quality=80, optimize=True)
            return out.getvalue()
        except Exception as e:
            logger.warning(f"Error optimizing image for vision AI: {e}. Using raw bytes.")
            return raw_bytes

    @staticmethod
    def reconcile_portions(components_with_ratios: List[Dict[str, Any]], net_food_weight_g: float) -> List[Dict[str, Any]]:
        """
        Reconciles component portion weights to mathematically guarantee that
        sum(w_i) == net_food_weight_g exactly (accounting for rounding to 1 decimal place).
        """
        if not components_with_ratios:
            return []
        
        total_ratio = sum(c.get("ratio", 0.0) for c in components_with_ratios)
        if total_ratio <= 0.0:
            total_ratio = 1.0
            for c in components_with_ratios:
                c["ratio"] = 1.0 / len(components_with_ratios)
        
        reconciled = []
        for c in components_with_ratios:
            norm_ratio = c["ratio"] / total_ratio
            w = round(net_food_weight_g * norm_ratio, 1)
            item = dict(c)
            item["weight_g"] = w
            item["confidence"] = c.get("confidence", 0.90)
            item["icon"] = c.get("icon", "restaurant")
            reconciled.append(item)
        
        # Calculate residual rounding discrepancy
        current_sum = round(sum(item["weight_g"] for item in reconciled), 1)
        discrepancy = round(net_food_weight_g - current_sum, 1)
        
        if discrepancy != 0.0 and reconciled:
            max_idx = max(range(len(reconciled)), key=lambda i: reconciled[i]["weight_g"])
            reconciled[max_idx]["weight_g"] = round(reconciled[max_idx]["weight_g"] + discrepancy, 1)
            
        return reconciled

    @classmethod
    def analyze_food_image(
        cls,
        image_base64: Optional[str] = None,
        image_url: Optional[str] = None,
        total_weight_g: float = 842.0,
        weight_source: str = "device",
        tare_weight_g: float = 356.0,
        dish_hint: Optional[str] = None
    ) -> Dict[str, Any]:
        """
        AI-powered food detection and portion estimation pipeline.
        
        Supports two weight input modes:
        - Mode A (Automatic 'device'): Net food = total_weight_g - tare_weight_g
        - Mode B (Manual 'manual'): Net food = total_weight_g (direct entered net food weight)
        
        Validates weight constraints (10g <= net_food_weight_g <= 2500g).
        Dynamically recognizes food holders / components from the image.
        Fetches and caches nutritional content locally.
        Reconciles portion allocation so sum(w_i) == net_food_weight_g.
        """
        # 1. Determine Net Food Weight
        if weight_source == "manual":
            net_food_weight_g = round(float(total_weight_g), 1)
            actual_gross_weight = net_food_weight_g
        else:
            net_food_weight_g = round(max(0.0, float(total_weight_g) - float(tare_weight_g)), 1)
            actual_gross_weight = round(float(total_weight_g), 1)

        # 2. Strict Input Validation
        if net_food_weight_g <= 0.0:
            raise ValueError(f"Food weight must be greater than zero (received {net_food_weight_g}g net food).")
        if net_food_weight_g < 10.0:
            raise ValueError(f"Food weight {net_food_weight_g}g is too small to analyze accurately. Minimum is 10.0g.")
        if net_food_weight_g > 2500.0:
            raise ValueError(f"Food weight {net_food_weight_g}g exceeds smart dining capacity of 2500.0g.")

        # 3. Process and normalize image input if provided
        norm_img_bytes: Optional[bytes] = None
        if image_base64 and len(image_base64.strip()) > 30:
            import base64
            raw_b64 = image_base64.strip()
            if "," in raw_b64:
                raw_b64 = raw_b64.split(",", 1)[1]
            try:
                decoded_bytes = base64.b64decode(raw_b64)
                norm_res = ImageNormalizer.normalize(decoded_bytes)
                norm_img_bytes = cls.optimize_image_for_ai(norm_res.bytes, max_dim=768)
            except (CorruptedImageError, DecompressionBombException, EmptyImageError, UnsupportedFormatError) as e:
                raise ValueError(f"Invalid meal photograph: {str(e)}")
            except Exception as e:
                logger.warning(f"Image normalization warning for base64: {e}")
        elif image_url and image_url.strip():
            clean_url = image_url.strip().split("?")[0]
            if clean_url.startswith("/uploads/"):
                clean_url = clean_url[len("/uploads/"):]
            upload_path = Path(__file__).resolve().parent.parent.parent / "uploads" / clean_url
            if upload_path.exists():
                try:
                    with open(upload_path, "rb") as f:
                        disk_bytes = f.read()
                    norm_res = ImageNormalizer.normalize(disk_bytes)
                    norm_img_bytes = cls.optimize_image_for_ai(norm_res.bytes, max_dim=768)
                except Exception as e:
                    logger.warning(f"Image normalization warning for stored image {upload_path}: {e}")

        ai_model = "catalog-fallback"
        ai_verified = False
        dish_name = dish_hint or "Dining Meal"
        overall_confidence = 0.90
        components_with_ratios: List[Dict[str, Any]] = []

        # 4. Live Gemini Vision Inference with Model Cascade
        api_key = settings.GEMINI_API_KEY or os.environ.get("GEMINI_API_KEY")
        if api_key and norm_img_bytes:
            try:
                from google import genai
                from google.genai import types
                client = genai.Client(api_key=api_key, http_options=types.HttpOptions(timeout=30000))
                
                hint_text = f"Optional hint: '{dish_hint}'. " if dish_hint else ""
                prompt = (
                    f"Analyze this food/meal image and accurately identify all visible food components (holders). "
                    f"Net food weight is {net_food_weight_g}g. {hint_text}"
                    f"Carefully recognize each specific food (e.g. if papaya and cucumber are shown, identify Papaya and Cucumber, do NOT guess roti or rice unless actually present). "
                    f"Return the overall dish name, classification confidence (0.0-1.0), and individual components with their "
                    f"approximate visual portion ratios (ratios must sum to 1.0), preparation style, and standard per-100g nutritional profile "
                    f"(calories_100g, protein_100g, carbs_100g, fat_100g, fiber_100g, sodium_100g)."
                )

                contents = [
                    prompt,
                    types.Part.from_bytes(data=norm_img_bytes, mime_type="image/jpeg")
                ]

                # Model cascade: prioritize fast gemini-3.1-flash-lite, fallback to 3.8
                candidate_models = ["gemini-3.1-flash-lite", "gemini-3.8-flash"]
                for model_candidate in candidate_models:
                    try:
                        logger.info(f"Invoking Gemini model '{model_candidate}' for vision analysis...")
                        response = client.models.generate_content(
                            model=model_candidate,
                            contents=contents,
                            config=types.GenerateContentConfig(
                                response_mime_type="application/json",
                                response_schema=LiveDishAnalysis,
                                temperature=0.1,
                            )
                        )

                        if response and response.text:
                            parsed = json.loads(response.text)
                            dish_name = parsed.get("dish_name", dish_name)
                            overall_confidence = float(parsed.get("overall_confidence", 0.92))
                            raw_comps = parsed.get("components", [])
                            if raw_comps:
                                components_with_ratios = []
                                for c in raw_comps:
                                    c_name = c.get("name", "Food Component").strip()
                                    c_ratio = float(c.get("portion_ratio", 0.2))
                                    c_conf = float(c.get("confidence", 0.90))
                                    c_prep = c.get("preparation_style", "Fresh / Cooked")
                                    
                                    # Pick appropriate icon
                                    lower_c = c_name.lower()
                                    c_icon = "restaurant"
                                    if any(f in lower_c for f in ["papaya", "cucumber", "fruit", "apple", "melon", "salad", "vegetable"]):
                                        c_icon = "eco"
                                    elif any(b in lower_c for b in ["roti", "bread", "chapati", "naan"]):
                                        c_icon = "bakery_dining"
                                    elif any(r in lower_c for r in ["rice", "grain", "oats"]):
                                        c_icon = "rice_bowl"
                                    elif any(d in lower_c for d in ["dal", "soup", "curry"]):
                                        c_icon = "soup_kitchen"
                                    elif any(p in lower_c for p in ["paneer", "egg", "chicken", "meat", "protein"]):
                                        c_icon = "egg"

                                    comp_dict = {
                                        "name": c_name,
                                        "ratio": c_ratio,
                                        "confidence": c_conf,
                                        "preparation_style": c_prep,
                                        "icon": c_icon,
                                        "calories_100g": float(c.get("calories_100g", 0.0)),
                                        "protein_100g": float(c.get("protein_100g", 0.0)),
                                        "carbs_100g": float(c.get("carbs_100g", 0.0)),
                                        "fat_100g": float(c.get("fat_100g", 0.0)),
                                        "fiber_100g": float(c.get("fiber_100g", 0.0)),
                                        "sodium_100g": float(c.get("sodium_100g", 0.0)),
                                    }
                                    components_with_ratios.append(comp_dict)

                                ai_model = model_candidate
                                ai_verified = True
                                logger.info(f"Successfully analyzed image with '{model_candidate}': '{dish_name}', components: {[c['name'] for c in components_with_ratios]}")
                                break
                    except Exception as model_err:
                        logger.warning(f"Model '{model_candidate}' failed: {model_err}")
                        continue
            except Exception as e:
                logger.warning(f"Live Gemini API invocation failed: {e}. Falling back.")

        # 5. Catalog Fallback (only if user provided an explicit dish hint, or if live AI failed)
        if not components_with_ratios:
            if dish_hint:
                hint_key = dish_hint.strip().lower()
                matched_template = None
                for key, tpl in CATALOG_TEMPLATES.items():
                    if key in hint_key or hint_key in key:
                        matched_template = tpl
                        break
                if matched_template:
                    dish_name = matched_template["dish_name"]
                    overall_confidence = matched_template["overall_confidence"]
                    components_with_ratios = [dict(c) for c in matched_template["components"]]
            
            # If still empty (e.g. no hint and AI was offline/unavailable)
            if not components_with_ratios:
                dish_name = "Dining Meal Plate"
                overall_confidence = 0.85
                components_with_ratios = [
                    {"name": "Main Course", "ratio": 0.60, "confidence": 0.85, "icon": "restaurant"},
                    {"name": "Side Dish / Salad", "ratio": 0.40, "confidence": 0.85, "icon": "eco"}
                ]
            ai_model = "catalog-fallback"
            ai_verified = False

        # 6. Reconcile Portions so sum(weight_g) == net_food_weight_g
        reconciled_components = cls.reconcile_portions(components_with_ratios, net_food_weight_g)

        # 7. Nutritional Calculation via Cache & Fetcher
        meal_nutrition = NutritionEngine.calculate_meal_totals(reconciled_components)

        return {
            "dish_name": dish_name,
            "overall_confidence": overall_confidence,
            "total_weight_g": actual_gross_weight,
            "net_food_weight_g": net_food_weight_g,
            "weight_source": weight_source,
            "ai_model": ai_model,
            "ai_verified": ai_verified,
            "is_stabilized": True,
            "total_calories": meal_nutrition["total_calories"],
            "total_protein_g": meal_nutrition["total_protein_g"],
            "total_carbs_g": meal_nutrition["total_carbs_g"],
            "total_fat_g": meal_nutrition["total_fat_g"],
            "components": meal_nutrition["components"]
        }
