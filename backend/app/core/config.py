import os
from pathlib import Path
from dotenv import load_dotenv
from pydantic import BaseModel

# Automatically load .env from backend/ or project root
_backend_dir = Path(__file__).resolve().parent.parent.parent
_backend_env = _backend_dir / ".env"
_root_env = _backend_dir.parent / ".env"

if _backend_env.exists():
    load_dotenv(dotenv_path=_backend_env)
elif _root_env.exists():
    load_dotenv(dotenv_path=_root_env)
else:
    load_dotenv()

class Settings(BaseModel):
    PROJECT_NAME: str = "DINIECO API"
    VERSION: str = "1.0.0"
    API_V1_STR: str = "/api/v1"
    
    # Database
    DATABASE_URL: str = os.getenv("DATABASE_URL", "sqlite:///./dinieco.db")
    
    # Security
    SECRET_KEY: str = os.getenv("SECRET_KEY", "dinieco-super-secret-key-smart-dining-2026")
    ALGORITHM: str = "HS256"
    ACCESS_TOKEN_EXPIRE_MINUTES: int = 60 * 24  # 1 day
    
    # Smart Pad BLE & Hardware Defaults
    SMART_PAD_DEVICE_ID: str = "DINIECO-PAD-001"
    SMART_PAD_FIRMWARE_VERSION: str = "v1.0"
    CALIBRATION_PRECISION_G: float = 0.5
    
    # AI Vision
    GEMINI_API_KEY: str = os.getenv("GEMINI_API_KEY", "")

settings = Settings()
