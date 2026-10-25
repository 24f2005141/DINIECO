from abc import ABC, abstractmethod
import time
import math
from typing import Dict, Any, List

class IWeightData(ABC):
    """
    Interface for Weight Data acquisition conforming to the OO Component Diagram:
    «interface» IWeightData
    """
    @abstractmethod
    def read_raw_adc(self) -> int:
        pass

    @abstractmethod
    def get_calibrated_weight_g(self) -> float:
        pass

    @abstractmethod
    def tare(self) -> float:
        pass

    @abstractmethod
    def is_stabilized(self) -> bool:
        pass

    @abstractmethod
    def get_diagnostics(self) -> Dict[str, Any]:
        pass

class SmartDiningPadBLE(IWeightData):
    """
    Smart Dining Pad BLE implementation.
    Handles communication with HX711 24-bit ADC, load cells, tare calibration,
    and BLE GATT characteristics.
    """
    SERVICE_UUID = "0000ffe0-0000-1000-8000-00805f9b34fb"
    CHAR_WEIGHT_STREAM_UUID = "0000ffe1-0000-1000-8000-00805f9b34fb"
    CHAR_TARE_COMMAND_UUID = "0000ffe2-0000-1000-8000-00805f9b34fb"
    CHAR_BATTERY_UUID = "00002a19-0000-1000-8000-00805f9b34fb"

    def __init__(self, device_id: str = "DINIECO-PAD-001"):
        self.device_id = device_id
        self.firmware = "v1.0"
        self.is_connected = True
        self.battery_percent = 94
        self.baseline_tare_g = 0.0
        self.calibration_factor = 420.0  # Raw ADC counts per gram
        self._current_weight_g = 842.0
        self._recent_readings: List[float] = [842.0, 842.1, 841.9, 842.0, 842.0]
        self._last_tare_time = time.time()
        self._tare_offset_adc = 0

    def connect(self) -> bool:
        self.is_connected = True
        return True

    def disconnect(self) -> bool:
        self.is_connected = False
        return True

    def read_raw_adc(self) -> int:
        """Simulates/reads HX711 24-bit raw signed integer (-8388608 to 8388607)"""
        return int(self._current_weight_g * self.calibration_factor)

    def get_calibrated_weight_g(self) -> float:
        """
        Calculates calibrated weight in grams, filtering noise and clamping negative values.
        """
        raw = self.read_raw_adc()
        net_raw = raw - self._tare_offset_adc
        calibrated = net_raw / self.calibration_factor
        # Reject sensor jitter below 0.5g precision and clamp negative readings
        if calibrated <= 0.0 or abs(calibrated) < 0.5:
            return 0.0
        return round(calibrated, 1)

    def tare(self) -> float:
        """Zeroes the current load as the tare baseline"""
        self._tare_offset_adc = self.read_raw_adc()
        self.baseline_tare_g = self._current_weight_g
        self._last_tare_time = time.time()
        return 0.0

    def set_simulation_weight(self, weight_g: float):
        """Allows testing varying load scenarios in controlled environments"""
        self._current_weight_g = max(0.0, weight_g)
        self._recent_readings.append(self._current_weight_g)
        if len(self._recent_readings) > 5:
            self._recent_readings.pop(0)

    def is_stabilized(self) -> bool:
        """Checks if weight variance over the last 5 readings is within 1.0g"""
        if len(self._recent_readings) < 3:
            return True
        mean = sum(self._recent_readings) / len(self._recent_readings)
        variance = sum((x - mean) ** 2 for x in self._recent_readings) / len(self._recent_readings)
        return math.sqrt(variance) < 1.0

    def execute_calibration_step(self, step: int) -> Dict[str, Any]:
        """
        4-Step Hardware Calibration sequence:
        Step 1: Remove all food and objects from the pad
        Step 2: Place the pad on a stable flat surface
        Step 3: Zero tare and load-cell sensor baseline
        Step 4: Calibration completed with 0.5g precision
        """
        if step == 1:
            return {
                "step": 1,
                "description": "Remove all food and objects from the pad",
                "status": "ready",
                "progress": 25.0,
                "is_complete": False
            }
        elif step == 2:
            return {
                "step": 2,
                "description": "Place the pad on a stable flat surface",
                "status": "ready",
                "progress": 50.0,
                "is_complete": False
            }
        elif step == 3:
            self.tare()
            return {
                "step": 3,
                "description": "Calibrating load cell sensors & zero tare...",
                "status": "in_progress",
                "progress": 75.0,
                "is_complete": False
            }
        elif step >= 4:
            self.baseline_tare_g = 0.0
            return {
                "step": 4,
                "description": "Sensors calibrated to 0.5g precision",
                "status": "completed",
                "progress": 100.0,
                "is_complete": True,
                "precision_g": 0.5
            }
        return {"step": step, "status": "unknown", "progress": 0.0, "is_complete": False}

    def get_diagnostics(self) -> Dict[str, Any]:
        return {
            "device_id": self.device_id,
            "firmware_version": self.firmware,
            "battery_percent": self.battery_percent,
            "load_sensor_status": "Active (HX711 24-bit)",
            "camera_status": "Connected (OV2640)",
            "is_connected": self.is_connected,
            "baseline_tare_g": self.baseline_tare_g,
            "precision_g": 0.5,
            "last_reading_g": self.get_calibrated_weight_g(),
            "stabilized": self.is_stabilized()
        }

# Global singleton driver for active BLE connection
smart_pad_driver = SmartDiningPadBLE()
