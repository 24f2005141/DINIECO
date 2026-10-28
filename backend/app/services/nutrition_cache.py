import os
import re
import json
import logging
from pathlib import Path
from typing import Dict, Any, Optional, List
from datetime import datetime, timezone

logger = logging.getLogger(__name__)

# Baseline verified nutritional values per 100g from USDA FoodData Central & ICMR
PRESEEDED_NUTRITION: Dict[str, Dict[str, Any]] = {
    "papaya": {
        "calories_100g": 43.0,
        "protein_100g": 0.5,
        "carbs_100g": 10.8,
        "fat_100g": 0.3,
        "fiber_100g": 1.7,
        "sodium_100g": 8.0,
        "preparation": "Fresh raw fruit",
        "icon": "eco"
    },
    "cucumber": {
        "calories_100g": 15.0,
        "protein_100g": 0.7,
        "carbs_100g": 3.6,
        "fat_100g": 0.1,
        "fiber_100g": 0.5,
        "sodium_100g": 2.0,
        "preparation": "Fresh raw sliced",
        "icon": "eco"
    },
    "watermelon": {
        "calories_100g": 30.0,
        "protein_100g": 0.6,
        "carbs_100g": 7.6,
        "fat_100g": 0.2,
        "fiber_100g": 0.4,
        "sodium_100g": 1.0,
        "preparation": "Fresh raw fruit",
        "icon": "eco"
    },
    "apple": {
        "calories_100g": 52.0,
        "protein_100g": 0.3,
        "carbs_100g": 13.8,
        "fat_100g": 0.2,
        "fiber_100g": 2.4,
        "sodium_100g": 1.0,
        "preparation": "Fresh raw with skin",
        "icon": "eco"
    },
    "banana": {
        "calories_100g": 89.0,
        "protein_100g": 1.1,
        "carbs_100g": 22.8,
        "fat_100g": 0.3,
        "fiber_100g": 2.6,
        "sodium_100g": 1.0,
        "preparation": "Fresh peeled ripe",
        "icon": "eco"
    },
    "orange": {
        "calories_100g": 47.0,
        "protein_100g": 0.9,
        "carbs_100g": 11.8,
        "fat_100g": 0.1,
        "fiber_100g": 2.4,
        "sodium_100g": 0.0,
        "preparation": "Fresh peeled citrus",
        "icon": "eco"
    },
    "steamed rice": {
        "calories_100g": 130.0,
        "protein_100g": 2.7,
        "carbs_100g": 28.2,
        "fat_100g": 0.3,
        "fiber_100g": 0.4,
        "sodium_100g": 1.0,
        "preparation": "Steamed white rice",
        "icon": "rice_bowl"
    },
    "roti": {
        "calories_100g": 264.0,
        "protein_100g": 9.1,
        "carbs_100g": 46.2,
        "fat_100g": 3.7,
        "fiber_100g": 6.5,
        "sodium_100g": 190.0,
        "preparation": "Tawa-roasted whole wheat flatbread",
        "icon": "bakery_dining"
    },
    "toor dal tadka": {
        "calories_100g": 125.0,
        "protein_100g": 6.8,
        "carbs_100g": 18.0,
        "fat_100g": 2.9,
        "fiber_100g": 3.8,
        "sodium_100g": 240.0,
        "preparation": "Simmered yellow pigeon pea stew",
        "icon": "soup_kitchen"
    },
    "paneer": {
        "calories_100g": 268.0,
        "protein_100g": 18.3,
        "carbs_100g": 3.4,
        "fat_100g": 20.8,
        "fiber_100g": 0.0,
        "sodium_100g": 22.0,
        "preparation": "Fresh cottage cheese",
        "icon": "egg"
    },
    "mixed vegetables": {
        "calories_100g": 65.0,
        "protein_100g": 2.6,
        "carbs_100g": 11.2,
        "fat_100g": 1.2,
        "fiber_100g": 3.5,
        "sodium_100g": 45.0,
        "preparation": "Sautéed mixed vegetables",
        "icon": "eco"
    },
    "salad": {
        "calories_100g": 22.0,
        "protein_100g": 0.9,
        "carbs_100g": 4.2,
        "fat_100g": 0.2,
        "fiber_100g": 1.4,
        "sodium_100g": 18.0,
        "preparation": "Fresh garden salad",
        "icon": "grass"
    },
    "chicken breast": {
        "calories_100g": 165.0,
        "protein_100g": 31.0,
        "carbs_100g": 0.0,
        "fat_100g": 3.6,
        "fiber_100g": 0.0,
        "sodium_100g": 74.0,
        "preparation": "Cooked skinless lean breast",
        "icon": "kebab_dining"
    },
    "boiled egg": {
        "calories_100g": 155.0,
        "protein_100g": 12.6,
        "carbs_100g": 1.1,
        "fat_100g": 10.6,
        "fiber_100g": 0.0,
        "sodium_100g": 124.0,
        "preparation": "Hard-boiled whole egg",
        "icon": "egg"
    },
    "yogurt": {
        "calories_100g": 61.0,
        "protein_100g": 3.5,
        "carbs_100g": 4.7,
        "fat_100g": 3.3,
        "fiber_100g": 0.0,
        "sodium_100g": 46.0,
        "preparation": "Plain whole milk curd",
        "icon": "local_cafe"
    }
}

NOISE_WORDS = {
    "fresh", "raw", "cooked", "steamed", "boiled", "fried", "baked", "grilled",
    "roasted", "sliced", "diced", "cubed", "chopped", "pieces", "bowl", "chunks",
    "ripe", "organic", "cut", "mixed", "whole", "portion"
}

class NutritionCache:
    """
    Two-level persistent nutrition cache:
    1. In-memory dictionary for instant O(1) lookups (<1ms).
    2. Persistent JSON disk file at backend/data/nutrition_cache.json.
    """
    _instance: Optional["NutritionCache"] = None

    def __init__(self, cache_file_path: Optional[Path] = None):
        if cache_file_path is None:
            # Default to backend/data/nutrition_cache.json
            base_dir = Path(__file__).resolve().parent.parent.parent
            self.data_dir = base_dir / "data"
            self.cache_file = self.data_dir / "nutrition_cache.json"
        else:
            self.cache_file = Path(cache_file_path)
            self.data_dir = self.cache_file.parent

        self._cache: Dict[str, Dict[str, Any]] = {}
        self._hits: int = 0
        self._misses: int = 0
        self._load_cache()

    @classmethod
    def get_instance(cls) -> "NutritionCache":
        if cls._instance is None:
            cls._instance = NutritionCache()
        return cls._instance

    @staticmethod
    def normalize_key(name: str) -> str:
        """
        Normalizes a food query string:
        - Lowercases and strips punctuation
        - Removes common preparation noise words (e.g. 'fresh papaya cubes' -> 'papaya')
        """
        if not name:
            return ""
        clean = name.lower()
        clean = re.sub(r"[^\w\s/]", " ", clean)
        tokens = [t.strip() for t in clean.split() if t.strip()]
        
        # Keep non-noise tokens
        meaningful = [t for t in tokens if t not in NOISE_WORDS]
        if meaningful:
            return " ".join(meaningful)
        return " ".join(tokens)

    def _load_cache(self) -> None:
        """Loads cached items from JSON file or seeds with baseline defaults."""
        self.data_dir.mkdir(parents=True, exist_ok=True)
        if self.cache_file.exists():
            try:
                with open(self.cache_file, "r", encoding="utf-8") as f:
                    data = json.load(f)
                    if isinstance(data, dict):
                        self._cache = data
                        logger.info(f"Loaded {len(self._cache)} nutrition items from {self.cache_file}")
                        return
            except Exception as e:
                logger.warning(f"Error loading nutrition cache file {self.cache_file}: {e}. Re-seeding defaults.")

        # Seed defaults
        now = datetime.now(timezone.utc).isoformat()
        for k, v in PRESEEDED_NUTRITION.items():
            entry = dict(v)
            entry["name"] = k.title()
            entry["source"] = "preseeded"
            entry["cached_at"] = now
            entry["hits"] = 0
            self._cache[k] = entry
        
        self._save_cache()

    def _save_cache(self) -> None:
        """Persists in-memory cache to disk."""
        try:
            self.data_dir.mkdir(parents=True, exist_ok=True)
            temp_file = self.cache_file.with_suffix(".tmp")
            with open(temp_file, "w", encoding="utf-8") as f:
                json.dump(self._cache, f, indent=2, ensure_ascii=False)
            temp_file.replace(self.cache_file)
        except Exception as e:
            logger.error(f"Failed to persist nutrition cache to {self.cache_file}: {e}")

    def get(self, name: str) -> Optional[Dict[str, Any]]:
        """
        Retrieves nutrition data for food name.
        Checks exact key, then normalized key, then partial substring match.
        """
        if not name:
            return None

        raw_key = name.strip().lower()
        # 1. Exact match
        if raw_key in self._cache:
            self._hits += 1
            item = dict(self._cache[raw_key])
            item["source"] = "local_cache"
            return item

        # 2. Normalized key match
        norm_key = self.normalize_key(name)
        if norm_key in self._cache:
            self._hits += 1
            item = dict(self._cache[norm_key])
            item["source"] = "local_cache"
            return item

        # 3. Substring match (e.g., 'papaya' matches 'fresh papaya' or vice versa)
        for k, entry in self._cache.items():
            if k == norm_key or (len(k) >= 3 and (k in norm_key or norm_key in k)):
                self._hits += 1
                item = dict(entry)
                item["source"] = "local_cache"
                return item

        self._misses += 1
        return None

    def set(
        self,
        name: str,
        data: Dict[str, Any],
        source: str = "internet_api"
    ) -> Dict[str, Any]:
        """
        Caches nutritional data per 100g for a food item and saves to disk.
        """
        norm_key = self.normalize_key(name) or name.strip().lower()
        entry = {
            "name": data.get("name", name.title()),
            "calories_100g": float(data.get("calories_100g", 0.0)),
            "protein_100g": float(data.get("protein_100g", 0.0)),
            "carbs_100g": float(data.get("carbs_100g", 0.0)),
            "fat_100g": float(data.get("fat_100g", 0.0)),
            "fiber_100g": float(data.get("fiber_100g", 0.0)),
            "sodium_100g": float(data.get("sodium_100g", 0.0)),
            "preparation": data.get("preparation", "Standard"),
            "icon": data.get("icon", "eco" if "fruit" in norm_key or "veg" in norm_key else "restaurant"),
            "source": source,
            "cached_at": datetime.now(timezone.utc).isoformat(),
            "hits": 0,
        }
        self._cache[norm_key] = entry
        # Also store under raw lower key if distinct
        raw_key = name.strip().lower()
        if raw_key != norm_key:
            self._cache[raw_key] = entry

        self._save_cache()
        logger.info(f"Cached nutrition for '{name}' (key: '{norm_key}', source: '{source}')")
        result = dict(entry)
        result["source"] = "local_cache"
        return result

    def has(self, name: str) -> bool:
        return self.get(name) is not None

    def stats(self) -> Dict[str, Any]:
        return {
            "total_items": len(self._cache),
            "hits": self._hits,
            "misses": self._misses,
            "cache_file": str(self.cache_file),
            "hit_ratio": round(self._hits / (self._hits + self._misses), 3) if (self._hits + self._misses) > 0 else 1.0,
        }

    def list_items(self) -> List[Dict[str, Any]]:
        return list(self._cache.values())
