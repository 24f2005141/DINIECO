import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dinieco/main.dart';
import 'package:dinieco/screens/active_session_screen.dart';
import 'package:dinieco/services/api_service.dart';
import 'package:dinieco/providers/dinieco_provider.dart';
import 'mock_api_service.dart';

class CompatibilityMockApiService extends MockApiService {
  Uint8List? lastUploadedBytes;
  String? lastUploadedFilename;
  String? lastContentType;

  @override
  Future<Map<String, dynamic>> uploadMealImage(XFile imageFile) async {
    final bytes = await imageFile.readAsBytes();
    if (bytes.isEmpty) {
      throw Exception('The selected photo is empty (0 bytes received).');
    }
    lastUploadedBytes = bytes;
    lastUploadedFilename = imageFile.name;
    lastContentType = ApiService.detectImageMimeType(bytes, imageFile.name);

    // Simulate backend returning normalized JPEG base64 (e.g. 1x1 transparent/red JPEG)
    final normalizedJpeg = base64Encode([0xFF, 0xD8, 0xFF, 0xE0, 0x00, 0x10, 0x4A, 0x46, 0x49, 0x46]);

    return {
      'image_id': 'compat-img-999',
      'filename': 'compat_normalized.jpg',
      'image_url': '/uploads/compat_normalized.jpg',
      'format': 'JPEG',
      'width': 1280,
      'height': 960,
      'normalized_base64': normalizedJpeg,
    };
  }
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('MIME Type and Magic Byte Detection Tests', () {
    test('Detects JPEG from magic bytes', () {
      final bytes = Uint8List.fromList([0xFF, 0xD8, 0xFF, 0xE0, 0x00, 0x10]);
      expect(ApiService.detectImageMimeType(bytes, 'unknown_file'), 'image/jpeg');
    });

    test('Detects PNG from magic bytes', () {
      final bytes = Uint8List.fromList([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00]);
      expect(ApiService.detectImageMimeType(bytes, 'meal_photo'), 'image/png');
    });

    test('Detects WebP from magic bytes', () {
      final bytes = Uint8List.fromList([
        0x52, 0x49, 0x46, 0x46, // RIFF
        0x00, 0x00, 0x00, 0x00, // length
        0x57, 0x45, 0x42, 0x50, // WEBP
      ]);
      expect(ApiService.detectImageMimeType(bytes, 'no_ext'), 'image/webp');
    });

    test('Detects GIF from magic bytes', () {
      final bytes = Uint8List.fromList([0x47, 0x49, 0x46, 0x38, 0x39, 0x61, 0x00]);
      expect(ApiService.detectImageMimeType(bytes, 'animated'), 'image/gif');
    });

    test('Detects BMP from magic bytes', () {
      final bytes = Uint8List.fromList([0x42, 0x4D, 0x00, 0x00]);
      expect(ApiService.detectImageMimeType(bytes, 'plate'), 'image/bmp');
    });

    test('Detects TIFF (Little & Big Endian) from magic bytes', () {
      final tiffLE = Uint8List.fromList([0x49, 0x49, 0x2A, 0x00]);
      final tiffBE = Uint8List.fromList([0x4D, 0x4D, 0x00, 0x2A]);
      expect(ApiService.detectImageMimeType(tiffLE, 'raw1'), 'image/tiff');
      expect(ApiService.detectImageMimeType(tiffBE, 'raw2'), 'image/tiff');
    });

    test('Detects HEIC and AVIF from ISO BMFF ftyp box', () {
      // ftypheic
      final heicBytes = Uint8List.fromList([
        0x00, 0x00, 0x00, 0x18, // box size
        0x66, 0x74, 0x79, 0x70, // 'ftyp'
        0x68, 0x65, 0x69, 0x63, // 'heic'
      ]);
      expect(ApiService.detectImageMimeType(heicBytes, 'ios_cam'), 'image/heic');

      // ftypavif
      final avifBytes = Uint8List.fromList([
        0x00, 0x00, 0x00, 0x1C,
        0x66, 0x74, 0x79, 0x70,
        0x61, 0x76, 0x69, 0x66, // 'avif'
      ]);
      expect(ApiService.detectImageMimeType(avifBytes, 'nextgen'), 'image/avif');
    });

    test('Maps common extensions correctly and case-insensitively', () {
      final dummy = Uint8List.fromList([0x00, 0x01, 0x02, 0x03]);
      expect(ApiService.detectImageMimeType(dummy, 'photo.JPG'), 'image/jpeg');
      expect(ApiService.detectImageMimeType(dummy, 'photo.jpeg'), 'image/jpeg');
      expect(ApiService.detectImageMimeType(dummy, 'photo.PNG'), 'image/png');
      expect(ApiService.detectImageMimeType(dummy, 'dish.WEBP'), 'image/webp');
      expect(ApiService.detectImageMimeType(dummy, 'IMG_0123.HEIC'), 'image/heic');
      expect(ApiService.detectImageMimeType(dummy, 'meal.heif'), 'image/heic');
      expect(ApiService.detectImageMimeType(dummy, 'icon.gif'), 'image/gif');
      expect(ApiService.detectImageMimeType(dummy, 'bitmap.bmp'), 'image/bmp');
      expect(ApiService.detectImageMimeType(dummy, 'scan.tiff'), 'image/tiff');
      expect(ApiService.detectImageMimeType(dummy, 'food.avif'), 'image/avif');
    });

    test('Rejects known non-image extensions with actionable error message', () {
      final dummy = Uint8List.fromList([0x00, 0x01, 0x02, 0x03]);
      expect(
        () => ApiService.detectImageMimeType(dummy, 'document.pdf'),
        throwsA(predicate((e) =>
            e.toString().contains('Image format is not supported') &&
            e.toString().contains('JPEG, PNG, WebP, HEIC'))),
      );
      expect(
        () => ApiService.detectImageMimeType(dummy, 'notes.txt'),
        throwsA(predicate((e) => e.toString().contains('Image format is not supported'))),
      );
      expect(
        () => ApiService.detectImageMimeType(dummy, 'video.mp4'),
        throwsA(predicate((e) => e.toString().contains('Image format is not supported'))),
      );
    });
  });

  group('Provider Photo Normalization & Meal Persistence Tests', () {
    test('uploadAndAnalyzePhoto handles HEIC photo and updates preview with normalized bytes', () async {
      final mockApi = CompatibilityMockApiService();
      final provider = DiniecoProvider(api: mockApi);

      // Create simulated HEIC photo
      final heicData = Uint8List.fromList([
        0x00, 0x00, 0x00, 0x18,
        0x66, 0x74, 0x79, 0x70,
        0x68, 0x65, 0x69, 0x63,
        0x00, 0x00, 0x00, 0x00,
      ]);
      final xfile = XFile.fromData(heicData, name: 'camera_meal.HEIC');

      final success = await provider.uploadAndAnalyzePhoto(xfile);
      expect(success, isTrue);
      expect(provider.photoError, isNull);
      expect(provider.uploadedImageUrl, '/uploads/compat_normalized.jpg');
      expect(mockApi.lastContentType, 'image/heic');
      expect(provider.selectedMealPhotoBytes, isNotNull);

      // Verify that saving meal retains uploaded image URL
      final record = await provider.saveMealSession(remainingWeightG: 50.0);
      expect(record, isNotNull);
      expect(record!.imageUrl, '/uploads/compat_normalized.jpg');
      expect(record.initialWeightG, greaterThan(0));
    });

    test('clearMealPhoto removes photo and resets preview bytes', () {
      final provider = DiniecoProvider(api: MockApiService());
      final xfile = XFile.fromData(Uint8List.fromList([1, 2, 3]), name: 'test.jpg');

      provider.setSelectedMealPhoto(xfile);
      expect(provider.selectedMealPhoto, isNotNull);

      provider.clearMealPhoto();
      expect(provider.selectedMealPhoto, isNull);
      expect(provider.selectedMealPhotoBytes, isNull);
      expect(provider.uploadedImageUrl, isNull);
      expect(provider.photoError, isNull);
    });
  });

  group('ActiveSessionScreen Viewfinder UI Tests', () {
    testWidgets('Renders viewfinder and Retake/Remove buttons when photo is set', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final provider = DiniecoProvider(api: CompatibilityMockApiService());
      // Set dummy photo bytes (valid 1x1 GIF)
      final gif1x1 = Uint8List.fromList([
        0x47, 0x49, 0x46, 0x38, 0x39, 0x61, 0x01, 0x00, 0x01, 0x00,
        0x80, 0x00, 0x00, 0xFF, 0xFF, 0xFF, 0x00, 0x00, 0x00, 0x21,
        0xF9, 0x04, 0x01, 0x00, 0x00, 0x00, 0x00, 0x2C, 0x00, 0x00,
        0x00, 0x00, 0x01, 0x00, 0x01, 0x00, 0x00, 0x02, 0x02, 0x44,
        0x01, 0x00, 0x3B
      ]);
      await provider.setSelectedMealPhoto(XFile.fromData(gif1x1, name: 'meal.gif'));

      await tester.pumpWidget(
        DiniecoApp(
          diniecoProvider: provider,
          home: ActiveSessionScreen(onFinishMeal: () {}, onCancel: () {}),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Retake'), findsOneWidget);
      expect(find.text('Remove'), findsOneWidget);

      // Tap Remove button
      await tester.tap(find.text('Remove'));
      await tester.pumpAndSettle();

      expect(provider.selectedMealPhoto, isNull);
      expect(find.text('Tap to Capture or Upload Meal Photo'), findsOneWidget);
    });
  });
}
