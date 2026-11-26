import 'package:flutter/material.dart';
import '../core/theme/app_theme.dart';
import '../models/meal_entry.dart';
import '../models/nutrition_analysis.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import 'capture_screen.dart';
import 'history_tab.dart';
import 'review_edit_screen.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[
      const _HomeTab(),
      const HistoryTab(),
      const _ProfileTab(),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Nutri Lens',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      body: SafeArea(child: pages[_selectedIndex]),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) {
          setState(() => _selectedIndex = index);
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Inicio',
          ),
          NavigationDestination(
            icon: Icon(Icons.history_outlined),
            selectedIcon: Icon(Icons.history),
            label: 'Historial',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Perfil',
          ),
        ],
      ),
    );
  }
}

class _HomeTab extends StatefulWidget {
  const _HomeTab();

  @override
  State<_HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<_HomeTab> {
  static const int _dailyCalorieGoal = 2000;

  final _authService = AuthService();
  final _firestoreService = FirestoreService();

  Future<void> _openCaptureFlow() async {
    final saved = await Navigator.of(context).push<NutritionAnalysis>(
      MaterialPageRoute<NutritionAnalysis>(
        builder: (_) => const CaptureScreen(),
      ),
    );

    if (saved == null || !mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '"${saved.dishName}" (${saved.totalCalories} kcal) guardado en tu historial.',
        ),
      ),
    );
  }

  Future<void> _editTodayMeal(String uid, MealEntry meal) async {
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
        const SnackBar(content: Text('Platillo actualizado.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al actualizar: $error')),
      );
    }
  }

  Future<void> _deleteTodayMeal(String uid, MealEntry meal) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Eliminar registro'),
        content: Text(
          '¿Deseas eliminar "${meal.analysis.dishName}" de hoy?',
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
    await _firestoreService.deleteMeal(uid: uid, mealId: meal.id);
  }

  @override
  Widget build(BuildContext context) {
    final uid = _authService.currentUid;
    final todayKey = formatDateKey(DateTime.now());
    final stream = uid == null
        ? Stream<List<MealEntry>>.value(const <MealEntry>[])
        : _firestoreService.watchMealsByDate(uid, todayKey);

    return StreamBuilder<List<MealEntry>>(
      stream: stream,
      initialData: const <MealEntry>[],
      builder: (context, snapshot) {
        final meals = snapshot.data ?? const <MealEntry>[];
        final summary = DailyNutritionSummary.fromMeals(meals);
        final progress =
            (summary.totalCalories / _dailyCalorieGoal).clamp(0.0, 1.0);

        return SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                '¿Qué vamos a analizar hoy?',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 16),
              InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: _openCaptureFlow,
                child: Ink(
                  padding: const EdgeInsets.symmetric(
                    vertical: 26,
                    horizontal: 20,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryGreen,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Column(
                    children: [
                      Icon(
                        Icons.camera_alt_rounded,
                        size: 46,
                        color: Colors.white,
                      ),
                      SizedBox(height: 10),
                      Text(
                        'Capturar alimento',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Toma una foto o elige una imagen',
                        style: TextStyle(color: Colors.white70, fontSize: 14),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 22),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Tu día en números',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
                  ),
                  Text(
                    '${summary.totalCalories} / $_dailyCalorieGoal kcal',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.primaryGreen,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 8,
                  backgroundColor: AppTheme.lightGreenSurface,
                  color: AppTheme.primaryGreen,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _MacroMiniCard(
                      label: 'Calorías',
                      value: '${summary.totalCalories} kcal',
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _MacroMiniCard(
                      label: 'Prot',
                      value: '${summary.totalProteinG} g',
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _MacroMiniCard(
                      label: 'Carb',
                      value: '${summary.totalCarbsG} g',
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _MacroMiniCard(
                      label: 'Gras',
                      value: '${summary.totalFatG} g',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 22),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Comidas de hoy (${meals.length})',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              if (snapshot.hasError)
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFEBEE),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'Error leyendo Firestore: ${snapshot.error}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFFB71C1C),
                    ),
                  ),
                )
              else if (meals.isEmpty)
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFE0E6E0)),
                  ),
                  child: const Text(
                    'Todavía no registras alimentos hoy. Toca "Capturar alimento" para comenzar.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 13, color: Colors.black54),
                  ),
                )
              else
                ...meals.map(
                  (meal) => MealHistoryCard(
                    meal: meal,
                    onEdit:
                        uid == null ? null : () => _editTodayMeal(uid, meal),
                    onDelete:
                        uid == null ? null : () => _deleteTodayMeal(uid, meal),
                  ),
                ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppTheme.lightGreenSurface,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.info_outline,
                      size: 20,
                      color: AppTheme.primaryGreen,
                    ),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Estimación orientativa generada por IA con fines informativos. No sustituye valoración médica ni nutricional profesional.',
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFF1B5E20),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ProfileTab extends StatefulWidget {
  const _ProfileTab();

  @override
  State<_ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends State<_ProfileTab> {
  final _authService = AuthService();
  final _firestoreService = FirestoreService();

  bool _isSyncing = false;
  String? _statusMessage;

  Future<void> _testFirestoreConnection() async {
    setState(() {
      _isSyncing = true;
      _statusMessage = null;
    });

    try {
      final user = await _authService.ensureSignedIn();
      if (user == null) {
        throw StateError('No se pudo obtener una sesión activa.');
      }

      await _firestoreService.syncUserProfile(user.uid);
      if (!mounted) return;

      setState(() {
        _statusMessage = 'Conectado: perfil sincronizado en Cloud Firestore.';
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _statusMessage = 'Error de conexión: $error';
      });
    } finally {
      if (mounted) {
        setState(() => _isSyncing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = _authService.currentUid;
    final todayKey = formatDateKey(DateTime.now());
    final todayStream = uid == null
        ? Stream<List<MealEntry>>.value(const <MealEntry>[])
        : _firestoreService.watchMealsByDate(uid, todayKey);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          StreamBuilder<List<MealEntry>>(
            stream: todayStream,
            initialData: const <MealEntry>[],
            builder: (context, snapshot) {
              final count = snapshot.data?.length ?? 0;

              return Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE0E6E0)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const CircleAvatar(
                          backgroundColor: AppTheme.lightGreenSurface,
                          child:
                              Icon(Icons.person, color: AppTheme.primaryGreen),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Sesión de Nutri Lens',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Text(
                              'Plan Gratuito • $count / 3 registros hoy',
                              style: const TextStyle(
                                fontSize: 13,
                                color: Colors.black54,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'ID de usuario (Firebase Auth):',
                      style: TextStyle(fontSize: 12, color: Colors.black54),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      uid ?? 'Sin sesión activa',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _isSyncing ? null : _testFirestoreConnection,
            style: FilledButton.styleFrom(
              backgroundColor: AppTheme.primaryGreen,
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            icon: _isSyncing
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.cloud_done_outlined),
            label: Text(
              _isSyncing
                  ? 'Sincronizando...'
                  : 'Probar conexión con Firestore',
            ),
          ),
          if (_statusMessage != null) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _statusMessage!.startsWith('Conectado')
                    ? AppTheme.lightGreenSurface
                    : const Color(0xFFFFEBEE),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                _statusMessage!,
                style: TextStyle(
                  fontSize: 13,
                  color: _statusMessage!.startsWith('Conectado')
                      ? const Color(0xFF1B5E20)
                      : const Color(0xFFB71C1C),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _MacroMiniCard extends StatelessWidget {
  const _MacroMiniCard({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE0E6E0)),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(fontSize: 12, color: Colors.black54),
          ),
        ],
      ),
    );
  }
}