/// Parsed response from the SOPAT OCR backend.
class OcrLine {
  final String text;
  final double confidence;

  const OcrLine({required this.text, required this.confidence});

  factory OcrLine.fromJson(Map<String, dynamic> json) => OcrLine(
        text: json['text'] as String? ?? '',
        confidence: (json['confidence'] as num?)?.toDouble() ?? 0,
      );
}

class OcrResult {
  final String text;
  final double confidence;
  final List<OcrLine> lines;
  final double processingTime;
  final String requestId;

  const OcrResult({
    required this.text,
    required this.confidence,
    required this.lines,
    required this.processingTime,
    required this.requestId,
  });

  factory OcrResult.fromJson(Map<String, dynamic> json) => OcrResult(
        text: json['text'] as String? ?? '',
        confidence: (json['confidence'] as num?)?.toDouble() ?? 0,
        lines: (json['lines'] as List<dynamic>? ?? [])
            .map((e) => OcrLine.fromJson(e as Map<String, dynamic>))
            .toList(),
        processingTime: (json['processing_time'] as num?)?.toDouble() ?? 0,
        requestId: json['request_id'] as String? ?? '',
      );
}

/// Thrown when the backend returns a failure or cannot be reached.
class OcrException implements Exception {
  final String message;
  const OcrException(this.message);

  @override
  String toString() => message;
}
