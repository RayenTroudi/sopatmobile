import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/sopat_api.dart';
import '../theme.dart';
import 'scan_screen.dart';

/// Écran de connexion SOPAT — même système d'authentification que le
/// back-office web. Accès réservé à l'équipe Réalisation (terrain + chef).
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, this.popOnSuccess = false});

  /// true quand l'écran est ouvert par-dessus un autre (session expirée) :
  /// on revient à l'appelant avec `true` au lieu de remplacer la pile.
  final bool popOnSuccess;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _rememberMe = true;
  bool _showPassword = false;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _emailController.text = SopatApi.instance.email ?? '';
    SharedPreferences.getInstance().then((prefs) {
      final saved = prefs.getString('sopat_email');
      if (saved != null && _emailController.text.isEmpty && mounted) {
        setState(() => _emailController.text = saved);
      }
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await SopatApi.instance.login(
        _emailController.text.trim(),
        _passwordController.text,
        rememberMe: _rememberMe,
      );
      if (!mounted) return;
      if (widget.popOnSuccess) {
        Navigator.pop(context, true);
      } else {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const ScanScreen()),
        );
      }
    } on SopatApiException catch (e) {
      setState(() => _error = e.message);
    } catch (e) {
      setState(() => _error = 'Erreur inattendue : $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SopatColors.green,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // ── Logo SOPAT (blanc sur fond vert) ──────────────────────
                Image.asset(
                  'assets/images/logo-sopat-white.png',
                  width: 220,
                  fit: BoxFit.contain,
                  semanticLabel: 'SOPAT — Société de Paysage de Tunisie',
                ),
                const SizedBox(height: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: SopatColors.ivory.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'Équipe Réalisation · Scan des dépenses',
                    style: TextStyle(
                      color: SopatColors.ivory.withValues(alpha: 0.9),
                      fontSize: 12,
                    ),
                  ),
                ),
                const SizedBox(height: 32),

                // ── Carte de connexion ────────────────────────────────────
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: SopatColors.surface,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text(
                          'Connexion',
                          style: TextStyle(
                            color: SopatColors.text,
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 20),
                        TextFormField(
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          autofillHints: const [AutofillHints.email],
                          decoration: const InputDecoration(
                            labelText: 'Email',
                            prefixIcon: Icon(Icons.mail_outline),
                          ),
                          validator: (v) => (v == null || !v.contains('@'))
                              ? 'Email invalide'
                              : null,
                        ),
                        const SizedBox(height: 14),
                        TextFormField(
                          controller: _passwordController,
                          obscureText: !_showPassword,
                          autofillHints: const [AutofillHints.password],
                          decoration: InputDecoration(
                            labelText: 'Mot de passe',
                            prefixIcon: const Icon(Icons.lock_outline),
                            suffixIcon: IconButton(
                              icon: Icon(_showPassword
                                  ? Icons.visibility_off_outlined
                                  : Icons.visibility_outlined),
                              onPressed: () => setState(
                                  () => _showPassword = !_showPassword),
                            ),
                          ),
                          validator: (v) => (v == null || v.length < 6)
                              ? 'Mot de passe trop court'
                              : null,
                          onFieldSubmitted: (_) => _submit(),
                        ),
                        const SizedBox(height: 8),
                        CheckboxListTile(
                          value: _rememberMe,
                          onChanged: (v) =>
                              setState(() => _rememberMe = v ?? false),
                          title: const Text(
                            'Se souvenir de moi',
                            style: TextStyle(
                                fontSize: 14, color: SopatColors.text),
                          ),
                          controlAffinity: ListTileControlAffinity.leading,
                          contentPadding: EdgeInsets.zero,
                          dense: true,
                        ),
                        if (_error != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 4, bottom: 8),
                            child: Text(
                              _error!,
                              style: const TextStyle(
                                  color: SopatColors.red, fontSize: 13),
                            ),
                          ),
                        const SizedBox(height: 8),
                        FilledButton(
                          onPressed: _busy ? null : _submit,
                          child: _busy
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: SopatColors.ivory,
                                  ),
                                )
                              : const Text('Se connecter'),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'Accès réservé à l’équipe Réalisation',
                  style: TextStyle(
                    color: SopatColors.ivory.withValues(alpha: 0.55),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
