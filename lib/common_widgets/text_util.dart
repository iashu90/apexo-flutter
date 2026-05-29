import 'package:fluent_ui/fluent_ui.dart';

String toTitleCase(String input) {
  final trimmed = input.trim();
  if (trimmed.isEmpty) return '';

  return trimmed
      .split(RegExp(r'\s+'))
      .map((word) {
        if (word.isEmpty) return word;
        final first = word[0].toUpperCase();
        final rest = word.length > 1 ? word.substring(1).toLowerCase() : '';
        return '$first$rest';
      })
      .join(' ');
}

TextSpan highlightMatch(String source, String query, TextStyle normal, TextStyle highlight) {
  if (query.isEmpty) return TextSpan(text: source, style: normal);

  final lcSource = source.toLowerCase();
  final lcQuery = query.toLowerCase();
  final start = lcSource.indexOf(lcQuery);

  if (start < 0) return TextSpan(text: source, style: normal);

  return TextSpan(
    children: [
      if (start > 0) TextSpan(text: source.substring(0, start), style: normal),
      TextSpan(
        text: source.substring(start, start + query.length),
        style: highlight,
      ),
      if (start + query.length < source.length)
        TextSpan(text: source.substring(start + query.length), style: normal),
    ],
  );
}