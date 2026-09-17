/// Formats a rupee amount as `₹1,299` (Indian digit grouping: the last 3
/// digits, then groups of 2). The catalogue and cart APIs allow up to 2
/// decimal places; a whole-number amount is shown with none, a fractional
/// one keeps exactly 2 (`₹1,299.50`), never a trailing `.00`.
String formatInr(num amount) {
  final isNegative = amount < 0;
  final abs = amount.abs();
  final whole = abs.truncate();
  final cents = ((abs - whole) * 100).round();

  final digits = whole.toString();
  final buffer = StringBuffer();

  if (digits.length <= 3) {
    buffer.write(digits);
  } else {
    final last3 = digits.substring(digits.length - 3);
    final rest = digits.substring(0, digits.length - 3);
    for (var i = 0; i < rest.length; i++) {
      final posFromEnd = rest.length - i;
      buffer.write(rest[i]);
      if (posFromEnd > 1 && posFromEnd % 2 == 1) buffer.write(',');
    }
    buffer.write(',$last3');
  }

  final decimals = cents == 0 ? '' : '.${cents.toString().padLeft(2, '0')}';
  return '${isNegative ? '-' : ''}₹$buffer$decimals';
}

/// e.g. `PackUnit.piece` string `"piece"` -> `"/ piece"`.
String formatUnit(String unit) => '/ $unit';
