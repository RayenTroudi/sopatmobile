import 'package:flutter_test/flutter_test.dart';
import 'package:sopat_ocr/services/expense_parser.dart';

void main() {
  group('ExpenseParser', () {
    test('prefers amount on a total line', () {
      final s = ExpenseParser.parse(
          'Quincaillerie El Amen\nciment 3 sacs 45,000\nTotal : 145,500 TND\n12/03/2026');
      expect(s.amount, '145.500');
      expect(s.expenseDate, '2026-03-12');
      expect(s.description, 'Quincaillerie El Amen');
    });

    test('falls back to largest decimal number', () {
      final s = ExpenseParser.parse('tuyaux PVC 89.500\nraccords 12.300');
      expect(s.amount, '89.500');
    });

    test('normalizes thousand separators', () {
      final s = ExpenseParser.parse('Montant 1 234,567');
      expect(s.amount, '1234.567');
    });

    test('parses ISO dates directly', () {
      final s = ExpenseParser.parse('livraison 2026-07-01 gravier 50,000');
      expect(s.expenseDate, '2026-07-01');
    });

    test('parses two-digit years', () {
      final s = ExpenseParser.parse('recu 05/06/26\nplantes 20,000');
      expect(s.expenseDate, '2026-06-05');
    });

    test('handles text with no numbers', () {
      final s = ExpenseParser.parse('note de chantier sans montant');
      expect(s.amount, isNull);
      expect(s.expenseDate, isNull);
      expect(s.description, 'note de chantier sans montant');
    });

    test('empty text yields empty suggestion', () {
      final s = ExpenseParser.parse('');
      expect(s.amount, isNull);
      expect(s.description, isNull);
    });
  });
}
