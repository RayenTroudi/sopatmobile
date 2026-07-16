import 'package:flutter/material.dart';

import 'screens/scan_screen.dart';
import 'services/sopat_api.dart';

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
      title: 'SOPAT OCR',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF2E7D32)),
        useMaterial3: true,
      ),
      home: const ScanScreen(),
    );
  }
}
