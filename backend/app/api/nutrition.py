from fastapi import APIRouter
from app.schemas.schemas import NutritionCalculateRequest, NutritionResponse
from app.services.nutrition_engine import NutritionEngine

router = APIRouter(prefix="/nutrition", tags=["Nutritional Analysis"])

@router.post("/calculate", response_model=NutritionResponse)
def calculate_nutrition(req: NutritionCalculateRequest):
    comp_dicts = [{"name": c.name, "weight_g": c.weight_g} for c in req.components]
    totals = NutritionEngine.calculate_meal_totals(comp_dicts)
    return NutritionResponse(
        total_calories=totals["total_calories"],
        total_protein_g=totals["total_protein_g"],
        total_carbs_g=totals["total_carbs_g"],
        total_fat_g=totals["total_fat_g"],
        total_fiber_g=totals["total_fiber_g"],
        total_sodium_mg=totals["total_sodium_mg"]
    )
