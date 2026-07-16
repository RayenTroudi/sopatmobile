import 'package:flutter_test/flutter_test.dart';
import 'package:sopat_ocr/main.dart';

void main() {
  testWidgets('scan screen renders with action buttons', (tester) async {
    await tester.pumpWidget(const SopatOcrApp());

    expect(find.text('SOPAT Handwriting OCR'), findsOneWidget);
    expect(find.text('Camera'), findsOneWidget);
    expect(find.text('Gallery'), findsOneWidget);
    expect(find.text('Take a photo of handwritten notes'), findsOneWidget);
  });
}
