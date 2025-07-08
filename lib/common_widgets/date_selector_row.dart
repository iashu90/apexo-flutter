import 'package:apexo/services/localization/locale.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:intl/intl.dart';
import 'package:flutter/material.dart' as material;

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
              onPressed: () =>
                  onChange(selectedDate.subtract(const Duration(days: 1))),
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
                              );
                              if (picked != null) {
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
              onPressed: () =>
                  onChange(selectedDate.add(const Duration(days: 1))),
            ),
            const SizedBox(width: 20),
            if (!DateUtils.isSameDay(selectedDate, DateTime.now()))
              Tooltip(
                message: txt("goToToday"),
                child: FilledButton(
                  child: Row(
                    children: [
                      Icon(FluentIcons.refresh),
                    ],
                  ),
                  onPressed: () => onChange(DateTime.now()),
                  style: ButtonStyle(
                    padding: ButtonState.all(
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    ),
                    backgroundColor: ButtonState.all(Colors.blue),
                    foregroundColor: ButtonState.all(Colors.white),
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
