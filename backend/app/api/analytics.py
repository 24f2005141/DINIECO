from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session
from datetime import datetime, timezone, timedelta
from typing import List
from app.core.database import get_db
from app.schemas.schemas import AnalyticsSummaryResponse, DailyTrendItem, CategoryWasteBreakdown
from app.models.models import MealSession, User, WasteAnalysis, NutritionalAnalysis
from app.api.auth import get_current_user

router = APIRouter(prefix="/analytics", tags=["Analytics & Waste Trends"])

def to_naive_utc(dt: datetime) -> datetime:
    if dt is None:
        return None
    if dt.tzinfo is not None:
        return dt.astimezone(timezone.utc).replace(tzinfo=None)
    return dt

@router.get("/summary", response_model=AnalyticsSummaryResponse)
def get_analytics_summary(filter_period: str = "7Days", current_user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    now = datetime.now(timezone.utc).replace(tzinfo=None)
    today_start = datetime(now.year, now.month, now.day)
    yesterday_start = today_start - timedelta(days=1)
    seven_days_ago = today_start - timedelta(days=6)
    fourteen_days_ago = today_start - timedelta(days=13)
    thirty_days_ago = today_start - timedelta(days=29)

    user_meals = db.query(MealSession).filter(
        MealSession.user_id == current_user.id,
        MealSession.status == "completed"
    ).all()

    if not user_meals:
        # Legitimate empty state for a new user with no completed meals
        daily_trends = []
        for i in range(7):
            day_dt = seven_days_ago + timedelta(days=i)
            daily_trends.append(DailyTrendItem(
                day_name=day_dt.strftime("%a"),
                waste_g=0.0,
                date_str=day_dt.strftime("%Y-%m-%d")
            ))

        return AnalyticsSummaryResponse(
            today_waste_g=0.0,
            today_waste_delta_g=0.0,
            weekly_waste_g=0.0,
            weekly_waste_delta_pct=0.0,
            monthly_waste_kg=0.0,
            waste_score=100,
            waste_score_label="No Data",
            avg_calories=0,
            avg_protein_g=0.0,
            avg_carbs_g=0.0,
            avg_fat_g=0.0,
            avg_meal_size_g=0.0,
            avg_consumed_pct=0.0,
            daily_trends=daily_trends,
            category_breakdown=[],
            insights=[
                "Welcome to DINIECO! No meals have been logged yet. Start a session or add a meal photo to track your nutrition and minimize food waste."
            ]
        )

    # 1. Today & Yesterday waste
    today_meals = [m for m in user_meals if m.end_time and to_naive_utc(m.end_time) >= today_start]
    yesterday_meals = [m for m in user_meals if m.end_time and yesterday_start <= to_naive_utc(m.end_time) < today_start]
    
    today_waste_g = sum(m.remaining_weight_g for m in today_meals)
    yesterday_waste_g = sum(m.remaining_weight_g for m in yesterday_meals)
    today_waste_delta_g = round(today_waste_g - yesterday_waste_g, 1)

    # 2. Weekly & Previous Week waste
    this_week_meals = [m for m in user_meals if m.end_time and to_naive_utc(m.end_time) >= seven_days_ago]
    last_week_meals = [m for m in user_meals if m.end_time and fourteen_days_ago <= to_naive_utc(m.end_time) < seven_days_ago]
    
    weekly_waste_g = round(sum(m.remaining_weight_g for m in this_week_meals), 1)
    last_week_waste_g = sum(m.remaining_weight_g for m in last_week_meals)
    
    if last_week_waste_g > 0:
        weekly_waste_delta_pct = round(((weekly_waste_g - last_week_waste_g) / last_week_waste_g) * 100.0, 1)
    else:
        weekly_waste_delta_pct = 0.0

    # 3. Monthly waste
    month_meals = [m for m in user_meals if m.end_time and to_naive_utc(m.end_time) >= thirty_days_ago]
    monthly_waste_kg = round(sum(m.remaining_weight_g for m in month_meals) / 1000.0, 2)

    # 4. Averages
    avg_score = int(sum(m.waste_score for m in user_meals) / len(user_meals))
    waste_score_label = "Optimal" if avg_score >= 80 else ("Moderate" if avg_score >= 60 else "Attention")
    
    calories_list = [m.nutrition.total_calories for m in user_meals if m.nutrition]
    avg_calories = int(sum(calories_list) / len(calories_list)) if calories_list else 0
    
    protein_list = [m.nutrition.total_protein for m in user_meals if m.nutrition]
    avg_protein = round(sum(protein_list) / len(protein_list), 1) if protein_list else 0.0

    carbs_list = [m.nutrition.total_carbs for m in user_meals if m.nutrition]
    avg_carbs = round(sum(carbs_list) / len(carbs_list), 1) if carbs_list else 0.0

    fat_list = [m.nutrition.total_fat for m in user_meals if m.nutrition]
    avg_fat = round(sum(fat_list) / len(fat_list), 1) if fat_list else 0.0

    meal_sizes = [m.initial_weight_g for m in user_meals]
    avg_meal_size = round(sum(meal_sizes) / len(meal_sizes), 1) if meal_sizes else 0.0

    consumed_pcts = [m.consumed_weight_g / m.initial_weight_g * 100.0 for m in user_meals if m.initial_weight_g > 0]
    avg_consumed_pct = round(sum(consumed_pcts) / len(consumed_pcts), 1) if consumed_pcts else 0.0

    # 5. 7-Day Daily Trends
    daily_trends = []
    for i in range(7):
        day_start = seven_days_ago + timedelta(days=i)
        day_end = day_start + timedelta(days=1)
        day_waste = sum(m.remaining_weight_g for m in user_meals if m.end_time and day_start <= to_naive_utc(m.end_time) < day_end)
        daily_trends.append(DailyTrendItem(
            day_name=day_start.strftime("%a"),
            waste_g=round(day_waste, 1),
            date_str=day_start.strftime("%Y-%m-%d")
        ))

    # 6. Category breakdown from real user WasteAnalysis
    total_rice = sum(m.waste_analysis.rice_waste_g for m in user_meals if m.waste_analysis)
    total_veg = sum(m.waste_analysis.veg_waste_g for m in user_meals if m.waste_analysis)
    total_bread = sum(m.waste_analysis.bread_waste_g for m in user_meals if m.waste_analysis)
    total_prot = sum(m.waste_analysis.protein_waste_g for m in user_meals if m.waste_analysis)
    total_other = sum(m.waste_analysis.other_waste_g for m in user_meals if m.waste_analysis)
    total_cat_waste = total_rice + total_veg + total_bread + total_prot + total_other

    category_breakdown = []
    if total_cat_waste > 0:
        category_breakdown = [
            CategoryWasteBreakdown(category="Rice / Grains", percentage=round(total_rice / total_cat_waste * 100.0, 1), color_hex="#003315"),
            CategoryWasteBreakdown(category="Vegetables & Gravy", percentage=round(total_veg / total_cat_waste * 100.0, 1), color_hex="#416900"),
            CategoryWasteBreakdown(category="Breads / Roti", percentage=round(total_bread / total_cat_waste * 100.0, 1), color_hex="#84cc16"),
            CategoryWasteBreakdown(category="Protein / Paneer", percentage=round(total_prot / total_cat_waste * 100.0, 1), color_hex="#acf847"),
            CategoryWasteBreakdown(category="Other / Chutney", percentage=round(total_other / total_cat_waste * 100.0, 1), color_hex="#c0c9be"),
        ]

    # 7. Insights dynamically tailored to user's real data
    insights = []
    if avg_consumed_pct >= 90.0:
        insights.append(f"Outstanding efficiency! You consumed {avg_consumed_pct}% of your prepared meals, keeping plate waste minimal.")
    elif avg_consumed_pct >= 75.0:
        insights.append(f"Solid progress: {avg_consumed_pct}% consumed on average. Consider adjusting side portions slightly to reduce leftovers.")
    else:
        insights.append(f"High leftovers detected ({round(100.0 - avg_consumed_pct, 1)}% waste average). Starting with smaller initial portions will improve sustainability.")

    if total_rice > 0 and total_rice >= max(total_veg, total_bread, total_prot, total_other):
        insights.append("Rice and grains account for your highest leftover category. Consider reducing your initial rice serving by 10-15%.")
    elif total_veg > 0 and total_veg >= max(total_rice, total_bread, total_prot, total_other):
        insights.append("Vegetables & gravy make up the bulk of your leftovers. Adjusting cooked batch quantities can lower waste.")

    return AnalyticsSummaryResponse(
        today_waste_g=today_waste_g,
        today_waste_delta_g=today_waste_delta_g,
        weekly_waste_g=weekly_waste_g,
        weekly_waste_delta_pct=weekly_waste_delta_pct,
        monthly_waste_kg=monthly_waste_kg,
        waste_score=avg_score,
        waste_score_label=waste_score_label,
        avg_calories=avg_calories,
        avg_protein_g=avg_protein,
        avg_carbs_g=avg_carbs,
        avg_fat_g=avg_fat,
        avg_meal_size_g=avg_meal_size,
        avg_consumed_pct=avg_consumed_pct,
        daily_trends=daily_trends,
        category_breakdown=category_breakdown,
        insights=insights
    )
