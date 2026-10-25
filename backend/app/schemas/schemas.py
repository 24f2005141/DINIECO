from pydantic import BaseModel, ConfigDict
from typing import List, Optional
from datetime import datetime

# Auth
class UserCreate(BaseModel):
    email: str
    password: str
    full_name: str = "Aarav"

class UserLogin(BaseModel):
    email: str
    password: str

class Token(BaseModel):
    access_token: str
    token_type: str = "bearer"
    user_id: str
    full_name: str

class UserResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    id: str
    email: str
    full_name: str
    created_at: datetime

# Device & BLE
class DeviceStatus(BaseModel):
    device_id: str
    mac_address: str
    firmware_version: str
    battery_percent: int
    load_sensor_status: str
    camera_status: str
    is_connected: bool
    last_sync: datetime
    last_calibrated: datetime
    baseline_tare_g: float

class TareRequest(BaseModel):
    device_id: str = "DINIECO-PAD-001"

class CalibrationStepRequest(BaseModel):
    device_id: str = "DINIECO-PAD-001"
    step: int
    confirm_action: bool = True

class CalibrationStatus(BaseModel):
    device_id: str
    current_step: int
    total_steps: int = 4
    step_description: str
    progress_percentage: float
    is_complete: bool
    baseline_tare_g: float
    precision_g: float = 0.5

# Vision & Recognition
class VisionComponent(BaseModel):
    name: str
    weight_g: float
    confidence: float = 0.92
    calories_kcal: int
    protein_g: float
    carbs_g: float
    fat_g: float
    fiber_g: float = 0.0
    sodium_mg: float = 0.0
    portion_ratio: float = 0.0
    uncertainty_min_kcal: int = 0
    uncertainty_max_kcal: int = 0
    preparation_style: str = "Cooked"
    icon_name: str = "restaurant"

class VisionAnalyzeRequest(BaseModel):
    image_base64: Optional[str] = None
    image_url: Optional[str] = None
    pad_weight_g: float = 842.0
    weight_source: str = "device"  # "device" or "manual"
    tare_weight_g: float = 356.0
    dish_hint: Optional[str] = "Vegetable Rice Bowl"

class VisionAnalyzeResponse(BaseModel):
    dish_name: str
    overall_confidence: float
    total_weight_g: float
    net_food_weight_g: float
    weight_source: str = "device"
    ai_model: str = "gemini-3.8-flash"
    ai_verified: bool = False
    is_stabilized: bool = True
    total_calories: int = 620
    total_protein_g: float = 24.0
    total_carbs_g: float = 82.0
    total_fat_g: float = 18.0
    components: List[VisionComponent]

# Nutrition
class NutritionCalculateRequest(BaseModel):
    components: List[VisionComponent]

class NutritionResponse(BaseModel):
    total_calories: int
    total_protein_g: float
    total_carbs_g: float
    total_fat_g: float
    total_fiber_g: float
    total_sodium_mg: float

class ImageUploadResponse(BaseModel):
    image_id: str
    image_url: str
    filename: str
    format: str = "JPEG"
    width: int = 0
    height: int = 0
    normalized_base64: Optional[str] = None

# Meals & Sessions
class MealCreateRequest(BaseModel):
    meal_name: str = "Vegetable Rice Bowl"
    initial_weight_g: float = 842.0
    remaining_weight_g: float = 210.0
    weight_source: str = "device"
    tare_weight_g: float = 0.0
    image_url: Optional[str] = None
    components: List[VisionComponent] = []

    # Extended measurement workflow fields
    start_gross_weight_g: Optional[float] = None
    end_gross_weight_g: Optional[float] = None
    plate_weight_g: Optional[float] = None
    plate_weight_mode: str = "none"  # "measured", "manual", "none"
    start_food_weight_g: Optional[float] = None
    end_food_weight_g: Optional[float] = None
    weight_reduction_g: Optional[float] = None
    start_image_url: Optional[str] = None
    end_image_url: Optional[str] = None
    start_image_source: str = "app_camera"
    end_image_source: str = "app_camera"
    device_id: Optional[str] = None
    is_calibrated: bool = True
    is_flagged_increase: bool = False
    readings_history: Optional[str] = None

class CategoryLeftover(BaseModel):
    category: str
    weight_g: float
    percentage: float

class MealResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    id: str
    meal_name: str
    start_time: datetime
    end_time: datetime
    initial_weight_g: float
    consumed_weight_g: float
    remaining_weight_g: float
    waste_score: int
    total_calories: int
    waste_percentage: float
    status: str
    weight_source: str = "device"
    tare_weight_g: float = 0.0
    image_url: Optional[str] = None

    # Extended measurement workflow fields
    start_gross_weight_g: Optional[float] = None
    end_gross_weight_g: Optional[float] = None
    plate_weight_g: Optional[float] = None
    plate_weight_mode: str = "none"
    start_food_weight_g: Optional[float] = None
    end_food_weight_g: Optional[float] = None
    weight_reduction_g: Optional[float] = None
    start_image_url: Optional[str] = None
    end_image_url: Optional[str] = None
    start_image_source: str = "app_camera"
    end_image_source: str = "app_camera"
    device_id: Optional[str] = None
    is_calibrated: bool = True
    is_flagged_increase: bool = False
    readings_history: Optional[str] = None

class MealDetailResponse(MealResponse):
    components: List[VisionComponent]
    nutrition: NutritionResponse
    leftovers: List[CategoryLeftover]
    ai_observation: str

# Analytics
class DailyTrendItem(BaseModel):
    day_name: str  # Mon, Tue, Wed, Thu, Fri, Sat, Sun
    waste_g: float
    date_str: str

class CategoryWasteBreakdown(BaseModel):
    category: str
    percentage: float
    color_hex: str

class AnalyticsSummaryResponse(BaseModel):
    today_waste_g: float
    today_waste_delta_g: float
    weekly_waste_g: float
    weekly_waste_delta_pct: float
    monthly_waste_kg: float
    waste_score: int
    waste_score_label: str = "Optimal"
    
    avg_calories: int
    avg_protein_g: float
    avg_carbs_g: float
    avg_fat_g: float
    avg_meal_size_g: float
    avg_consumed_pct: float
    
    daily_trends: List[DailyTrendItem]
    category_breakdown: List[CategoryWasteBreakdown]
    insights: List[str]

# Insights
class InsightItem(BaseModel):
    id: str
    title: str
    message: str
    category: str
    impact_percent: float
    created_at: datetime
