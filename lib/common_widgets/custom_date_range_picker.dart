import 'package:fluent_ui/fluent_ui.dart';
import 'package:intl/intl.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  Simple range type
// ─────────────────────────────────────────────────────────────────────────────

class ApexoDateRange {
  final DateTime start;
  final DateTime end;
  const ApexoDateRange({required this.start, required this.end});
}

// ─────────────────────────────────────────────────────────────────────────────
//  Entry point
// ─────────────────────────────────────────────────────────────────────────────

Future<ApexoDateRange?> showCustomDateRangePicker(
  BuildContext context, {
  DateTime? initialStart,
  DateTime? initialEnd,
}) async {
  return showDialog<ApexoDateRange?>(
    context: context,
    barrierDismissible: true,
    builder: (_) => _CustomDateRangePickerDialog(
      initialStart: initialStart,
      initialEnd: initialEnd,
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
//  Dialog
// ─────────────────────────────────────────────────────────────────────────────

class _CustomDateRangePickerDialog extends StatefulWidget {
  final DateTime? initialStart;
  final DateTime? initialEnd;
  const _CustomDateRangePickerDialog({this.initialStart, this.initialEnd});

  @override
  State<_CustomDateRangePickerDialog> createState() =>
      _CustomDateRangePickerDialogState();
}

class _CustomDateRangePickerDialogState
    extends State<_CustomDateRangePickerDialog> {
  late DateTime _leftMonth;
  DateTime? _start;
  DateTime? _end;
  DateTime? _hovered;

  @override
  void initState() {
    super.initState();
    _start = widget.initialStart;
    _end = widget.initialEnd;
    final ref = widget.initialStart ?? DateTime.now();
    _leftMonth = DateTime(ref.year, ref.month, 1);
  }

  DateTime get _rightMonth =>
      DateTime(_leftMonth.year, _leftMonth.month + 1, 1);

  void _onDayTap(DateTime day) {
    setState(() {
      if (_start == null || (_start != null && _end != null)) {
        _start = day;
        _end = null;
      } else {
        if (day.isBefore(_start!)) {
          _end = _start;
          _start = day;
        } else {
          _end = day;
        }
      }
    });
  }

  void _setRange(DateTime start, DateTime end) {
    setState(() {
      _start = start;
      _end = end;
      _leftMonth = DateTime(start.year, start.month, 1);
    });
  }

  void _applyQuick(String label) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    switch (label) {
      case 'Last 7 Days':
        _setRange(today.subtract(const Duration(days: 6)), today);
      case 'Next 7 Days':
        _setRange(today, today.add(const Duration(days: 6)));
      case 'Last 30 Days':
        _setRange(today.subtract(const Duration(days: 29)), today);
      case 'Next 30 Days':
        _setRange(today, today.add(const Duration(days: 29)));
      case 'This Month':
        _setRange(
          DateTime(today.year, today.month, 1),
          DateTime(today.year, today.month + 1, 0),
        );
      case 'Last Month':
        _setRange(
          DateTime(today.year, today.month - 1, 1),
          DateTime(today.year, today.month, 0),
        );
      case 'Next Month':
        _setRange(
          DateTime(today.year, today.month + 1, 1),
          DateTime(today.year, today.month + 2, 0),
        );
      case 'YTD':
        _setRange(DateTime(today.year, 1, 1), today);
      case 'Last 1 Year':
        _setRange(
          DateTime(today.year - 1, today.month, today.day),
          today,
        );
    }
  }

  void _setDay(DateTime day) {
    setState(() {
      _start = day;
      _end = day;
    });
  }

  @override
  Widget build(BuildContext context) {
    final selectedText = _start == null
        ? 'No dates selected'
        : _end == null || _same(_start!, _end!)
            ? _formatDate(_start!)
            : '${_formatDate(_start!)}  \u2192  ${_formatDate(_end!)}';

    return ContentDialog(
      constraints: const BoxConstraints(maxWidth: 820, maxHeight: 640),
      title: null,
      content: SizedBox(
        height: 540,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Quick select sidebar ───────────────────────────────────
            Container(
              width: 136,
              padding: const EdgeInsets.fromLTRB(10, 12, 10, 10),
              decoration: const BoxDecoration(
                color: Color(0xFFF6F9FD),
                border: Border(right: BorderSide(color: Color(0xFFDDE8F2))),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'QUICK SELECT',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF8AAAC6),
                      letterSpacing: 0.6,
                    ),
                  ),
                  const SizedBox(height: 10),
                  ...[
                    'Last 7 Days',
                    'Next 7 Days',
                    'Last 30 Days',
                    'Next 30 Days',
                    'This Month',
                    'Last Month',
                    'Next Month',
                    'YTD',
                    'Last 1 Year',
                  ].map(
                    (label) => _QuickItem(
                      label: label,
                      onTap: () => _applyQuick(label),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),

            // ── Two-month calendars + action bar ──────────────────────
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Close button row
                  Align(
                    alignment: Alignment.topRight,
                    child: IconButton(
                      icon: const Icon(FluentIcons.chrome_close, size: 13),
                      onPressed: () => Navigator.pop(context, null),
                    ),
                  ),

                  // Two calendars side by side
                  Expanded(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: _MonthCalendar(
                            month: _leftMonth,
                            start: _start,
                            end: _end,
                            hovered: _hovered,
                            onDayTap: _onDayTap,
                            onHover: (d) => setState(() => _hovered = d),
                            onPrev: () => setState(() {
                              _leftMonth = DateTime(
                                  _leftMonth.year, _leftMonth.month - 1);
                            }),
                            onNext: null,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _MonthCalendar(
                            month: _rightMonth,
                            start: _start,
                            end: _end,
                            hovered: _hovered,
                            onDayTap: _onDayTap,
                            onHover: (d) => setState(() => _hovered = d),
                            onPrev: null,
                            onNext: () => setState(() {
                              _leftMonth = DateTime(
                                  _leftMonth.year, _leftMonth.month + 1);
                            }),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Divider(style: DividerThemeData(thickness: 0.5)),
                  const SizedBox(height: 6),

                  // Selected label
                  Center(
                    child: Text(
                      selectedText,
                      style: const TextStyle(
                        fontSize: 14,
                        color: Color(0xFF1B3A5C),
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Action buttons
                  Row(
                    children: [
                      HyperlinkButton(
                        onPressed: () =>
                            setState(() { _start = null; _end = null; }),
                        child: const Text(
                          'CLEAR DATES',
                          style: TextStyle(
                            color: Color(0xFFD6455D),
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const Spacer(),
                      _ActionDayBtn(
                        label: 'YESTERDAY',
                        onTap: () {
                          final d = DateTime.now()
                              .subtract(const Duration(days: 1));
                          _setDay(DateTime(d.year, d.month, d.day));
                        },
                      ),
                      const SizedBox(width: 6),
                      _ActionDayBtn(
                        label: 'TODAY',
                        onTap: () {
                          final n = DateTime.now();
                          _setDay(DateTime(n.year, n.month, n.day));
                        },
                      ),
                      const SizedBox(width: 6),
                      _ActionDayBtn(
                        label: 'TOMORROW',
                        onTap: () {
                          final d =
                              DateTime.now().add(const Duration(days: 1));
                          _setDay(DateTime(d.year, d.month, d.day));
                        },
                      ),
                      const SizedBox(width: 10),
                      FilledButton(
                        style: ButtonStyle(
                          backgroundColor: WidgetStateProperty.all(
                              const Color(0xFF1459AD)),
                        ),
                        onPressed: _start == null
                            ? null
                            : () {
                                Navigator.pop(
                                  context,
                                  ApexoDateRange(
                                    start: _start!,
                                    end: _end ?? _start!,
                                  ),
                                );
                              },
                        child: const Text('APPLY DATES'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}-${_monthNames[d.month - 1]}-${d.year}';

  static const _monthNames = [
    'JAN', 'FEB', 'MAR', 'APR', 'MAY', 'JUN',
    'JUL', 'AUG', 'SEP', 'OCT', 'NOV', 'DEC',
  ];

  bool _same(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}

// ─────────────────────────────────────────────────────────────────────────────
//  Quick select item
// ─────────────────────────────────────────────────────────────────────────────

class _QuickItem extends StatefulWidget {
  final String label;
  final VoidCallback onTap;
  const _QuickItem({required this.label, required this.onTap});

  @override
  State<_QuickItem> createState() => _QuickItemState();
}

class _QuickItemState extends State<_QuickItem> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 6),
          decoration: BoxDecoration(
            color: _hovered
                ? const Color(0xFFE6F0FC)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            widget.label,
            style: TextStyle(
              fontSize: 13,
              color: _hovered
                  ? const Color(0xFF1459AD)
                  : const Color(0xFF3D5A7E),
              fontWeight:
                  _hovered ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Action day button (YESTERDAY / TODAY / TOMORROW)
// ─────────────────────────────────────────────────────────────────────────────

class _ActionDayBtn extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _ActionDayBtn({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Button(
      onPressed: onTap,
      style: ButtonStyle(
        padding: WidgetStateProperty.all(
            const EdgeInsets.symmetric(horizontal: 10, vertical: 6)),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Month calendar
// ─────────────────────────────────────────────────────────────────────────────

class _MonthCalendar extends StatelessWidget {
  final DateTime month;
  final DateTime? start;
  final DateTime? end;
  final DateTime? hovered;
  final void Function(DateTime) onDayTap;
  final void Function(DateTime?) onHover;
  final VoidCallback? onPrev;
  final VoidCallback? onNext;

  const _MonthCalendar({
    required this.month,
    required this.start,
    required this.end,
    required this.hovered,
    required this.onDayTap,
    required this.onHover,
    required this.onPrev,
    required this.onNext,
  });

  static const _weekDays = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];

  List<DateTime?> _buildDaySlots() {
    final first = DateTime(month.year, month.month, 1);
    final lastDay = DateTime(month.year, month.month + 1, 0).day;
    final startWeekday = first.weekday % 7; // 0=Sun, 1=Mon, …
    final slots = <DateTime?>[];
    for (int i = 0; i < startWeekday; i++) {
      slots.add(null);
    }
    for (int d = 1; d <= lastDay; d++) {
      slots.add(DateTime(month.year, month.month, d));
    }
    return slots;
  }

  bool _isStart(DateTime day) =>
      start != null && _same(day, start!);

  bool _isEnd(DateTime day) =>
      end != null && _same(day, end!);

  bool _isInRange(DateTime day) {
    if (start == null) return false;
    final other = end ?? hovered;
    if (other == null) return false;
    final lo = start!.isBefore(other) ? start! : other;
    final hi = start!.isBefore(other) ? other : start!;
    return day.isAfter(lo) && day.isBefore(hi);
  }

  bool _isToday(DateTime day) => _same(day, DateTime.now());

  bool _same(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  @override
  Widget build(BuildContext context) {
    final slots = _buildDaySlots();

    // Pad to full weeks
    while (slots.length % 7 != 0) {
      slots.add(null);
    }

    final weeks = <List<DateTime?>>[];
    for (int i = 0; i < slots.length; i += 7) {
      weeks.add(slots.sublist(i, i + 7));
    }

    return Column(
      children: [
        // Month header
        Row(
          children: [
            SizedBox(
              width: 28,
              child: IconButton(
                icon: const Icon(FluentIcons.chevron_left, size: 11),
                onPressed: onPrev,
                style: ButtonStyle(
                  foregroundColor: WidgetStateProperty.all(
                    onPrev == null
                        ? const Color(0xFFCCD6E0)
                        : const Color(0xFF2D476D),
                  ),
                ),
              ),
            ),
            Expanded(
              child: Center(
                child: Text(
                  DateFormat('MMMM  yyyy').format(month),
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    color: Color(0xFF1B3A5C),
                  ),
                ),
              ),
            ),
            SizedBox(
              width: 28,
              child: IconButton(
                icon: const Icon(FluentIcons.chevron_right, size: 11),
                onPressed: onNext,
                style: ButtonStyle(
                  foregroundColor: WidgetStateProperty.all(
                    onNext == null
                        ? const Color(0xFFCCD6E0)
                        : const Color(0xFF2D476D),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),

        // Day-of-week header
        Row(
          children: _weekDays.map((h) {
            return Expanded(
              child: Center(
                child: Text(
                  h,
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF8AAAC6),
                  ),
                ),
              ),
            );
          }).toList(growable: false),
        ),
        const SizedBox(height: 2),

        // Day rows
        ...weeks.map(
          (week) => MouseRegion(
            onExit: (_) => onHover(null),
            child: Row(
              children: week.map((day) {
                if (day == null) {
                  return const Expanded(child: SizedBox(height: 32));
                }

                final isStart = _isStart(day);
                final isEnd = _isEnd(day);
                final inRange = _isInRange(day);
                final isToday = _isToday(day);
                final highlighted = isStart || isEnd;

                return Expanded(
                  child: MouseRegion(
                    cursor: SystemMouseCursors.click,
                    onEnter: (_) => onHover(day),
                    child: GestureDetector(
                      onTap: () => onDayTap(day),
                      child: Container(
                        height: 32,
                        decoration: BoxDecoration(
                          color: highlighted
                              ? const Color(0xFF1459AD)
                              : inRange
                                  ? const Color(0xFFCDE4FA)
                                  : Colors.transparent,
                          borderRadius: highlighted
                              ? BorderRadius.circular(999)
                              : inRange
                                  ? BorderRadius.horizontal(
                                      left: isStart
                                          ? const Radius.circular(999)
                                          : Radius.zero,
                                      right: isEnd
                                          ? const Radius.circular(999)
                                          : Radius.zero,
                                    )
                                  : null,
                          border: isToday && !highlighted
                              ? Border.all(
                                  color: const Color(0xFF1459AD),
                                  width: 1.2,
                                )
                              : null,
                          shape: highlighted
                              ? BoxShape.rectangle
                              : BoxShape.rectangle,
                        ),
                        child: Center(
                          child: Text(
                            '${day.day}',
                            style: TextStyle(
                              fontSize: 12,
                              color: highlighted
                                  ? Colors.white
                                  : isToday
                                      ? const Color(0xFF1459AD)
                                      : const Color(0xFF1B3A5C),
                              fontWeight:
                                  highlighted || isToday
                                      ? FontWeight.w700
                                      : FontWeight.w400,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(growable: false),
            ),
          ),
        ),
      ],
    );
  }
}
