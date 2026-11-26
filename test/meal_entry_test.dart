import 'package:flutter_test/flutter_test.dart';
import 'package:nutri_lens/models/food_item.dart';
import 'package:nutri_lens/models/meal_entry.dart';
import 'package:nutri_lens/models/nutrition_analysis.dart';

void main() {
  group('Utilidades de fecha y MealEntry', () {
    test('formatDateKey devuelve YYYY-MM-DD con ceros a la izquierda', () {
      expect(formatDateKey(DateTime(2026, 3, 5)), '2026-03-05');
      expect(formatDateKey(DateTime(2026, 11, 24)), '2026-11-24');
    });

    test('serializa y reconstruye MealEntry manteniendo datos intactos', () {
      final now = DateTime(2026, 11, 24, 14, 30);
      const analysis = NutritionAnalysis(
        isFood: true,
        dishName: 'Tacos de asada',
        confidence: 90,
        totalCalories: 460,
        totalProteinG: 28.0,
        totalCarbsG: 42.0,
        totalFatG: 19.5,
        notes: 'Sin salsa extra.',
        items: [
          FoodItem(
            name: 'Bistec de res',
            portionGrams: 120,
            calories: 260,
            proteinG: 24.0,
            carbsG: 0.0,
            fatG: 17.5,
          ),
        ],
      );

      final entry = MealEntry(
        id: 'meal-1',
        userId: 'uid-123',
        dateKey: '2026-11-24',
        createdAt: now,
        updatedAt: now,
        analysis: analysis,
      );

      final restored = MealEntry.fromMap('meal-1', entry.toFirestoreCreateMap());

      expect(restored.id, 'meal-1');
      expect(restored.userId, 'uid-123');
      expect(restored.dateKey, '2026-11-24');
      expect(restored.analysis.dishName, 'Tacos de asada');
      expect(restored.analysis.totalCalories, 460);
      expect(restored.analysis.items.length, 1);
    });
  });

  group('DailyNutritionSummary', () {
    test('agrega calorías y macros de múltiples comidas del mismo día', () {
      final now = DateTime(2026, 11, 24, 9, 0);
      final meals = [
        MealEntry(
          id: 'm1',
          userId: 'u1',
          dateKey: '2026-11-24',
          createdAt: now,
          updatedAt: now,
          analysis: const NutritionAnalysis(
            isFood: true,
            dishName: 'Desayuno',
            confidence: 90,
            totalCalories: 350,
            totalProteinG: 18.2,
            totalCarbsG: 32.5,
            totalFatG: 14.0,
            notes: '',
            items: [],
          ),
        ),
        MealEntry(
          id: 'm2',
          userId: 'u1',
          dateKey: '2026-11-24',
          createdAt: now.add(const Duration(hours: 5)),
          updatedAt: now.add(const Duration(hours: 5)),
          analysis: const NutritionAnalysis(
            isFood: true,
            dishName: 'Comida',
            confidence: 95,
            totalCalories: 640,
            totalProteinG: 41.3,
            totalCarbsG: 58.0,
            totalFatG: 22.4,
            notes: '',
            items: [],
          ),
        ),
      ];

      final summary = DailyNutritionSummary.fromMeals(meals);

      expect(summary.mealCount, 2);
      expect(summary.totalCalories, 990);
      expect(summary.totalProteinG, 59.5);
      expect(summary.totalCarbsG, 90.5);
      expect(summary.totalFatG, 36.4);
    });
  });
}