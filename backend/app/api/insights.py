from fastapi import APIRouter, Depends
from typing import List
from datetime import datetime, timezone
from sqlalchemy.orm import Session
from app.core.database import get_db
from app.models.models import User, MealSession, AIInsight
from app.schemas.schemas import InsightItem
from app.api.auth import get_current_user

router = APIRouter(prefix="/insights", tags=["AI Recommendations"])

@router.get("/", response_model=List[InsightItem])
def get_insights(current_user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    now = datetime.now(timezone.utc)
    
    # Query database stored insights for user
    db_insights = db.query(AIInsight).filter(AIInsight.user_id == current_user.id).all()
    if db_insights:
        return [
            InsightItem(
                id=i.id,
                title=i.title,
                message=i.message,
                category=i.category,
                impact_percent=i.impact_percent,
                created_at=i.created_at
            ) for i in db_insights
        ]

    # Dynamically generate based on user's real meals
    user_meals = db.query(MealSession).filter(
        MealSession.user_id == current_user.id,
        MealSession.status == "completed"
    ).order_by(MealSession.end_time.desc()).limit(10).all()

    if not user_meals:
        return [
            InsightItem(
                id="onboarding-insight",
                title="AI Dining Assistant Ready",
                message="No meal records found yet. Place your meal on the DINIECO Smart Pad or take a meal photo to unlock personalized portion optimization and sustainability insights.",
                category="onboarding",
                impact_percent=0.0,
                created_at=now
            )
        ]

    items = []
    # Real insight 1: Waste efficiency
    total_initial = sum(m.initial_weight_g for m in user_meals)
    total_remaining = sum(m.remaining_weight_g for m in user_meals)
    waste_pct = round((total_remaining / total_initial * 100.0), 1) if total_initial > 0 else 0.0

    if waste_pct <= 10.0:
        items.append(InsightItem(
            id=f"insight-{user_meals[0].id}-eff",
            title="Exceptional Meal Efficiency",
            message=f"Across your recent sessions, your plate leftover rate is only {waste_pct}%. Your dining habits are actively minimizing food waste.",
            category="waste_reduction",
            impact_percent=-waste_pct,
            created_at=now
        ))
    else:
        items.append(InsightItem(
            id=f"insight-{user_meals[0].id}-portion",
            title="Portion Optimization Suggested",
            message=f"Recent sessions indicate a {waste_pct}% plate leftover rate. Starting with smaller initial portions will help minimize post-meal waste.",
            category="portion_control",
            impact_percent=waste_pct,
            created_at=now
        ))

    # Real insight 2: Nutrition consistency
    nutri_meals = [m for m in user_meals if m.nutrition]
    if nutri_meals:
        avg_protein = round(sum(m.nutrition.total_protein for m in nutri_meals) / len(nutri_meals), 1)
        items.append(InsightItem(
            id=f"insight-{user_meals[0].id}-nutri",
            title="Nutrient Balance Highlight",
            message=f"Your protein intake averages {avg_protein}g per recorded meal session.",
            category="nutrition",
            impact_percent=5.0,
            created_at=now
        ))

    return items
