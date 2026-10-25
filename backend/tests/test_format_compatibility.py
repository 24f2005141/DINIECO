import io
import os
import sys
import base64
import pytest
from fastapi.testclient import TestClient
from PIL import Image, ImageOps, ImageDraw

sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), "..")))
from app.main import app
from app.api.auth import create_access_token
from app.services.image_normalizer import (
    ImageNormalizer,
    EmptyImageError,
    CorruptedImageError,
    UnsupportedFormatError,
    DecompressionBombException,
)
from app.services.vision_recognizer import FoodVisionRecognizer

client = TestClient(app)

def get_auth_headers(email="compat_user@dinieco.com"):
    reg = client.post("/api/v1/auth/register", json={
        "email": email,
        "password": "password123",
        "full_name": "Compatibility User"
    })
    token = reg.json().get("access_token") if reg.status_code == 200 else client.post("/api/v1/auth/login", json={
        "email": email,
        "password": "password123"
    }).json()["access_token"]
    return {"Authorization": f"Bearer {token}"}

def create_image_bytes(format_name: str, mode: str = "RGB", size: tuple = (120, 120), color="green") -> bytes:
    """Generates valid image bytes for testing specific formats and color modes."""
    img = Image.new(mode, size, color=color)
    buf = io.BytesIO()
    if format_name.upper() == "JPEG":
        if mode != "RGB":
            img = img.convert("RGB")
        img.save(buf, format="JPEG", quality=90)
    elif format_name.upper() in ("HEIC", "HEIF"):
        try:
            import pillow_heif
            heif_file = pillow_heif.from_pillow(img)
            heif_file.save(buf)
        except Exception:
            pytest.skip("HEIF/HEIC encoding is not supported or libheif DLL is unavailable on this environment.")
    else:
        img.save(buf, format=format_name)
    return buf.getvalue()

class TestImageNormalizerDirect:
    """Direct unit tests for ImageNormalizer service across all formats and edge cases."""

    @pytest.mark.parametrize("fmt,mode", [
        ("JPEG", "RGB"),
        ("PNG", "RGBA"),
        ("WEBP", "RGB"),
        ("BMP", "RGB"),
        ("TIFF", "RGB"),
        ("GIF", "P"),
        ("AVIF", "RGB"),
        ("HEIF", "RGB"),
    ])
    def test_normalize_all_supported_formats(self, fmt, mode):
        raw = create_image_bytes(fmt, mode=mode)
        res = ImageNormalizer.normalize(raw)
        assert res.mime_type == "image/jpeg"
        assert res.format == "JPEG"
        assert res.width > 0
        assert res.height > 0
        assert len(res.bytes) > 0
        # Verify result is re-openable as RGB JPEG
        with Image.open(io.BytesIO(res.bytes)) as check:
            assert check.format == "JPEG"
            assert check.mode == "RGB"

    def test_normalize_grayscale(self):
        raw = create_image_bytes("PNG", mode="L", color=128)
        res = ImageNormalizer.normalize(raw)
        with Image.open(io.BytesIO(res.bytes)) as check:
            assert check.mode == "RGB"

    def test_normalize_rgba_transparency_white_background(self):
        # Create half-transparent red PNG
        img = Image.new("RGBA", (50, 50), color=(255, 0, 0, 128))
        buf = io.BytesIO()
        img.save(buf, format="PNG")
        res = ImageNormalizer.normalize(buf.getvalue())
        assert res.mime_type == "image/jpeg"
        with Image.open(io.BytesIO(res.bytes)) as check:
            assert check.mode == "RGB"

    def test_normalize_exif_orientation(self):
        # 100 wide x 50 high with EXIF tag 6 (90 CW)
        img = Image.new("RGB", (100, 50), color="blue")
        exif = img.getexif()
        exif[0x0112] = 6
        buf = io.BytesIO()
        img.save(buf, format="JPEG", exif=exif)
        res = ImageNormalizer.normalize(buf.getvalue())
        # Transposed should have width 50 and height 100
        assert res.width == 50
        assert res.height == 100

    def test_normalize_dimension_downscaling(self):
        # Excessively large 3000x2000 image
        raw = create_image_bytes("JPEG", size=(3000, 2000))
        res = ImageNormalizer.normalize(raw, max_dim=1920)
        assert max(res.width, res.height) == 1920
        # Aspect ratio preserved
        assert round(res.width / res.height, 2) == round(3000 / 2000, 2)

    def test_reject_empty_bytes(self):
        with pytest.raises(EmptyImageError):
            ImageNormalizer.normalize(b"")

    def test_reject_corrupted_bytes(self):
        with pytest.raises(CorruptedImageError):
            ImageNormalizer.normalize(b"not an image at all\x00\x01\x02\x03\x04")

    def test_reject_unsupported_format(self):
        # Create an ICO or PDF-like header
        fake_ico = b"\x00\x00\x01\x00\x01\x00" + b"\x00" * 50
        with pytest.raises((CorruptedImageError, UnsupportedFormatError)):
            ImageNormalizer.normalize(fake_ico)


class TestUploadEndpointCompatibility:
    """API-level integration tests for POST /api/v1/vision/upload."""

    @pytest.mark.parametrize("fmt,ext,declared_mime", [
        ("JPEG", ".jpg", "image/jpeg"),
        ("JPEG", ".JPEG", "image/jpeg"),
        ("PNG", ".png", "image/png"),
        ("WEBP", ".webp", "image/webp"),
        ("HEIF", ".heic", "image/heic"),
        ("HEIF", ".HEIF", "application/octet-stream"),
        ("BMP", ".bmp", "image/bmp"),
        ("TIFF", ".tiff", "image/tiff"),
        ("GIF", ".gif", "image/gif"),
        ("AVIF", ".avif", "image/avif"),
        ("JPEG", "", "application/octet-stream"),  # No extension
    ])
    def test_upload_supported_formats(self, fmt, ext, declared_mime):
        headers = get_auth_headers()
        raw_bytes = create_image_bytes(fmt)
        filename = f"meal_upload{ext}" if ext else "meal_upload"

        response = client.post(
            "/api/v1/vision/upload",
            headers=headers,
            files={"file": (filename, io.BytesIO(raw_bytes), declared_mime)}
        )
        assert response.status_code == 200, f"Failed for {fmt} with {ext}: {response.text}"
        data = response.json()
        assert "image_id" in data
        assert data["image_url"].startswith("/uploads/")
        assert data["format"] in ("JPEG", "PNG", "WEBP", "HEIF", "BMP", "TIFF", "GIF", "AVIF")
        assert "normalized_base64" in data
        assert len(data["normalized_base64"]) > 50

    def test_upload_mismatched_extension_and_content(self):
        """PNG image saved with .jpg extension and octet-stream MIME must decode cleanly by content."""
        headers = get_auth_headers()
        real_png = create_image_bytes("PNG")
        response = client.post(
            "/api/v1/vision/upload",
            headers=headers,
            files={"file": ("fake_name.jpg", io.BytesIO(real_png), "application/octet-stream")}
        )
        assert response.status_code == 200
        data = response.json()
        assert data["format"] == "PNG"

    def test_upload_empty_file_rejected(self):
        headers = get_auth_headers()
        response = client.post(
            "/api/v1/vision/upload",
            headers=headers,
            files={"file": ("empty.jpg", io.BytesIO(b""), "image/jpeg")}
        )
        assert response.status_code == 400
        assert "empty" in response.json()["detail"].lower()

    def test_upload_text_file_renamed_to_jpg_rejected(self):
        headers = get_auth_headers()
        response = client.post(
            "/api/v1/vision/upload",
            headers=headers,
            files={"file": ("malicious.jpg", io.BytesIO(b"Hello world this is plain text"), "image/jpeg")}
        )
        assert response.status_code == 400
        assert "cannot decode" in response.json()["detail"].lower() or "corrupted" in response.json()["detail"].lower()

    def test_upload_oversized_file_rejected(self):
        headers = get_auth_headers()
        # 16 MB dummy payload
        big_payload = io.BytesIO(b"0" * (16 * 1024 * 1024))
        response = client.post(
            "/api/v1/vision/upload",
            headers=headers,
            files={"file": ("oversized.jpg", big_payload, "image/jpeg")}
        )
        assert response.status_code == 413


class TestEndToEndMealVisionAndNutrition:
    """End-to-end tests: upload -> analyze (Gemini 3.8 Flash / CV) -> nutrition calculation."""

    def test_analyze_with_normalized_heic_image(self):
        headers = get_auth_headers()
        heic_bytes = create_image_bytes("HEIF")
        b64_heic = base64.b64encode(heic_bytes).decode("ascii")

        response = client.post(
            "/api/v1/vision/analyze",
            headers=headers,
            json={
                "image_base64": b64_heic,
                "pad_weight_g": 520.0,
                "weight_source": "manual",
                "dish_hint": "Paneer Roti Meal"
            }
        )
        assert response.status_code == 200
        data = response.json()
        assert data["total_weight_g"] == 520.0
        assert data["net_food_weight_g"] == 520.0
        assert len(data["components"]) > 0
        comp_sum = round(sum(c["weight_g"] for c in data["components"]), 1)
        assert comp_sum == 520.0
        assert data["total_calories"] > 0

    def test_analyze_with_corrupted_base64_returns_422(self):
        headers = get_auth_headers()
        corrupted_b64 = base64.b64encode(b"completely invalid image contents").decode("ascii")

        response = client.post(
            "/api/v1/vision/analyze",
            headers=headers,
            json={
                "image_base64": corrupted_b64,
                "pad_weight_g": 400.0,
                "weight_source": "manual"
            }
        )
        assert response.status_code == 422
        assert "invalid" in response.json()["detail"].lower() or "corrupted" in response.json()["detail"].lower()
