String formatIndianCompactNumber(
  num value, {
  int fractionDigits = 2,
}) {
  final absValue = value.abs().toDouble();
  final sign = value < 0 ? '-' : '';

  if (absValue >= 10000000) {
    final formatted = (absValue / 10000000).toStringAsFixed(fractionDigits);
    return '$sign$formatted Cr';
  }

  if (absValue >= 100000) {
    final formatted = (absValue / 100000).toStringAsFixed(fractionDigits);
    return '$sign$formatted L';
  }

  if (absValue >= 1000) {
    final formatted = (absValue / 1000).toStringAsFixed(fractionDigits);
    return '$sign$formatted K';
  }

  if (absValue == absValue.roundToDouble()) {
    return '$sign${absValue.toStringAsFixed(0)}';
  }

  return '$sign${absValue.toStringAsFixed(fractionDigits)}';
}

String formatIndianShortCurrency(
  num value, {
  String symbol = '₹',
  int fractionDigits = 2,
}) {
  return '$symbol${formatIndianCompactNumber(value, fractionDigits: fractionDigits)}';
}
