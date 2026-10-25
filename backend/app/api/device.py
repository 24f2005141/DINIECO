from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session
from datetime import datetime, timezone
from app.core.database import get_db
from app.models.models import SmartPadDevice
from app.schemas.schemas import DeviceStatus, TareRequest
from app.services.ble_protocol import smart_pad_driver

router = APIRouter(prefix="/device", tags=["Device Diagnostics & BLE"])

@router.get("/status", response_model=DeviceStatus)
def get_device_status(db: Session = Depends(get_db)):
    diag = smart_pad_driver.get_diagnostics()
    return DeviceStatus(
        device_id=diag["device_id"],
        mac_address="C4:4F:33:01:8A:2F",
        firmware_version=diag["firmware_version"],
        battery_percent=diag["battery_percent"],
        load_sensor_status=diag["load_sensor_status"],
        camera_status=diag["camera_status"],
        is_connected=diag["is_connected"],
        last_sync=datetime.now(timezone.utc),
        last_calibrated=datetime.now(timezone.utc),
        baseline_tare_g=diag["baseline_tare_g"]
    )

@router.post("/connect")
def connect_device():
    smart_pad_driver.connect()
    return {"status": "connected", "device_id": smart_pad_driver.device_id}

@router.post("/disconnect")
def disconnect_device():
    smart_pad_driver.disconnect()
    return {"status": "disconnected", "device_id": smart_pad_driver.device_id}

@router.post("/tare")
def tare_pad(req: TareRequest):
    tare_val = smart_pad_driver.tare()
    return {"status": "success", "tare_g": tare_val}

@router.get("/weight-stream")
def read_weight_stream():
    weight_g = smart_pad_driver.get_calibrated_weight_g()
    is_stable = smart_pad_driver.is_stabilized()
    return {
        "device_id": smart_pad_driver.device_id,
        "weight_g": weight_g,
        "is_stabilized": is_stable,
        "unit": "g"
    }
