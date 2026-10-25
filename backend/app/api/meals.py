from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from typing import List
import datetime
from app.core.database import get_db
from app.models.models import User, MealSession, FoodComponent, NutritionalAnalysis, WasteAnalysis
from app.schemas.schemas import MealCreateRequest, MealDetailResponse, MealResponse, VisionComponent, NutritionResponse, CategoryLeftover
from app.services.nutrition_engine import NutritionEngine
from app.services.waste_calculator import WasteCalculator
from app.api.auth import get_current_user

router = APIRouter(prefix="/meals", tags=["Meal Tracking & History"])

@router.get("/", response_model=List[MealResponse])
def get_meals(current_user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    meals = db.query(MealSession).filter(MealSession.user_id == current_user.id).order_by(MealSession.end_time.desc()).all()
    results = []
    for m in meals:
        cal = m.nutrition.total_calories if m.nutrition else 0
        waste_pct = m.waste_analysis.waste_percentage if m.waste_analysis else 0.0
        results.append(MealResponse(
            id=m.id,
            meal_name=m.meal_name,
            start_time=m.start_time,
            end_time=m.end_time,
            initial_weight_g=m.initial_weight_g,
            consumed_weight_g=m.consumed_weight_g,
            remaining_weight_g=m.remaining_weight_g,
            waste_score=m.waste_score,
            total_calories=cal,
            waste_percentage=waste_pct,
            status=m.status,
            weight_source=getattr(m, "weight_source", "device") or "device",
            tare_weight_g=getattr(m, "tare_weight_g", 0.0) or 0.0,
            image_url=getattr(m, "image_url", None),
            start_gross_weight_g=getattr(m, "start_gross_weight_g", None),
            end_gross_weight_g=getattr(m, "end_gross_weight_g", None),
            plate_weight_g=getattr(m, "plate_weight_g", None),
            plate_weight_mode=getattr(m, "plate_weight_mode", "none") or "none",
            start_food_weight_g=getattr(m, "start_food_weight_g", None),
            end_food_weight_g=getattr(m, "end_food_weight_g", None),
            weight_reduction_g=getattr(m, "weight_reduction_g", None),
            start_image_url=getattr(m, "start_image_url", None) or getattr(m, "image_url", None),
            end_image_url=getattr(m, "end_image_url", None),
            start_image_source=getattr(m, "start_image_source", "app_camera") or "app_camera",
            end_image_source=getattr(m, "end_image_source", "app_camera") or "app_camera",
            device_id=getattr(m, "device_id", None),
            is_calibrated=getattr(m, "is_calibrated", True) if getattr(m, "is_calibrated", None) is not None else True,
            is_flagged_increase=getattr(m, "is_flagged_increase", False) or False,
            readings_history=getattr(m, "readings_history", None),
        ))
    return results

@router.post("/", response_model=MealDetailResponse)
def create_meal(req: MealCreateRequest, current_user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    start_gross = req.start_gross_weight_g if req.start_gross_weight_g is not None else req.initial_weight_g
    end_gross = req.end_gross_weight_g if req.end_gross_weight_g is not None else req.remaining_weight_g
    plate_w = req.plate_weight_g
    plate_mode = req.plate_weight_mode or ("measured" if plate_w is not None and plate_w > 0 else "none")

    if plate_w is not None and plate_w > 0:
        start_food = max(0.0, start_gross - plate_w)
        end_food = max(0.0, end_gross - plate_w)
    else:
        start_food = req.start_food_weight_g if req.start_food_weight_g is not None else start_gross
        end_food = req.end_food_weight_g if req.end_food_weight_g is not None else end_gross

    weight_reduction = req.weight_reduction_g if req.weight_reduction_g is not None else max(0.0, start_food - end_food)
    is_flagged = bool(end_food > (start_food + 1.0))
    start_img = req.start_image_url or req.image_url
    end_img = req.end_image_url

    waste_data = WasteCalculator.calculate_waste_metrics(start_food, end_food)
    
    comp_dicts = [{"name": c.name, "weight_g": c.weight_g, "confidence": c.confidence} for c in req.components]
    nutri_totals = NutritionEngine.calculate_meal_totals(comp_dicts)
    
    now = datetime.datetime.now(datetime.timezone.utc)
    meal = MealSession(
        user_id=current_user.id,
        meal_name=req.meal_name,
        start_time=now - datetime.timedelta(minutes=20),
        end_time=now,
        initial_weight_g=start_food,
        consumed_weight_g=waste_data["consumed_weight_g"],
        remaining_weight_g=waste_data["remaining_weight_g"],
        waste_score=waste_data["waste_score"],
        status="completed",
        weight_source=req.weight_source,
        tare_weight_g=req.tare_weight_g,
        image_url=start_img,
        start_gross_weight_g=start_gross,
        end_gross_weight_g=end_gross,
        plate_weight_g=plate_w,
        plate_weight_mode=plate_mode,
        start_food_weight_g=start_food,
        end_food_weight_g=end_food,
        weight_reduction_g=weight_reduction,
        start_image_url=start_img,
        end_image_url=end_img,
        start_image_source=req.start_image_source or "app_camera",
        end_image_source=req.end_image_source or "app_camera",
        device_id=req.device_id,
        is_calibrated=req.is_calibrated,
        is_flagged_increase=is_flagged,
        readings_history=req.readings_history,
        ai_model="gemini-2.5-flash"
    )
    db.add(meal)
    db.flush()

    for comp in nutri_totals["components"]:
        fc = FoodComponent(
            meal_session_id=meal.id,
            name=comp["name"],
            weight_g=comp["weight_g"],
            calories_kcal=comp["calories_kcal"],
            protein_g=comp["protein_g"],
            carbs_g=comp["carbs_g"],
            fat_g=comp["fat_g"],
            confidence=comp.get("confidence", 0.92),
            icon_name=comp["icon_name"]
        )
        db.add(fc)

    nutri = NutritionalAnalysis(
        meal_session_id=meal.id,
        total_calories=nutri_totals["total_calories"],
        total_protein=nutri_totals["total_protein_g"],
        total_carbs=nutri_totals["total_carbs_g"],
        total_fat=nutri_totals["total_fat_g"],
        total_fiber=nutri_totals["total_fiber_g"],
        total_sodium=nutri_totals["total_sodium_mg"]
    )
    db.add(nutri)

    waste = WasteAnalysis(
        meal_session_id=meal.id,
        waste_percentage=waste_data["waste_pct"],
        consumed_percentage=waste_data["consumed_pct"],
        observation=waste_data["observation"]
    )
    db.add(waste)
    db.commit()
    db.refresh(meal)

    leftovers = [CategoryLeftover(**cat) for cat in waste_data["category_breakdown"]]
    
    return MealDetailResponse(
        id=meal.id,
        meal_name=meal.meal_name,
        start_time=meal.start_time,
        end_time=meal.end_time,
        initial_weight_g=meal.initial_weight_g,
        consumed_weight_g=meal.consumed_weight_g,
        remaining_weight_g=meal.remaining_weight_g,
        waste_score=meal.waste_score,
        total_calories=nutri.total_calories,
        waste_percentage=waste.waste_percentage,
        status=meal.status,
        weight_source=meal.weight_source or "device",
        tare_weight_g=meal.tare_weight_g or 0.0,
        image_url=meal.image_url,
        start_gross_weight_g=meal.start_gross_weight_g,
        end_gross_weight_g=meal.end_gross_weight_g,
        plate_weight_g=meal.plate_weight_g,
        plate_weight_mode=meal.plate_weight_mode or "none",
        start_food_weight_g=meal.start_food_weight_g,
        end_food_weight_g=meal.end_food_weight_g,
        weight_reduction_g=meal.weight_reduction_g,
        start_image_url=meal.start_image_url or meal.image_url,
        end_image_url=meal.end_image_url,
        start_image_source=meal.start_image_source or "app_camera",
        end_image_source=meal.end_image_source or "app_camera",
        device_id=meal.device_id,
        is_calibrated=meal.is_calibrated if meal.is_calibrated is not None else True,
        is_flagged_increase=meal.is_flagged_increase or False,
        readings_history=meal.readings_history,
        components=req.components,
        nutrition=NutritionResponse(
            total_calories=nutri.total_calories,
            total_protein_g=nutri.total_protein,
            total_carbs_g=nutri.total_carbs,
            total_fat_g=nutri.total_fat,
            total_fiber_g=nutri.total_fiber,
            total_sodium_mg=nutri.total_sodium
        ),
        leftovers=leftovers,
        ai_observation=waste.observation
    )

@router.get("/{meal_id}", response_model=MealDetailResponse)
def get_meal_detail(meal_id: str, current_user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    meal = db.query(MealSession).filter(MealSession.id == meal_id, MealSession.user_id == current_user.id).first()
    if not meal:
        raise HTTPException(status_code=404, detail="Meal not found")
        
    waste_data = WasteCalculator.calculate_waste_metrics(meal.initial_weight_g, meal.remaining_weight_g)
    leftovers = [CategoryLeftover(**cat) for cat in waste_data["category_breakdown"]]
    
    comps = [
        VisionComponent(
            name=c.name,
            weight_g=c.weight_g,
            confidence=c.confidence,
            calories_kcal=c.calories_kcal,
            protein_g=c.protein_g,
            carbs_g=c.carbs_g,
            fat_g=c.fat_g,
            icon_name=c.icon_name
        ) for c in meal.components
    ]
    
    nutri = meal.nutrition or NutritionalAnalysis()
    return MealDetailResponse(
        id=meal.id,
        meal_name=meal.meal_name,
        start_time=meal.start_time,
        end_time=meal.end_time,
        initial_weight_g=meal.initial_weight_g,
        consumed_weight_g=meal.consumed_weight_g,
        remaining_weight_g=meal.remaining_weight_g,
        waste_score=meal.waste_score,
        total_calories=nutri.total_calories if nutri else 0,
        waste_percentage=meal.waste_analysis.waste_percentage if meal.waste_analysis else 0.0,
        status=meal.status,
        weight_source=getattr(meal, "weight_source", "device") or "device",
        tare_weight_g=getattr(meal, "tare_weight_g", 0.0) or 0.0,
        image_url=getattr(meal, "image_url", None),
        start_gross_weight_g=getattr(meal, "start_gross_weight_g", None),
        end_gross_weight_g=getattr(meal, "end_gross_weight_g", None),
        plate_weight_g=getattr(meal, "plate_weight_g", None),
        plate_weight_mode=getattr(meal, "plate_weight_mode", "none") or "none",
        start_food_weight_g=getattr(meal, "start_food_weight_g", None),
        end_food_weight_g=getattr(meal, "end_food_weight_g", None),
        weight_reduction_g=getattr(meal, "weight_reduction_g", None),
        start_image_url=getattr(meal, "start_image_url", None) or getattr(meal, "image_url", None),
        end_image_url=getattr(meal, "end_image_url", None),
        start_image_source=getattr(meal, "start_image_source", "app_camera") or "app_camera",
        end_image_source=getattr(meal, "end_image_source", "app_camera") or "app_camera",
        device_id=getattr(meal, "device_id", None),
        is_calibrated=getattr(meal, "is_calibrated", True) if getattr(meal, "is_calibrated", None) is not None else True,
        is_flagged_increase=getattr(meal, "is_flagged_increase", False) or False,
        readings_history=getattr(meal, "readings_history", None),
        components=comps,
        nutrition=NutritionResponse(
            total_calories=nutri.total_calories if nutri else 0,
            total_protein_g=nutri.total_protein if nutri else 0.0,
            total_carbs_g=nutri.total_carbs if nutri else 0.0,
            total_fat_g=nutri.total_fat if nutri else 0.0,
            total_fiber_g=nutri.total_fiber if nutri else 0.0,
            total_sodium_mg=nutri.total_sodium if nutri else 0.0
        ),
        leftovers=leftovers,
        ai_observation=meal.waste_analysis.observation if meal.waste_analysis else waste_data["observation"]
    )

