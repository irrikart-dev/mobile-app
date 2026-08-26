/// Formats whole-rupee amounts as `₹1,299` (Indian digit grouping: the last
/// 3 digits, then groups of 2).
String formatInr(int amount) {
  final isNegative = amount < 0;
  final digits = amount.abs().toString();

  if (digits.length <= 3) return '${isNegative ? '-' : ''}₹$digits';

  final last3 = digits.substring(digits.length - 3);
  final rest = digits.substring(0, digits.length - 3);
  final buffer = StringBuffer();
  for (var i = 0; i < rest.length; i++) {
    final posFromEnd = rest.length - i;
    buffer.write(rest[i]);
    if (posFromEnd > 1 && posFromEnd % 2 == 1) buffer.write(',');
  }

  return '${isNegative ? '-' : ''}₹$buffer,$last3';
}

/// e.g. `PackUnit.piece` string `"piece"` -> `"/ piece"`.
String formatUnit(String unit) => '/ $unit';
