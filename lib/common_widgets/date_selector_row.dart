import 'package:apexo/core/activity_logger.dart';
import 'package:apexo/services/localization/locale.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:intl/intl.dart';
import 'package:flutter/material.dart' as material;
import 'package:apexo/theme/material_date_picker_theme.dart';

class DateSelectorRow extends StatefulWidget {
  final DateTime selectedDate;
  final void Function(DateTime newDate) onChange;

  const DateSelectorRow({
    super.key,
    required this.selectedDate,
    required this.onChange,
  });

  @override
  State<DateSelectorRow> createState() => _DateSelectorRowState();
}

class _DateSelectorRowState extends State<DateSelectorRow> {
  bool _isHovering = false;

  @override
  Widget build(BuildContext context) {
    final selectedDate = widget.selectedDate;
    final onChange = widget.onChange;
    const double goToTodayButtonWidth = 44;
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(
              icon: const Icon(FluentIcons.chevron_left),
              onPressed: () {
                final newDate = selectedDate.subtract(const Duration(days: 1));
                ActivityLogger.logAction(
                  "Date Backward Clicked",
                  screen: "DateSelectorRow",
                  data: {
                    "from": selectedDate.toIso8601String(),
                    "to": newDate.toIso8601String(),
                  },
                );
                onChange(newDate);
              },
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 120,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 120,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        MouseRegion(
                          onEnter: (_) => setState(() => _isHovering = true),
                          onExit: (_) => setState(() => _isHovering = false),
                          child: GestureDetector(
                            onTap: () async {
                              final picked = await material.showDatePicker(
                                context: context,
                                initialDate: selectedDate,
                                firstDate: DateTime(2000),
                                lastDate: DateTime(2100),
                                builder: apexoDatePickerBuilder(context),
                              );
                              if (picked != null) {
                                ActivityLogger.logAction(
                                  "Date Selected",
                                  screen: "DateSelectorRow",
                                  data: {
                                    "from": selectedDate.toIso8601String(),
                                    "to": picked.toIso8601String(),
                                  },
                                );
                                onChange(picked);
                              }
                            },
                            child: Text(
                              DateFormat('d MMM yyyy').format(selectedDate),
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 16,
                                color: material.Colors.blue,
                                decoration: _isHovering
                                    ? TextDecoration.underline
                                    : null,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          mainAxisSize: MainAxisSize.max,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              DateFormat('EEEE').format(selectedDate) +
                                  (DateUtils.isSameDay(
                                          selectedDate, DateTime.now())
                                      ? " (${txt('today')})"
                                      : ""),
                              style: const TextStyle(
                                fontSize: 14,
                                fontStyle: FontStyle.italic,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(FluentIcons.chevron_right),
              onPressed: () {
                final newDate = selectedDate.add(const Duration(days: 1));
                ActivityLogger.logAction(
                  "Date Forward Clicked",
                  screen: "DateSelectorRow",
                  data: {
                    "from": selectedDate.toIso8601String(),
                    "to": newDate.toIso8601String(),
                  },
                );
                onChange(newDate);
              },
            ),
            const SizedBox(width: 20),
            if (!DateUtils.isSameDay(selectedDate, DateTime.now()))
              Tooltip(
                message: txt("goToToday"),
                child: FilledButton(
                  onPressed: () {
                    ActivityLogger.logAction(
                      "Go To Today Clicked",
                      screen: "DateSelectorRow",
                      data: {
                        "from": selectedDate.toIso8601String(),
                        "to": DateTime.now().toIso8601String(),
                      },
                    );
                    onChange(DateTime.now());
                  },
                  style: ButtonStyle(
                    padding: ButtonState.all(
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    ),
                    backgroundColor: ButtonState.all(Colors.blue),
                    foregroundColor: ButtonState.all(Colors.white),
                  ),
                  child: const Row(
                    children: [
                      Icon(FluentIcons.refresh),
                    ],
                  ),
                ),
              )
            else
              const SizedBox(width: goToTodayButtonWidth),
          ],
        ),
      ],
    );
  }
}
