import io
import logging
from dataclasses import dataclass
from typing import Optional, Set
from PIL import Image, ImageOps

logger = logging.getLogger(__name__)

# Register HEIF / HEIC opener via pillow_heif if available
try:
    import pillow_heif
    pillow_heif.register_heif_opener()
    HEIF_AVAILABLE = True
except Exception:
    logger.warning("pillow_heif is not installed or libheif DLL unavailable. HEIC/HEIF files will not be supported.")
    HEIF_AVAILABLE = False

# Ensure standard PIL image formats (including AVIF if built) are initialized
Image.init()

# Enforce decompression-bomb safety limit (50 Megapixels max)
Image.MAX_IMAGE_PIXELS = 50_000_000

SUPPORTED_FORMATS: Set[str] = {
    "JPEG", "JPG", "PNG", "WEBP", "HEIF", "HEIC",
    "BMP", "TIFF", "TIF", "GIF", "AVIF", "MPO", "DIB"
}

class ImageProcessingError(Exception):
    """Base exception for image processing and validation errors."""
    pass

class EmptyImageError(ImageProcessingError):
    """Raised when uploaded file contains zero bytes."""
    pass

class CorruptedImageError(ImageProcessingError):
    """Raised when uploaded bytes cannot be decoded as an image or are truncated."""
    pass

class UnsupportedFormatError(ImageProcessingError):
    """Raised when image format is recognized but not supported by DINIECO."""
    pass

class DecompressionBombException(ImageProcessingError):
    """Raised when image pixel dimensions exceed safety limits."""
    pass

@dataclass
class NormalizedImageResult:
    bytes: bytes
    mime_type: str = "image/jpeg"
    format: str = "JPEG"
    width: int = 0
    height: int = 0
    original_format: str = "UNKNOWN"
    original_size_bytes: int = 0

class ImageNormalizer:
    """
    Robust image normalization service for DINIECO.
    
    Accepts meal photography in multiple formats (JPEG, PNG, WebP, HEIC/HEIF,
    GIF, BMP, TIFF, AVIF), validates content integrity, corrects EXIF orientation,
    handles transparency/palette modes cleanly, limits dimensions to protect AI
    and memory resources, and produces high-quality normalized JPEG bytes.
    """

    @classmethod
    def normalize(
        cls,
        raw_bytes: bytes,
        max_dim: int = 1920,
        quality: int = 88,
        filename_hint: Optional[str] = None
    ) -> NormalizedImageResult:
        """
        Validates and normalizes image bytes into a standardized JPEG representation.
        
        Args:
            raw_bytes: Raw binary image payload.
            max_dim: Maximum width or height constraint (maintains aspect ratio).
            quality: JPEG compression quality (1-100).
            filename_hint: Optional filename for logging and extension hints.
            
        Returns:
            NormalizedImageResult with normalized JPEG bytes and metadata.
        """
        if not raw_bytes or len(raw_bytes) == 0:
            raise EmptyImageError("Uploaded file is empty (0 bytes received).")

        # 1. Decode and verify initial image stream
        in_buf = io.BytesIO(raw_bytes)
        try:
            img = Image.open(in_buf)
            detected_format = (img.format or "").upper()
        except Image.DecompressionBombError as e:
            raise DecompressionBombException(
                f"Image pixel dimensions exceed safety limit of {Image.MAX_IMAGE_PIXELS} pixels: {str(e)}"
            )
        except Exception as e:
            raise CorruptedImageError(
                f"Cannot decode image: file is corrupted, incomplete, or not a valid image format."
            )

        if not detected_format:
            # Fallback format detection check
            detected_format = "UNKNOWN"

        # Check supported format allowlist
        if detected_format not in SUPPORTED_FORMATS:
            raise UnsupportedFormatError(
                f"Image format '{detected_format}' is not supported. "
                f"Supported formats: JPEG, PNG, WebP, HEIC, GIF, BMP, TIFF, AVIF."
            )

        # 2. Extract static frame for animated/multi-frame formats (GIF, multi-page TIFF)
        try:
            img.seek(0)
        except Exception:
            pass

        # 3. Force pixel load to guarantee stream is not corrupted/truncated
        try:
            img.load()
        except Image.DecompressionBombError as e:
            raise DecompressionBombException(f"Decompression bomb detected during load: {str(e)}")
        except Exception as e:
            raise CorruptedImageError(f"Corrupted or truncated image data: {str(e)}")

        # 4. Correct EXIF Orientation (smartphones, cameras)
        try:
            transposed = ImageOps.exif_transpose(img)
            if transposed is not None:
                img = transposed
        except Exception as e:
            logger.debug(f"EXIF orientation transpose skipped or failed: {e}")

        # 5. Normalize Color Mode (JPEG requires RGB, handle alpha & palettes)
        if img.mode in ("RGBA", "LA") or (img.mode == "P" and "transparency" in img.info):
            # Composite transparent images over a neutral, clean white dining background
            rgba_img = img.convert("RGBA")
            bg = Image.new("RGB", rgba_img.size, (255, 255, 255))
            bg.paste(rgba_img, mask=rgba_img.split()[3])
            img = bg
        elif img.mode != "RGB":
            img = img.convert("RGB")

        # 6. Constrain Dimensions (Resize large meal photos to avoid AI timeouts/OOM)
        if img.width > max_dim or img.height > max_dim:
            img.thumbnail((max_dim, max_dim), Image.Resampling.LANCZOS)

        # 7. Encode to high-quality JPEG
        out_buf = io.BytesIO()
        try:
            img.save(out_buf, format="JPEG", quality=quality, optimize=True)
            normalized_bytes = out_buf.getvalue()
        except Exception as e:
            raise ImageProcessingError(f"Failed to encode normalized JPEG image: {str(e)}")
        finally:
            out_buf.close()
            in_buf.close()

        # 8. Re-verify normalized output integrity
        with io.BytesIO(normalized_bytes) as verify_buf:
            with Image.open(verify_buf) as check_img:
                check_img.load()
                final_width, final_height = check_img.size

        return NormalizedImageResult(
            bytes=normalized_bytes,
            mime_type="image/jpeg",
            format="JPEG",
            width=final_width,
            height=final_height,
            original_format=detected_format,
            original_size_bytes=len(raw_bytes)
        )
