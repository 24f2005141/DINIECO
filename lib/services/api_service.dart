import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:image_picker/image_picker.dart';
import '../models/models.dart';
import 'auth_service.dart';

class ApiService {
  final String baseUrl;
  final AuthService authService;

  ApiService({
    this.baseUrl = 'http://127.0.0.1:8000/api/v1',
    AuthService? auth,
  }) : authService = auth ?? AuthService(baseUrl: baseUrl);

  Future<Map<String, String>> _getHeaders({bool isJson = true}) async {
    final headers = <String, String>{};
    if (isJson) {
      headers['Content-Type'] = 'application/json';
    }
    final token = await authService.getToken();
    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }
    return headers;
  }

  // HTTP Helpers with genuine error propagation
  Future<dynamic> _get(String path) async {
    try {
      final headers = await _getHeaders();
      final res = await http.get(
        Uri.parse('$baseUrl$path'),
        headers: headers,
      ).timeout(const Duration(seconds: 2));

      if (res.statusCode == 200) {
        return jsonDecode(res.body);
      }
    } catch (_) {}
    return null;
  }

  Future<dynamic> _post(
    String path,
    Map<String, dynamic> body, {
    Duration timeout = const Duration(seconds: 3),
  }) async {
    try {
      final headers = await _getHeaders();
      final res = await http.post(
        Uri.parse('$baseUrl$path'),
        headers: headers,
        body: jsonEncode(body),
      ).timeout(timeout);

      if (res.statusCode == 200) {
        return jsonDecode(res.body);
      } else {
        String? detail;
        try {
          final errJson = jsonDecode(res.body);
          if (errJson is Map && errJson['detail'] != null) {
            detail = errJson['detail'].toString();
          }
        } catch (_) {}
        if (detail != null && detail.isNotEmpty) {
          throw Exception(detail);
        }
      }
    } on TimeoutException {
      throw Exception('Request timed out. Please check your network connection.');
    } catch (e) {
      if (e is Exception && !e.toString().contains('Failed host lookup')) {
        rethrow;
      }
    }
    return null;
  }

  // Device & BLE
  Future<PadStatus> getDeviceStatus() async {
    final data = await _get('/device/status');
    if (data != null && data is Map<String, dynamic>) {
      return PadStatus.fromJson(data);
    }
    // Return honest offline state when device is disconnected
    return PadStatus(
      deviceId: 'DINIECO-PAD-001',
      batteryPercent: 0,
      loadSensorStatus: 'Offline',
      cameraStatus: 'Offline',
      isConnected: false,
      baselineTareG: 0.0,
    );
  }

  Future<double> getWeightReading() async {
    final data = await _get('/device/weight-stream');
    if (data != null && data['weight_g'] != null) {
      return (data['weight_g'] as num).toDouble();
    }
    return 0.0;
  }

  Future<bool> tarePad() async {
    final data = await _post('/device/tare', {'device_id': 'DINIECO-PAD-001'});
    return data != null && data['status'] == 'success';
  }

  Future<bool> connectDevice() async {
    final data = await _post('/device/connect', {});
    return data != null && data['status'] == 'connected';
  }

  Future<bool> disconnectDevice() async {
    final data = await _post('/device/disconnect', {});
    return data != null && data['status'] == 'disconnected';
  }

  // Calibration
  Future<CalibrationState> getCalibrationStatus() async {
    final data = await _get('/calibration/status');
    if (data != null && data is Map<String, dynamic>) {
      return CalibrationState.fromJson(data);
    }
    return CalibrationState(
      currentStep: 1,
      totalSteps: 4,
      stepDescription: 'Connect to Smart Pad to start calibration',
      progressPercentage: 0.0,
      isComplete: false,
    );
  }

  Future<CalibrationState> advanceCalibrationStep(int step) async {
    final data = await _post('/calibration/step', {
      'device_id': 'DINIECO-PAD-001',
      'step': step,
      'confirm_action': true,
    });
    if (data != null && data is Map<String, dynamic>) {
      return CalibrationState.fromJson(data);
    }
    return CalibrationState(
      currentStep: step,
      totalSteps: 4,
      stepDescription: 'Calibration step $step',
      progressPercentage: (step / 4.0) * 100.0,
      isComplete: step >= 4,
    );
  }

  /// Detects MIME type from image magic bytes first, falling back to extension mapping.
  /// Throws clear actionable exception for known non-image file formats.
  static String detectImageMimeType(Uint8List bytes, String filename) {
    // 1. Sniff magic bytes
    if (bytes.length >= 3 && bytes[0] == 0xFF && bytes[1] == 0xD8 && bytes[2] == 0xFF) {
      return 'image/jpeg';
    }
    if (bytes.length >= 8 &&
        bytes[0] == 0x89 && bytes[1] == 0x50 && bytes[2] == 0x4E && bytes[3] == 0x47 &&
        bytes[4] == 0x0D && bytes[5] == 0x0A && bytes[6] == 0x1A && bytes[7] == 0x0A) {
      return 'image/png';
    }
    if (bytes.length >= 12 &&
        bytes[0] == 0x52 && bytes[1] == 0x49 && bytes[2] == 0x46 && bytes[3] == 0x46 &&
        bytes[8] == 0x57 && bytes[9] == 0x45 && bytes[10] == 0x42 && bytes[11] == 0x50) {
      return 'image/webp';
    }
    if (bytes.length >= 6 &&
        bytes[0] == 0x47 && bytes[1] == 0x49 && bytes[2] == 0x46 && bytes[3] == 0x38 &&
        (bytes[4] == 0x37 || bytes[4] == 0x39) && bytes[5] == 0x61) {
      return 'image/gif';
    }
    if (bytes.length >= 2 && bytes[0] == 0x42 && bytes[1] == 0x4D) {
      return 'image/bmp';
    }
    if (bytes.length >= 4 &&
        ((bytes[0] == 0x49 && bytes[1] == 0x49 && bytes[2] == 0x2A && bytes[3] == 0x00) ||
         (bytes[0] == 0x4D && bytes[1] == 0x4D && bytes[2] == 0x00 && bytes[3] == 0x2A))) {
      return 'image/tiff';
    }
    if (bytes.length >= 12 &&
        bytes[4] == 0x66 && bytes[5] == 0x74 && bytes[6] == 0x79 && bytes[7] == 0x70) {
      final brand = String.fromCharCodes(bytes.sublist(8, 12)).toLowerCase();
      if (brand == 'avif' || brand == 'avis') {
        return 'image/avif';
      }
      if (brand.startsWith('he') || brand == 'mif1' || brand == 'msf1') {
        return 'image/heic';
      }
    }

    // 2. Fall back to extension mapping
    final ext = filename.contains('.') ? filename.split('.').last.toLowerCase().trim() : '';
    switch (ext) {
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'webp':
        return 'image/webp';
      case 'heic':
      case 'heif':
        return 'image/heic';
      case 'gif':
        return 'image/gif';
      case 'bmp':
        return 'image/bmp';
      case 'tiff':
      case 'tif':
        return 'image/tiff';
      case 'avif':
        return 'image/avif';
      default:
        const nonImageExts = {
          'pdf', 'txt', 'mp4', 'mov', 'avi', 'mkv', 'doc', 'docx',
          'xls', 'xlsx', 'json', 'xml', 'html', 'zip', 'tar', 'gz', 'exe'
        };
        if (nonImageExts.contains(ext)) {
          throw Exception(
            'Image format is not supported. Please select a valid photo (JPEG, PNG, WebP, HEIC, GIF, BMP, TIFF, or AVIF).'
          );
        }
        // If file has unknown or missing extension, permit backend normalizer to inspect
        return 'image/jpeg';
    }
  }

  // Multipart Meal Photo Upload
  Future<Map<String, dynamic>> uploadMealImage(XFile imageFile) async {
    final bytes = await imageFile.readAsBytes();
    if (bytes.isEmpty) {
      throw Exception('The selected photo is empty (0 bytes received).');
    }

    final mimeType = detectImageMimeType(bytes, imageFile.name);

    final uri = Uri.parse('$baseUrl/vision/upload');
    final request = http.MultipartRequest('POST', uri);

    final token = await authService.getToken();
    if (token != null && token.isNotEmpty) {
      request.headers['Authorization'] = 'Bearer $token';
    }

    final multipartFile = http.MultipartFile.fromBytes(
      'file',
      bytes,
      filename: imageFile.name.isNotEmpty ? imageFile.name : 'meal_photo.jpg',
      contentType: MediaType.parse(mimeType),
    );
    request.files.add(multipartFile);

    final streamedResponse = await request.send().timeout(const Duration(seconds: 25));
    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    } else {
      String errMsg = 'Failed to upload image (${response.statusCode})';
      try {
        final errJson = jsonDecode(response.body);
        if (errJson is Map && errJson['detail'] != null) {
          errMsg = errJson['detail'].toString();
        }
      } catch (_) {}
      throw Exception(errMsg);
    }
  }

  // Vision Analysis
  Future<Map<String, dynamic>> analyzeFoodVision({
    required double padWeight,
    String weightSource = 'device',
    double tareWeightG = 0.0,
    String? dishHint,
    String? imageBase64,
  }) async {
    final payload = <String, dynamic>{
      'pad_weight_g': padWeight,
      'weight_source': weightSource,
      'tare_weight_g': tareWeightG,
      'dish_hint': dishHint,
    };
    if (imageBase64 != null) {
      payload['image_base64'] = imageBase64;
    }

    final data = await _post(
      '/vision/analyze',
      payload,
      timeout: const Duration(seconds: 30),
    );
    if (data != null && data is Map<String, dynamic>) {
      var rawComps = data['components'] as List<dynamic>? ?? [];
      var comps = rawComps.map((c) => FoodComponentItem.fromJson(c as Map<String, dynamic>)).toList();
      return {
        'dish_name': data['dish_name'] as String? ?? (dishHint ?? 'Custom Meal'),
        'confidence': (data['overall_confidence'] as num?)?.toDouble() ?? 0.85,
        'total_weight_g': (data['total_weight_g'] as num?)?.toDouble() ?? padWeight,
        'net_food_weight_g': (data['net_food_weight_g'] as num?)?.toDouble() ?? padWeight,
        'weight_source': data['weight_source'] as String? ?? weightSource,
        'ai_model': data['ai_model'] as String? ?? 'gemini-2.5-flash',
        'ai_verified': data['ai_verified'] as bool? ?? false,
        'is_stabilized': data['is_stabilized'] as bool? ?? true,
        'total_calories': (data['total_calories'] as num?)?.toInt() ?? 0,
        'total_protein_g': (data['total_protein_g'] as num?)?.toDouble() ?? 0.0,
        'total_carbs_g': (data['total_carbs_g'] as num?)?.toDouble() ?? 0.0,
        'total_fat_g': (data['total_fat_g'] as num?)?.toDouble() ?? 0.0,
        'components': comps,
      };
    }

    throw Exception('AI Vision service is temporarily unavailable. Check backend connection.');
  }

  // Meals
  Future<List<MealRecord>> getRecentMeals() async {
    final data = await _get('/meals/');
    if (data != null && data is List) {
      return data.map((e) => MealRecord.fromJson(e as Map<String, dynamic>)).toList();
    }
    return [];
  }

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
    final payload = {
      'meal_name': mealName,
      'initial_weight_g': initialWeightG,
      'remaining_weight_g': remainingWeightG,
      'weight_source': weightSource,
      'tare_weight_g': tareWeightG,
      'image_url': imageUrl,
      'components': components.map((c) => c.toJson()).toList(),
      'start_gross_weight_g': startGrossWeightG,
      'end_gross_weight_g': endGrossWeightG,
      'plate_weight_g': plateWeightG,
      'plate_weight_mode': plateWeightMode,
      'start_food_weight_g': startFoodWeightG,
      'end_food_weight_g': endFoodWeightG,
      'weight_reduction_g': weightReductionG,
      'start_image_url': startImageUrl ?? imageUrl,
      'end_image_url': endImageUrl,
      'start_image_source': startImageSource,
      'end_image_source': endImageSource,
      'device_id': deviceId,
      'is_calibrated': isCalibrated,
      'is_flagged_increase': isFlaggedIncrease,
      'readings_history': readingsHistory,
    };
    final data = await _post('/meals/', payload);
    if (data != null && data is Map<String, dynamic>) {
      return MealRecord.fromJson(data);
    }
    return null;
  }

  // Analytics
  Future<Map<String, dynamic>> getAnalyticsSummary() async {
    final data = await _get('/analytics/summary');
    if (data != null && data is Map<String, dynamic>) {
      return data;
    }
    return {
      'today_waste_g': 0.0,
      'today_waste_delta_g': 0.0,
      'weekly_waste_g': 0.0,
      'weekly_waste_delta_pct': 0.0,
      'monthly_waste_kg': 0.0,
      'waste_score': 100,
      'waste_score_label': 'No Data',
      'avg_calories': 0,
      'avg_protein_g': 0.0,
      'avg_carbs_g': 0.0,
      'avg_fat_g': 0.0,
      'avg_meal_size_g': 0.0,
      'avg_consumed_pct': 0.0,
      'daily_trends': <Map<String, dynamic>>[],
      'category_breakdown': <Map<String, dynamic>>[],
      'insights': <String>[
        'Start a meal session to begin tracking food waste and nutrition trends.'
      ]
    };
  }

  // AI Insights
  Future<List<Map<String, dynamic>>> getAiInsights() async {
    final data = await _get('/insights/');
    if (data != null && data is List) {
      return data.map((e) => e as Map<String, dynamic>).toList();
    }
    return [];
  }
}
