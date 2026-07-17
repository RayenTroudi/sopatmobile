import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/ocr_result.dart';
import '../models/project.dart';
import '../services/ocr_service.dart';
import '../services/sopat_api.dart';
import '../theme.dart';
import 'camera_screen.dart';
import 'expense_form_screen.dart';
import 'login_screen.dart';

/// Écran principal : photographier ou choisir une image, l'envoyer au
/// backend OCR, afficher le texte reconnu puis créer la dépense SOPAT.
class ScanScreen extends StatefulWidget {
  const ScanScreen({super.key});

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> {
  // Backend OCR déployé sur Railway — accessible depuis n'importe quel
  // réseau (plus besoin d'être sur le Wi-Fi du PC). Modifiable via le
  // bouton serveur dans la barre du haut.
  static const _defaultServerUrl = 'https://sopatbackend-production.up.railway.app';
  static const _prefsOcrUrl = 'ocr_server_url';

  final _picker = ImagePicker();
  String _serverUrl = _defaultServerUrl;

  XFile? _image;
  Uint8List? _imageBytes;
  OcrResult? _result;
  String? _error;
  bool _busy = false;

  OcrService get _service => OcrService(baseUrl: _serverUrl);

  @override
  void initState() {
    super.initState();
    SharedPreferences.getInstance().then((prefs) {
      final saved = prefs.getString(_prefsOcrUrl);
      if (saved != null && mounted) setState(() => _serverUrl = saved);
    });
  }

  /// Caméra intégrée (aperçu → capture → prévisualisation → utiliser).
  Future<void> _openCamera() async {
    final captured = await Navigator.push<XFile>(
      context,
      MaterialPageRoute(builder: (_) => const CameraScreen()),
    );
    if (captured != null) await _useImage(captured);
  }

  /// Sélection depuis la galerie / les fichiers.
  Future<void> _pickFromGallery() async {
    final XFile? picked;
    try {
      picked = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 2000,
        imageQuality: 85,
      );
    } on PlatformException catch (e) {
      setState(() {
        _error = 'Impossible d’ouvrir la galerie (${e.code}). '
            'Vérifiez l’accès aux photos dans les réglages.';
      });
      return;
    } catch (e) {
      setState(() => _error = 'Erreur lors de la sélection de l’image : $e');
      return;
    }
    if (picked == null) return; // annulé par l'utilisateur
    await _useImage(picked);
  }

  Future<void> _useImage(XFile picked) async {
    final bytes = await picked.readAsBytes();
    if (bytes.isEmpty) {
      setState(() =>
          _error = 'L’image sélectionnée est vide ou illisible. Reprenez la photo.');
      return;
    }
    setState(() {
      _image = picked;
      _imageBytes = bytes;
      _result = null;
      _error = null;
    });
    await _runOcr();
  }

  Future<void> _runOcr() async {
    final image = _image;
    if (image == null) return;
    setState(() {
      _busy = true;
      _error = null;
      _result = null;
    });
    try {
      final result = await _service.extractText(image);
      setState(() => _result = result);
    } on OcrException catch (e) {
      setState(() => _error = e.message);
    } catch (e) {
      setState(() => _error = 'Erreur inattendue : $e');
    } finally {
      setState(() => _busy = false);
    }
  }

  Future<void> _editServerUrl() async {
    final controller = TextEditingController(text: _serverUrl);
    final value = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Serveur OCR'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.url,
          decoration:
              const InputDecoration(hintText: 'http://192.168.1.10:8000'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Enregistrer'),
          ),
        ],
      ),
    );
    if (value != null && value.isNotEmpty) {
      final cleaned = value.replaceAll(RegExp(r'/+$'), '');
      setState(() => _serverUrl = cleaned);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefsOcrUrl, cleaned);
    }
  }

  Future<void> _logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Déconnexion'),
        content: const Text('Voulez-vous vous déconnecter ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Se déconnecter'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await SopatApi.instance.logout();
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
  }

  Future<void> _createExpense() async {
    final text = _result?.text;
    if (text == null || text.isEmpty) return;
    final created = await Navigator.push<ExpenseCreated>(
      context,
      MaterialPageRoute(
        builder: (_) => ExpenseFormScreen(ocrText: text, image: _image),
      ),
    );
    if (created != null && mounted) {
      final budget = created.budget;
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          icon: const Icon(Icons.check_circle,
              color: SopatColors.emerald, size: 40),
          title: Text('Dépense ${created.reference} créée'),
          content: Text(
            budget?.approvedBudget != null
                ? 'En attente de validation par la direction.\n\n'
                    'Budget consommé : ${formatAmount(budget!.spent)} / '
                    '${formatAmount(budget.approvedBudget!)}'
                    '${budget.percentSpent != null ? ' (${budget.percentSpent} %)' : ''}\n'
                    'Dépenses en attente : +${formatAmount(budget.pendingTotal)}'
                : 'En attente de validation par la direction.',
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    }
  }

  void _copyText() {
    final text = _result?.text;
    if (text == null || text.isEmpty) return;
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Texte copié')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final email = SopatApi.instance.email;
    return Scaffold(
      appBar: AppBar(
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('SOPAT',
                style: TextStyle(letterSpacing: 3, fontSize: 16)),
            Text('Scan des dépenses',
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w400,
                    color: Color(0xBBF5F0E8))),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.dns_outlined),
            tooltip: 'Serveur OCR',
            onPressed: _editServerUrl,
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Déconnexion',
            onPressed: _logout,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (email != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                'Connecté : $email',
                style: const TextStyle(
                    fontSize: 12, color: SopatColors.textMuted),
              ),
            ),
          _ImagePreview(imageBytes: _imageBytes),
          const SizedBox(height: 16),
          if (_busy) const _BusyIndicator(),
          if (_error != null) _ErrorCard(message: _error!, onRetry: _runOcr),
          if (_result != null) ...[
            _ResultCard(result: _result!, onCopy: _copyText),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _createExpense,
              icon: const Icon(Icons.receipt_long),
              label: const Text('Créer une dépense SOPAT'),
            ),
          ],
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: _busy ? null : _openCamera,
                  icon: const Icon(Icons.photo_camera),
                  label: const Text('Caméra'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _busy ? null : _pickFromGallery,
                  icon: const Icon(Icons.photo_library),
                  label: const Text('Galerie'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ImagePreview extends StatelessWidget {
  const _ImagePreview({required this.imageBytes});

  final Uint8List? imageBytes;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: imageBytes == null
          ? Container(
              height: 220,
              decoration: BoxDecoration(
                color: SopatColors.surface,
                border: Border.all(color: SopatColors.border),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.document_scanner_outlined,
                      size: 56, color: SopatColors.textMuted),
                  SizedBox(height: 12),
                  Text(
                    'Photographiez un reçu ou une note manuscrite',
                    style: TextStyle(color: SopatColors.textMuted),
                  ),
                ],
              ),
            )
          : Image.memory(imageBytes!, height: 220, fit: BoxFit.cover),
    );
  }
}

class _BusyIndicator extends StatelessWidget {
  const _BusyIndicator();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 24),
      child: Column(
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 12),
          Text('Extraction du texte…',
              style: TextStyle(color: SopatColors.textMuted)),
        ],
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: const Color(0xFFFBEEEC),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: SopatColors.red.withValues(alpha: 0.3)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(message, style: const TextStyle(color: SopatColors.red)),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh, color: SopatColors.accent),
              label: const Text('Réessayer',
                  style: TextStyle(color: SopatColors.accent)),
            ),
          ],
        ),
      ),
    );
  }
}

class _ResultCard extends StatelessWidget {
  const _ResultCard({required this.result, required this.onCopy});

  final OcrResult result;
  final VoidCallback onCopy;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('Texte reconnu',
                    style: theme.textTheme.titleMedium
                        ?.copyWith(color: SopatColors.text)),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.copy, color: SopatColors.textMuted),
                  tooltip: 'Tout copier',
                  onPressed: onCopy,
                ),
              ],
            ),
            const Divider(),
            for (final line in result.lines)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: SelectableText(line.text,
                    style: theme.textTheme.bodyLarge
                        ?.copyWith(color: SopatColors.text)),
              ),
            const SizedBox(height: 8),
            Text(
              '${result.processingTime.toStringAsFixed(1)}s',
              style: theme.textTheme.labelSmall
                  ?.copyWith(color: SopatColors.textMuted),
            ),
          ],
        ),
      ),
    );
  }
}
