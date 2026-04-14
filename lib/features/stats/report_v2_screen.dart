import 'dart:math' as math;

import 'package:apexo/core/multi_stream_builder.dart';
import 'package:apexo/features/appointments/appointment_model.dart';
import 'package:apexo/features/appointments/appointments_store.dart';
import 'package:apexo/features/doctors/doctors_store.dart';
import 'package:apexo/features/expenses/expense_model.dart';
import 'package:apexo/features/expenses/expenses_store.dart';
import 'package:apexo/features/patients/patients_store.dart';
import 'package:apexo/utils/indian_money.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:intl/intl.dart';

class ReportV2Screen extends StatelessWidget {
  const ReportV2Screen({super.key});

  @override
  Widget build(BuildContext context) {
    return ScaffoldPage.scrollable(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
      children: [
        MStreamBuilder(
          streams: [
            appointments.observableMap.stream,
            expenses.observableMap.stream,
            patients.observableMap.stream,
          ],
          builder: (context, _) {
            final allAppointments =
                appointments.present.values.toList(growable: false);
            final allExpenses = expenses.present.values.toList(growable: false);
            final screenWidth = MediaQuery.of(context).size.width;
            final horizontalPadding = screenWidth < 700 ? 32.0 : 42.0;
            final available =
                (screenWidth - horizontalPadding).clamp(320.0, 1800.0);
            final cardsPerRow = available >= 1600
                ? 3
                : available >= 980
                    ? 2
                    : 1;
            final cardWidth = cardsPerRow == 1
                ? available
                : ((available - ((cardsPerRow - 1) * 10)) / cardsPerRow)
                    .clamp(320.0, 820.0);

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Reports',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF12355F),
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Advanced analytics for appointments, traffic, and doctor outputs',
                  style: TextStyle(
                    color: Color(0xFF5A7397),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    SizedBox(
                      width: cardWidth,
                      child: _DailyAppointmentsTrendWindowCard(
                          rows: allAppointments),
                    ),
                    SizedBox(
                      width: cardWidth,
                      child: _MonthlyAppointmentsTrendWindowCard(
                        rows: allAppointments,
                      ),
                    ),
                    SizedBox(
                      width: cardWidth,
                      child:
                          _DailyRevenueTrendWindowCard(rows: allAppointments),
                    ),
                    SizedBox(
                      width: cardWidth,
                      child:
                          _MonthlyRevenueTrendWindowCard(rows: allAppointments),
                    ),
                    SizedBox(
                      width: cardWidth,
                      child: _MonthlyExpensesTrendWindowCard(rows: allExpenses),
                    ),
                    SizedBox(
                      width: cardWidth,
                      child: _MonthlyNetRevenueTrendWindowCard(
                        appointmentsRows: allAppointments,
                        expenseRows: allExpenses,
                      ),
                    ),
                    SizedBox(
                      width: cardWidth,
                      child: _ReferralSourceDistributionCard(),
                    ),
                    SizedBox(
                      width: cardWidth,
                      child: _MonthlyTreatmentDistributionCard(
                        rows: allAppointments,
                      ),
                    ),
                    SizedBox(
                      width: cardWidth,
                      child: _TrafficByTimeCard(rows: allAppointments),
                    ),
                    SizedBox(
                      width: cardWidth,
                      child: _TrafficByDayCard(rows: allAppointments),
                    ),
                    SizedBox(
                      width: cardWidth,
                      child: _AppointmentMetricsCard(rows: allAppointments),
                    ),
                    SizedBox(
                      width: cardWidth,
                      child: _NewVsReturningCard(rows: allAppointments),
                    ),
                  ],
                ),
              ],
            );
          },
        ),
      ],
    );
  }
}

enum _RangeFilter { today, week, month, sixMonths, ytd, year, all }

extension _RangeFilterLabel on _RangeFilter {
  String get label {
    switch (this) {
      case _RangeFilter.today:
        return 'Today';
      case _RangeFilter.week:
        return 'Week';
      case _RangeFilter.month:
        return 'Monthly';
      case _RangeFilter.sixMonths:
        return '6M';
      case _RangeFilter.ytd:
        return 'YTD';
      case _RangeFilter.year:
        return 'Year';
      case _RangeFilter.all:
        return 'All';
    }
  }
}

DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

List<Appointment> _rangeRows(
  List<Appointment> rows,
  _RangeFilter range, {
  DateTime? monthAnchor,
}) {
  if (range == _RangeFilter.all) return rows;

  final now = DateTime.now();
  final today = _dateOnly(now);
  DateTime start;
  DateTime endExclusive = today.add(const Duration(days: 1));

  switch (range) {
    case _RangeFilter.today:
      start = today;
      break;
    case _RangeFilter.week:
      start = today.subtract(const Duration(days: 6));
      break;
    case _RangeFilter.month:
      final anchor = monthAnchor ?? today;
      start = DateTime(anchor.year, anchor.month, 1);
      endExclusive = DateTime(anchor.year, anchor.month + 1, 1);
      break;
    case _RangeFilter.sixMonths:
      start = DateTime(today.year, today.month - 5, 1);
      break;
    case _RangeFilter.ytd:
      start = DateTime(today.year, 1, 1);
      break;
    case _RangeFilter.year:
      start = today.subtract(const Duration(days: 364));
      break;
    case _RangeFilter.all:
      start = DateTime(1970);
      break;
  }

  return rows
      .where((a) => !a.date.isBefore(start) && a.date.isBefore(endExclusive))
      .toList(growable: false);
}

List<MapEntry<String, int>> _treatmentDistributionRows(
    List<Appointment> source) {
  final counts = <String, int>{};
  for (final appointment in source) {
    for (final treatment in appointment.selectedTreatments) {
      final name = treatment.trim();
      if (name.isEmpty) continue;
      counts[name] = (counts[name] ?? 0) + 1;
    }
  }
  final rows = counts.entries.toList(growable: false)
    ..sort((a, b) => b.value.compareTo(a.value));
  return rows.take(8).toList(growable: false);
}

class _NewVsReturningCard extends StatelessWidget {
  final List<Appointment> rows;

  const _NewVsReturningCard({
    required this.rows,
  });

  @override
  Widget build(BuildContext context) {
    return _NewVsReturningCardBody(rows: rows);
  }
}

class _NewVsReturningCardBody extends StatefulWidget {
  final List<Appointment> rows;

  const _NewVsReturningCardBody({required this.rows});

  @override
  State<_NewVsReturningCardBody> createState() =>
      _NewVsReturningCardBodyState();
}

class _NewVsReturningCardBodyState extends State<_NewVsReturningCardBody> {
  _RangeFilter _range = _RangeFilter.month;
  DateTime _monthAnchor =
      DateTime(DateTime.now().year, DateTime.now().month, 1);

  @override
  Widget build(BuildContext context) {
    final firstVisitByPatient = <String, DateTime>{};
    for (final row in widget.rows) {
      final pid = row.patientID;
      if (pid == null || pid.isEmpty) continue;
      final existing = firstVisitByPatient[pid];
      if (existing == null || row.date.isBefore(existing)) {
        firstVisitByPatient[pid] = row.date;
      }
    }

    final scoped = _rangeRows(
      widget.rows,
      _range,
      monthAnchor: _monthAnchor,
    );
    final newCount = scoped.where((a) {
      final pid = a.patientID;
      if (pid == null || pid.isEmpty) return false;
      final first = firstVisitByPatient[pid];
      if (first == null) return false;
      return _dateOnly(first) == _dateOnly(a.date);
    }).length;
    final returningCount = math.max(0, scoped.length - newCount);
    final total = newCount + returningCount;
    final newPct = total == 0 ? 0.0 : (newCount / total) * 100;
    final returningPct = total == 0 ? 0.0 : (returningCount / total) * 100;

    return SizedBox(
      width: 560,
      child: _ReportContainer(
        title: 'New vs Returning',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _FilterChips(
              selected: _range,
              onChanged: (v) => setState(() => _range = v),
              monthAnchor: _monthAnchor,
              monthOptions: _monthOptions(widget.rows),
              onMonthChanged: (value) => setState(() => _monthAnchor = value),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 10,
              runSpacing: 8,
              children: [
                _pill('New', '$newCount', const Color(0xFF2D7BD8)),
                _pill('Returning', '$returningCount', const Color(0xFF2BA58D)),
                _pill('Total', '$total', const Color(0xFF5A7397)),
              ],
            ),
            const SizedBox(height: 12),
            _ratioBar('New', newPct, const Color(0xFF2D7BD8)),
            const SizedBox(height: 8),
            _ratioBar('Returning', returningPct, const Color(0xFF2BA58D)),
          ],
        ),
      ),
    );
  }

  Widget _pill(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF6FAFF),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFDCE8F6)),
      ),
      child: Text(
        '$label: $value',
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w800,
          fontSize: 12,
        ),
      ),
    );
  }

  Widget _ratioBar(String label, double pct, Color color) {
    return Row(
      children: [
        SizedBox(
          width: 90,
          child: Text(
            label,
            style: const TextStyle(
              color: Color(0xFF36557C),
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
        ),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Container(
              height: 10,
              color: const Color(0xFFEAF2FC),
              child: FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: (pct / 100).clamp(0.0, 1.0),
                child: Container(color: color),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          '${pct.toStringAsFixed(1)}%',
          style: const TextStyle(
            color: Color(0xFF36557C),
            fontWeight: FontWeight.w700,
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}

class _MonthlyTreatmentDistributionCard extends StatefulWidget {
  final List<Appointment> rows;

  const _MonthlyTreatmentDistributionCard({required this.rows});

  @override
  State<_MonthlyTreatmentDistributionCard> createState() =>
      _MonthlyTreatmentDistributionCardState();
}

class _MonthlyTreatmentDistributionCardState
    extends State<_MonthlyTreatmentDistributionCard> {
  int _monthOffset = 0;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final monthStart = DateTime(now.year, now.month - _monthOffset, 1);
    final monthEnd = DateTime(monthStart.year, monthStart.month + 1, 1);
    final scoped = widget.rows
        .where((a) => !a.date.isBefore(monthStart) && a.date.isBefore(monthEnd))
        .toList(growable: false);
    final rows = _treatmentDistributionRows(scoped);
    final total = rows.fold<int>(0, (s, e) => s + e.value);
    final colors = const [
      Color(0xFF2D7BD8),
      Color(0xFF2BA58D),
      Color(0xFFE09C31),
      Color(0xFF7D8FA7),
      Color(0xFFD6455D),
      Color(0xFF8D5CF6),
    ];

    return SizedBox(
      width: 560,
      child: _ReportContainer(
        title: 'Monthly Treatment Distribution',
        subtitle: DateFormat('MMMM yyyy').format(monthStart),
        trailing: _TrendNavButtons(
          canGoForward: _monthOffset > 0,
          onBack: () => setState(() => _monthOffset += 1),
          onForward:
              _monthOffset > 0 ? () => setState(() => _monthOffset -= 1) : null,
        ),
        child: SizedBox(
          height: 250,
          child: rows.isEmpty
              ? const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'No treatment data for this month.',
                    style: TextStyle(color: Color(0xFF6D84A8)),
                  ),
                )
              : Row(
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(left: 8, right: 2),
                      child: SizedBox(
                        width: 112,
                        height: 112,
                        child: CustomPaint(
                          painter: _DonutPainter(
                            rows: rows,
                            colors: colors,
                          ),
                          child: Center(
                            child: Text(
                              '$total',
                              style: const TextStyle(
                                color: Color(0xFF1D3E67),
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: rows.asMap().entries.map((entry) {
                            final row = entry.value;
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 6),
                              child: Row(
                                children: [
                                  Container(
                                    width: 9,
                                    height: 9,
                                    decoration: BoxDecoration(
                                      color: colors[entry.key % colors.length],
                                      borderRadius: BorderRadius.circular(2),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      '${row.key} (${row.value})',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: Color(0xFF36557C),
                                        fontWeight: FontWeight.w700,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList(growable: false),
                        ),
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

class _DonutPainter extends CustomPainter {
  final List<MapEntry<String, int>> rows;
  final List<Color> colors;

  _DonutPainter({required this.rows, required this.colors});

  @override
  void paint(Canvas canvas, Size size) {
    final total = rows.fold<int>(0, (s, e) => s + e.value);
    if (total == 0) return;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);
    final stroke = radius * 0.34;

    var start = -math.pi / 2;
    for (var i = 0; i < rows.length; i++) {
      final sweep = (rows[i].value / total) * math.pi * 2;
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.round
        ..color = colors[i % colors.length];
      canvas.drawArc(rect, start, sweep, false, paint);
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant _DonutPainter oldDelegate) {
    return oldDelegate.rows != rows || oldDelegate.colors != colors;
  }
}

class _FilterChips extends StatelessWidget {
  final _RangeFilter selected;
  final ValueChanged<_RangeFilter> onChanged;
  final bool includeToday;
  final DateTime? monthAnchor;
  final List<DateTime>? monthOptions;
  final ValueChanged<DateTime>? onMonthChanged;

  const _FilterChips({
    required this.selected,
    required this.onChanged,
    this.includeToday = true,
    this.monthAnchor,
    this.monthOptions,
    this.onMonthChanged,
  });

  @override
  Widget build(BuildContext context) {
    final all = _RangeFilter.values
        .where((r) => includeToday || r != _RangeFilter.today)
        .toList(growable: false);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: all
              .map(
                (range) => GestureDetector(
                  onTap: () => onChanged(range),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: selected == range
                          ? const Color(0xFF2D7BD8)
                          : const Color(0xFFEFF4FB),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: selected == range
                            ? const Color(0xFF2D7BD8)
                            : const Color(0xFFD6E2F0),
                      ),
                    ),
                    child: Text(
                      range.label,
                      style: TextStyle(
                        color: selected == range
                            ? Colors.white
                            : const Color(0xFF355279),
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
              )
              .toList(growable: false),
        ),
        if (selected == _RangeFilter.month &&
            monthOptions != null &&
            monthOptions!.isNotEmpty &&
            onMonthChanged != null) ...[
          const SizedBox(height: 8),
          SizedBox(
            width: 180,
            child: ComboBox<DateTime>(
              isExpanded: true,
              value: monthAnchor,
              items: monthOptions!
                  .map(
                    (m) => ComboBoxItem<DateTime>(
                      value: m,
                      child: Text(DateFormat('MMMM yyyy').format(m)),
                    ),
                  )
                  .toList(growable: false),
              onChanged: (v) {
                if (v != null) onMonthChanged!(v);
              },
            ),
          ),
        ],
      ],
    );
  }
}

List<DateTime> _monthOptions(List<Appointment> rows) {
  final months = rows
      .map((a) => DateTime(a.date.year, a.date.month, 1))
      .toSet()
      .toList(growable: false)
    ..sort((a, b) => b.compareTo(a));
  return months;
}

class _DailyAppointmentsTrendWindowCard extends StatefulWidget {
  final List<Appointment> rows;

  const _DailyAppointmentsTrendWindowCard({required this.rows});

  @override
  State<_DailyAppointmentsTrendWindowCard> createState() =>
      _DailyAppointmentsTrendWindowCardState();
}

class _DailyAppointmentsTrendWindowCardState
    extends State<_DailyAppointmentsTrendWindowCard> {
  int _monthOffset = 0;

  @override
  Widget build(BuildContext context) {
    final currentMonth = DateTime(DateTime.now().year, DateTime.now().month, 1);
    final monthStart =
        DateTime(currentMonth.year, currentMonth.month - _monthOffset, 1);
    final monthEnd = DateTime(monthStart.year, monthStart.month + 1, 1);
    final dayCount = monthEnd.difference(monthStart).inDays;

    final starts = List<DateTime>.generate(
        dayCount, (i) => monthStart.add(Duration(days: i)),
        growable: false);

    final points = starts.map((start) {
      final end = start.add(const Duration(days: 1));
      final count = widget.rows
          .where((a) => !a.date.isBefore(start) && a.date.isBefore(end))
          .length
          .toDouble();
      return (label: DateFormat('dd').format(start), value: count);
    }).toList(growable: false);

    return SizedBox(
      width: 560,
      child: _SimpleBarsCard(
        title: 'Appointment Trend (Daily)',
        subtitle: DateFormat('MMMM yyyy').format(monthStart),
        rows: points,
        barColor: const Color(0xFF2D7BD8),
        showEveryNthXLabel: 5,
        trailing: _TrendNavButtons(
          canGoForward: _monthOffset > 0,
          onBack: () => setState(() => _monthOffset += 1),
          onForward:
              _monthOffset > 0 ? () => setState(() => _monthOffset -= 1) : null,
        ),
      ),
    );
  }
}

class _MonthlyAppointmentsTrendWindowCard extends StatefulWidget {
  final List<Appointment> rows;

  const _MonthlyAppointmentsTrendWindowCard({required this.rows});

  @override
  State<_MonthlyAppointmentsTrendWindowCard> createState() =>
      _MonthlyAppointmentsTrendWindowCardState();
}

class _MonthlyAppointmentsTrendWindowCardState
    extends State<_MonthlyAppointmentsTrendWindowCard> {
  int _windowOffset = 0;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final windowEnd = DateTime(now.year, now.month - _windowOffset + 1, 1);
    final windowStart = DateTime(windowEnd.year, windowEnd.month - 12, 1);
    final starts = List<DateTime>.generate(
      12,
      (i) => DateTime(windowStart.year, windowStart.month + i, 1),
      growable: false,
    );

    final points = starts.map((start) {
      final end = DateTime(start.year, start.month + 1, 1);
      final count = widget.rows
          .where((a) => !a.date.isBefore(start) && a.date.isBefore(end))
          .length
          .toDouble();
      return (label: DateFormat('MMM').format(start), value: count);
    }).toList(growable: false);

    return SizedBox(
      width: 560,
      child: _SimpleBarsCard(
        title: 'Appointment Trend (Monthly)',
        subtitle:
            '${DateFormat('MMM yyyy').format(starts.first)} - ${DateFormat('MMM yyyy').format(starts.last)}',
        rows: points,
        barColor: const Color(0xFF2BA58D),
        trailing: _TrendNavButtons(
          canGoForward: _windowOffset > 0,
          onBack: () => setState(() => _windowOffset += 1),
          onForward: _windowOffset > 0
              ? () => setState(() => _windowOffset -= 1)
              : null,
        ),
      ),
    );
  }
}

class _DailyRevenueTrendWindowCard extends StatefulWidget {
  final List<Appointment> rows;

  const _DailyRevenueTrendWindowCard({required this.rows});

  @override
  State<_DailyRevenueTrendWindowCard> createState() =>
      _DailyRevenueTrendWindowCardState();
}

class _DailyRevenueTrendWindowCardState
    extends State<_DailyRevenueTrendWindowCard> {
  int _monthOffset = 0;

  @override
  Widget build(BuildContext context) {
    final currentMonth = DateTime(DateTime.now().year, DateTime.now().month, 1);
    final monthStart =
        DateTime(currentMonth.year, currentMonth.month - _monthOffset, 1);
    final monthEnd = DateTime(monthStart.year, monthStart.month + 1, 1);
    final dayCount = monthEnd.difference(monthStart).inDays;

    final starts = List<DateTime>.generate(
        dayCount, (i) => monthStart.add(Duration(days: i)),
        growable: false);

    final points = starts.map((start) {
      final end = start.add(const Duration(days: 1));
      final value = widget.rows
          .where((a) => !a.date.isBefore(start) && a.date.isBefore(end))
          .fold<double>(0, (sum, a) => sum + a.paid + a.prescriptionPaid);
      return (label: DateFormat('dd').format(start), value: value);
    }).toList(growable: false);

    return SizedBox(
      width: 560,
      child: _SimpleBarsCard(
        title: 'Gross Revenue Trend (Daily)',
        subtitle: DateFormat('MMMM yyyy').format(monthStart),
        rows: points,
        barColor: const Color(0xFF1468CC),
        showEveryNthXLabel: 5,
        valueFormatter: formatIndianShortCurrency,
        verticalValueLabels: true,
        trailing: _TrendNavButtons(
          canGoForward: _monthOffset > 0,
          onBack: () => setState(() => _monthOffset += 1),
          onForward:
              _monthOffset > 0 ? () => setState(() => _monthOffset -= 1) : null,
        ),
      ),
    );
  }
}

class _MonthlyRevenueTrendWindowCard extends StatefulWidget {
  final List<Appointment> rows;

  const _MonthlyRevenueTrendWindowCard({required this.rows});

  @override
  State<_MonthlyRevenueTrendWindowCard> createState() =>
      _MonthlyRevenueTrendWindowCardState();
}

class _MonthlyRevenueTrendWindowCardState
    extends State<_MonthlyRevenueTrendWindowCard> {
  int _windowOffset = 0;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final windowEnd = DateTime(now.year, now.month - _windowOffset + 1, 1);
    final windowStart = DateTime(windowEnd.year, windowEnd.month - 12, 1);
    final starts = List<DateTime>.generate(
      12,
      (i) => DateTime(windowStart.year, windowStart.month + i, 1),
      growable: false,
    );

    final points = starts.map((start) {
      final end = DateTime(start.year, start.month + 1, 1);
      final value = widget.rows
          .where((a) => !a.date.isBefore(start) && a.date.isBefore(end))
          .fold<double>(0, (sum, a) => sum + a.paid + a.prescriptionPaid);
      return (label: DateFormat('MMM').format(start), value: value);
    }).toList(growable: false);

    return SizedBox(
      width: 560,
      child: _SimpleBarsCard(
        title: 'Gross Revenue Trend (Monthly)',
        subtitle:
            '${DateFormat('MMM yyyy').format(starts.first)} - ${DateFormat('MMM yyyy').format(starts.last)}',
        rows: points,
        barColor: const Color(0xFF2BA58D),
        valueFormatter: formatIndianShortCurrency,
        trailing: _TrendNavButtons(
          canGoForward: _windowOffset > 0,
          onBack: () => setState(() => _windowOffset += 1),
          onForward: _windowOffset > 0
              ? () => setState(() => _windowOffset -= 1)
              : null,
        ),
      ),
    );
  }
}

class _MonthlyExpensesTrendWindowCard extends StatefulWidget {
  final List<Expense> rows;

  const _MonthlyExpensesTrendWindowCard({required this.rows});

  @override
  State<_MonthlyExpensesTrendWindowCard> createState() =>
      _MonthlyExpensesTrendWindowCardState();
}

class _MonthlyNetRevenueTrendWindowCard extends StatefulWidget {
  final List<Appointment> appointmentsRows;
  final List<Expense> expenseRows;

  const _MonthlyNetRevenueTrendWindowCard({
    required this.appointmentsRows,
    required this.expenseRows,
  });

  @override
  State<_MonthlyNetRevenueTrendWindowCard> createState() =>
      _MonthlyNetRevenueTrendWindowCardState();
}

class _MonthlyNetRevenueTrendWindowCardState
    extends State<_MonthlyNetRevenueTrendWindowCard> {
  int _windowOffset = 0;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final windowEnd = DateTime(now.year, now.month - _windowOffset + 1, 1);
    final windowStart = DateTime(windowEnd.year, windowEnd.month - 12, 1);
    final starts = List<DateTime>.generate(
      12,
      (i) => DateTime(windowStart.year, windowStart.month + i, 1),
      growable: false,
    );

    final points = starts.map((start) {
      final end = DateTime(start.year, start.month + 1, 1);
      final gross = widget.appointmentsRows
          .where((a) => !a.date.isBefore(start) && a.date.isBefore(end))
          .fold<double>(0, (sum, a) => sum + a.paid + a.prescriptionPaid);
      final expensesSum = widget.expenseRows
          .where((e) => !e.date.isBefore(start) && e.date.isBefore(end))
          .fold<double>(0, (sum, e) => sum + e.amount);
      final net = gross - expensesSum;
      return (label: DateFormat('MMM').format(start), value: net);
    }).toList(growable: false);

    return SizedBox(
      width: 560,
      child: _SimpleBarsCard(
        title: 'Net Revenue Trend (Monthly)',
        subtitle:
            '${DateFormat('MMM yyyy').format(starts.first)} - ${DateFormat('MMM yyyy').format(starts.last)}',
        rows: points,
        barColor: const Color(0xFF2D7BD8),
        valueFormatter: formatIndianShortCurrency,
        trailing: _TrendNavButtons(
          canGoForward: _windowOffset > 0,
          onBack: () => setState(() => _windowOffset += 1),
          onForward: _windowOffset > 0
              ? () => setState(() => _windowOffset -= 1)
              : null,
        ),
      ),
    );
  }
}

class _ReferralSourceDistributionCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final counts = <String, int>{};
    for (final patient in patients.present.values) {
      final source = patient.referralSource.trim().isEmpty
          ? 'None'
          : patient.referralSource.trim();
      counts[source] = (counts[source] ?? 0) + 1;
    }

    final rows = counts.entries.toList(growable: false)
      ..sort((a, b) => b.value.compareTo(a.value));
    final total = rows.fold<int>(0, (sum, e) => sum + e.value);
    final colors = const [
      Color(0xFF2D7BD8),
      Color(0xFF2BA58D),
      Color(0xFFE09C31),
      Color(0xFFD6455D),
      Color(0xFF7D8FA7),
      Color(0xFF8D5CF6),
    ];

    return SizedBox(
      width: 560,
      child: _ReportContainer(
        title: 'Referral Source Report',
        subtitle: 'Patient acquisition channels',
        child: SizedBox(
          height: 250,
          child: rows.isEmpty
              ? const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'No referral source data found.',
                    style: TextStyle(color: Color(0xFF6D84A8)),
                  ),
                )
              : Row(
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(left: 8, right: 2),
                      child: SizedBox(
                        width: 112,
                        height: 112,
                        child: CustomPaint(
                          painter: _DonutPainter(rows: rows, colors: colors),
                          child: Center(
                            child: Text(
                              '$total',
                              style: const TextStyle(
                                color: Color(0xFF1D3E67),
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: rows.asMap().entries.map((entry) {
                            final row = entry.value;
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 6),
                              child: Row(
                                children: [
                                  Container(
                                    width: 9,
                                    height: 9,
                                    decoration: BoxDecoration(
                                      color: colors[entry.key % colors.length],
                                      borderRadius: BorderRadius.circular(2),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      '${row.key} (${row.value})',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: Color(0xFF36557C),
                                        fontWeight: FontWeight.w700,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList(growable: false),
                        ),
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

class _MonthlyExpensesTrendWindowCardState
    extends State<_MonthlyExpensesTrendWindowCard> {
  int _windowOffset = 0;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final windowEnd = DateTime(now.year, now.month - _windowOffset + 1, 1);
    final windowStart = DateTime(windowEnd.year, windowEnd.month - 12, 1);
    final starts = List<DateTime>.generate(
      12,
      (i) => DateTime(windowStart.year, windowStart.month + i, 1),
      growable: false,
    );

    final points = starts.map((start) {
      final end = DateTime(start.year, start.month + 1, 1);
      final value = widget.rows
          .where((e) => !e.date.isBefore(start) && e.date.isBefore(end))
          .fold<double>(0, (sum, e) => sum + e.amount);
      return (label: DateFormat('MMM').format(start), value: value);
    }).toList(growable: false);

    return SizedBox(
      width: 560,
      child: _SimpleBarsCard(
        title: 'Expenses Trend (Monthly)',
        subtitle:
            '${DateFormat('MMM yyyy').format(starts.first)} - ${DateFormat('MMM yyyy').format(starts.last)}',
        rows: points,
        barColor: const Color(0xFFD6455D),
        valueFormatter: formatIndianShortCurrency,
        trailing: _TrendNavButtons(
          canGoForward: _windowOffset > 0,
          onBack: () => setState(() => _windowOffset += 1),
          onForward: _windowOffset > 0
              ? () => setState(() => _windowOffset -= 1)
              : null,
        ),
      ),
    );
  }
}

class _TrendNavButtons extends StatelessWidget {
  final VoidCallback onBack;
  final VoidCallback? onForward;
  final bool canGoForward;

  const _TrendNavButtons({
    required this.onBack,
    required this.onForward,
    required this.canGoForward,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 24,
          height: 24,
          child: IconButton(
            icon: const Icon(FluentIcons.chevron_left, size: 11),
            onPressed: onBack,
          ),
        ),
        const SizedBox(width: 4),
        SizedBox(
          width: 24,
          height: 24,
          child: IconButton(
            icon: const Icon(FluentIcons.chevron_right, size: 11),
            onPressed: canGoForward ? onForward : null,
          ),
        ),
      ],
    );
  }
}

class _SimpleBarsCard extends StatelessWidget {
  final String title;
  final String? subtitle;
  final List<({String label, double value})> rows;
  final Color barColor;
  final int showEveryNthXLabel;
  final Widget? trailing;
  final String Function(double value)? valueFormatter;
  final bool verticalValueLabels;

  const _SimpleBarsCard({
    required this.title,
    this.subtitle,
    required this.rows,
    required this.barColor,
    this.showEveryNthXLabel = 1,
    this.trailing,
    this.valueFormatter,
    this.verticalValueLabels = false,
  });

  @override
  Widget build(BuildContext context) {
    final max = rows.fold<double>(1, (m, row) => row.value > m ? row.value : m);

    return _ReportContainer(
      title: title,
      subtitle: subtitle,
      trailing: trailing,
      child: SizedBox(
        height: 250,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: rows
              .asMap()
              .entries
              .map(
                (entry) => Expanded(
                  child: Tooltip(
                    message:
                        '${entry.value.label}: ${valueFormatter == null ? entry.value.value.toStringAsFixed(0) : valueFormatter!(entry.value.value)}',
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          if (!verticalValueLabels)
                            Text(
                              valueFormatter == null
                                  ? entry.value.value.toStringAsFixed(0)
                                  : valueFormatter!(entry.value.value),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Color(0xFF36557C),
                                fontWeight: FontWeight.w700,
                                fontSize: 10,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          if (verticalValueLabels)
                            RotatedBox(
                              quarterTurns: 3,
                              child: SizedBox(
                                width: 44,
                                child: Text(
                                  entry.value.value == 0
                                      ? ''
                                      : (valueFormatter == null
                                          ? entry.value.value.toStringAsFixed(0)
                                          : valueFormatter!(entry.value.value)),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Color(0xFF36557C),
                                    fontWeight: FontWeight.w700,
                                    fontSize: 9,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ),
                          const SizedBox(height: 3),
                          Container(
                            height: (145 * (entry.value.value / max))
                                .clamp(0, 145)
                                .toDouble(),
                            decoration: BoxDecoration(
                              color: barColor,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            entry.key % showEveryNthXLabel == 0
                                ? entry.value.label
                                : '',
                            style: const TextStyle(
                              color: Color(0xFF5A7397),
                              fontWeight: FontWeight.w700,
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              )
              .toList(growable: false),
        ),
      ),
    );
  }
}

class _TrafficByTimeCard extends StatefulWidget {
  final List<Appointment> rows;

  const _TrafficByTimeCard({required this.rows});

  @override
  State<_TrafficByTimeCard> createState() => _TrafficByTimeCardState();
}

class _TrafficByTimeCardState extends State<_TrafficByTimeCard> {
  _RangeFilter _range = _RangeFilter.today;
  DateTime _monthAnchor =
      DateTime(DateTime.now().year, DateTime.now().month, 1);

  @override
  Widget build(BuildContext context) {
    final scoped = _rangeRows(widget.rows, _range, monthAnchor: _monthAnchor);
    final buckets = <String, double>{
      '12-3 AM': 0,
      '3-6 AM': 0,
      '6-9 AM': 0,
      '9-12 AM': 0,
      '12-3 PM': 0,
      '3-6 PM': 0,
      '6-9 PM': 0,
      '9-12 PM': 0,
    };

    for (final appointment in scoped) {
      final hour = appointment.date.hour;
      if (hour < 3) {
        buckets['12-3 AM'] = (buckets['12-3 AM'] ?? 0) + 1;
      } else if (hour < 6) {
        buckets['3-6 AM'] = (buckets['3-6 AM'] ?? 0) + 1;
      } else if (hour < 9) {
        buckets['6-9 AM'] = (buckets['6-9 AM'] ?? 0) + 1;
      } else if (hour < 12) {
        buckets['9-12 AM'] = (buckets['9-12 AM'] ?? 0) + 1;
      } else if (hour < 15) {
        buckets['12-3 PM'] = (buckets['12-3 PM'] ?? 0) + 1;
      } else if (hour < 18) {
        buckets['3-6 PM'] = (buckets['3-6 PM'] ?? 0) + 1;
      } else if (hour < 21) {
        buckets['6-9 PM'] = (buckets['6-9 PM'] ?? 0) + 1;
      } else {
        buckets['9-12 PM'] = (buckets['9-12 PM'] ?? 0) + 1;
      }
    }

    final points = buckets.entries
        .map((e) => (label: e.key, value: e.value))
        .toList(growable: false);

    return SizedBox(
      width: 560,
      child: _ReportContainer(
        title: 'Traffic by Time',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _FilterChips(
              selected: _range,
              onChanged: (v) => setState(() => _range = v),
              monthAnchor: _monthAnchor,
              monthOptions: _monthOptions(widget.rows),
              onMonthChanged: (value) => setState(() => _monthAnchor = value),
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 220,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: points
                    .map(
                      (point) => Expanded(
                        child: Tooltip(
                          message:
                              '${point.label}: ${point.value.toStringAsFixed(0)}',
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 2),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                Text(
                                  point.value.toStringAsFixed(0),
                                  style: const TextStyle(
                                    fontSize: 10,
                                    color: Color(0xFF36557C),
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Container(
                                  height: (120 *
                                          (point.value /
                                              points.fold<double>(
                                                1,
                                                (m, e) =>
                                                    e.value > m ? e.value : m,
                                              )))
                                      .clamp(4, 120)
                                      .toDouble(),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF2D7BD8),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  point.label,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    fontSize: 10,
                                    color: Color(0xFF5A7397),
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    )
                    .toList(growable: false),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TrafficByDayCard extends StatefulWidget {
  final List<Appointment> rows;

  const _TrafficByDayCard({required this.rows});

  @override
  State<_TrafficByDayCard> createState() => _TrafficByDayCardState();
}

class _TrafficByDayCardState extends State<_TrafficByDayCard> {
  _RangeFilter _range = _RangeFilter.week;
  DateTime _monthAnchor =
      DateTime(DateTime.now().year, DateTime.now().month, 1);

  @override
  Widget build(BuildContext context) {
    final scoped = _rangeRows(widget.rows, _range, monthAnchor: _monthAnchor);
    final buckets = <String, double>{
      'Mon': 0,
      'Tue': 0,
      'Wed': 0,
      'Thu': 0,
      'Fri': 0,
      'Sat': 0,
      'Sun': 0,
    };

    for (final appointment in scoped) {
      final key = switch (appointment.date.weekday) {
        1 => 'Mon',
        2 => 'Tue',
        3 => 'Wed',
        4 => 'Thu',
        5 => 'Fri',
        6 => 'Sat',
        _ => 'Sun',
      };
      buckets[key] = (buckets[key] ?? 0) + 1;
    }

    final points = buckets.entries
        .map((e) => (label: e.key, value: e.value))
        .toList(growable: false);
    final max = points.fold<double>(1, (m, e) => e.value > m ? e.value : m);

    return SizedBox(
      width: 560,
      child: _ReportContainer(
        title: 'Traffic by Day',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _FilterChips(
              selected: _range,
              includeToday: false,
              onChanged: (v) => setState(() => _range = v),
              monthAnchor: _monthAnchor,
              monthOptions: _monthOptions(widget.rows),
              onMonthChanged: (value) => setState(() => _monthAnchor = value),
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 220,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: points
                    .map(
                      (point) => Expanded(
                        child: Tooltip(
                          message:
                              '${point.label}: ${point.value.toStringAsFixed(0)}',
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 3),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                Text(
                                  point.value.toStringAsFixed(0),
                                  style: const TextStyle(
                                    color: Color(0xFF36557C),
                                    fontWeight: FontWeight.w700,
                                    fontSize: 10,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Container(
                                  height: (130 * (point.value / max))
                                      .clamp(4, 130)
                                      .toDouble(),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF2BA58D),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  point.label,
                                  style: const TextStyle(
                                    color: Color(0xFF5A7397),
                                    fontWeight: FontWeight.w700,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    )
                    .toList(growable: false),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AppointmentMetricsCard extends StatefulWidget {
  final List<Appointment> rows;

  const _AppointmentMetricsCard({required this.rows});

  @override
  State<_AppointmentMetricsCard> createState() =>
      _AppointmentMetricsCardState();
}

class _AppointmentMetricsCardState extends State<_AppointmentMetricsCard> {
  _RangeFilter _range = _RangeFilter.today;
  DateTime _monthAnchor =
      DateTime(DateTime.now().year, DateTime.now().month, 1);

  @override
  Widget build(BuildContext context) {
    final scoped = _rangeRows(widget.rows, _range, monthAnchor: _monthAnchor);
    final data = <({String doctor, int appointments, double earned})>[];

    for (final doctor in doctors.present.values) {
      final rows = scoped
          .where((a) => a.operatorsIDs.contains(doctor.id))
          .toList(growable: false);
      if (rows.isEmpty) continue;

      final earned = rows.fold<double>(
        0,
        (sum, a) => sum + a.paid + a.prescriptionPaid,
      );
      data.add((
        doctor: doctor.title.trim().isEmpty ? 'Unnamed doctor' : doctor.title,
        appointments: rows.length,
        earned: earned,
      ));
    }

    data.sort((a, b) => b.appointments.compareTo(a.appointments));

    final totalAppointments =
        data.fold<int>(0, (sum, row) => sum + row.appointments);
    final totalEarned = data.fold<double>(0, (sum, row) => sum + row.earned);

    return SizedBox(
      width: 560,
      child: _ReportContainer(
        title: 'Appointment Metrics',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _FilterChips(
              selected: _range,
              onChanged: (v) => setState(() => _range = v),
              monthAnchor: _monthAnchor,
              monthOptions: _monthOptions(widget.rows),
              onMonthChanged: (value) => setState(() => _monthAnchor = value),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 10,
              runSpacing: 8,
              children: [
                _metricPill('Appointments', '$totalAppointments'),
                _metricPill(
                    'Money Earned', formatIndianShortCurrency(totalEarned)),
                _metricPill('Active Doctors', '${data.length}'),
              ],
            ),
            const SizedBox(height: 10),
            if (data.isEmpty)
              const Text(
                'No appointment metrics for selected range.',
                style: TextStyle(color: Color(0xFF6D84A8)),
              )
            else
              ...data.take(10).map(
                    (row) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              row.doctor,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Color(0xFF1F446E),
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          Text(
                            '${row.appointments} appts • ${formatIndianShortCurrency(row.earned)}',
                            style: const TextStyle(
                              color: Color(0xFF5B789F),
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
          ],
        ),
      ),
    );
  }

  Widget _metricPill(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF6FAFF),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFDCE8F6)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$label: ',
            style: const TextStyle(
              color: Color(0xFF36557C),
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              color: Color(0xFF1459AD),
              fontWeight: FontWeight.w800,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _ReportContainer extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final Widget child;

  const _ReportContainer({
    required this.title,
    this.subtitle,
    this.trailing,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFD7E3F0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x160D2F5B),
            blurRadius: 10,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    color: Color(0xFF183A67),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (trailing != null) trailing!,
            ],
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(
              subtitle!,
              style: const TextStyle(
                color: Color(0xFF5A7397),
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
          ],
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}
