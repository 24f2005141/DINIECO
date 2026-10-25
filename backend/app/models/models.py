import datetime
import uuid
from sqlalchemy import Column, String, Integer, Float, Boolean, DateTime, ForeignKey, Text
from sqlalchemy.orm import relationship
from app.core.database import Base

def utc_now():
    return datetime.datetime.now(datetime.timezone.utc)

class User(Base):
    __tablename__ = "users"
    
    id = Column(String, primary_key=True, default=lambda: str(uuid.uuid4()))
    email = Column(String, unique=True, index=True, nullable=False)
    full_name = Column(String, nullable=False, default="Aarav")
    hashed_password = Column(String, nullable=False)
    created_at = Column(DateTime, default=utc_now)
    
    meals = relationship("MealSession", back_populates="user", cascade="all, delete-orphan")
    insights = relationship("AIInsight", back_populates="user", cascade="all, delete-orphan")

class SmartPadDevice(Base):
    __tablename__ = "smart_pad_devices"
    
    id = Column(String, primary_key=True, default=lambda: str(uuid.uuid4()))
    device_id = Column(String, unique=True, index=True, default="DINIECO-PAD-001")
    mac_address = Column(String, default="C4:4F:33:01:8A:2F")
    firmware_version = Column(String, default="v1.0")
    battery_percent = Column(Integer, default=94)
    load_sensor_status = Column(String, default="Active (HX711 24-bit)")
    camera_status = Column(String, default="Connected (OV2640)")
    is_connected = Column(Boolean, default=True)
    last_sync = Column(DateTime, default=utc_now)
    last_calibrated = Column(DateTime, default=utc_now)
    baseline_tare_g = Column(Float, default=0.0)

class CalibrationLog(Base):
    __tablename__ = "calibration_logs"
    
    id = Column(String, primary_key=True, default=lambda: str(uuid.uuid4()))
    device_id = Column(String, ForeignKey("smart_pad_devices.device_id"), nullable=False)
    step = Column(Integer, default=1)
    status = Column(String, default="completed")
    baseline_tare_g = Column(Float, default=0.0)
    precision_g = Column(Float, default=0.5)
    created_at = Column(DateTime, default=utc_now)

class MealSession(Base):
    __tablename__ = "meal_sessions"
    
    id = Column(String, primary_key=True, default=lambda: str(uuid.uuid4()))
    user_id = Column(String, ForeignKey("users.id"), nullable=False)
    meal_name = Column(String, nullable=False, default="Vegetable Rice Bowl")
    start_time = Column(DateTime, default=utc_now)
    end_time = Column(DateTime, default=utc_now)
    initial_weight_g = Column(Float, nullable=False, default=842.0)
    consumed_weight_g = Column(Float, nullable=False, default=632.0)
    remaining_weight_g = Column(Float, nullable=False, default=210.0)
    waste_score = Column(Integer, default=82)  # 0 to 100
    status = Column(String, default="completed")  # in_progress, completed, cancelled
    weight_source = Column(String, default="device")  # "device" or "manual"
    tare_weight_g = Column(Float, default=0.0)
    ai_model = Column(String, default="gemini-2.5-flash")
    image_url = Column(String, nullable=True)
    
    # Extended Meal Measurement Workflow fields
    start_gross_weight_g = Column(Float, nullable=True)
    end_gross_weight_g = Column(Float, nullable=True)
    plate_weight_g = Column(Float, nullable=True)
    plate_weight_mode = Column(String, default="none")  # "measured", "manual", "none"
    start_food_weight_g = Column(Float, nullable=True)
    end_food_weight_g = Column(Float, nullable=True)
    weight_reduction_g = Column(Float, nullable=True)
    start_image_url = Column(String, nullable=True)
    end_image_url = Column(String, nullable=True)
    start_image_source = Column(String, default="app_camera")  # "app_camera", "device_camera"
    end_image_source = Column(String, default="app_camera")
    device_id = Column(String, nullable=True)
    is_calibrated = Column(Boolean, default=True)
    is_flagged_increase = Column(Boolean, default=False)
    readings_history = Column(Text, nullable=True)
    
    user = relationship("User", back_populates="meals")
    components = relationship("FoodComponent", back_populates="meal_session", cascade="all, delete-orphan")
    nutrition = relationship("NutritionalAnalysis", back_populates="meal_session", uselist=False, cascade="all, delete-orphan")
    waste_analysis = relationship("WasteAnalysis", back_populates="meal_session", uselist=False, cascade="all, delete-orphan")

class FoodComponent(Base):
    __tablename__ = "food_components"
    
    id = Column(String, primary_key=True, default=lambda: str(uuid.uuid4()))
    meal_session_id = Column(String, ForeignKey("meal_sessions.id"), nullable=False)
    name = Column(String, nullable=False)
    weight_g = Column(Float, nullable=False)
    calories_kcal = Column(Integer, default=0)
    protein_g = Column(Float, default=0.0)
    carbs_g = Column(Float, default=0.0)
    fat_g = Column(Float, default=0.0)
    confidence = Column(Float, default=0.92)
    icon_name = Column(String, default="restaurant")
    
    meal_session = relationship("MealSession", back_populates="components")

class NutritionalAnalysis(Base):
    __tablename__ = "nutritional_analyses"
    
    id = Column(String, primary_key=True, default=lambda: str(uuid.uuid4()))
    meal_session_id = Column(String, ForeignKey("meal_sessions.id"), nullable=False, unique=True)
    total_calories = Column(Integer, default=620)
    total_protein = Column(Float, default=24.0)
    total_carbs = Column(Float, default=82.0)
    total_fat = Column(Float, default=18.0)
    total_fiber = Column(Float, default=9.0)
    total_sodium = Column(Float, default=420.0)
    
    meal_session = relationship("MealSession", back_populates="nutrition")

class WasteAnalysis(Base):
    __tablename__ = "waste_analyses"
    
    id = Column(String, primary_key=True, default=lambda: str(uuid.uuid4()))
    meal_session_id = Column(String, ForeignKey("meal_sessions.id"), nullable=False, unique=True)
    waste_percentage = Column(Float, default=24.9)
    consumed_percentage = Column(Float, default=75.1)
    
    # Leftover categories
    rice_waste_g = Column(Float, default=80.0)
    rice_waste_pct = Column(Float, default=38.0)
    veg_waste_g = Column(Float, default=57.0)
    veg_waste_pct = Column(Float, default=27.0)
    bread_waste_g = Column(Float, default=31.0)
    bread_waste_pct = Column(Float, default=15.0)
    protein_waste_g = Column(Float, default=25.0)
    protein_waste_pct = Column(Float, default=12.0)
    other_waste_g = Column(Float, default=17.0)
    other_waste_pct = Column(Float, default=8.0)
    
    observation = Column(Text, default="You tend to leave more rice during lunch. Consider starting with a 15% smaller rice portion to reduce plate leftovers.")
    
    meal_session = relationship("MealSession", back_populates="waste_analysis")

class AIInsight(Base):
    __tablename__ = "ai_insights"
    
    id = Column(String, primary_key=True, default=lambda: str(uuid.uuid4()))
    user_id = Column(String, ForeignKey("users.id"), nullable=False)
    title = Column(String, nullable=False, default="AI Insight")
    message = Column(Text, nullable=False)
    category = Column(String, default="waste_reduction")
    impact_percent = Column(Float, default=-18.0)
    created_at = Column(DateTime, default=utc_now)
    
    user = relationship("User", back_populates="insights")
