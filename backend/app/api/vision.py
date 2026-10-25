import os
import uuid
import base64
from typing import Optional
from pathlib import Path
from fastapi import APIRouter, HTTPException, Depends, UploadFile, File, status
from app.schemas.schemas import VisionAnalyzeRequest, VisionAnalyzeResponse, VisionComponent, ImageUploadResponse
from app.services.vision_recognizer import FoodVisionRecognizer
from app.services.image_normalizer import (
    ImageNormalizer,
    EmptyImageError,
    CorruptedImageError,
    UnsupportedFormatError,
    DecompressionBombException,
    ImageProcessingError,
)
from app.models.models import User
from app.api.auth import get_current_user, get_optional_current_user

router = APIRouter(prefix="/vision", tags=["AI Food Vision"])

# Ensure uploads directory exists
UPLOAD_DIR = Path(__file__).resolve().parent.parent.parent / "uploads"
UPLOAD_DIR.mkdir(parents=True, exist_ok=True)

MAX_FILE_SIZE_BYTES = 15 * 1024 * 1024  # 15 MB

@router.post("/upload", response_model=ImageUploadResponse)
async def upload_food_image(
    file: UploadFile = File(...),
    current_user: User = Depends(get_current_user)
):
    """
    Receives meal photograph, validates and normalizes it across all supported
    formats (JPEG, PNG, WebP, HEIC/HEIF, BMP, TIFF, GIF, AVIF), and stores
    the standardized JPEG image for analysis and persistence.
    """
    # 1. Read bytes and enforce size constraints
    try:
        contents = await file.read()
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Failed to read image upload stream: {str(e)}"
        )

    if not contents or len(contents) == 0:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Uploaded file is empty (0 bytes received)."
        )

    if len(contents) > MAX_FILE_SIZE_BYTES:
        raise HTTPException(
            status_code=status.HTTP_413_REQUEST_ENTITY_TOO_LARGE,
            detail=f"File exceeds maximum allowed size of {MAX_FILE_SIZE_BYTES // (1024 * 1024)}MB"
        )

    # 2. Decode and normalize image using content-based inspection
    try:
        norm_result = ImageNormalizer.normalize(
            raw_bytes=contents,
            max_dim=1920,
            quality=88,
            filename_hint=file.filename
        )
    except EmptyImageError as e:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(e))
    except CorruptedImageError as e:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(e))
    except UnsupportedFormatError as e:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(e))
    except DecompressionBombException as e:
        raise HTTPException(status_code=status.HTTP_422_UNPROCESSABLE_ENTITY, detail=str(e))
    except ImageProcessingError as e:
        raise HTTPException(status_code=status.HTTP_422_UNPROCESSABLE_ENTITY, detail=str(e))
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Unexpected error during image normalization: {str(e)}"
        )

    # 3. Store normalized JPEG securely
    image_id = str(uuid.uuid4())
    filename = f"{image_id}.jpg"
    target_path = UPLOAD_DIR / filename

    try:
        with open(target_path, "wb") as f:
            f.write(norm_result.bytes)
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to save normalized image to storage: {str(e)}"
        )

    image_url = f"/uploads/{filename}"
    normalized_b64 = base64.b64encode(norm_result.bytes).decode("ascii")

    return ImageUploadResponse(
        image_id=image_id,
        image_url=image_url,
        filename=filename,
        format=norm_result.original_format,
        width=norm_result.width,
        height=norm_result.height,
        normalized_base64=normalized_b64
    )

@router.post("/analyze", response_model=VisionAnalyzeResponse)
def analyze_plate(
    req: VisionAnalyzeRequest,
    current_user: Optional[User] = Depends(get_optional_current_user)
):
    """
    Analyzes meal photograph using Google Gemini 3.8 Flash Vision (with deterministic
    CV fallback), applies portion reconciliation, and calculates USDA/ICMR nutrition.
    """
    try:
        result = FoodVisionRecognizer.analyze_food_image(
            image_base64=req.image_base64,
            image_url=req.image_url,
            total_weight_g=req.pad_weight_g,
            weight_source=req.weight_source,
            tare_weight_g=req.tare_weight_g,
            dish_hint=req.dish_hint
        )
    except ValueError as e:
        raise HTTPException(status_code=status.HTTP_422_UNPROCESSABLE_ENTITY, detail=str(e))
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Vision analysis internal error: {str(e)}"
        )

    comps = [VisionComponent(**c) for c in result["components"]]
    return VisionAnalyzeResponse(
        dish_name=result["dish_name"],
        overall_confidence=result["overall_confidence"],
        total_weight_g=result["total_weight_g"],
        net_food_weight_g=result["net_food_weight_g"],
        weight_source=result["weight_source"],
        ai_model=result["ai_model"],
        ai_verified=result["ai_verified"],
        is_stabilized=result["is_stabilized"],
        total_calories=result["total_calories"],
        total_protein_g=result["total_protein_g"],
        total_carbs_g=result["total_carbs_g"],
        total_fat_g=result["total_fat_g"],
        components=comps
    )
