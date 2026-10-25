class UserModel {
  final String id;
  final String email;
  final String fullName;

  UserModel({
    required this.id,
    required this.email,
    required this.fullName,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] as String? ?? json['user_id'] as String? ?? '',
      email: json['email'] as String? ?? '',
      fullName: json['full_name'] as String? ?? 'Dining User',
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'email': email,
    'full_name': fullName,
  };
}

class FoodComponentItem {
  final String name;
  double weightG;
  final double confidence;
  int caloriesKcal;
  double proteinG;
  double carbsG;
  double fatG;
  double fiberG;
  double sodiumMg;
  double portionRatio;
  int uncertaintyMinKcal;
  int uncertaintyMaxKcal;
  String preparationStyle;
  final String iconName;

  FoodComponentItem({
    required this.name,
    required this.weightG,
    required this.confidence,
    required this.caloriesKcal,
    required this.proteinG,
    required this.carbsG,
    required this.fatG,
    this.fiberG = 0.0,
    this.sodiumMg = 0.0,
    this.portionRatio = 0.0,
    this.uncertaintyMinKcal = 0,
    this.uncertaintyMaxKcal = 0,
    this.preparationStyle = 'Cooked',
    this.iconName = 'restaurant',
  });

  factory FoodComponentItem.fromJson(Map<String, dynamic> json) {
    return FoodComponentItem(
      name: json['name'] as String? ?? 'Food Item',
      weightG: (json['weight_g'] as num?)?.toDouble() ?? 0.0,
      confidence: (json['confidence'] as num?)?.toDouble() ?? 0.9,
      caloriesKcal: (json['calories_kcal'] as num?)?.toInt() ?? 0,
      proteinG: (json['protein_g'] as num?)?.toDouble() ?? 0.0,
      carbsG: (json['carbs_g'] as num?)?.toDouble() ?? 0.0,
      fatG: (json['fat_g'] as num?)?.toDouble() ?? 0.0,
      fiberG: (json['fiber_g'] as num?)?.toDouble() ?? 0.0,
      sodiumMg: (json['sodium_mg'] as num?)?.toDouble() ?? 0.0,
      portionRatio: (json['portion_ratio'] as num?)?.toDouble() ?? 0.0,
      uncertaintyMinKcal: (json['uncertainty_min_kcal'] as num?)?.toInt() ?? 0,
      uncertaintyMaxKcal: (json['uncertainty_max_kcal'] as num?)?.toInt() ?? 0,
      preparationStyle: json['preparation_style'] as String? ?? 'Cooked',
      iconName: json['icon_name'] as String? ?? 'restaurant',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'weight_g': weightG,
      'confidence': confidence,
      'calories_kcal': caloriesKcal,
      'protein_g': proteinG,
      'carbs_g': carbsG,
      'fat_g': fatG,
      'fiber_g': fiberG,
      'sodium_mg': sodiumMg,
      'portion_ratio': portionRatio,
      'uncertainty_min_kcal': uncertaintyMinKcal,
      'uncertainty_max_kcal': uncertaintyMaxKcal,
      'preparation_style': preparationStyle,
      'icon_name': iconName,
    };
  }
}

class NutritionTotals {
  final int totalCalories;
  final double totalProteinG;
  final double totalCarbsG;
  final double totalFatG;
  final double totalFiberG;
  final double totalSodiumMg;

  NutritionTotals({
    required this.totalCalories,
    required this.totalProteinG,
    required this.totalCarbsG,
    required this.totalFatG,
    required this.totalFiberG,
    required this.totalSodiumMg,
  });

  factory NutritionTotals.fromJson(Map<String, dynamic> json) {
    return NutritionTotals(
      totalCalories: (json['total_calories'] as num?)?.toInt() ?? 0,
      totalProteinG: (json['total_protein_g'] as num?)?.toDouble() ?? 0.0,
      totalCarbsG: (json['total_carbs_g'] as num?)?.toDouble() ?? 0.0,
      totalFatG: (json['total_fat_g'] as num?)?.toDouble() ?? 0.0,
      totalFiberG: (json['total_fiber_g'] as num?)?.toDouble() ?? 0.0,
      totalSodiumMg: (json['total_sodium_mg'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class CategoryLeftoverItem {
  final String category;
  final double weightG;
  final double percentage;

  CategoryLeftoverItem({
    required this.category,
    required this.weightG,
    required this.percentage,
  });

  factory CategoryLeftoverItem.fromJson(Map<String, dynamic> json) {
    return CategoryLeftoverItem(
      category: json['category'] as String? ?? '',
      weightG: (json['weight_g'] as num?)?.toDouble() ?? 0.0,
      percentage: (json['percentage'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class MealRecord {
  final String id;
  final String mealName;
  final DateTime startTime;
  final DateTime endTime;
  final double initialWeightG;
  final double consumedWeightG;
  final double remainingWeightG;
  final int wasteScore;
  final int totalCalories;
  final double wastePercentage;
  final String status;
  final String weightSource;
  final double tareWeightG;
  final String? imageUrl;
  final List<FoodComponentItem> components;
  final NutritionTotals? nutrition;
  final List<CategoryLeftoverItem> leftovers;
  final String aiObservation;

  // Extended Meal Measurement Workflow fields
  final double? startGrossWeightG;
  final double? endGrossWeightG;
  final double? plateWeightG;
  final String plateWeightMode; // 'measured', 'manual', 'none'
  final double? startFoodWeightG;
  final double? endFoodWeightG;
  final double? weightReductionG;
  final String? startImageUrl;
  final String? endImageUrl;
  final String startImageSource;
  final String endImageSource;
  final String? deviceId;
  final bool isCalibrated;
  final bool isFlaggedIncrease;
  final String? readingsHistory;

  MealRecord({
    required this.id,
    required this.mealName,
    required this.startTime,
    required this.endTime,
    required this.initialWeightG,
    required this.consumedWeightG,
    required this.remainingWeightG,
    required this.wasteScore,
    required this.totalCalories,
    required this.wastePercentage,
    required this.status,
    this.weightSource = 'device',
    this.tareWeightG = 0.0,
    this.imageUrl,
    this.components = const [],
    this.nutrition,
    this.leftovers = const [],
    this.aiObservation = '',
    this.startGrossWeightG,
    this.endGrossWeightG,
    this.plateWeightG,
    this.plateWeightMode = 'none',
    this.startFoodWeightG,
    this.endFoodWeightG,
    this.weightReductionG,
    this.startImageUrl,
    this.endImageUrl,
    this.startImageSource = 'app_camera',
    this.endImageSource = 'app_camera',
    this.deviceId,
    this.isCalibrated = true,
    this.isFlaggedIncrease = false,
    this.readingsHistory,
  });

  factory MealRecord.fromJson(Map<String, dynamic> json) {
    var rawComps = json['components'] as List<dynamic>? ?? [];
    var rawLeftovers = json['leftovers'] as List<dynamic>? ?? [];
    
    return MealRecord(
      id: json['id'] as String? ?? '',
      mealName: json['meal_name'] as String? ?? 'Meal',
      startTime: DateTime.tryParse(json['start_time'] as String? ?? '') ?? DateTime.now(),
      endTime: DateTime.tryParse(json['end_time'] as String? ?? '') ?? DateTime.now(),
      initialWeightG: (json['initial_weight_g'] as num?)?.toDouble() ?? 0.0,
      consumedWeightG: (json['consumed_weight_g'] as num?)?.toDouble() ?? 0.0,
      remainingWeightG: (json['remaining_weight_g'] as num?)?.toDouble() ?? 0.0,
      wasteScore: (json['waste_score'] as num?)?.toInt() ?? 0,
      totalCalories: (json['total_calories'] as num?)?.toInt() ?? 0,
      wastePercentage: (json['waste_percentage'] as num?)?.toDouble() ?? 0.0,
      status: json['status'] as String? ?? 'completed',
      weightSource: json['weight_source'] as String? ?? 'device',
      tareWeightG: (json['tare_weight_g'] as num?)?.toDouble() ?? 0.0,
      imageUrl: json['image_url'] as String?,
      components: rawComps.map((e) => FoodComponentItem.fromJson(e as Map<String, dynamic>)).toList(),
      nutrition: json['nutrition'] != null ? NutritionTotals.fromJson(json['nutrition'] as Map<String, dynamic>) : null,
      leftovers: rawLeftovers.map((e) => CategoryLeftoverItem.fromJson(e as Map<String, dynamic>)).toList(),
      aiObservation: json['ai_observation'] as String? ?? '',
      startGrossWeightG: (json['start_gross_weight_g'] as num?)?.toDouble(),
      endGrossWeightG: (json['end_gross_weight_g'] as num?)?.toDouble(),
      plateWeightG: (json['plate_weight_g'] as num?)?.toDouble(),
      plateWeightMode: json['plate_weight_mode'] as String? ?? 'none',
      startFoodWeightG: (json['start_food_weight_g'] as num?)?.toDouble(),
      endFoodWeightG: (json['end_food_weight_g'] as num?)?.toDouble(),
      weightReductionG: (json['weight_reduction_g'] as num?)?.toDouble(),
      startImageUrl: json['start_image_url'] as String? ?? json['image_url'] as String?,
      endImageUrl: json['end_image_url'] as String?,
      startImageSource: json['start_image_source'] as String? ?? 'app_camera',
      endImageSource: json['end_image_source'] as String? ?? 'app_camera',
      deviceId: json['device_id'] as String?,
      isCalibrated: json['is_calibrated'] as bool? ?? true,
      isFlaggedIncrease: json['is_flagged_increase'] as bool? ?? false,
      readingsHistory: json['readings_history'] as String?,
    );
  }
}

/// Represents an ongoing live meal measurement session with local persistence capability
class ActiveMealSession {
  final String sessionId;
  final DateTime startTime;
  String mealName;
  double? plateWeightG;
  String plateWeightMode; // 'measured', 'manual', 'none'
  double? startGrossWeightG;
  double? startFoodWeightG;
  String? startImageUrl;
  String startImageSource;
  String? endImageUrl;
  String endImageSource;
  double? endGrossWeightG;
  double? endFoodWeightG;
  double? weightReductionG;
  bool isFlaggedIncrease;
  String? deviceId;
  bool isCalibrated;
  List<double> recentWeightSamples;
  List<Map<String, dynamic>> readingsHistory;
  bool isCompleted;

  ActiveMealSession({
    required this.sessionId,
    required this.startTime,
    this.mealName = 'Meal Session',
    this.plateWeightG,
    this.plateWeightMode = 'none',
    this.startGrossWeightG,
    this.startFoodWeightG,
    this.startImageUrl,
    this.startImageSource = 'app_camera',
    this.endImageUrl,
    this.endImageSource = 'app_camera',
    this.endGrossWeightG,
    this.endFoodWeightG,
    this.weightReductionG,
    this.isFlaggedIncrease = false,
    this.deviceId,
    this.isCalibrated = true,
    List<double>? recentWeightSamples,
    List<Map<String, dynamic>>? readingsHistory,
    this.isCompleted = false,
  })  : recentWeightSamples = recentWeightSamples ?? [],
        readingsHistory = readingsHistory ?? [];

  Map<String, dynamic> toJson() => {
        'session_id': sessionId,
        'start_time': startTime.toIso8601String(),
        'meal_name': mealName,
        'plate_weight_g': plateWeightG,
        'plate_weight_mode': plateWeightMode,
        'start_gross_weight_g': startGrossWeightG,
        'start_food_weight_g': startFoodWeightG,
        'start_image_url': startImageUrl,
        'start_image_source': startImageSource,
        'end_image_url': endImageUrl,
        'end_image_source': endImageSource,
        'end_gross_weight_g': endGrossWeightG,
        'end_food_weight_g': endFoodWeightG,
        'weight_reduction_g': weightReductionG,
        'is_flagged_increase': isFlaggedIncrease,
        'device_id': deviceId,
        'is_calibrated': isCalibrated,
        'recent_samples': recentWeightSamples,
        'readings_history': readingsHistory,
        'is_completed': isCompleted,
      };

  factory ActiveMealSession.fromJson(Map<String, dynamic> json) {
    return ActiveMealSession(
      sessionId: json['session_id'] as String? ?? '',
      startTime: DateTime.tryParse(json['start_time'] as String? ?? '') ?? DateTime.now(),
      mealName: json['meal_name'] as String? ?? 'Meal Session',
      plateWeightG: (json['plate_weight_g'] as num?)?.toDouble(),
      plateWeightMode: json['plate_weight_mode'] as String? ?? 'none',
      startGrossWeightG: (json['start_gross_weight_g'] as num?)?.toDouble(),
      startFoodWeightG: (json['start_food_weight_g'] as num?)?.toDouble(),
      startImageUrl: json['start_image_url'] as String?,
      startImageSource: json['start_image_source'] as String? ?? 'app_camera',
      endImageUrl: json['end_image_url'] as String?,
      endImageSource: json['end_image_source'] as String? ?? 'app_camera',
      endGrossWeightG: (json['end_gross_weight_g'] as num?)?.toDouble(),
      endFoodWeightG: (json['end_food_weight_g'] as num?)?.toDouble(),
      weightReductionG: (json['weight_reduction_g'] as num?)?.toDouble(),
      isFlaggedIncrease: json['is_flagged_increase'] as bool? ?? false,
      deviceId: json['device_id'] as String?,
      isCalibrated: json['is_calibrated'] as bool? ?? true,
      recentWeightSamples: (json['recent_samples'] as List<dynamic>?)
              ?.map((e) => (e as num).toDouble())
              .toList() ??
          [],
      readingsHistory: (json['readings_history'] as List<dynamic>?)
              ?.map((e) => Map<String, dynamic>.from(e as Map))
              .toList() ??
          [],
      isCompleted: json['is_completed'] as bool? ?? false,
    );
  }
}

class PadStatus {
  final String deviceId;
  final int batteryPercent;
  final String loadSensorStatus;
  final String cameraStatus;
  final bool isConnected;
  final double baselineTareG;

  PadStatus({
    required this.deviceId,
    required this.batteryPercent,
    required this.loadSensorStatus,
    required this.cameraStatus,
    required this.isConnected,
    required this.baselineTareG,
  });

  factory PadStatus.fromJson(Map<String, dynamic> json) {
    return PadStatus(
      deviceId: json['device_id'] as String? ?? 'DINIECO-PAD-001',
      batteryPercent: (json['battery_percent'] as num?)?.toInt() ?? 0,
      loadSensorStatus: json['load_sensor_status'] as String? ?? 'Offline',
      cameraStatus: json['camera_status'] as String? ?? 'Offline',
      isConnected: json['is_connected'] as bool? ?? false,
      baselineTareG: (json['baseline_tare_g'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class CalibrationState {
  final int currentStep;
  final int totalSteps;
  final String stepDescription;
  final double progressPercentage;
  final bool isComplete;

  CalibrationState({
    required this.currentStep,
    required this.totalSteps,
    required this.stepDescription,
    required this.progressPercentage,
    required this.isComplete,
  });

  factory CalibrationState.fromJson(Map<String, dynamic> json) {
    return CalibrationState(
      currentStep: (json['current_step'] as num?)?.toInt() ?? 1,
      totalSteps: (json['total_steps'] as num?)?.toInt() ?? 4,
      stepDescription: json['step_description'] as String? ?? '',
      progressPercentage: (json['progress_percentage'] as num?)?.toDouble() ?? 0.0,
      isComplete: json['is_complete'] as bool? ?? false,
    );
  }
}
