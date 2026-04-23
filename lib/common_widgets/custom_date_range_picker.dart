import 'package:apexo/theme/material_date_picker_theme.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/material.dart' as material;

class ApexoDateRange {
  final DateTime start;
  final DateTime end;

  const ApexoDateRange({required this.start, required this.end});
}

Future<ApexoDateRange?> showCustomDateRangePicker(
  BuildContext context, {
  DateTime? initialStart,
  DateTime? initialEnd,
}) async {
  final now = DateTime.now();
  final initialRange =
      (initialStart != null && initialEnd != null && !initialEnd.isBefore(initialStart))
          ? material.DateTimeRange(start: initialStart, end: initialEnd)
          : null;

  final picked = await material.showDateRangePicker(
    context: context,
    firstDate: DateTime(now.year - 50, 1, 1),
    lastDate: DateTime(now.year + 50, 12, 31),
    initialDateRange: initialRange,
    builder: apexoDatePickerBuilder(context),
  );

  if (picked == null) return null;
  return ApexoDateRange(start: picked.start, end: picked.end);
}
