from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session
from app.core.database import get_db
from app.models.models import CalibrationLog
from app.schemas.schemas import CalibrationStatus, CalibrationStepRequest
from app.services.ble_protocol import smart_pad_driver

router = APIRouter(prefix="/calibration", tags=["Smart Pad Calibration"])

current_step_state = 3  # Matches the Stitch design: "Step 3 of 4: Calibrating load cell sensors..."

@router.get("/status", response_model=CalibrationStatus)
def get_calibration_status():
    step_info = smart_pad_driver.execute_calibration_step(current_step_state)
    return CalibrationStatus(
        device_id=smart_pad_driver.device_id,
        current_step=current_step_state,
        total_steps=4,
        step_description=step_info.get("description", "Calibration step in progress"),
        progress_percentage=step_info.get("progress", 75.0),
        is_complete=step_info.get("is_complete", False),
        baseline_tare_g=smart_pad_driver.baseline_tare_g,
        precision_g=0.5
    )

@router.post("/step", response_model=CalibrationStatus)
def advance_calibration_step(req: CalibrationStepRequest, db: Session = Depends(get_db)):
    global current_step_state
    current_step_state = req.step
    step_info = smart_pad_driver.execute_calibration_step(current_step_state)
    
    log = CalibrationLog(
        device_id=smart_pad_driver.device_id,
        step=current_step_state,
        status=step_info.get("status", "in_progress"),
        baseline_tare_g=smart_pad_driver.baseline_tare_g,
        precision_g=0.5
    )
    db.add(log)
    db.commit()
    
    return CalibrationStatus(
        device_id=smart_pad_driver.device_id,
        current_step=current_step_state,
        total_steps=4,
        step_description=step_info.get("description", ""),
        progress_percentage=step_info.get("progress", 0.0),
        is_complete=step_info.get("is_complete", False),
        baseline_tare_g=smart_pad_driver.baseline_tare_g,
        precision_g=0.5
    )

@router.post("/reset")
def reset_calibration():
    global current_step_state
    current_step_state = 1
    return {"status": "reset", "step": 1}
