import 'package:flutter_test/flutter_test.dart';
import 'package:nutri_lens/models/food_item.dart';
import 'package:nutri_lens/models/nutrition_analysis.dart';

void main() {
  group('NutritionAnalysis.fromWebhookJson', () {
    test('deserializa correctamente una respuesta válida de comida', () {
      final Map<String, dynamic> json = {
        'ok': true,
        'data': {
          'is_food': true,
          'dish_name': 'Pozole rojo',
          'confidence': 92,
          'total_calories': 520,
          'total_protein_g': 34.5,
          'total_carbs_g': 54.0,
          'total_fat_g': 16.2,
          'notes': 'Considera tostadas o crema adicional.',
          'items': [
            {
              'name': 'Maíz pozolero',
              'portion_grams': 180,
              'calories': 210,
              'protein_g': 6.0,
              'carbs_g': 44.0,
              'fat_g': 2.0,
            },
            {
              'name': 'Carne de cerdo magra',
              'portion_grams': 120,
              'calories': 250,
              'protein_g': 28.5,
              'carbs_g': 0,
              'fat_g': 14.2,
            },
          ],
        },
      };

      final analysis = NutritionAnalysis.fromWebhookJson(json);

      expect(analysis.isFood, isTrue);
      expect(analysis.dishName, 'Pozole rojo');
      expect(analysis.confidence, 92);
      expect(analysis.totalCalories, 520);
      expect(analysis.items.length, 2);
      expect(analysis.items.first.name, 'Maíz pozolero');
    });

    test('maneja correctamente una imagen que no es comida', () {
      final Map<String, dynamic> json = {
        'ok': true,
        'data': {
          'is_food': false,
          'dish_name': 'No se detectó alimento',
          'confidence': 0,
          'total_calories': 0,
          'total_protein_g': 0,
          'total_carbs_g': 0,
          'total_fat_g': 0,
          'notes': 'La imagen no muestra alimentos.',
          'items': [],
        },
      };

      final analysis = NutritionAnalysis.fromWebhookJson(json);

      expect(analysis.isFood, isFalse);
      expect(analysis.totalCalories, 0);
      expect(analysis.items, isEmpty);
    });

    test('lanza FormatException si falta un campo obligatorio o tipo inválido', () {
      final Map<String, dynamic> brokenJson = {
        'ok': true,
        'data': {
          'is_food': true,
          'dish_name': 'Tacos',
          'confidence': 'alto',
          'total_calories': 400,
          'total_protein_g': 20,
          'total_carbs_g': 30,
          'total_fat_g': 15,
          'notes': '',
          'items': [],
        },
      };

      expect(
        () => NutritionAnalysis.fromWebhookJson(brokenJson),
        throwsFormatException,
      );
    });
  });

  group('Edición manual y recálculo dinámico', () {
    test('FoodItem.scaleToGrams escala proporcionalmente calorías y macros', () {
      const pollo = FoodItem(
        name: 'Pechuga de pollo',
        portionGrams: 100,
        calories: 165,
        proteinG: 31.0,
        carbsG: 0.0,
        fatG: 3.6,
      );

      final doble = pollo.scaleToGrams(150);

      expect(doble.portionGrams, 150.0);
      expect(doble.calories, 248);
      expect(doble.proteinG, 46.5);
      expect(doble.fatG, 5.4);
    });

    test('withRecalculatedItems suma todos los ingredientes modificados', () {
      const base = NutritionAnalysis(
        isFood: true,
        dishName: 'Ensalada',
        confidence: 88,
        totalCalories: 200,
        totalProteinG: 20,
        totalCarbsG: 10,
        totalFatG: 8,
        notes: '',
        items: [
          FoodItem(
            name: 'Pollo asado',
            portionGrams: 100,
            calories: 165,
            proteinG: 31.0,
            carbsG: 0.0,
            fatG: 3.6,
          ),
        ],
      );

      const aceite = FoodItem(
        name: 'Aceite vegetal (1 cda)',
        portionGrams: 10,
        calories: 90,
        proteinG: 0.0,
        carbsG: 0.0,
        fatG: 10.0,
      );

      final updated = base.withRecalculatedItems(
        [...base.items, aceite],
        dishName: 'Ensalada con aceite',
      );

      expect(updated.dishName, 'Ensalada con aceite');
      expect(updated.totalCalories, 255);
      expect(updated.totalProteinG, 31.0);
      expect(updated.totalFatG, 13.6);
      expect(updated.items.length, 2);
    });
  });
}