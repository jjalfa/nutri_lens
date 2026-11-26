import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import '../core/config/app_config.dart';
import '../models/nutrition_analysis.dart';

class N8nApiException implements Exception {
  const N8nApiException(this.message);

  final String message;

  @override
  String toString() => message;
}

class N8nApiService {
  Future<NutritionAnalysis> analyzeFoodImage({
    required Uint8List imageBytes,
    String mimeType = 'image/jpeg',
  }) async {
    final uri = Uri.parse(AppConfig.n8nWebhookUrl);
    final payload = jsonEncode({
      'imageBase64': base64Encode(imageBytes),
      'mimeType': mimeType,
    });

    try {
      final response = await http
          .post(
            uri,
            headers: const {'Content-Type': 'application/json'},
            body: payload,
          )
          .timeout(AppConfig.requestTimeout);

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw N8nApiException(
          'El servidor respondió con código ${response.statusCode}. Verifica el flujo en n8n.',
        );
      }

      final bodyText = utf8.decode(response.bodyBytes);
      final decoded = jsonDecode(bodyText);
      if (decoded is! Map<String, dynamic>) {
        throw const N8nApiException(
          'La respuesta de n8n no tiene formato JSON válido.',
        );
      }

      return NutritionAnalysis.fromWebhookJson(decoded);
    } on TimeoutException {
      throw const N8nApiException(
        'Tiempo de espera agotado (45 s). Revisa tu conexión e intenta de nuevo.',
      );
    } on SocketException {
      throw const N8nApiException(
        'No se pudo conectar con n8n. Verifica que n8n esté iniciado y el túnel ADB activo.',
      );
    } on FormatException catch (error) {
      throw N8nApiException(
        'Respuesta incompatible con el esquema nutricional: ${error.message}',
      );
    }
  }
}