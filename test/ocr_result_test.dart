import 'package:flutter_test/flutter_test.dart';
import 'package:sopat_ocr/models/ocr_result.dart';

void main() {
  group('OcrResult.fromJson', () {
    test('parses a full backend response', () {
      final result = OcrResult.fromJson({
        'success': true,
        'text': 'hello\nworld',
        'confidence': 0.91,
        'lines': [
          {'text': 'hello', 'confidence': 0.95},
          {'text': 'world', 'confidence': 0.87},
        ],
        'processing_time': 1.42,
        'request_id': 'abc123',
      });

      expect(result.text, 'hello\nworld');
      expect(result.confidence, 0.91);
      expect(result.lines, hasLength(2));
      expect(result.lines.first.text, 'hello');
      expect(result.lines.first.confidence, 0.95);
      expect(result.processingTime, 1.42);
      expect(result.requestId, 'abc123');
    });

    test('tolerates missing optional fields', () {
      final result = OcrResult.fromJson({'text': 'x'});
      expect(result.text, 'x');
      expect(result.confidence, 0);
      expect(result.lines, isEmpty);
    });

    test('handles integer confidence values', () {
      final result = OcrResult.fromJson({
        'text': 'x',
        'confidence': 1,
        'lines': [
          {'text': 'x', 'confidence': 1},
        ],
      });
      expect(result.confidence, 1.0);
      expect(result.lines.first.confidence, 1.0);
    });
  });
}
