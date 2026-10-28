import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/models.dart';
import '../models/ble_models.dart';
import '../services/api_service.dart';
import 'ble_provider.dart';

class DeviceReadinessResult {
  final bool isReady;
  final bool isBluetoothEnabled;
  final bool isConnected;
  final bool isReceivingData;
  final bool isDataFresh;
  final bool isCalibrated;
  final bool hasExistingSession;
  final String? errorMessage;
  final String? warningMessage;

  const DeviceReadinessResult({
    required this.isReady,
    required this.isBluetoothEnabled,
    required this.isConnected,
    required this.isReceivingData,
    required this.isDataFresh,
    required this.isCalibrated,
    required this.hasExistingSession,
    this.errorMessage,
    this.warningMessage,
  });
}

class DiniecoProvider extends ChangeNotifier {
  final ApiService apiService;

  DiniecoProvider({ApiService? api}) : apiService = api ?? ApiService();

  int _selectedTab = 0;
  int get selectedTab => _selectedTab;

  PadStatus _padStatus = PadStatus(
    deviceId: 'DINIECO-PAD-001',
    batteryPercent: 0,
    loadSensorStatus: 'Checking...',
    cameraStatus: 'Checking...',
    isConnected: false,
    baselineTareG: 0.0,
  );
  PadStatus get padStatus => _padStatus;
  void setPadStatus(PadStatus status) {
    _padStatus = status;
    notifyListeners();
  }

  bool _isBleTestProfile = false;
  bool get isBleTestProfile => _isBleTestProfile;

  // Moving average smoothing buffer (5 samples) for HX711 jitter elimination
  final List<double> _smoothingBuffer = [];
  static const int _smoothingWindowSize = 5;
  List<double> get smoothingBuffer => List.unmodifiable(_smoothingBuffer);

  double get smoothedWeightG {
    if (_smoothingBuffer.isEmpty) return _currentWeightG;
    final sum = _smoothingBuffer.fold<double>(0.0, (acc, val) => acc + val);
    return sum / _smoothingBuffer.length;
  }

  bool get isWeightStable {
    if (_smoothingBuffer.length < 3) return false;
    final maxW = _smoothingBuffer.reduce((a, b) => a > b ? a : b);
    final minW = _smoothingBuffer.reduce((a, b) => a < b ? a : b);
    return (maxW - minW) <= 1.5;
  }

  // Pre-session Plate Setup state
  double? _setupPlateWeightG;
  double? get setupPlateWeightG => _setupPlateWeightG;

  String _setupPlateWeightMode = 'none'; // 'measured', 'manual', 'none'
  String get setupPlateWeightMode => _setupPlateWeightMode;

  void setSetupPlateWeight(double? weightG, [String mode = 'manual']) {
    _setupPlateWeightG = weightG != null ? (weightG * 10).round() / 10.0 : null;
    _setupPlateWeightMode = mode;
    notifyListeners();
  }

  bool autoCapturePlateWeight() {
    if (!isWeightStable) return false;
    final current = smoothedWeightG;
    if (current > 10.0) {
      _setupPlateWeightG = (current * 10).round() / 10.0;
      _setupPlateWeightMode = 'measured';
      notifyListeners();
      return true;
    }
    return false;
  }

  void clearSetupPlateWeight() {
    _setupPlateWeightG = null;
    _setupPlateWeightMode = 'none';
    notifyListeners();
  }

  void setLastSavedMeal(MealRecord? meal) {
    _lastSavedMeal = meal;
    if (meal != null && !_meals.contains(meal)) {
      _meals.insert(0, meal);
    }
    notifyListeners();
  }

  // Active meal session state & local persistence
  ActiveMealSession? _activeSession;
  ActiveMealSession? get activeSession => _activeSession;
  bool get hasActiveSession => _activeSession != null && !_activeSession!.isCompleted;

  static const String _prefActiveSessionKey = 'dinieco_active_meal_session';

  Future<void> restoreActiveSessionFromStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = prefs.getString(_prefActiveSessionKey);
      if (jsonStr != null && jsonStr.isNotEmpty) {
        final map = jsonDecode(jsonStr) as Map<String, dynamic>;
        final session = ActiveMealSession.fromJson(map);
        if (!session.isCompleted) {
          _activeSession = session;
          notifyListeners();
        }
      }
    } catch (_) {}
  }

  Future<void> _persistActiveSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (_activeSession != null && !_activeSession!.isCompleted) {
        await prefs.setString(_prefActiveSessionKey, jsonEncode(_activeSession!.toJson()));
      } else {
        await prefs.remove(_prefActiveSessionKey);
      }
    } catch (_) {}
  }

  Future<void> _clearPersistedActiveSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_prefActiveSessionKey);
    } catch (_) {}
  }

  Future<DeviceReadinessResult> checkDeviceReadiness(BleProvider ble) async {
    final btEnabled = await ble.bleService.isBluetoothEnabled();
    final connected = ble.status == BleConnectionStatus.connected && ble.connectedDevice != null;
    final packet = ble.latestPacket;
    final receiving = packet != null;
    final isFresh = packet != null &&
        !packet.isStale &&
        DateTime.now().difference(packet.timestamp).inSeconds < 3;
    final isCalibrated = packet?.isCalibrated ?? true;
    final hasExisting = hasActiveSession;

    String? err;
    String? warn;

    if (!btEnabled) {
      err = 'Bluetooth is turned off on your device. Please enable Bluetooth.';
    } else if (!connected) {
      err = 'Smart Dining Pad is not connected. Please connect your pad.';
    } else if (!receiving || !isFresh) {
      err = 'No live telemetry received from pad (data stale or disconnected).';
    }

    if (packet != null && packet.isCalibrated == false) {
      warn = 'Load-cell calibration required. Measurements may be inaccurate.';
    }

    final isReady = err == null;

    return DeviceReadinessResult(
      isReady: isReady,
      isBluetoothEnabled: btEnabled,
      isConnected: connected,
      isReceivingData: receiving,
      isDataFresh: isFresh,
      isCalibrated: isCalibrated,
      hasExistingSession: hasExisting,
      errorMessage: err,
      warningMessage: warn,
    );
  }

  BleTelemetryPacket? _lastProcessedPacket;

  void updateFromBleTelemetry(BleTelemetryPacket packet, {required bool isTestProfile, String? deviceId}) {
    if (identical(_lastProcessedPacket, packet)) return;
    _lastProcessedPacket = packet;
    _isBleTestProfile = isTestProfile;

    // Moving average filter buffer
    _smoothingBuffer.add(packet.weightG);
    if (_smoothingBuffer.length > _smoothingWindowSize) {
      _smoothingBuffer.removeAt(0);
    }

    if (isTestProfile) {
      _currentWeightG = packet.weightG;
      _weightSource = 'test_device';
      _padStatus = PadStatus(
        deviceId: deviceId ?? 'DINIECO_PAD_TEST',
        batteryPercent: 95,
        loadSensorStatus: 'Active (ESP32-C3)',
        cameraStatus: 'Simulated',
        isConnected: true,
        baselineTareG: 0.0,
      );
    } else {
      _currentWeightG = (packet.weightG - _tareWeightG).clamp(0.0, 3000.0);
      _weightSource = 'device';
      _padStatus = PadStatus(
        deviceId: deviceId ?? 'DINIECO-PAD-001',
        batteryPercent: 92,
        loadSensorStatus: 'Active (HX711 24-bit)',
        cameraStatus: 'Connected (OV2640)',
        isConnected: true,
        baselineTareG: _tareWeightG,
      );
    }

    // Live session reading history tracking (throttled to 2 seconds)
    if (_activeSession != null && !_activeSession!.isCompleted) {
      final now = DateTime.now();
      final history = _activeSession!.readingsHistory;
      bool shouldAppend = true;
      if (history.isNotEmpty) {
        final lastTimeStr = history.last['timestamp'] as String?;
        if (lastTimeStr != null) {
          final lastTime = DateTime.tryParse(lastTimeStr);
          if (lastTime != null && now.difference(lastTime).inSeconds < 2) {
            shouldAppend = false;
          }
        }
      }
      if (shouldAppend) {
        history.add({
          'timestamp': now.toIso8601String(),
          'gross_weight_g': (smoothedWeightG * 10).round() / 10.0,
          'stable': packet.isStable ?? isWeightStable,
        });
        if (history.length > 100) {
          history.removeAt(0);
        }
        _persistActiveSession();
      }
    }

    _reconcileComponentsForFoodWeight(_currentWeightG);
    notifyListeners();
  }

  void onBleDisconnected() {
    _isBleTestProfile = false;
    _padStatus = PadStatus(
      deviceId: 'DINIECO-PAD-001',
      batteryPercent: 0,
      loadSensorStatus: 'Offline',
      cameraStatus: 'Offline',
      isConnected: false,
      baselineTareG: 0.0,
    );
    // Note: Do NOT discard _activeSession on disconnect! Active sessions persist
    // so user can reconnect without losing meal progress.
    _weightSource = 'manual';
    notifyListeners();
  }

  double? get currentRemainingFoodWeightG {
    if (_activeSession != null && _activeSession!.plateWeightG != null && _activeSession!.plateWeightMode != 'none') {
      return (smoothedWeightG - _activeSession!.plateWeightG!).clamp(0.0, double.infinity);
    }
    return null;
  }

  double? get currentWeightReductionG {
    if (_activeSession != null && _activeSession!.startGrossWeightG != null) {
      return (_activeSession!.startGrossWeightG! - smoothedWeightG).clamp(0.0, double.infinity);
    }
    return null;
  }

  // Weight Mode: 'device' (Mode A) vs 'manual' (Mode B)
  String _weightSource = 'device';
  String get weightSource => _weightSource;

  final double _tareWeightG = 356.0;
  double get tareWeightG => _tareWeightG;

  double _currentWeightG = 0.0;
  double get currentWeightG => _currentWeightG;

  final bool _isStabilized = true;
  bool get isStabilized => _isStabilized;

  String _currentDishName = '';
  String get currentDishName => _currentDishName;

  double _currentConfidence = 0.0;
  double get currentConfidence => _currentConfidence;

  String _aiModel = 'gemini-2.5-flash';
  String get aiModel => _aiModel;

  bool _aiVerified = false;
  bool get aiVerified => _aiVerified;

  List<FoodComponentItem> _detectedComponents = [];
  List<FoodComponentItem> get detectedComponents => _detectedComponents;
  set detectedComponents(List<FoodComponentItem> comps) {
    _detectedComponents = comps;
    notifyListeners();
  }

  List<MealRecord> _meals = [];
  List<MealRecord> get meals => _meals;

  MealRecord? _lastSavedMeal;
  MealRecord? get lastSavedMeal => _lastSavedMeal;

  CalibrationState _calibrationState = CalibrationState(
    currentStep: 1,
    totalSteps: 4,
    stepDescription: 'Load sensor calibration',
    progressPercentage: 0.0,
    isComplete: false,
  );
  CalibrationState get calibrationState => _calibrationState;

  Map<String, dynamic> _analytics = {};
  Map<String, dynamic> get analytics => _analytics;

  List<Map<String, dynamic>> _insights = [];
  List<Map<String, dynamic>> get insights => _insights;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  // Meal Photo state
  XFile? _selectedMealPhoto;
  XFile? get selectedMealPhoto => _selectedMealPhoto;
  Uint8List? _selectedMealPhotoBytes;
  Uint8List? get selectedMealPhotoBytes => _selectedMealPhotoBytes;

  String? _uploadedImageUrl;
  String? get uploadedImageUrl => _uploadedImageUrl;

  bool _isPhotoUploading = false;
  bool get isPhotoUploading => _isPhotoUploading;

  bool _isVisionAnalyzing = false;
  bool get isVisionAnalyzing => _isVisionAnalyzing;

  String? _photoError;
  String? get photoError => _photoError;

  void setTab(int index) {
    _selectedTab = index;
    notifyListeners();
  }

  Future<void> init() async {
    _isLoading = true;
    notifyListeners();

    await Future.wait([
      _loadPadStatus(),
      _loadMeals(),
      _loadAnalytics(),
      _loadInsights(),
      _loadCalibration(),
      restoreActiveSessionFromStorage(),
    ]);

    _isLoading = false;
    notifyListeners();
  }

  Future<void> _loadPadStatus() async {
    _padStatus = await apiService.getDeviceStatus();
    final weight = await apiService.getWeightReading();
    if (_weightSource == 'device') {
      _currentWeightG = weight;
    }
  }

  Future<void> _loadMeals() async {
    _meals = await apiService.getRecentMeals();
  }

  Future<void> _loadAnalytics() async {
    _analytics = await apiService.getAnalyticsSummary();
  }

  Future<void> _loadInsights() async {
    _insights = await apiService.getAiInsights();
  }

  Future<void> _loadCalibration() async {
    _calibrationState = await apiService.getCalibrationStatus();
  }

  void setWeightSource(String source) {
    if (_weightSource == source) return;
    _weightSource = source;
    if (_weightSource == 'manual') {
      _currentWeightG = totalFoodPortionG > 0 ? totalFoodPortionG : 400.0;
    } else {
      _currentWeightG = totalFoodPortionG + _tareWeightG;
    }
    notifyListeners();
  }

  void setManualWeight(double weightG) {
    _currentWeightG = weightG.clamp(10.0, 2500.0);
    _reconcileComponentsForFoodWeight(_currentWeightG);
    notifyListeners();
  }

  void setSimulatedWeight(double weightG) {
    _currentWeightG = weightG.clamp(0.0, 3000.0);
    _reconcileComponentsForFoodWeight(_currentWeightG);
    notifyListeners();
  }

  void _reconcileComponentsForFoodWeight(double targetFoodWeightG) {
    if (_detectedComponents.isEmpty) return;
    final totalExistingWeight = _detectedComponents.fold(0.0, (sum, c) => sum + c.weightG);
    if (totalExistingWeight <= 0) return;

    for (var comp in _detectedComponents) {
      final ratio = comp.weightG / totalExistingWeight;
      final newW = (targetFoodWeightG * ratio).roundToDouble();
      comp.weightG = newW;
      _updateNutrientValuesForComponent(comp);
    }

    final sumW = _detectedComponents.fold(0.0, (sum, c) => sum + c.weightG);
    final diff = (targetFoodWeightG - sumW).roundToDouble();
    if (diff != 0 && _detectedComponents.isNotEmpty) {
      _detectedComponents[0].weightG += diff;
      _updateNutrientValuesForComponent(_detectedComponents[0]);
    }
  }

  void _updateNutrientValuesForComponent(FoodComponentItem comp) {
    final factor = comp.weightG / 100.0;
    
    // 1. If component already has verified per-100g nutrients from cache or vision, use them directly
    double c100 = comp.calories100g;
    double p100 = comp.protein100g;
    double cb100 = comp.carbs100g;
    double f100 = comp.fat100g;

    // 2. Fallback to name-based lookup if per-100g values were not set
    if (c100 <= 0.0) {
      final name = comp.name.toLowerCase();
      c100 = 120.0; p100 = 4.0; cb100 = 18.0; f100 = 3.5;
      if (name.contains('papaya')) {
        c100 = 43.0; p100 = 0.5; cb100 = 10.8; f100 = 0.3;
      } else if (name.contains('cucumber')) {
        c100 = 15.0; p100 = 0.7; cb100 = 3.6; f100 = 0.1;
      } else if (name.contains('watermelon') || name.contains('melon')) {
        c100 = 30.0; p100 = 0.6; cb100 = 7.6; f100 = 0.2;
      } else if (name.contains('apple')) {
        c100 = 52.0; p100 = 0.3; cb100 = 13.8; f100 = 0.2;
      } else if (name.contains('banana')) {
        c100 = 89.0; p100 = 1.1; cb100 = 22.8; f100 = 0.3;
      } else if (name.contains('rice')) {
        c100 = 130.0; p100 = 2.7; cb100 = 28.2; f100 = 0.3;
      } else if (name.contains('dal')) {
        c100 = 125.0; p100 = 6.8; cb100 = 18.0; f100 = 2.9;
      } else if (name.contains('paneer')) {
        c100 = 268.0; p100 = 18.3; cb100 = 3.4; f100 = 20.8;
      } else if (name.contains('veg')) {
        c100 = 65.0; p100 = 2.6; cb100 = 11.2; f100 = 1.2;
      } else if (name.contains('salad')) {
        c100 = 22.0; p100 = 0.9; cb100 = 4.2; f100 = 0.2;
      } else if (name.contains('roti') || name.contains('chapati')) {
        c100 = 264.0; p100 = 9.1; cb100 = 46.2; f100 = 3.7;
      } else if (name.contains('idli')) {
        c100 = 140.0; p100 = 4.5; cb100 = 26.0; f100 = 1.8;
      }
    }

    comp.caloriesKcal = (c100 * factor).round();
    comp.proteinG = (p100 * factor * 10).round() / 10.0;
    comp.carbsG = (cb100 * factor * 10).round() / 10.0;
    comp.fatG = (f100 * factor * 10).round() / 10.0;
    comp.uncertaintyMinKcal = (comp.caloriesKcal * 0.9).round();
    comp.uncertaintyMaxKcal = (comp.caloriesKcal * 1.1).round();
  }

  // Meal Photo Management
  Future<void> setSelectedMealPhoto(XFile file) async {
    _selectedMealPhoto = file;
    _selectedMealPhotoBytes = await file.readAsBytes();
    _photoError = null;
    notifyListeners();
  }

  void clearMealPhoto() {
    _selectedMealPhoto = null;
    _selectedMealPhotoBytes = null;
    _uploadedImageUrl = null;
    _photoError = null;
    notifyListeners();
  }

  Future<bool> uploadAndAnalyzePhoto(XFile photo) async {
    _selectedMealPhoto = photo;
    _isPhotoUploading = true;
    _photoError = null;
    notifyListeners();

    try {
      final bytes = await photo.readAsBytes();
      _selectedMealPhotoBytes = bytes;
      notifyListeners();
      // 1. Upload file via multipart request
      final uploadRes = await apiService.uploadMealImage(photo);
      _uploadedImageUrl = uploadRes['image_url'] as String?;

      // If backend returned normalized JPEG preview bytes, update local preview bytes
      // so non-native phone formats (HEIC, AVIF, TIFF) render seamlessly on any device
      final normalizedB64 = uploadRes['normalized_base64'] as String?;
      if (normalizedB64 != null && normalizedB64.isNotEmpty) {
        try {
          _selectedMealPhotoBytes = base64Decode(normalizedB64);
        } catch (_) {}
      }

      _isPhotoUploading = false;
      _isVisionAnalyzing = true;
      notifyListeners();

      // 2. Pass normalized JPEG base64 (or fallback to original bytes) to vision analyzer
      final base64Str = normalizedB64 ?? base64Encode(bytes);

      // 3. Analyze image with weight - do not bias dish hint with old preset
      final weightToUse = _currentWeightG > 0 ? _currentWeightG : 500.0;
      final visionData = await apiService.analyzeFoodVision(
        padWeight: weightToUse,
        weightSource: _weightSource,
        tareWeightG: _weightSource == 'device' ? _tareWeightG : 0.0,
        dishHint: null,
        imageBase64: base64Str,
      );

      _currentDishName = visionData['dish_name'] as String;
      _currentConfidence = visionData['confidence'] as double;
      _currentWeightG = visionData['total_weight_g'] as double;
      _aiModel = visionData['ai_model'] as String? ?? 'gemini-3.1-flash-lite';
      _aiVerified = visionData['ai_verified'] as bool? ?? true;
      _detectedComponents = List<FoodComponentItem>.from(visionData['components'] as List);

      _isVisionAnalyzing = false;
      notifyListeners();
      return true;
    } catch (e) {
      _isPhotoUploading = false;
      _isVisionAnalyzing = false;
      _photoError = e.toString().replaceFirst('Exception: ', '');
      notifyListeners();
      return false;
    }
  }

  Future<void> startNewMealSession({String? dishHint, String? imageBase64}) async {
    _isLoading = true;
    notifyListeners();

    try {
      final weightToUse = _currentWeightG > 0 ? _currentWeightG : 500.0;
      final visionData = await apiService.analyzeFoodVision(
        padWeight: weightToUse,
        weightSource: _weightSource,
        tareWeightG: _weightSource == 'device' ? _tareWeightG : 0.0,
        dishHint: dishHint ?? (_currentDishName.isNotEmpty ? _currentDishName : null),
        imageBase64: imageBase64,
      );

      _currentDishName = visionData['dish_name'] as String;
      _currentConfidence = visionData['confidence'] as double;
      _currentWeightG = visionData['total_weight_g'] as double;
      _aiModel = visionData['ai_model'] as String? ?? 'gemini-3.1-flash-lite';
      _aiVerified = visionData['ai_verified'] as bool? ?? false;
      _detectedComponents = List<FoodComponentItem>.from(visionData['components'] as List);
    } catch (_) {
      _currentDishName = '';
      _currentConfidence = 0.0;
      _aiVerified = false;
      _aiModel = 'unavailable';
      _detectedComponents = [];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void updateComponentWeight(int index, double newWeight) {
    if (index >= 0 && index < _detectedComponents.length) {
      _detectedComponents[index].weightG = newWeight.clamp(0.0, 1500.0);
      _updateNutrientValuesForComponent(_detectedComponents[index]);
      notifyListeners();
    }
  }

  int get totalCalories {
    if (_detectedComponents.isEmpty) return 0;
    return _detectedComponents.fold(0, (sum, item) => sum + item.caloriesKcal);
  }

  double get totalProtein {
    if (_detectedComponents.isEmpty) return 0.0;
    return _detectedComponents.fold(0.0, (sum, item) => sum + item.proteinG);
  }

  double get totalCarbs {
    if (_detectedComponents.isEmpty) return 0.0;
    return _detectedComponents.fold(0.0, (sum, item) => sum + item.carbsG);
  }

  double get totalFat {
    if (_detectedComponents.isEmpty) return 0.0;
    return _detectedComponents.fold(0.0, (sum, item) => sum + item.fatG);
  }

  Future<MealRecord?> saveMealSession({double remainingWeightG = 0.0}) async {
    _isLoading = true;
    notifyListeners();

    final saved = await apiService.recordMealSession(
      mealName: _currentDishName.isNotEmpty ? _currentDishName : 'Meal Session',
      initialWeightG: _currentWeightG,
      remainingWeightG: remainingWeightG,
      weightSource: _weightSource,
      tareWeightG: _weightSource == 'device' ? _tareWeightG : 0.0,
      imageUrl: _uploadedImageUrl,
      components: _detectedComponents,
    );

    final initialW = _currentWeightG > 0 ? _currentWeightG : totalFoodPortionG;
    final consumedW = (initialW - remainingWeightG).clamp(0.0, initialW);
    final wastePct = initialW > 0 ? (remainingWeightG / initialW * 100.0).clamp(0.0, 100.0) : 0.0;
    final wasteScore = (100.0 - wastePct * 1.5).round().clamp(0, 100);

    final record = saved ??
        MealRecord(
          id: 'local_${DateTime.now().millisecondsSinceEpoch}',
          mealName: _currentDishName.isNotEmpty ? _currentDishName : 'Meal Session',
          startTime: DateTime.now().subtract(const Duration(minutes: 25)),
          endTime: DateTime.now(),
          initialWeightG: initialW,
          consumedWeightG: consumedW,
          remainingWeightG: remainingWeightG,
          wasteScore: wasteScore,
          totalCalories: totalCalories,
          wastePercentage: wastePct,
          status: 'completed',
          weightSource: _weightSource,
          tareWeightG: _weightSource == 'device' ? _tareWeightG : 0.0,
          imageUrl: _uploadedImageUrl,
          components: List.from(_detectedComponents),
          aiObservation: _isBleTestProfile ? 'ESP32-C3 Test Profile — Simulated Measurement' : '',
        );

    _lastSavedMeal = record;
    _meals.insert(0, record);
    if (saved != null) {
      // Reload analytics to reflect the newly persisted meal
      await _loadAnalytics();
      await _loadInsights();
    }

    _isLoading = false;
    notifyListeners();
    return record;
  }

  double get totalFoodPortionG {
    if (_detectedComponents.isEmpty) {
      return _weightSource == 'manual'
          ? _currentWeightG
          : (_currentWeightG - _tareWeightG).clamp(0.0, 2500.0);
    }
    return _detectedComponents.fold(0.0, (sum, item) => sum + item.weightG);
  }

  Future<void> tarePad() async {
    await apiService.tarePad();
    if (_weightSource == 'device') {
      _currentWeightG = 0.0;
    }
    notifyListeners();
  }

  Future<void> reconnectBLE() async {
    _isLoading = true;
    notifyListeners();
    await apiService.connectDevice();
    await _loadPadStatus();
    _isLoading = false;
    notifyListeners();
  }

  Future<void> disconnectPad() async {
    await apiService.disconnectDevice();
    await _loadPadStatus();
    _weightSource = 'manual';
    notifyListeners();
  }

  Future<ActiveMealSession> startMealMeasurementSession({
    String? mealName,
    XFile? startPhoto,
    String imageSource = 'app_camera',
    String? deviceId,
    bool? isCalibrated,
  }) async {
    _isLoading = true;
    notifyListeners();

    try {
      String? uploadedUrl;
      if (startPhoto != null) {
        _isPhotoUploading = true;
        notifyListeners();
        try {
          final uploadRes = await apiService.uploadMealImage(startPhoto);
          uploadedUrl = uploadRes['image_url'] as String?;
          _uploadedImageUrl = uploadedUrl;
          final normalizedB64 = uploadRes['normalized_base64'] as String?;
          if (normalizedB64 != null && normalizedB64.isNotEmpty) {
            try {
              _selectedMealPhotoBytes = base64Decode(normalizedB64);
            } catch (_) {}
          }
        } catch (e) {
          _photoError = e.toString().replaceFirst('Exception: ', '');
        } finally {
          _isPhotoUploading = false;
        }
      }

      final startGross = (smoothedWeightG > 0 ? smoothedWeightG : _currentWeightG).clamp(0.0, 5000.0);
      double? startFood;
      if (_setupPlateWeightG != null && _setupPlateWeightMode != 'none') {
        startFood = (startGross - _setupPlateWeightG!).clamp(0.0, double.infinity);
        startFood = (startFood * 10).round() / 10.0;
      }

      final session = ActiveMealSession(
        sessionId: 'session_${DateTime.now().millisecondsSinceEpoch}',
        startTime: DateTime.now(),
        mealName: mealName ?? (_currentDishName.isNotEmpty ? _currentDishName : 'Meal Session'),
        plateWeightG: _setupPlateWeightG,
        plateWeightMode: _setupPlateWeightMode,
        startGrossWeightG: (startGross * 10).round() / 10.0,
        startFoodWeightG: startFood,
        startImageUrl: uploadedUrl ?? _uploadedImageUrl,
        startImageSource: imageSource,
        deviceId: deviceId ?? _padStatus.deviceId,
        isCalibrated: isCalibrated ?? true,
        recentWeightSamples: List.from(_smoothingBuffer),
        readingsHistory: [
          {
            'timestamp': DateTime.now().toIso8601String(),
            'gross_weight_g': (startGross * 10).round() / 10.0,
            'stable': isWeightStable,
          }
        ],
      );

      _activeSession = session;
      await _persistActiveSession();

      // Reset setup variables for next session
      _setupPlateWeightG = null;
      _setupPlateWeightMode = 'none';

      return session;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<MealRecord?> finalizeMealMeasurementSession({
    XFile? endPhoto,
    String imageSource = 'app_camera',
  }) async {
    if (_activeSession == null) return null;
    _isLoading = true;
    notifyListeners();

    try {
      String? endUploadedUrl;
      if (endPhoto != null) {
        _isPhotoUploading = true;
        notifyListeners();
        try {
          final uploadRes = await apiService.uploadMealImage(endPhoto);
          endUploadedUrl = uploadRes['image_url'] as String?;
        } catch (e) {
          _photoError = e.toString().replaceFirst('Exception: ', '');
        } finally {
          _isPhotoUploading = false;
        }
      }

      final endGross = (smoothedWeightG > 0 ? smoothedWeightG : _currentWeightG).clamp(0.0, 5000.0);
      final startGross = _activeSession!.startGrossWeightG ?? endGross;
      final plateWeight = _activeSession!.plateWeightG;
      final plateMode = _activeSession!.plateWeightMode;

      double? endFood;
      if (plateWeight != null && plateMode != 'none') {
        endFood = (endGross - plateWeight).clamp(0.0, double.infinity);
        endFood = (endFood * 10).round() / 10.0;
      }

      final startFood = _activeSession!.startFoodWeightG;

      // Calculate food weight reduction and detect unexpected weight increase
      double weightReduction;
      bool isIncrease = false;

      if (startFood != null && endFood != null) {
        if (endFood > startFood + 1.0) {
          isIncrease = true;
          weightReduction = 0.0;
        } else {
          weightReduction = (startFood - endFood).clamp(0.0, double.infinity);
        }
      } else {
        if (endGross > startGross + 1.0) {
          isIncrease = true;
          weightReduction = 0.0;
        } else {
          weightReduction = (startGross - endGross).clamp(0.0, double.infinity);
        }
      }
      weightReduction = (weightReduction * 10).round() / 10.0;

      _activeSession!.endGrossWeightG = (endGross * 10).round() / 10.0;
      _activeSession!.endFoodWeightG = endFood;
      _activeSession!.weightReductionG = weightReduction;
      _activeSession!.isFlaggedIncrease = isIncrease;
      _activeSession!.endImageUrl = endUploadedUrl;
      _activeSession!.endImageSource = imageSource;
      _activeSession!.isCompleted = true;

      // Persist to backend API
      final saved = await apiService.recordMealSession(
        mealName: _activeSession!.mealName,
        initialWeightG: startGross,
        remainingWeightG: endGross,
        weightSource: _weightSource,
        tareWeightG: plateWeight ?? 0.0,
        imageUrl: _activeSession!.startImageUrl,
        components: _detectedComponents,
        startGrossWeightG: startGross,
        endGrossWeightG: endGross,
        plateWeightG: plateWeight,
        plateWeightMode: plateMode,
        startFoodWeightG: startFood,
        endFoodWeightG: endFood,
        weightReductionG: weightReduction,
        startImageUrl: _activeSession!.startImageUrl,
        endImageUrl: endUploadedUrl,
        startImageSource: _activeSession!.startImageSource,
        endImageSource: imageSource,
        deviceId: _activeSession!.deviceId,
        isCalibrated: _activeSession!.isCalibrated,
        isFlaggedIncrease: isIncrease,
        readingsHistory: jsonEncode(_activeSession!.readingsHistory),
      );

      final initialW = startFood ?? startGross;
      final remainingW = endFood ?? endGross;
      final wastePct = initialW > 0 ? (remainingW / initialW * 100.0).clamp(0.0, 100.0) : 0.0;
      final wasteScore = (100.0 - wastePct * 1.5).round().clamp(0, 100);

      final record = saved ??
          MealRecord(
            id: 'local_${DateTime.now().millisecondsSinceEpoch}',
            mealName: _activeSession!.mealName,
            startTime: _activeSession!.startTime,
            endTime: DateTime.now(),
            initialWeightG: initialW,
            consumedWeightG: weightReduction,
            remainingWeightG: remainingW,
            wasteScore: wasteScore,
            totalCalories: totalCalories,
            wastePercentage: wastePct,
            status: 'completed',
            weightSource: _weightSource,
            tareWeightG: plateWeight ?? 0.0,
            imageUrl: _activeSession!.startImageUrl,
            components: List.from(_detectedComponents),
            startGrossWeightG: startGross,
            endGrossWeightG: endGross,
            plateWeightG: plateWeight,
            plateWeightMode: plateMode,
            startFoodWeightG: startFood,
            endFoodWeightG: endFood,
            weightReductionG: weightReduction,
            startImageUrl: _activeSession!.startImageUrl,
            endImageUrl: endUploadedUrl,
            startImageSource: _activeSession!.startImageSource,
            endImageSource: imageSource,
            deviceId: _activeSession!.deviceId,
            isCalibrated: _activeSession!.isCalibrated,
            isFlaggedIncrease: isIncrease,
            readingsHistory: jsonEncode(_activeSession!.readingsHistory),
          );

      _lastSavedMeal = record;
      _meals.insert(0, record);

      await _clearPersistedActiveSession();
      _activeSession = null;

      if (saved != null) {
        await _loadAnalytics();
        await _loadInsights();
      }

      return record;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> cancelActiveMealSession() async {
    _activeSession = null;
    await _clearPersistedActiveSession();
    notifyListeners();
  }

  Future<void> advanceCalibration(int step) async {
    _calibrationState = await apiService.advanceCalibrationStep(step);
    notifyListeners();
  }
}
