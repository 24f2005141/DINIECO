from pathlib import Path
from fastapi import FastAPI
from fastapi.staticfiles import StaticFiles
from fastapi.middleware.cors import CORSMiddleware
from app.core.config import settings
from app.core.database import engine, Base
from app.api import auth, device, calibration, vision, nutrition, meals, analytics, insights

# Create tables
Base.metadata.create_all(bind=engine)

def auto_migrate():
    with engine.connect() as conn:
        try:
            from sqlalchemy import inspect, text
            inspector = inspect(engine)
            if "meal_sessions" in inspector.get_table_names():
                columns = [c["name"] for c in inspector.get_columns("meal_sessions")]
                if "weight_source" not in columns:
                    conn.execute(text("ALTER TABLE meal_sessions ADD COLUMN weight_source VARCHAR DEFAULT 'device'"))
                if "tare_weight_g" not in columns:
                    conn.execute(text("ALTER TABLE meal_sessions ADD COLUMN tare_weight_g FLOAT DEFAULT 0.0"))
                if "ai_model" not in columns:
                    conn.execute(text("ALTER TABLE meal_sessions ADD COLUMN ai_model VARCHAR DEFAULT 'gemini-2.5-flash'"))
                if "image_url" not in columns:
                    conn.execute(text("ALTER TABLE meal_sessions ADD COLUMN image_url VARCHAR"))
                if "start_gross_weight_g" not in columns:
                    conn.execute(text("ALTER TABLE meal_sessions ADD COLUMN start_gross_weight_g FLOAT"))
                if "end_gross_weight_g" not in columns:
                    conn.execute(text("ALTER TABLE meal_sessions ADD COLUMN end_gross_weight_g FLOAT"))
                if "plate_weight_g" not in columns:
                    conn.execute(text("ALTER TABLE meal_sessions ADD COLUMN plate_weight_g FLOAT"))
                if "plate_weight_mode" not in columns:
                    conn.execute(text("ALTER TABLE meal_sessions ADD COLUMN plate_weight_mode VARCHAR DEFAULT 'none'"))
                if "start_food_weight_g" not in columns:
                    conn.execute(text("ALTER TABLE meal_sessions ADD COLUMN start_food_weight_g FLOAT"))
                if "end_food_weight_g" not in columns:
                    conn.execute(text("ALTER TABLE meal_sessions ADD COLUMN end_food_weight_g FLOAT"))
                if "weight_reduction_g" not in columns:
                    conn.execute(text("ALTER TABLE meal_sessions ADD COLUMN weight_reduction_g FLOAT"))
                if "start_image_url" not in columns:
                    conn.execute(text("ALTER TABLE meal_sessions ADD COLUMN start_image_url VARCHAR"))
                if "end_image_url" not in columns:
                    conn.execute(text("ALTER TABLE meal_sessions ADD COLUMN end_image_url VARCHAR"))
                if "start_image_source" not in columns:
                    conn.execute(text("ALTER TABLE meal_sessions ADD COLUMN start_image_source VARCHAR DEFAULT 'app_camera'"))
                if "end_image_source" not in columns:
                    conn.execute(text("ALTER TABLE meal_sessions ADD COLUMN end_image_source VARCHAR DEFAULT 'app_camera'"))
                if "device_id" not in columns:
                    conn.execute(text("ALTER TABLE meal_sessions ADD COLUMN device_id VARCHAR"))
                if "is_calibrated" not in columns:
                    conn.execute(text("ALTER TABLE meal_sessions ADD COLUMN is_calibrated BOOLEAN DEFAULT 1"))
                if "is_flagged_increase" not in columns:
                    conn.execute(text("ALTER TABLE meal_sessions ADD COLUMN is_flagged_increase BOOLEAN DEFAULT 0"))
                if "readings_history" not in columns:
                    conn.execute(text("ALTER TABLE meal_sessions ADD COLUMN readings_history TEXT"))
                conn.commit()
        except Exception:
            pass

auto_migrate()

uploads_path = Path(__file__).resolve().parent.parent / "uploads"
uploads_path.mkdir(parents=True, exist_ok=True)

app = FastAPI(
    title="DINIECO API - Smart Dining & Food Waste Platform",
    description="Backend API powering the DINIECO Smart Dining Pad, AI food recognition, nutrition estimation, and waste analytics.",
    version="1.0.0"
)

# Enable CORS for Flutter Web, Mobile, and Desktop
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Mount API routers
app.include_router(auth.router, prefix=settings.API_V1_STR)
app.include_router(device.router, prefix=settings.API_V1_STR)
app.include_router(calibration.router, prefix=settings.API_V1_STR)
app.include_router(vision.router, prefix=settings.API_V1_STR)
app.include_router(nutrition.router, prefix=settings.API_V1_STR)
app.include_router(meals.router, prefix=settings.API_V1_STR)
app.include_router(analytics.router, prefix=settings.API_V1_STR)
app.include_router(insights.router, prefix=settings.API_V1_STR)

# Mount static uploads
app.mount("/uploads", StaticFiles(directory=uploads_path), name="uploads")

@app.get("/")
def root():
    return {
        "platform": "DINIECO",
        "description": "Smart Dining & Food Waste Platform",
        "status": "operational",
        "version": settings.VERSION
    }

@app.get("/health")
def health_check():
    return {"status": "healthy", "database": "connected"}

if __name__ == "__main__":
    import uvicorn
    uvicorn.run("main:app", host="0.0.0.0", port=8000, reload=True)
