class FoodItem {
  const FoodItem({
    required this.name,
    required this.portionGrams,
    required this.calories,
    required this.proteinG,
    required this.carbsG,
    required this.fatG,
  });

  final String name;
  final double portionGrams;
  final int calories;
  final double proteinG;
  final double carbsG;
  final double fatG;

  factory FoodItem.fromJson(Map<String, dynamic> json) {
    final name = _requireString(json, 'name');
    final portionGrams = _requireNonNegativeDouble(json, 'portion_grams');
    final calories = _requireNonNegativeDouble(json, 'calories').round();
    final proteinG = _requireNonNegativeDouble(json, 'protein_g');
    final carbsG = _requireNonNegativeDouble(json, 'carbs_g');
    final fatG = _requireNonNegativeDouble(json, 'fat_g');

    return FoodItem(
      name: name,
      portionGrams: portionGrams,
      calories: calories,
      proteinG: proteinG,
      carbsG: carbsG,
      fatG: fatG,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'portion_grams': portionGrams,
      'calories': calories,
      'protein_g': proteinG,
      'carbs_g': carbsG,
      'fat_g': fatG,
    };
  }

  FoodItem copyWith({
    String? name,
    double? portionGrams,
    int? calories,
    double? proteinG,
    double? carbsG,
    double? fatG,
  }) {
    return FoodItem(
      name: name ?? this.name,
      portionGrams: portionGrams ?? this.portionGrams,
      calories: calories ?? this.calories,
      proteinG: proteinG ?? this.proteinG,
      carbsG: carbsG ?? this.carbsG,
      fatG: fatG ?? this.fatG,
    );
  }

  FoodItem scaleToGrams(double newGrams) {
    final clamped = newGrams < 0 ? 0.0 : newGrams;
    final roundedGrams = double.parse(clamped.toStringAsFixed(1));

    if (portionGrams <= 0) {
      return copyWith(portionGrams: roundedGrams);
    }

    final factor = roundedGrams / portionGrams;
    return copyWith(
      portionGrams: roundedGrams,
      calories: (calories * factor).round(),
      proteinG: double.parse((proteinG * factor).toStringAsFixed(1)),
      carbsG: double.parse((carbsG * factor).toStringAsFixed(1)),
      fatG: double.parse((fatG * factor).toStringAsFixed(1)),
    );
  }

  static String _requireString(Map<String, dynamic> json, String key) {
    final value = json[key];
    if (value is! String || value.trim().isEmpty) {
      throw FormatException('Campo de texto inválido o vacío: $key');
    }
    return value.trim();
  }

  static double _requireNonNegativeDouble(
    Map<String, dynamic> json,
    String key,
  ) {
    final value = json[key];
    if (value is! num || value.isNaN || value < 0) {
      throw FormatException('Campo numérico inválido en ingrediente: $key');
    }
    return double.parse(value.toDouble().toStringAsFixed(1));
  }
}