import 'package:flutter/material.dart';
import '../core/theme/app_theme.dart';
import '../models/meal_entry.dart';
import '../models/nutrition_analysis.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import 'review_edit_screen.dart';

class HistoryTab extends StatefulWidget {
  const HistoryTab({super.key});

  @override
  State<HistoryTab> createState() => _HistoryTabState();
}

class _HistoryTabState extends State<HistoryTab> {
  final _authService = AuthService();
  final _firestoreService = FirestoreService();

  DateTime _selectedDate = DateTime.now();

  bool get _isToday =>
      formatDateKey(_selectedDate) == formatDateKey(DateTime.now());

  void _shiftDays(int days) {
    final next = _selectedDate.add(Duration(days: days));
    final today = DateTime.now();
    final nextKey = formatDateKey(next);
    final todayKey = formatDateKey(today);
    if (nextKey.compareTo(todayKey) > 0) return;
    setState(() => _selectedDate = next);
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2024, 1, 1),
      lastDate: DateTime.now(),
    );
    if (picked == null || !mounted) return;
    setState(() => _selectedDate = picked);
  }

  Future<void> _editMeal(String uid, MealEntry meal) async {
    final edited = await Navigator.of(context).push<NutritionAnalysis>(
      MaterialPageRoute<NutritionAnalysis>(
        builder: (_) => ReviewEditScreen(initialAnalysis: meal.analysis),
      ),
    );
    if (edited == null || !mounted) return;

    try {
      await _firestoreService.updateMeal(
        uid: uid,
        existing: meal,
        updatedAnalysis: edited,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Registro actualizado en Firestore.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo actualizar: $error')),
      );
    }
  }

  Future<void> _confirmDeleteMeal(String uid, MealEntry meal) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Eliminar registro'),
        content: Text(
          '¿Seguro que deseas eliminar "${meal.analysis.dishName}" (${meal.analysis.totalCalories} kcal)?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFC62828),
            ),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    try {
      await _firestoreService.deleteMeal(uid: uid, mealId: meal.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Registro eliminado.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al eliminar: $error')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = _authService.currentUid;
    final dateKey = formatDateKey(_selectedDate);
    final stream = uid == null
        ? Stream<List<MealEntry>>.value(const <MealEntry>[])
        : _firestoreService.watchMealsByDate(uid, dateKey);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFE0E6E0)),
            ),
            child: Row(
              children: [
                IconButton(
                  onPressed: () => _shiftDays(-1),
                  icon: const Icon(Icons.chevron_left),
                  tooltip: 'Día anterior',
                ),
                Expanded(
                  child: InkWell(
                    borderRadius: BorderRadius.circular(10),
                    onTap: _pickDate,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.calendar_today_outlined,
                            size: 16,
                            color: AppTheme.primaryGreen,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            formatDisplayDate(_selectedDate),
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                IconButton(
                  onPressed: _isToday ? null : () => _shiftDays(1),
                  icon: const Icon(Icons.chevron_right),
                  tooltip: 'Día siguiente',
                ),
              ],
            ),
          ),
        ),
        Expanded(
          child: StreamBuilder<List<MealEntry>>(
            stream: stream,
            initialData: const <MealEntry>[],
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      'No se pudo cargar el historial: ${snapshot.error}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Color(0xFFB71C1C)),
                    ),
                  ),
                );
              }

              final meals = snapshot.data ?? const <MealEntry>[];
              final summary = DailyNutritionSummary.fromMeals(meals);

              return ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                children: [
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppTheme.lightGreenSurface,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _MiniStat(
                          label: 'Calorías',
                          value: '${summary.totalCalories} kcal',
                        ),
                        _MiniStat(
                          label: 'Prot',
                          value: '${summary.totalProteinG} g',
                        ),
                        _MiniStat(
                          label: 'Carb',
                          value: '${summary.totalCarbsG} g',
                        ),
                        _MiniStat(
                          label: 'Gras',
                          value: '${summary.totalFatG} g',
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (meals.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(28),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFE0E6E0)),
                      ),
                      child: Column(
                        children: [
                          const Icon(
                            Icons.restaurant_menu,
                            size: 44,
                            color: Colors.black26,
                          ),
                          const SizedBox(height: 10),
                          Text(
                            'Sin comidas registradas el ${formatDisplayDate(_selectedDate).toLowerCase()}',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              color: Colors.black54,
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    ...meals.map(
                      (meal) => MealHistoryCard(
                        meal: meal,
                        onEdit: uid == null ? null : () => _editMeal(uid, meal),
                        onDelete: uid == null
                            ? null
                            : () => _confirmDeleteMeal(uid, meal),
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}

class MealHistoryCard extends StatelessWidget {
  const MealHistoryCard({
    super.key,
    required this.meal,
    this.onEdit,
    this.onDelete,
  });

  final MealEntry meal;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final a = meal.analysis;
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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      a.dishName,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${formatTime24h(meal.createdAt)}  •  ${a.items.length} ingredientes',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.black54,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                '${a.totalCalories} kcal',
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                  color: AppTheme.primaryGreen,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Text(
                'P: ${a.totalProteinG}g  •  C: ${a.totalCarbsG}g  •  G: ${a.totalFatG}g',
                style: const TextStyle(fontSize: 12, color: Colors.black54),
              ),
              const Spacer(),
              IconButton(
                onPressed: onEdit,
                icon: const Icon(Icons.edit_outlined, size: 20),
                visualDensity: VisualDensity.compact,
                tooltip: 'Editar platillo',
              ),
              IconButton(
                onPressed: onDelete,
                icon: const Icon(
                  Icons.delete_outline,
                  size: 20,
                  color: Color(0xFFC62828),
                ),
                visualDensity: VisualDensity.compact,
                tooltip: 'Eliminar platillo',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 13,
            color: Color(0xFF1B5E20),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: Color(0xFF2E7D32)),
        ),
      ],
    );
  }
}