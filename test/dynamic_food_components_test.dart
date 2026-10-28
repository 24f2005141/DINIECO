import 'package:flutter_test/flutter_test.dart';
import 'package:dinieco/models/models.dart';
import 'package:dinieco/providers/dinieco_provider.dart';
import 'mock_api_service.dart';

void main() {
  group('Dynamic Food Components & Nutrition Caching Model Tests', () {
    test('FoodComponentItem correctly parses per-100g nutrients and source', () {
      final json = {
        'name': 'Papaya Cubes',
        'weight_g': 320.0,
        'confidence': 0.95,
        'calories_kcal': 138,
        'protein_g': 1.6,
        'carbs_g': 34.6,
        'fat_g': 1.0,
        'fiber_g': 5.4,
        'sodium_mg': 25.6,
        'portion_ratio': 0.8,
        'preparation_style': 'Fresh, cubed',
        'icon_name': 'eco',
        'calories_100g': 43.0,
        'protein_100g': 0.5,
        'carbs_100g': 10.8,
        'fat_100g': 0.3,
        'fiber_100g': 1.7,
        'sodium_100g': 8.0,
        'source': 'local_cache',
      };

      final comp = FoodComponentItem.fromJson(json);
      expect(comp.name, equals('Papaya Cubes'));
      expect(comp.weightG, equals(320.0));
      expect(comp.calories100g, equals(43.0));
      expect(comp.protein100g, equals(0.5));
      expect(comp.carbs100g, equals(10.8));
      expect(comp.fat100g, equals(0.3));
      expect(comp.source, equals('local_cache'));

      final serialized = comp.toJson();
      expect(serialized['calories_100g'], equals(43.0));
      expect(serialized['source'], equals('local_cache'));
    });

    test('DiniecoProvider scales portion nutrients using actual per-100g values', () {
      final mockApi = MockApiService();
      final provider = DiniecoProvider(api: mockApi);

      // Create a Papaya component carrying 43 kcal/100g
      final papaya = FoodComponentItem(
        name: 'Papaya Cubes',
        weightG: 200.0,
        confidence: 0.95,
        caloriesKcal: 86,
        proteinG: 1.0,
        carbsG: 21.6,
        fatG: 0.6,
        calories100g: 43.0,
        protein100g: 0.5,
        carbs100g: 10.8,
        fat100g: 0.3,
      );

      // Create a Cucumber component carrying 15 kcal/100g
      final cucumber = FoodComponentItem(
        name: 'Cucumber Slices',
        weightG: 100.0,
        confidence: 0.92,
        caloriesKcal: 15,
        proteinG: 0.7,
        carbsG: 3.6,
        fatG: 0.1,
        calories100g: 15.0,
        protein100g: 0.7,
        carbs100g: 3.6,
        fat100g: 0.1,
      );

      // Inject components
      provider.detectedComponents = [papaya, cucumber];
      expect(provider.detectedComponents.length, equals(2));

      // Update Papaya weight to 300g (factor = 3.0)
      provider.updateComponentWeight(0, 300.0);

      // 43 * 3.0 = 129 kcal (NOT hardcoded roti / rice values!)
      expect(provider.detectedComponents[0].weightG, equals(300.0));
      expect(provider.detectedComponents[0].caloriesKcal, equals(129));
      expect(provider.detectedComponents[0].proteinG, equals(1.5));
      expect(provider.detectedComponents[0].carbsG, equals(32.4));
      expect(provider.detectedComponents[0].fatG, equals(0.9));

      // Update Cucumber weight to 200g (factor = 2.0)
      provider.updateComponentWeight(1, 200.0);

      // 15 * 2.0 = 30 kcal
      expect(provider.detectedComponents[1].weightG, equals(200.0));
      expect(provider.detectedComponents[1].caloriesKcal, equals(30));
      expect(provider.detectedComponents[1].proteinG, equals(1.4));
      expect(provider.detectedComponents[1].carbsG, equals(7.2));
      expect(provider.detectedComponents[1].fatG, equals(0.2));
    });
  });
}
