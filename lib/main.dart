import 'package:flutter/material.dart';

import 'screens/login_screen.dart';
import 'screens/scan_screen.dart';
import 'services/sopat_api.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SopatApi.instance.init();
  runApp(const SopatOcrApp());
}

class SopatOcrApp extends StatelessWidget {
  const SopatOcrApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SOPAT Réalisation',
      debugShowCheckedModeBanner: false,
      theme: sopatTheme(),
      // Connexion obligatoire au premier lancement ; « Se souvenir de moi »
      // conserve la session (cookie iron-session) entre les lancements.
      home: SopatApi.instance.isLoggedIn
          ? const ScanScreen()
          : const LoginScreen(),
    );
  }
}
