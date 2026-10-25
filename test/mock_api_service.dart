import 'package:image_picker/image_picker.dart';
import 'package:dinieco/models/models.dart';
import 'package:dinieco/services/api_service.dart';

class MockApiService extends ApiService {
  MockApiService() : super(baseUrl: 'http://mock');

  @override
  Future<PadStatus> getDeviceStatus() async {
    return PadStatus(
      deviceId: 'DINIECO-PAD-001',
      batteryPercent: 92,
      loadSensorStatus: 'Active (HX711 24-bit)',
      cameraStatus: 'Connected (OV2640)',
      isConnected: true,
      baselineTareG: 0.0,
    );
  }

  @override
  Future<double> getWeightReading() async => 486.0;

  @override
  Future<bool> tarePad() async => true;

  @override
  Future<bool> connectDevice() async => true;

  @override
  Future<bool> disconnectDevice() async => true;

  @override
  Future<CalibrationState> getCalibrationStatus() async {
    return CalibrationState(
      currentStep: 1,
      totalSteps: 4,
      stepDescription: 'Load sensor calibration',
      progressPercentage: 25.0,
      isComplete: false,
    );
  }

  @override
  Future<CalibrationState> advanceCalibrationStep(int step) async {
    return CalibrationState(
      currentStep: step,
      totalSteps: 4,
      stepDescription: 'Step $step completed',
      progressPercentage: (step / 4.0) * 100.0,
      isComplete: step >= 4,
    );
  }

  @override
  Future<List<MealRecord>> getRecentMeals() async => [];

  @override
  Future<Map<String, dynamic>> getAnalyticsSummary() async => {
        'total_meals': 0,
        'avg_waste_pct': 0.0,
        'total_waste_g': 0.0,
        'total_calories': 0,
        'avg_waste_score': 0,
        'daily_breakdown': [],
      };

  @override
  Future<List<Map<String, dynamic>>> getAiInsights() async => [];

  @override
  Future<Map<String, dynamic>> analyzeFoodVision({
    required double padWeight,
    String weightSource = 'device',
    double tareWeightG = 0.0,
    String? dishHint,
    String? imageBase64,
  }) async {
    return {
      'dish_name': dishHint ?? 'Vegetable Rice Bowl',
      'confidence': 0.94,
      'total_weight_g': padWeight > 0 ? padWeight : 486.0,
      'net_food_weight_g': padWeight > 0 ? padWeight : 486.0,
      'weight_source': weightSource,
      'ai_model': 'gemini-2.5-flash',
      'ai_verified': true,
      'is_stabilized': true,
      'total_calories': 637,
      'total_protein_g': 27.8,
      'total_carbs_g': 90.9,
      'total_fat_g': 17.7,
      'components': [
        FoodComponentItem(name: 'Steamed Basmati Rice', weightG: 180.0, confidence: 0.92, caloriesKcal: 234, proteinG: 4.8, carbsG: 50.8, fatG: 0.5),
        FoodComponentItem(name: 'Yellow Dal Tadka', weightG: 150.0, confidence: 0.88, caloriesKcal: 188, proteinG: 10.2, carbsG: 27.0, fatG: 4.4),
        FoodComponentItem(name: 'Sauteed Vegetables', weightG: 100.0, confidence: 0.85, caloriesKcal: 65, proteinG: 2.6, carbsG: 11.2, fatG: 1.2),
        FoodComponentItem(name: 'Paneer Cubes', weightG: 56.0, confidence: 0.80, caloriesKcal: 150, proteinG: 10.2, carbsG: 1.9, fatG: 11.6),
      ],
    };
  }

  @override
  Future<Map<String, dynamic>> uploadMealImage(XFile imageFile) async {
    return {
      'image_id': 'mock-image-123',
      'filename': 'mock_upload.jpg',
      'image_url': '/uploads/mock_upload.jpg',
      'format': 'JPEG',
      'width': 800,
      'height': 600,
      'file_size_bytes': 1024,
      'content_type': 'image/jpeg',
    };
  }

  @override
  Future<MealRecord?> recordMealSession({
    required String mealName,
    required double initialWeightG,
    required double remainingWeightG,
    required List<FoodComponentItem> components,
    String weightSource = 'device',
    double tareWeightG = 0.0,
    String? imageUrl,
    double? startGrossWeightG,
    double? endGrossWeightG,
    double? plateWeightG,
    String plateWeightMode = 'none',
    double? startFoodWeightG,
    double? endFoodWeightG,
    double? weightReductionG,
    String? startImageUrl,
    String? endImageUrl,
    String startImageSource = 'app_camera',
    String endImageSource = 'app_camera',
    String? deviceId,
    bool isCalibrated = true,
    bool isFlaggedIncrease = false,
    String? readingsHistory,
  }) async {
    final initialW = initialWeightG > 0 ? initialWeightG : 486.0;
    final consumedW = (initialW - remainingWeightG).clamp(0.0, initialW);
    final wastePct = initialW > 0 ? (remainingWeightG / initialW * 100.0).clamp(0.0, 100.0) : 0.0;
    final wasteScore = (100.0 - wastePct * 1.5).round().clamp(0, 100);

    return MealRecord(
      id: 'mock_session_${DateTime.now().millisecondsSinceEpoch}',
      mealName: mealName,
      startTime: DateTime.now().subtract(const Duration(minutes: 25)),
      endTime: DateTime.now(),
      initialWeightG: initialW,
      consumedWeightG: consumedW,
      remainingWeightG: remainingWeightG,
      wasteScore: wasteScore,
      totalCalories: components.fold(0, (sum, c) => sum + c.caloriesKcal),
      wastePercentage: wastePct,
      status: 'completed',
      weightSource: weightSource,
      tareWeightG: tareWeightG,
      imageUrl: imageUrl ?? startImageUrl,
      components: List.from(components),
      startGrossWeightG: startGrossWeightG ?? initialW,
      endGrossWeightG: endGrossWeightG ?? remainingWeightG,
      plateWeightG: plateWeightG,
      plateWeightMode: plateWeightMode,
      startFoodWeightG: startFoodWeightG ?? initialW,
      endFoodWeightG: endFoodWeightG ?? remainingWeightG,
      weightReductionG: weightReductionG ?? consumedW,
      startImageUrl: startImageUrl ?? imageUrl,
      endImageUrl: endImageUrl,
      startImageSource: startImageSource,
      endImageSource: endImageSource,
      deviceId: deviceId,
      isCalibrated: isCalibrated,
      isFlaggedIncrease: isFlaggedIncrease,
      readingsHistory: readingsHistory,
    );
  }
}
