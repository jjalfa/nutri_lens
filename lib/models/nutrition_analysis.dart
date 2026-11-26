import 'food_item.dart';

class NutritionAnalysis {
  const NutritionAnalysis({
    required this.isFood,
    required this.dishName,
    required this.confidence,
    required this.totalCalories,
    required this.totalProteinG,
    required this.totalCarbsG,
    required this.totalFatG,
    required this.notes,
    required this.items,
  });

  final bool isFood;
  final String dishName;
  final int confidence;
  final int totalCalories;
  final double totalProteinG;
  final double totalCarbsG;
  final double totalFatG;
  final String notes;
  final List<FoodItem> items;

  factory NutritionAnalysis.fromWebhookJson(Map<String, dynamic> json) {
    if (json['ok'] != true) {
      throw const FormatException('El webhook indicó una respuesta no exitosa.');
    }

    final data = json['data'];
    if (data is! Map<String, dynamic>) {
      throw const FormatException('Falta el objeto "data" en la respuesta.');
    }

    return NutritionAnalysis.fromDataJson(data);
  }

  factory NutritionAnalysis.fromDataJson(Map<String, dynamic> data) {
    final isFood = data['is_food'];
    if (isFood is! bool) {
      throw const FormatException('Campo booleano inválido: is_food');
    }

    final dishName = data['dish_name'];
    if (dishName is! String || dishName.trim().isEmpty) {
      throw const FormatException('Campo de texto inválido: dish_name');
    }

    final confidenceRaw = data['confidence'];
    if (confidenceRaw is! num || confidenceRaw.isNaN) {
      throw const FormatException('Campo numérico inválido: confidence');
    }

    final notesRaw = data['notes'];
    if (notesRaw != null && notesRaw is! String) {
      throw const FormatException('Campo de texto inválido: notes');
    }

    final rawItems = data['items'];
    if (rawItems is! List) {
      throw const FormatException('El campo "items" debe ser una lista.');
    }

    final items = <FoodItem>[];
    for (final entry in rawItems) {
      if (entry is! Map<String, dynamic>) {
        throw const FormatException('Elemento de "items" con formato inválido.');
      }
      items.add(FoodItem.fromJson(entry));
    }

    return NutritionAnalysis(
      isFood: isFood,
      dishName: dishName.trim(),
      confidence: confidenceRaw.round().clamp(0, 100),
      totalCalories: _requireNonNegativeDouble(data, 'total_calories').round(),
      totalProteinG: _requireNonNegativeDouble(data, 'total_protein_g'),
      totalCarbsG: _requireNonNegativeDouble(data, 'total_carbs_g'),
      totalFatG: _requireNonNegativeDouble(data, 'total_fat_g'),
      notes: (notesRaw as String? ?? '').trim(),
      items: items,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'is_food': isFood,
      'dish_name': dishName,
      'confidence': confidence,
      'total_calories': totalCalories,
      'total_protein_g': totalProteinG,
      'total_carbs_g': totalCarbsG,
      'total_fat_g': totalFatG,
      'notes': notes,
      'items': items.map((item) => item.toJson()).toList(),
    };
  }

  NutritionAnalysis copyWith({
    bool? isFood,
    String? dishName,
    int? confidence,
    int? totalCalories,
    double? totalProteinG,
    double? totalCarbsG,
    double? totalFatG,
    String? notes,
    List<FoodItem>? items,
  }) {
    return NutritionAnalysis(
      isFood: isFood ?? this.isFood,
      dishName: dishName ?? this.dishName,
      confidence: confidence ?? this.confidence,
      totalCalories: totalCalories ?? this.totalCalories,
      totalProteinG: totalProteinG ?? this.totalProteinG,
      totalCarbsG: totalCarbsG ?? this.totalCarbsG,
      totalFatG: totalFatG ?? this.totalFatG,
      notes: notes ?? this.notes,
      items: items ?? this.items,
    );
  }

  NutritionAnalysis withRecalculatedItems(
    List<FoodItem> updatedItems, {
    String? dishName,
    String? notes,
  }) {
    var caloriesSum = 0;
    var proteinSum = 0.0;
    var carbsSum = 0.0;
    var fatSum = 0.0;

    for (final item in updatedItems) {
      caloriesSum += item.calories;
      proteinSum += item.proteinG;
      carbsSum += item.carbsG;
      fatSum += item.fatG;
    }

    return copyWith(
      dishName: dishName,
      notes: notes,
      items: List<FoodItem>.unmodifiable(updatedItems),
      totalCalories: caloriesSum,
      totalProteinG: double.parse(proteinSum.toStringAsFixed(1)),
      totalCarbsG: double.parse(carbsSum.toStringAsFixed(1)),
      totalFatG: double.parse(fatSum.toStringAsFixed(1)),
    );
  }

  static double _requireNonNegativeDouble(
    Map<String, dynamic> json,
    String key,
  ) {
    final value = json[key];
    if (value is! num || value.isNaN || value < 0) {
      throw FormatException('Campo numérico inválido: $key');
    }
    return double.parse(value.toDouble().toStringAsFixed(1));
  }
}