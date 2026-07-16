import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../models/ocr_result.dart';
import '../models/project.dart';
import '../services/ocr_service.dart';
import 'expense_form_screen.dart';

/// Main screen: capture or pick an image, send it to the OCR backend,
/// display the recognized handwriting.
class ScanScreen extends StatefulWidget {
  const ScanScreen({super.key});

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> {
  // 10.0.2.2 reaches the host machine from the Android emulator.
  // Replace with your PC's LAN IP when testing on a physical device.
  static const _defaultServerUrl = 'http://10.0.2.2:8000';

  final _picker = ImagePicker();
  String _serverUrl = _defaultServerUrl;

  File? _image;
  OcrResult? _result;
  String? _error;
  bool _busy = false;

  OcrService get _service => OcrService(baseUrl: _serverUrl);

  Future<void> _pickImage(ImageSource source) async {
    final picked = await _picker.pickImage(
      source: source,
      maxWidth: 2000,
      imageQuality: 85,
    );
    if (picked == null) return;
    setState(() {
      _image = File(picked.path);
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
      setState(() => _error = 'Unexpected error: $e');
    } finally {
      setState(() => _busy = false);
    }
  }

  Future<void> _editServerUrl() async {
    final controller = TextEditingController(text: _serverUrl);
    final value = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('OCR server URL'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.url,
          decoration: const InputDecoration(hintText: 'http://192.168.1.10:8000'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (value != null && value.isNotEmpty) {
      setState(() => _serverUrl = value.replaceAll(RegExp(r'/+$'), ''));
    }
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
          icon: const Icon(Icons.check_circle, color: Colors.green, size: 40),
          title: Text('Dépense ${created.reference} créée'),
          content: Text(
            budget?.approvedBudget != null
                ? 'En attente de validation par la direction.\n\n'
                    'Budget du projet : ${budget!.spent.toStringAsFixed(0)} / '
                    '${budget.approvedBudget!.toStringAsFixed(0)}'
                    '${budget.percentSpent != null ? ' (${budget.percentSpent}%)' : ''}'
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
      const SnackBar(content: Text('Text copied to clipboard')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('SOPAT Handwriting OCR'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: 'Server URL',
            onPressed: _editServerUrl,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _ImagePreview(image: _image),
          const SizedBox(height: 16),
          if (_busy) const _BusyIndicator(),
          if (_error != null) _ErrorCard(message: _error!, onRetry: _runOcr),
          if (_result != null) ...[
            _ResultCard(result: _result!, onCopy: _copyText),
            const SizedBox(height: 12),
            FilledButton.tonalIcon(
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
                  onPressed: _busy ? null : () => _pickImage(ImageSource.camera),
                  icon: const Icon(Icons.photo_camera),
                  label: const Text('Camera'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _busy ? null : () => _pickImage(ImageSource.gallery),
                  icon: const Icon(Icons.photo_library),
                  label: const Text('Gallery'),
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
  const _ImagePreview({required this.image});

  final File? image;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: image == null
          ? Container(
              height: 220,
              color: theme.colorScheme.surfaceContainerHighest,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.document_scanner_outlined,
                      size: 56, color: theme.colorScheme.outline),
                  const SizedBox(height: 12),
                  Text(
                    'Take a photo of handwritten notes',
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(color: theme.colorScheme.outline),
                  ),
                ],
              ),
            )
          : Image.file(image!, height: 220, fit: BoxFit.cover),
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
          Text('Extracting handwriting…'),
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
    final theme = Theme.of(context);
    return Card(
      color: theme.colorScheme.errorContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(message,
                style: TextStyle(color: theme.colorScheme.onErrorContainer)),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
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

  Color _confidenceColor(BuildContext context, double confidence) {
    if (confidence >= 0.85) return Colors.green;
    if (confidence >= 0.6) return Colors.orange;
    return Theme.of(context).colorScheme.error;
  }

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
                Text('Recognized text', style: theme.textTheme.titleMedium),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.copy),
                  tooltip: 'Copy all',
                  onPressed: onCopy,
                ),
              ],
            ),
            const Divider(),
            for (final line in result.lines)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: SelectableText(line.text,
                          style: theme.textTheme.bodyLarge),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${(line.confidence * 100).round()}%',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: _confidenceColor(context, line.confidence),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 8),
            Text(
              'Overall ${(result.confidence * 100).round()}% · '
              '${result.processingTime.toStringAsFixed(1)}s',
              style: theme.textTheme.labelSmall
                  ?.copyWith(color: theme.colorScheme.outline),
            ),
          ],
        ),
      ),
    );
  }
}
