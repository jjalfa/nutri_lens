class AppConfig {
  static const String n8nWebhookUrl =
      'http://127.0.0.1:5678/webhook/nutri-lens-analyze';

  static const Duration requestTimeout = Duration(seconds: 45);
}