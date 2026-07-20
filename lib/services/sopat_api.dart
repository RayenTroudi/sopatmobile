import 'dart:async';
import 'dart:convert';

import 'package:cross_file/cross_file.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/project.dart';
import 'image_upload.dart';

class SopatApiException implements Exception {
  final String message;
  final int? statusCode;
  const SopatApiException(this.message, {this.statusCode});

  bool get isAuthError => statusCode == 401;

  @override
  String toString() => message;
}

/// Client for the SOPAT ERP (Next.js). Authenticates against the mobile API
/// (POST /api/mobile/auth/login) — mêmes identifiants que le back-office web,
/// mais via un jeton JWT Bearer (fonctionne sur Chrome Web, Android et iOS,
/// contrairement au cookie qui ne passe pas en cross-origin dans un navigateur).
class SopatApi {
  SopatApi._();
  static final SopatApi instance = SopatApi._();

  static const _prefsToken = 'sopat_token';
  static const _prefsRole = 'sopat_role';
  static const _prefsEmail = 'sopat_email';

  /// URL du back-office SOPAT — déploiement Vercel de production.
  static const baseUrl = 'https://sopat.vercel.app';

  String? _token;
  String? _role;
  String? _email;
  final _client = http.Client();

  bool get isLoggedIn => _token != null;
  String? get role => _role;
  String? get email => _email;

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString(_prefsToken);
    _role = prefs.getString(_prefsRole);
    _email = prefs.getString(_prefsEmail);
  }

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        if (_token != null) 'Authorization': 'Bearer $_token',
      };

  /// POST /api/mobile/auth/login — mêmes identifiants que le back-office web
  /// (table users, bcrypt), renvoie un jeton JWT. Refuse les rôles hors équipe
  /// Réalisation. Avec [rememberMe], le jeton est conservé après fermeture.
  Future<void> login(
    String email,
    String password, {
    bool rememberMe = false,
  }) async {
    final http.Response response;
    try {
      response = await _client
          .post(
            Uri.parse('$baseUrl/api/mobile/auth/login'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'email': email, 'password': password}),
          )
          .timeout(const Duration(seconds: 15));
    } on TimeoutException {
      throw const SopatApiException(
          'Délai d’attente dépassé. Le serveur SOPAT ne répond pas — '
          'vérifiez le réseau Wi-Fi et le pare-feu du PC.');
    } on http.ClientException catch (e) {
      throw SopatApiException(
          'Serveur SOPAT injoignable (${e.message}). Vérifiez que le serveur '
          'est démarré et que le téléphone est sur le même réseau Wi-Fi.');
    }

    final body = _decode(response); // lève une SopatApiException si status >= 400

    final token = body['token'] as String?;
    final role = body['role'] as String? ?? '';
    if (token == null) {
      throw const SopatApiException('Session non reçue du serveur.');
    }
    _token = token;
    _role = role;
    _email = email;

    final prefs = await SharedPreferences.getInstance();
    if (rememberMe) {
      await prefs.setString(_prefsToken, token);
      await prefs.setString(_prefsRole, role);
      await prefs.setString(_prefsEmail, email);
    } else {
      // Session en mémoire uniquement — ne survit pas au redémarrage.
      await prefs.remove(_prefsToken);
      await prefs.remove(_prefsRole);
      // On garde l'email pour préremplir le prochain login.
      await prefs.setString(_prefsEmail, email);
    }
  }

  Future<void> logout() async {
    _token = null;
    _role = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefsToken);
    await prefs.remove(_prefsRole);
  }

  /// GET /api/mobile/projects
  Future<List<Project>> fetchProjects() async {
    final body = await _get('/api/mobile/projects');
    return (body['projects'] as List<dynamic>)
        .map((e) => Project.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// POST /api/mobile/expenses — multipart: champ `data` (JSON) + `image`
  /// (photo du justificatif, affichée dans le panneau admin).
  Future<ExpenseCreated> createExpense({
    String? projectId,
    required String expenseDate,
    String? category,
    required String description,
    required String amount,
    String currency = 'TND',
    String? ocrRawText,
    Map<String, dynamic>? ocrSuggested,
    XFile? image,
  }) async {
    final payload = {
      'projectId': ?projectId,
      'expenseDate': expenseDate,
      if (category != null && category.isNotEmpty) 'category': category,
      'description': description,
      'amount': amount,
      'currency': currency,
      'ocrRawText': ?ocrRawText,
      'ocrSuggested': ?ocrSuggested,
    };

    final request =
        http.MultipartRequest('POST', Uri.parse('$baseUrl/api/mobile/expenses'));
    if (_token != null) request.headers['Authorization'] = 'Bearer $_token';
    request.fields['data'] = jsonEncode(payload);
    if (image != null) {
      try {
        request.files.add(await imagePart(image));
      } on EmptyImageException {
        throw const SopatApiException(
            'La photo est vide ou illisible. Reprenez la photo.');
      }
    }

    http.Response response;
    try {
      final streamed = await request.send().timeout(const Duration(seconds: 60));
      response = await http.Response.fromStream(streamed);
    } on TimeoutException {
      throw const SopatApiException(
          'Délai d’attente dépassé lors de l’envoi de la dépense.');
    } on http.ClientException catch (e) {
      throw SopatApiException('Serveur SOPAT injoignable (${e.message}).');
    }
    return ExpenseCreated.fromJson(_decode(response));
  }

  Future<Map<String, dynamic>> _get(String path) async {
    final http.Response response;
    try {
      response = await _client
          .get(Uri.parse('$baseUrl$path'), headers: _headers)
          .timeout(const Duration(seconds: 30));
    } on TimeoutException {
      throw const SopatApiException(
          'Délai d’attente dépassé. Le serveur SOPAT ne répond pas.');
    } on http.ClientException catch (e) {
      throw SopatApiException('Serveur SOPAT injoignable (${e.message}).');
    }
    return _decode(response);
  }

  Map<String, dynamic> _decode(http.Response response) {
    final Map<String, dynamic> body;
    try {
      body = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
    } catch (_) {
      throw SopatApiException(
        'Réponse inattendue du serveur (HTTP ${response.statusCode}).',
        statusCode: response.statusCode,
      );
    }
    if (response.statusCode >= 400) {
      throw SopatApiException(
        body['error'] as String? ?? 'Erreur serveur (${response.statusCode}).',
        statusCode: response.statusCode,
      );
    }
    return body;
  }

}
