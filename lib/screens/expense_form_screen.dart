import 'dart:io';

import 'package:flutter/material.dart';

import '../models/project.dart';
import '../services/expense_parser.dart';
import '../services/sopat_api.dart';
import 'login_screen.dart';

/// Review-and-validate form for an OCR-scanned expense.
///
/// The OCR suggestions pre-fill the fields; the user corrects them, picks
/// the project, and submits. The expense is created `pending` in SOPAT and
/// counts toward the project budget once approved by the direction.
class ExpenseFormScreen extends StatefulWidget {
  const ExpenseFormScreen({super.key, required this.ocrText, this.image});

  final String ocrText;

  /// Photo scannée — jointe à la dépense et affichée dans le panneau admin.
  final File? image;

  @override
  State<ExpenseFormScreen> createState() => _ExpenseFormScreenState();
}

class _ExpenseFormScreenState extends State<ExpenseFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final ExpenseSuggestion _suggestion;

  late final TextEditingController _amountController;
  late final TextEditingController _descriptionController;
  final _categoryController = TextEditingController();
  late DateTime _expenseDate;

  List<Project>? _projects;
  Project? _selectedProject;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _suggestion = ExpenseParser.parse(widget.ocrText);
    _amountController = TextEditingController(text: _suggestion.amount ?? '');
    _descriptionController =
        TextEditingController(text: _suggestion.description ?? '');
    _expenseDate =
        DateTime.tryParse(_suggestion.expenseDate ?? '') ?? DateTime.now();
    _loadProjects();
  }

  Future<bool> _ensureLoggedIn() async {
    if (SopatApi.instance.isLoggedIn) return true;
    final ok = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen(popOnSuccess: true)),
    );
    return ok == true;
  }

  Future<void> _loadProjects() async {
    if (!await _ensureLoggedIn()) {
      if (mounted) Navigator.pop(context);
      return;
    }
    try {
      final projects = await SopatApi.instance.fetchProjects();
      if (mounted) setState(() => _projects = projects);
    } on SopatApiException catch (e) {
      if (e.isAuthError) {
        await SopatApi.instance.logout();
        if (mounted) {
          setState(() {});
          _loadProjects();
        }
        return;
      }
      if (mounted) setState(() => _error = e.message);
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _expenseDate,
      firstDate: DateTime(2015),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (picked != null) setState(() => _expenseDate = picked);
  }

  String get _dateLabel =>
      '${_expenseDate.year}-${_expenseDate.month.toString().padLeft(2, '0')}-${_expenseDate.day.toString().padLeft(2, '0')}';

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final created = await SopatApi.instance.createExpense(
        projectId: _selectedProject?.id,
        expenseDate: _dateLabel,
        category: _categoryController.text.trim(),
        description: _descriptionController.text.trim(),
        amount: _amountController.text.trim(),
        currency: _selectedProject?.currency ?? 'TND',
        ocrRawText: widget.ocrText,
        image: widget.image,
        ocrSuggested: {
          if (_suggestion.amount != null) 'amount': _suggestion.amount,
          if (_suggestion.expenseDate != null)
            'expenseDate': _suggestion.expenseDate,
          if (_suggestion.description != null)
            'description': _suggestion.description,
        },
      );
      if (mounted) Navigator.pop(context, created);
    } on SopatApiException catch (e) {
      if (e.isAuthError) {
        await SopatApi.instance.logout();
        if (mounted && await _ensureLoggedIn()) {
          _submit();
          return;
        }
      }
      setState(() => _error = e.message);
    } catch (e) {
      setState(() => _error = 'Erreur inattendue : $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _descriptionController.dispose();
    _categoryController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Nouvelle dépense')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (_projects == null)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: LinearProgressIndicator(),
              )
            else
              DropdownButtonFormField<Project>(
                initialValue: _selectedProject,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Projet',
                  prefixIcon: Icon(Icons.folder_outlined),
                ),
                items: _projects!
                    .map((p) => DropdownMenuItem(
                          value: p,
                          child: Text(p.label, overflow: TextOverflow.ellipsis),
                        ))
                    .toList(),
                onChanged: (p) => setState(() => _selectedProject = p),
                validator: (p) => p == null ? 'Sélectionnez un projet' : null,
              ),
            if (_selectedProject != null) _BudgetBar(project: _selectedProject!),
            const SizedBox(height: 16),
            TextFormField(
              controller: _amountController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: 'Montant (${_selectedProject?.currency ?? 'TND'})',
                prefixIcon: const Icon(Icons.payments_outlined),
                helperText: _suggestion.amount != null
                    ? 'Suggéré par OCR — vérifiez avant validation'
                    : null,
              ),
              validator: (v) {
                final value = double.tryParse((v ?? '').replaceAll(',', '.'));
                if (value == null || value <= 0) return 'Montant invalide';
                return null;
              },
            ),
            const SizedBox(height: 16),
            InkWell(
              onTap: _pickDate,
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Date de la dépense',
                  prefixIcon: Icon(Icons.event_outlined),
                ),
                child: Text(_dateLabel),
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _descriptionController,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Description',
                prefixIcon: Icon(Icons.notes_outlined),
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Description requise' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _categoryController,
              decoration: const InputDecoration(
                labelText: 'Catégorie (optionnel)',
                prefixIcon: Icon(Icons.sell_outlined),
              ),
            ),
            const SizedBox(height: 16),
            ExpansionTile(
              title: Text('Texte OCR détecté', style: theme.textTheme.titleSmall),
              tilePadding: EdgeInsets.zero,
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(widget.ocrText, style: theme.textTheme.bodySmall),
                ),
              ],
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  _error!,
                  style: TextStyle(color: theme.colorScheme.error),
                ),
              ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _busy ? null : _submit,
              icon: _busy
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.check),
              label: const Text('Enregistrer la dépense'),
            ),
            const SizedBox(height: 8),
            Text(
              'La dépense sera soumise à validation par la direction avant '
              'd’être comptée dans le budget du projet.',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.outline),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _BudgetBar extends StatelessWidget {
  const _BudgetBar({required this.project});

  final Project project;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final percent = project.percentSpent;
    if (project.approvedBudget == null) {
      return Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Text(
          'Pas de budget approuvé pour ce projet.',
          style: theme.textTheme.bodySmall
              ?.copyWith(color: theme.colorScheme.outline),
        ),
      );
    }
    final ratio = ((percent ?? 0) / 100).clamp(0.0, 1.0);
    final color = (percent ?? 0) >= 100
        ? theme.colorScheme.error
        : (percent ?? 0) >= 90
            ? Colors.orange
            : Colors.green;
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: ratio,
              minHeight: 8,
              color: color,
              backgroundColor: theme.colorScheme.surfaceContainerHighest,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Budget : ${project.spent.toStringAsFixed(0)} / '
            '${project.approvedBudget!.toStringAsFixed(0)} ${project.currency}'
            '${percent != null ? ' ($percent%)' : ''}',
            style: theme.textTheme.labelSmall,
          ),
        ],
      ),
    );
  }
}
