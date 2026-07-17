import 'dart:async';
import 'dart:convert';

import 'package:cross_file/cross_file.dart';
import 'package:http/http.dart' as http;

import '../models/ocr_result.dart';
import 'image_upload.dart';

/// Client for the SOPAT OCR backend (POST /ocr, GET /health).
class OcrService {
  OcrService({required this.baseUrl, http.Client? client})
      : _client = client ?? http.Client();

  final String baseUrl;
  final http.Client _client;

  static const _timeout = Duration(seconds: 120);

  Uri _uri(String path) => Uri.parse('$baseUrl$path');

  Future<bool> checkHealth() async {
    try {
      final response =
          await _client.get(_uri('/health')).timeout(const Duration(seconds: 5));
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  /// Upload an image file and return the recognized text.
  Future<OcrResult> extractText(XFile image) async {
    final request = http.MultipartRequest('POST', _uri('/ocr'));
    try {
      request.files.add(await imagePart(image));
    } on EmptyImageException {
      throw const OcrException(
          'L’image sélectionnée est vide ou illisible. Reprenez la photo.');
    }

    http.Response response;
    try {
      final streamed = await request.send().timeout(_timeout);
      response = await http.Response.fromStream(streamed);
    } on TimeoutException {
      throw const OcrException(
          'Délai d’attente dépassé. Le serveur OCR ne répond pas — '
          'vérifiez le réseau Wi-Fi et le pare-feu du PC.');
    } on http.ClientException catch (e) {
      throw OcrException(
          'Serveur OCR injoignable (${e.message}). Vérifiez l’URL du serveur OCR.');
    }

    final Map<String, dynamic> body;
    try {
      body = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
    } catch (_) {
      throw OcrException(
          'Réponse inattendue du serveur (HTTP ${response.statusCode}).');
    }

    if (response.statusCode == 200 && body['success'] == true) {
      return OcrResult.fromJson(body);
    }
    throw OcrException(body['error'] as String? ?? 'Échec de l’OCR.');
  }
}
