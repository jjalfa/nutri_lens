import 'package:flutter_test/flutter_test.dart';
import 'package:nutri_lens/main.dart';

void main() {
  testWidgets('Renderiza pantalla inicial de Nutri Lens', (tester) async {
    await tester.pumpWidget(const NutriLensApp());

    expect(find.text('Nutri Lens'), findsOneWidget);
    expect(find.text('Capturar alimento'), findsOneWidget);
    expect(find.text('Inicio'), findsOneWidget);
  });
}