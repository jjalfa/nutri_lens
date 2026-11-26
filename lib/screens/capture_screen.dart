import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../core/theme/app_theme.dart';
import '../models/food_item.dart';
import '../models/nutrition_analysis.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import '../services/image_capture_service.dart';
import '../services/n8n_api_service.dart';
import 'review_edit_screen.dart';

class CaptureScreen extends StatefulWidget {
  const CaptureScreen({super.key});

  @override
  State<CaptureScreen> createState() => _CaptureScreenState();
}

class _CaptureScreenState extends State<CaptureScreen> {
  final _captureService = ImageCaptureService();
  final _apiService = N8nApiService();
  final _authService = AuthService();
  final _firestoreService = FirestoreService();

  CapturedImage? _capturedImage;
  bool _isAnalyzing = false;
  bool _isSaving = false;
  String? _errorMessage;
  NutritionAnalysis? _analysis;
  bool _isConfirmed = false;

  Future<void> _selectImage(ImageSource source) async {
    setState(() {
      _errorMessage = null;
      _analysis = null;
      _isConfirmed = false;
    });

    try {
      final image = await _captureService.pickAndCompress(source);
      if (!mounted || image == null) return;

      setState(() => _capturedImage = image);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'No se pudo obtener la imagen: $error';
      });
    }
  }

  Future<void> _saveToFirestore(NutritionAnalysis confirmed) async {
    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    try {
      final user = await _authService.ensureSignedIn();
      if (user == null) {
        throw StateError('No se pudo verificar la sesión de usuario.');
      }

      await _firestoreService.addMeal(uid: user.uid, analysis: confirmed);
      if (!mounted) return;

      Navigator.of(context).pop(confirmed);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _errorMessage =
            'El platillo se editó, pero no se pudo guardar en Firestore: $error';
      });
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Future<void> _openReviewEditor(NutritionAnalysis initial) async {
    final confirmed = await Navigator.of(context).push<NutritionAnalysis>(
      MaterialPageRoute<NutritionAnalysis>(
        builder: (_) => ReviewEditScreen(
          initialAnalysis: initial,
          imageFile: _capturedImage?.file,
        ),
      ),
    );

    if (!mounted || confirmed == null) return;

    setState(() {
      _analysis = confirmed;
      _isConfirmed = true;
    });

    await _saveToFirestore(confirmed);
  }

  Future<void> _analyzeImage() async {
    final image = _capturedImage;
    if (image == null) return;

    setState(() {
      _isAnalyzing = true;
      _errorMessage = null;
      _analysis = null;
      _isConfirmed = false;
    });

    try {
      final result = await _apiService.analyzeFoodImage(
        imageBytes: image.bytes,
        mimeType: image.mimeType,
      );

      if (!mounted) return;
      setState(() => _analysis = result);

      if (result.isFood) {
        await _openReviewEditor(result);
      }
    } on N8nApiException catch (error) {
      if (!mounted) return;
      setState(() => _errorMessage = error.message);
    } catch (error) {
      if (!mounted) return;
      setState(() => _errorMessage = 'Error inesperado: $error');
    } finally {
      if (mounted) {
        setState(() => _isAnalyzing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isBusy = _isAnalyzing || _isSaving;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Capturar alimento',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: isBusy
                          ? null
                          : () => _selectImage(ImageSource.camera),
                      icon: const Icon(Icons.camera_alt_outlined),
                      label: const Text('Cámara'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: isBusy
                          ? null
                          : () => _selectImage(ImageSource.gallery),
                      icon: const Icon(Icons.photo_library_outlined),
                      label: const Text('Galería'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                height: 240,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE0E6E0)),
                ),
                clipBehavior: Clip.antiAlias,
                child: _capturedImage == null
                    ? const Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.fastfood_outlined,
                              size: 48,
                              color: Colors.black38,
                            ),
                            SizedBox(height: 8),
                            Text(
                              'Toma una foto o selecciona un platillo',
                              style: TextStyle(color: Colors.black54),
                            ),
                          ],
                        ),
                      )
                    : Image.file(_capturedImage!.file, fit: BoxFit.cover),
              ),
              if (_capturedImage != null) ...[
                const SizedBox(height: 8),
                Text(
                  'Imagen comprimida lista: ${_capturedImage!.sizeKb.toStringAsFixed(1)} KB',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 12, color: Colors.black54),
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: isBusy ? null : _analyzeImage,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppTheme.primaryGreen,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  icon: isBusy
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.auto_awesome),
                  label: Text(
                    _isSaving
                        ? 'Guardando en Firestore...'
                        : _isAnalyzing
                            ? 'Analizando platillo con IA...'
                            : 'Analizar con IA',
                  ),
                ),
              ],
              if (_errorMessage != null) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFEBEE),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        _errorMessage!,
                        style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFFB71C1C),
                        ),
                      ),
                      if (_isConfirmed && _analysis != null) ...[
                        const SizedBox(height: 10),
                        OutlinedButton.icon(
                          onPressed: _isSaving
                              ? null
                              : () => _saveToFirestore(_analysis!),
                          icon: const Icon(Icons.refresh),
                          label: const Text('Reintentar guardar'),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
              if (_analysis != null) ...[
                const SizedBox(height: 20),
                _AnalysisPreviewSection(
                  analysis: _analysis!,
                  isConfirmed: _isConfirmed,
                  onEditPressed: _analysis!.isFood && !isBusy
                      ? () => _openReviewEditor(_analysis!)
                      : null,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _AnalysisPreviewSection extends StatelessWidget {
  const _AnalysisPreviewSection({
    required this.analysis,
    required this.isConfirmed,
    this.onEditPressed,
  });

  final NutritionAnalysis analysis;
  final bool isConfirmed;
  final VoidCallback? onEditPressed;

  @override
  Widget build(BuildContext context) {
    if (!analysis.isFood) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF8E1),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFFFE082)),
        ),
        child: const Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.warning_amber_rounded, color: Color(0xFFF57F17)),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'No se detectaron alimentos ni bebidas en esta fotografía. Intenta con una toma más clara del platillo.',
                style: TextStyle(fontSize: 13, color: Color(0xFF5D4037)),
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE0E6E0)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      analysis.dishName,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.lightGreenSurface,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      isConfirmed
                          ? 'Confirmado'
                          : '${analysis.confidence}% confianza',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.primaryGreen,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: _MacroChip(
                      label: 'Calorías',
                      value: '${analysis.totalCalories} kcal',
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _MacroChip(
                      label: 'Prot',
                      value: '${analysis.totalProteinG} g',
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _MacroChip(
                      label: 'Carb',
                      value: '${analysis.totalCarbsG} g',
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _MacroChip(
                      label: 'Gras',
                      value: '${analysis.totalFatG} g',
                    ),
                  ),
                ],
              ),
              if (onEditPressed != null) ...[
                const SizedBox(height: 14),
                OutlinedButton.icon(
                  onPressed: onEditPressed,
                  icon: const Icon(Icons.tune),
                  label: const Text('Editar y guardar platillo'),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          'Ingredientes identificados',
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        ...analysis.items.map((item) => _FoodItemTile(item: item)),
      ],
    );
  }
}

class _MacroChip extends StatelessWidget {
  const _MacroChip({required this.label, required this.value});

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

class _FoodItemTile extends StatelessWidget {
  const _FoodItemTile({required this.item});

  final FoodItem item;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE0E6E0)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${item.portionGrams} g  •  P: ${item.proteinG}g  C: ${item.carbsG}g  G: ${item.fatG}g',
                  style: const TextStyle(fontSize: 12, color: Colors.black54),
                ),
              ],
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
    );
  }
}