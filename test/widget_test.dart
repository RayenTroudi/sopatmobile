import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sopat_ocr/main.dart';
import 'package:sopat_ocr/screens/scan_screen.dart';
import 'package:sopat_ocr/theme.dart';
import 'package:flutter/material.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('app opens on the login screen when logged out', (tester) async {
    await tester.pumpWidget(const SopatOcrApp());
    await tester.pumpAndSettle();

    expect(find.text('Connexion'), findsOneWidget);
    expect(find.text('Se connecter'), findsOneWidget);
    expect(find.text('Se souvenir de moi'), findsOneWidget);
    expect(find.text('Email'), findsOneWidget);
    expect(find.text('Mot de passe'), findsOneWidget);
  });

  testWidgets('scan screen renders with action buttons', (tester) async {
    await tester.pumpWidget(
      MaterialApp(theme: sopatTheme(), home: const ScanScreen()),
    );
    await tester.pumpAndSettle();

    expect(find.text('Caméra'), findsOneWidget);
    expect(find.text('Galerie'), findsOneWidget);
    expect(
      find.text('Photographiez un reçu ou une note manuscrite'),
      findsOneWidget,
    );
  });
}
