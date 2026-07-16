import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../models/ocr_result.dart';

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
  Future<OcrResult> extractText(File image) async {
    final request = http.MultipartRequest('POST', _uri('/ocr'));
    request.files.add(await http.MultipartFile.fromPath('image', image.path));

    http.Response response;
    try {
      final streamed = await request.send().timeout(_timeout);
      response = await http.Response.fromStream(streamed);
    } on SocketException {
      throw const OcrException(
          'Cannot reach the OCR server. Check the server URL in settings.');
    } on HttpException {
      throw const OcrException('Connection to the OCR server failed.');
    }

    final Map<String, dynamic> body;
    try {
      body = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
    } catch (_) {
      throw OcrException(
          'Unexpected response from server (HTTP ${response.statusCode}).');
    }

    if (response.statusCode == 200 && body['success'] == true) {
      return OcrResult.fromJson(body);
    }
    throw OcrException(body['error'] as String? ?? 'OCR failed.');
  }
}
