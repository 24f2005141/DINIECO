import pytest
import sys, os
sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), "..")))
from app.services.ble_protocol import SmartDiningPadBLE

def test_smart_dining_pad_ble_weight_reading():
    pad = SmartDiningPadBLE()
    pad.set_simulation_weight(842.0)
    
    # 1. Weight read
    calibrated = pad.get_calibrated_weight_g()
    assert abs(calibrated - 842.0) < 0.2
    
    # 2. Raw ADC count
    adc = pad.read_raw_adc()
    assert adc > 0
    
    # 3. Tare operation
    tare_result = pad.tare()
    assert tare_result == 0.0
    
    # After tare with same load, calibrated reading should be ~0.0
    post_tare = pad.get_calibrated_weight_g()
    assert abs(post_tare) < 0.6
    
    # 4. New meal load after tare
    pad.set_simulation_weight(486.0)
    new_weight = pad.get_calibrated_weight_g()
    assert new_weight >= 0.0

def test_smart_dining_pad_calibration_steps():
    pad = SmartDiningPadBLE()
    
    s1 = pad.execute_calibration_step(1)
    assert s1["step"] == 1
    assert s1["is_complete"] is False
    
    s2 = pad.execute_calibration_step(2)
    assert s2["step"] == 2
    assert s2["is_complete"] is False
    
    s3 = pad.execute_calibration_step(3)
    assert s3["step"] == 3
    assert s3["progress"] == 75.0
    
    s4 = pad.execute_calibration_step(4)
    assert s4["step"] == 4
    assert s4["is_complete"] is True
    assert s4["precision_g"] == 0.5
