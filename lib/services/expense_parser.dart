/// Heuristic extraction of expense fields from OCR'd receipt/note text.
///
/// These are *suggestions* — the user reviews and corrects them in the
/// expense form before anything is saved (AI suggests, humans validate).
class ExpenseSuggestion {
  final String? amount; // normalized "123.450"
  final String? expenseDate; // "yyyy-MM-dd"
  final String? description;

  const ExpenseSuggestion({this.amount, this.expenseDate, this.description});
}

class ExpenseParser {
  /// Lines containing these words likely carry the payable total.
  static final _totalHint =
      RegExp(r'total|montant|somme|net|payer|ttc', caseSensitive: false);

  /// Number with decimal separator, e.g. 123.45 / 1 234,500 / 99,00
  static final _decimalNumber = RegExp(r'\d{1,3}(?:[  ]?\d{3})*[.,]\d{1,3}');

  static final _dmyDate = RegExp(r'\b(\d{1,2})[/\-.](\d{1,2})[/\-.](\d{4}|\d{2})\b');
  static final _ymdDate = RegExp(r'\b(\d{4})-(\d{2})-(\d{2})\b');

  static ExpenseSuggestion parse(String ocrText) {
    final lines = ocrText
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();

    return ExpenseSuggestion(
      amount: _extractAmount(lines),
      expenseDate: _extractDate(ocrText),
      description: _extractDescription(lines),
    );
  }

  static String? _extractAmount(List<String> lines) {
    // Prefer a number on a line mentioning "total"/"montant"/...
    for (final line in lines) {
      if (_totalHint.hasMatch(line)) {
        final match = _decimalNumber.firstMatch(line);
        if (match != null) return _normalizeNumber(match.group(0)!);
      }
    }
    // Otherwise take the largest decimal number found anywhere.
    double? best;
    String? bestRaw;
    for (final line in lines) {
      for (final match in _decimalNumber.allMatches(line)) {
        final normalized = _normalizeNumber(match.group(0)!);
        final value = double.tryParse(normalized);
        if (value != null && (best == null || value > best)) {
          best = value;
          bestRaw = normalized;
        }
      }
    }
    return bestRaw;
  }

  static String _normalizeNumber(String raw) {
    var s = raw.replaceAll(RegExp(r'[  ]'), '');
    // If both separators appear, the last one is the decimal point.
    final lastComma = s.lastIndexOf(',');
    final lastDot = s.lastIndexOf('.');
    if (lastComma >= 0 && lastDot >= 0) {
      if (lastComma > lastDot) {
        s = s.replaceAll('.', '').replaceAll(',', '.');
      } else {
        s = s.replaceAll(',', '');
      }
    } else if (lastComma >= 0) {
      s = s.replaceAll(',', '.');
    }
    return s;
  }

  static String? _extractDate(String text) {
    final ymd = _ymdDate.firstMatch(text);
    if (ymd != null) return ymd.group(0);

    final dmy = _dmyDate.firstMatch(text);
    if (dmy != null) {
      final day = int.tryParse(dmy.group(1)!) ?? 0;
      final month = int.tryParse(dmy.group(2)!) ?? 0;
      var year = int.tryParse(dmy.group(3)!) ?? 0;
      if (year < 100) year += 2000;
      if (day >= 1 && day <= 31 && month >= 1 && month <= 12) {
        return '$year-${month.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}';
      }
    }
    return null;
  }

  static String? _extractDescription(List<String> lines) {
    // First line that is mostly letters (not a number/date/total line).
    for (final line in lines) {
      final letters = line.replaceAll(RegExp(r'[^A-Za-zÀ-ÿ]'), '').length;
      if (letters >= 4 && letters >= line.length ~/ 2 && !_totalHint.hasMatch(line)) {
        return line;
      }
    }
    return lines.isNotEmpty ? lines.first : null;
  }
}
