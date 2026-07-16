import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/project.dart';

class SopatApiException implements Exception {
  final String message;
  final int? statusCode;
  const SopatApiException(this.message, {this.statusCode});

  bool get isAuthError => statusCode == 401;

  @override
  String toString() => message;
}

/// Client for the SOPAT ERP (Next.js). Authenticates with the same
/// iron-session cookie as the web app and keeps it across restarts.
class SopatApi {
  SopatApi._();
  static final SopatApi instance = SopatApi._();

  static const _prefsBaseUrl = 'sopat_base_url';
  static const _prefsCookie = 'sopat_cookie';

  String _baseUrl = 'http://10.0.2.2:3000';
  String? _cookie;
  final _client = http.Client();

  String get baseUrl => _baseUrl;
  bool get isLoggedIn => _cookie != null;

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _baseUrl = prefs.getString(_prefsBaseUrl) ?? _baseUrl;
    _cookie = prefs.getString(_prefsCookie);
  }

  Future<void> setBaseUrl(String url) async {
    _baseUrl = url.replaceAll(RegExp(r'/+$'), '');
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsBaseUrl, _baseUrl);
  }

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        'Cookie': ?_cookie,
      };

  /// POST /api/auth/login — stores the session cookies on success.
  Future<void> login(String email, String password) async {
    final http.Response response;
    try {
      response = await _client
          .post(
            Uri.parse('$_baseUrl/api/auth/login'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'email': email, 'password': password}),
          )
          .timeout(const Duration(seconds: 20));
    } on SocketException {
      throw const SopatApiException(
          'Serveur SOPAT injoignable. Vérifiez l’URL dans les réglages.');
    }

    if (response.statusCode != 200) {
      throw SopatApiException(
        _errorFrom(response, 'Échec de la connexion.'),
        statusCode: response.statusCode,
      );
    }

    final cookie = _extractCookies(response);
    if (cookie == null) {
      throw const SopatApiException('Session non reçue du serveur.');
    }
    _cookie = cookie;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsCookie, cookie);
  }

  Future<void> logout() async {
    _cookie = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefsCookie);
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
    File? image,
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
        http.MultipartRequest('POST', Uri.parse('$_baseUrl/api/mobile/expenses'));
    if (_cookie != null) request.headers['Cookie'] = _cookie!;
    request.fields['data'] = jsonEncode(payload);
    if (image != null) {
      request.files.add(await http.MultipartFile.fromPath('image', image.path));
    }

    http.Response response;
    try {
      final streamed = await request.send().timeout(const Duration(seconds: 60));
      response = await http.Response.fromStream(streamed);
    } on SocketException {
      throw const SopatApiException('Serveur SOPAT injoignable.');
    }
    return ExpenseCreated.fromJson(_decode(response));
  }

  Future<Map<String, dynamic>> _get(String path) async {
    final http.Response response;
    try {
      response = await _client
          .get(Uri.parse('$_baseUrl$path'), headers: _headers)
          .timeout(const Duration(seconds: 30));
    } on SocketException {
      throw const SopatApiException('Serveur SOPAT injoignable.');
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

  String _errorFrom(http.Response response, String fallback) {
    try {
      final body = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
      return body['error'] as String? ?? fallback;
    } catch (_) {
      return fallback;
    }
  }

  /// Pulls the `sopat_session` / `sopat_auth` cookies out of the combined
  /// Set-Cookie header (the http package folds them into one string).
  static String? _extractCookies(http.Response response) {
    final raw = response.headers['set-cookie'];
    if (raw == null) return null;
    final pairs = <String>[];
    for (final name in ['sopat_session', 'sopat_auth']) {
      final match = RegExp('$name=([^;,\\s]+)').firstMatch(raw);
      if (match != null) pairs.add('$name=${match.group(1)}');
    }
    return pairs.isEmpty ? null : pairs.join('; ');
  }
}
