import 'package:cloud_firestore/cloud_firestore.dart';
import 'nutrition_analysis.dart';

String formatDateKey(DateTime date) {
  final year = date.year.toString().padLeft(4, '0');
  final month = date.month.toString().padLeft(2, '0');
  final day = date.day.toString().padLeft(2, '0');
  return '$year-$month-$day';
}

String formatDisplayDate(DateTime date, {DateTime? reference}) {
  const months = [
    'ene',
    'feb',
    'mar',
    'abr',
    'may',
    'jun',
    'jul',
    'ago',
    'sep',
    'oct',
    'nov',
    'dic',
  ];

  final now = reference ?? DateTime.now();
  final todayKey = formatDateKey(now);
  final yesterdayKey = formatDateKey(now.subtract(const Duration(days: 1)));
  final targetKey = formatDateKey(date);
  final label = '${date.day} ${months[date.month - 1]}';

  if (targetKey == todayKey) return 'Hoy, $label';
  if (targetKey == yesterdayKey) return 'Ayer, $label';
  return '$label ${date.year}';
}

String formatTime24h(DateTime date) {
  final hour = date.hour.toString().padLeft(2, '0');
  final minute = date.minute.toString().padLeft(2, '0');
  return '$hour:$minute';
}

class MealEntry {
  const MealEntry({
    required this.id,
    required this.userId,
    required this.dateKey,
    required this.createdAt,
    required this.updatedAt,
    required this.analysis,
  });

  final String id;
  final String userId;
  final String dateKey;
  final DateTime createdAt;
  final DateTime updatedAt;
  final NutritionAnalysis analysis;

  factory MealEntry.fromMap(String id, Map<String, dynamic> map) {
    final createdAt = _parseDateTime(map['createdAt']);
    final updatedAt = _parseDateTime(map['updatedAt'], fallback: createdAt);
    final rawDateKey = map['dateKey'];
    final dateKey = rawDateKey is String && rawDateKey.isNotEmpty
        ? rawDateKey
        : formatDateKey(createdAt);

    return MealEntry(
      id: id,
      userId: (map['userId'] as String? ?? '').trim(),
      dateKey: dateKey,
      createdAt: createdAt,
      updatedAt: updatedAt,
      analysis: NutritionAnalysis.fromDataJson(map),
    );
  }

  Map<String, dynamic> toFirestoreCreateMap() {
    return {
      ...analysis.toJson(),
      'userId': userId,
      'dateKey': dateKey,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  Map<String, dynamic> toFirestoreUpdateMap() {
    return {
      ...analysis.toJson(),
      'userId': userId,
      'dateKey': dateKey,
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  MealEntry copyWith({
    String? id,
    String? userId,
    String? dateKey,
    DateTime? createdAt,
    DateTime? updatedAt,
    NutritionAnalysis? analysis,
  }) {
    return MealEntry(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      dateKey: dateKey ?? this.dateKey,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      analysis: analysis ?? this.analysis,
    );
  }

  static DateTime _parseDateTime(Object? raw, {DateTime? fallback}) {
    if (raw is Timestamp) return raw.toDate();
    if (raw is DateTime) return raw;
    if (raw is String) {
      final parsed = DateTime.tryParse(raw);
      if (parsed != null) return parsed;
    }
    return fallback ?? DateTime.now();
  }
}

class DailyNutritionSummary {
  const DailyNutritionSummary({
    required this.mealCount,
    required this.totalCalories,
    required this.totalProteinG,
    required this.totalCarbsG,
    required this.totalFatG,
  });

  final int mealCount;
  final int totalCalories;
  final double totalProteinG;
  final double totalCarbsG;
  final double totalFatG;

  static const DailyNutritionSummary empty = DailyNutritionSummary(
    mealCount: 0,
    totalCalories: 0,
    totalProteinG: 0,
    totalCarbsG: 0,
    totalFatG: 0,
  );

  factory DailyNutritionSummary.fromMeals(List<MealEntry> meals) {
    if (meals.isEmpty) return empty;

    var calories = 0;
    var protein = 0.0;
    var carbs = 0.0;
    var fat = 0.0;

    for (final meal in meals) {
      calories += meal.analysis.totalCalories;
      protein += meal.analysis.totalProteinG;
      carbs += meal.analysis.totalCarbsG;
      fat += meal.analysis.totalFatG;
    }

    return DailyNutritionSummary(
      mealCount: meals.length,
      totalCalories: calories,
      totalProteinG: double.parse(protein.toStringAsFixed(1)),
      totalCarbsG: double.parse(carbs.toStringAsFixed(1)),
      totalFatG: double.parse(fat.toStringAsFixed(1)),
    );
  }
}