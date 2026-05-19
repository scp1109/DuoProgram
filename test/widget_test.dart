import 'package:flutter_test/flutter_test.dart';

import 'package:duo_program/main.dart';

void main() {
  testWidgets('La app muestra la pantalla de inicio', (WidgetTester tester) async {
    // Carga la aplicacion principal para verificar que abre correctamente.
    await tester.pumpWidget(const DuoProgramApp());

    // La primera pantalla debe mostrar el nombre de la app y el boton de login.
    expect(find.text('DuoProgram'), findsOneWidget);
    expect(find.text('Iniciar sesión'), findsOneWidget);
  });
}
