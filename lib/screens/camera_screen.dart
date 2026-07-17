import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../theme.dart';

/// Caméra intégrée à l'app (plugin `camera` : CameraX sur Android,
/// getUserMedia sur le Web) : aperçu en direct, capture, prévisualisation,
/// puis retour de la photo (XFile) à l'écran appelant.
///
/// Remplace `image_picker` + ImageSource.camera, qui ne peut pas ouvrir de
/// caméra sur un navigateur de bureau (l'attribut `capture` y est ignoré).
class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen>
    with WidgetsBindingObserver {
  CameraController? _controller;
  String? _error;
  bool _capturing = false;

  XFile? _captured;
  Uint8List? _capturedBytes;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initCamera();
  }

  Future<void> _initCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        setState(() => _error =
            'Aucune caméra détectée sur cet appareil. Utilisez la galerie.');
        return;
      }
      // Caméra arrière de préférence (documents) ; sinon la première.
      final camera = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );
      final controller = CameraController(
        camera,
        ResolutionPreset.high,
        enableAudio: false,
      );
      await controller.initialize();
      if (!mounted) {
        await controller.dispose();
        return;
      }
      setState(() => _controller = controller);
    } on CameraException catch (e) {
      setState(() => _error = switch (e.code) {
            'CameraAccessDenied' ||
            'cameraPermission' =>
              'Accès à la caméra refusé. Autorisez la caméra dans les '
                  'réglages, puis réessayez.',
            _ => 'Impossible d’ouvrir la caméra (${e.code}).',
          });
    } catch (e) {
      setState(() => _error = 'Impossible d’ouvrir la caméra : $e');
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;
    if (state == AppLifecycleState.inactive) {
      controller.dispose();
      _controller = null;
    } else if (state == AppLifecycleState.resumed) {
      _initCamera();
    }
  }

  Future<void> _capture() async {
    final controller = _controller;
    if (controller == null || _capturing) return;
    setState(() => _capturing = true);
    try {
      final file = await controller.takePicture();
      final bytes = await file.readAsBytes();
      if (!mounted) return;
      setState(() {
        _captured = file;
        _capturedBytes = bytes;
      });
    } on CameraException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Échec de la capture (${e.code}).')),
        );
      }
    } finally {
      if (mounted) setState(() => _capturing = false);
    }
  }

  void _retake() {
    setState(() {
      _captured = null;
      _capturedBytes = null;
    });
  }

  void _use() {
    final captured = _captured;
    if (captured != null) Navigator.pop(context, captured);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Photographier le document'),
        backgroundColor: SopatColors.green,
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    // 1. Photo capturée → prévisualisation + Reprendre / Utiliser
    if (_capturedBytes != null) {
      return Column(
        children: [
          Expanded(
            child: Center(
              child: Image.memory(_capturedBytes!, fit: BoxFit.contain),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _retake,
                      icon: const Icon(Icons.refresh, color: SopatColors.ivory),
                      label: const Text('Reprendre',
                          style: TextStyle(color: SopatColors.ivory)),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: SopatColors.ivory),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _use,
                      icon: const Icon(Icons.check),
                      label: const Text('Utiliser'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    }

    // 2. Erreur (permission refusée, pas de caméra…)
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.no_photography_outlined,
                  size: 56, color: SopatColors.ivory),
              const SizedBox(height: 16),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: SopatColors.ivory),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: () {
                  setState(() => _error = null);
                  _initCamera();
                },
                icon: const Icon(Icons.refresh),
                label: const Text('Réessayer'),
              ),
            ],
          ),
        ),
      );
    }

    // 3. Chargement
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) {
      return const Center(
        child: CircularProgressIndicator(color: SopatColors.ivory),
      );
    }

    // 4. Aperçu en direct + déclencheur
    return Stack(
      fit: StackFit.expand,
      children: [
        Center(child: CameraPreview(controller)),
        Positioned(
          bottom: 32,
          left: 0,
          right: 0,
          child: Center(
            child: GestureDetector(
              onTap: _capturing ? null : _capture,
              child: Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _capturing
                      ? SopatColors.ivory.withValues(alpha: 0.5)
                      : SopatColors.ivory,
                  border: Border.all(color: SopatColors.green, width: 4),
                ),
                child: _capturing
                    ? const Padding(
                        padding: EdgeInsets.all(20),
                        child: CircularProgressIndicator(strokeWidth: 3),
                      )
                    : const Icon(Icons.photo_camera,
                        color: SopatColors.green, size: 32),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
