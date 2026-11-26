import 'dart:io';
import 'package:flutter/material.dart';
import '../core/theme/app_theme.dart';
import '../models/food_item.dart';
import '../models/nutrition_analysis.dart';

class ReviewEditScreen extends StatefulWidget {
  const ReviewEditScreen({
    super.key,
    required this.initialAnalysis,
    this.imageFile,
  });

  final NutritionAnalysis initialAnalysis;
  final File? imageFile;

  @override
  State<ReviewEditScreen> createState() => _ReviewEditScreenState();
}

class _ReviewEditScreenState extends State<ReviewEditScreen> {
  static const List<FoodItem> _hiddenIngredientPresets = [
    FoodItem(
      name: 'Aceite vegetal (1 cda)',
      portionGrams: 10,
      calories: 90,
      proteinG: 0,
      carbsG: 0,
      fatG: 10,
    ),
    FoodItem(
      name: 'Aderezo cremoso (2 cdas)',
      portionGrams: 30,
      calories: 120,
      proteinG: 0.5,
      carbsG: 3,
      fatG: 12,
    ),
    FoodItem(
      name: 'Crema (2 cdas)',
      portionGrams: 30,
      calories: 60,
      proteinG: 0.8,
      carbsG: 1.2,
      fatG: 6,
    ),
    FoodItem(
      name: 'Queso fresco (30 g)',
      portionGrams: 30,
      calories: 95,
      proteinG: 6.5,
      carbsG: 1,
      fatG: 7.5,
    ),
    FoodItem(
      name: 'Tortilla de maíz (1 pza)',
      portionGrams: 30,
      calories: 65,
      proteinG: 1.6,
      carbsG: 13.5,
      fatG: 0.8,
    ),
  ];

  late final TextEditingController _dishNameController;
  late NutritionAnalysis _analysis;

  @override
  void initState() {
    super.initState();
    _dishNameController = TextEditingController(
      text: widget.initialAnalysis.dishName,
    );
    _analysis = widget.initialAnalysis.items.isNotEmpty
        ? widget.initialAnalysis.withRecalculatedItems(
            widget.initialAnalysis.items,
          )
        : widget.initialAnalysis;
  }

  @override
  void dispose() {
    _dishNameController.dispose();
    super.dispose();
  }

  void _updateItems(List<FoodItem> nextItems) {
    setState(() {
      _analysis = _analysis.withRecalculatedItems(
        nextItems,
        dishName: _dishNameController.text.trim().isEmpty
            ? _analysis.dishName
            : _dishNameController.text.trim(),
      );
    });
  }

  void _adjustGrams(int index, double delta) {
    final current = _analysis.items[index];
    final targetGrams = (current.portionGrams + delta).clamp(10.0, 2000.0);
    final nextItems = List<FoodItem>.of(_analysis.items);
    nextItems[index] = current.scaleToGrams(targetGrams);
    _updateItems(nextItems);
  }

  void _addPresetIngredient(FoodItem preset) {
    final nextItems = List<FoodItem>.of(_analysis.items)..add(preset);
    _updateItems(nextItems);
  }

  void _removeIngredient(int index) {
    final nextItems = List<FoodItem>.of(_analysis.items)..removeAt(index);
    _updateItems(nextItems);
  }

  Future<void> _openIngredientDialog({int? editIndex}) async {
    final existing = editIndex != null ? _analysis.items[editIndex] : null;
    final edited = await showDialog<FoodItem>(
      context: context,
      builder: (_) => _IngredientDialog(initialItem: existing),
    );

    if (edited == null || !mounted) return;

    final nextItems = List<FoodItem>.of(_analysis.items);
    if (editIndex != null) {
      nextItems[editIndex] = edited;
    } else {
      nextItems.add(edited);
    }
    _updateItems(nextItems);
  }

  void _confirmAnalysis() {
    final cleanName = _dishNameController.text.trim();
    if (cleanName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Escribe un nombre para el platillo.')),
      );
      return;
    }

    if (_analysis.items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Agrega al menos un ingrediente antes de confirmar.'),
        ),
      );
      return;
    }

    final finalResult = _analysis.withRecalculatedItems(
      _analysis.items,
      dishName: cleanName,
    );
    Navigator.of(context).pop(finalResult);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Revisar y editar',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (widget.imageFile != null) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: SizedBox(
                    height: 150,
                    child: Image.file(widget.imageFile!, fit: BoxFit.cover),
                  ),
                ),
                const SizedBox(height: 14),
              ],
              TextField(
                controller: _dishNameController,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  labelText: 'Nombre del platillo',
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE0E6E0)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Totales recalculados',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          '${_analysis.confidence}% confianza IA',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppTheme.primaryGreen,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _TotalTile(
                            label: 'Calorías',
                            value: '${_analysis.totalCalories} kcal',
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _TotalTile(
                            label: 'Prot',
                            value: '${_analysis.totalProteinG} g',
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _TotalTile(
                            label: 'Carb',
                            value: '${_analysis.totalCarbsG} g',
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _TotalTile(
                            label: 'Gras',
                            value: '${_analysis.totalFatG} g',
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              const Text(
                '¿Ingredientes ocultos? Agrégalos con un toque:',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: _hiddenIngredientPresets.map((preset) {
                  return ActionChip(
                    avatar: const Icon(
                      Icons.add,
                      size: 16,
                      color: AppTheme.primaryGreen,
                    ),
                    label: Text(
                      preset.name,
                      style: const TextStyle(fontSize: 12),
                    ),
                    backgroundColor: AppTheme.lightGreenSurface,
                    onPressed: () => _addPresetIngredient(preset),
                  );
                }).toList(),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Ingredientes (${_analysis.items.length})',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () => _openIngredientDialog(),
                    icon: const Icon(Icons.add_circle_outline, size: 18),
                    label: const Text('Agregar manual'),
                  ),
                ],
              ),
              if (_analysis.items.isEmpty)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE0E6E0)),
                  ),
                  child: const Text(
                    'No hay ingredientes en la lista. Agrega uno manualmente o con los chips de arriba.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.black54, fontSize: 13),
                  ),
                )
              else
                ...List<Widget>.generate(_analysis.items.length, (index) {
                  final item = _analysis.items[index];
                  return _EditableFoodCard(
                    item: item,
                    onDecrease: item.portionGrams > 10
                        ? () => _adjustGrams(index, -10)
                        : null,
                    onIncrease: () => _adjustGrams(index, 10),
                    onEdit: () => _openIngredientDialog(editIndex: index),
                    onDelete: () => _removeIngredient(index),
                  );
                }),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: _confirmAnalysis,
                style: FilledButton.styleFrom(
                  backgroundColor: AppTheme.primaryGreen,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                icon: const Icon(Icons.check_circle_outline),
                label: const Text(
                  'Confirmar platillo',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TotalTile extends StatelessWidget {
  const _TotalTile({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
      decoration: BoxDecoration(
        color: AppTheme.scaffoldBackground,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(fontSize: 11, color: Colors.black54),
          ),
        ],
      ),
    );
  }
}

class _EditableFoodCard extends StatelessWidget {
  const _EditableFoodCard({
    required this.item,
    required this.onDecrease,
    required this.onIncrease,
    required this.onEdit,
    required this.onDelete,
  });

  final FoodItem item;
  final VoidCallback? onDecrease;
  final VoidCallback onIncrease;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE0E6E0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  item.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
              ),
              Text(
                '${item.calories} kcal',
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  color: AppTheme.primaryGreen,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'P: ${item.proteinG}g  •  C: ${item.carbsG}g  •  G: ${item.fatG}g',
            style: const TextStyle(fontSize: 12, color: Colors.black54),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              IconButton.outlined(
                onPressed: onDecrease,
                icon: const Icon(Icons.remove, size: 18),
                visualDensity: VisualDensity.compact,
                tooltip: '-10 g',
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Text(
                  '${item.portionGrams} g',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
              IconButton.outlined(
                onPressed: onIncrease,
                icon: const Icon(Icons.add, size: 18),
                visualDensity: VisualDensity.compact,
                tooltip: '+10 g',
              ),
              const Spacer(),
              IconButton(
                onPressed: onEdit,
                icon: const Icon(Icons.edit_outlined, size: 20),
                tooltip: 'Editar valores',
              ),
              IconButton(
                onPressed: onDelete,
                icon: const Icon(
                  Icons.delete_outline,
                  size: 20,
                  color: Color(0xFFC62828),
                ),
                tooltip: 'Eliminar ingrediente',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _IngredientDialog extends StatefulWidget {
  const _IngredientDialog({this.initialItem});

  final FoodItem? initialItem;

  @override
  State<_IngredientDialog> createState() => _IngredientDialogState();
}

class _IngredientDialogState extends State<_IngredientDialog> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _gramsCtrl;
  late final TextEditingController _caloriesCtrl;
  late final TextEditingController _proteinCtrl;
  late final TextEditingController _carbsCtrl;
  late final TextEditingController _fatCtrl;

  String? _errorText;

  @override
  void initState() {
    super.initState();
    final item = widget.initialItem;
    _nameCtrl = TextEditingController(text: item?.name ?? '');
    _gramsCtrl = TextEditingController(
      text: item != null ? item.portionGrams.toString() : '100',
    );
    _caloriesCtrl = TextEditingController(
      text: item != null ? item.calories.toString() : '0',
    );
    _proteinCtrl = TextEditingController(
      text: item != null ? item.proteinG.toString() : '0',
    );
    _carbsCtrl = TextEditingController(
      text: item != null ? item.carbsG.toString() : '0',
    );
    _fatCtrl = TextEditingController(
      text: item != null ? item.fatG.toString() : '0',
    );
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _gramsCtrl.dispose();
    _caloriesCtrl.dispose();
    _proteinCtrl.dispose();
    _carbsCtrl.dispose();
    _fatCtrl.dispose();
    super.dispose();
  }

  double? _parseNum(String raw) {
    return double.tryParse(raw.trim().replaceAll(',', '.'));
  }

  void _applyProportionalScale() {
    final base = widget.initialItem;
    final newGrams = _parseNum(_gramsCtrl.text);
    if (base == null || newGrams == null || newGrams <= 0) return;

    final scaled = base.scaleToGrams(newGrams);
    setState(() {
      _caloriesCtrl.text = scaled.calories.toString();
      _proteinCtrl.text = scaled.proteinG.toString();
      _carbsCtrl.text = scaled.carbsG.toString();
      _fatCtrl.text = scaled.fatG.toString();
      _errorText = null;
    });
  }

  void _submit() {
    final name = _nameCtrl.text.trim();
    final grams = _parseNum(_gramsCtrl.text);
    final calories = _parseNum(_caloriesCtrl.text);
    final protein = _parseNum(_proteinCtrl.text);
    final carbs = _parseNum(_carbsCtrl.text);
    final fat = _parseNum(_fatCtrl.text);

    if (name.isEmpty) {
      setState(() => _errorText = 'Escribe el nombre del ingrediente.');
      return;
    }

    if (grams == null ||
        calories == null ||
        protein == null ||
        carbs == null ||
        fat == null ||
        grams < 0 ||
        calories < 0 ||
        protein < 0 ||
        carbs < 0 ||
        fat < 0) {
      setState(
        () => _errorText = 'Usa únicamente números válidos mayores o iguales a 0.',
      );
      return;
    }

    Navigator.of(context).pop(
      FoodItem(
        name: name,
        portionGrams: double.parse(grams.toStringAsFixed(1)),
        calories: calories.round(),
        proteinG: double.parse(protein.toStringAsFixed(1)),
        carbsG: double.parse(carbs.toStringAsFixed(1)),
        fatG: double.parse(fat.toStringAsFixed(1)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.initialItem != null;

    return AlertDialog(
      title: Text(isEditing ? 'Editar ingrediente' : 'Agregar ingrediente'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _nameCtrl,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(labelText: 'Nombre'),
            ),
            const SizedBox(height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: TextField(
                    controller: _gramsCtrl,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(labelText: 'Porción (g)'),
                  ),
                ),
                if (isEditing) ...[
                  const SizedBox(width: 8),
                  TextButton(
                    onPressed: _applyProportionalScale,
                    child: const Text('Recalcular'),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _caloriesCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Calorías (kcal)'),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _proteinCtrl,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(labelText: 'Prot (g)'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _carbsCtrl,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(labelText: 'Carb (g)'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _fatCtrl,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(labelText: 'Gras (g)'),
                  ),
                ),
              ],
            ),
            if (_errorText != null) ...[
              const SizedBox(height: 10),
              Text(
                _errorText!,
                style: const TextStyle(color: Color(0xFFB71C1C), fontSize: 12),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _submit,
          style: FilledButton.styleFrom(backgroundColor: AppTheme.primaryGreen),
          child: const Text('Guardar'),
        ),
      ],
    );
  }
}