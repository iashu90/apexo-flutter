import 'package:apexo/core/multi_stream_builder.dart';
import 'package:apexo/features/appointments/appointment_model.dart';
import 'package:apexo/features/appointments/appointments_store.dart';
import 'package:apexo/features/doctors/doctors_store.dart';
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
          streams: [appointments.observableMap.stream],
          builder: (context, _) {
            final allAppointments =
                appointments.present.values.toList(growable: false);

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Report V2',
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
                    _DailyAppointmentsTrend30Card(rows: allAppointments),
                    _MonthlyAppointmentsTrend12Card(rows: allAppointments),
                    _TrafficByTimeCard(rows: allAppointments),
                    _TrafficByDayCard(rows: allAppointments),
                    _AppointmentMetricsCard(rows: allAppointments),
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

List<Appointment> _rangeRows(List<Appointment> rows, _RangeFilter range) {
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
      start = DateTime(today.year, today.month, 1);
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

class _FilterChips extends StatelessWidget {
  final _RangeFilter selected;
  final ValueChanged<_RangeFilter> onChanged;

  const _FilterChips({
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final all = _RangeFilter.values;
    return Wrap(
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
    );
  }
}

class _DailyAppointmentsTrend30Card extends StatelessWidget {
  final List<Appointment> rows;

  const _DailyAppointmentsTrend30Card({required this.rows});

  @override
  Widget build(BuildContext context) {
    final now = _dateOnly(DateTime.now());
    final starts = List<DateTime>.generate(
      30,
      (i) => now.subtract(Duration(days: 29 - i)),
      growable: false,
    );

    final points = starts
        .map((start) {
          final end = start.add(const Duration(days: 1));
          final count = rows
              .where((a) => !a.date.isBefore(start) && a.date.isBefore(end))
              .length
              .toDouble();
          return (label: DateFormat('dd').format(start), value: count);
        })
        .toList(growable: false);

    return SizedBox(
      width: 660,
      child: _SimpleBarsCard(
        title: 'Appointment Trend (Daily - 30 Days)',
        rows: points,
        barColor: const Color(0xFF2D7BD8),
        showEveryNthXLabel: 5,
      ),
    );
  }
}

class _MonthlyAppointmentsTrend12Card extends StatelessWidget {
  final List<Appointment> rows;

  const _MonthlyAppointmentsTrend12Card({required this.rows});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final starts = List<DateTime>.generate(
      12,
      (i) => DateTime(now.year, now.month - (11 - i), 1),
      growable: false,
    );

    final points = starts
        .map((start) {
          final end = DateTime(start.year, start.month + 1, 1);
          final count = rows
              .where((a) => !a.date.isBefore(start) && a.date.isBefore(end))
              .length
              .toDouble();
          return (label: DateFormat('MMM').format(start), value: count);
        })
        .toList(growable: false);

    return SizedBox(
      width: 660,
      child: _SimpleBarsCard(
        title: 'Appointment Trend (Monthly - 12 Months)',
        rows: points,
        barColor: const Color(0xFF2BA58D),
      ),
    );
  }
}

class _SimpleBarsCard extends StatelessWidget {
  final String title;
  final List<({String label, double value})> rows;
  final Color barColor;
  final int showEveryNthXLabel;

  const _SimpleBarsCard({
    required this.title,
    required this.rows,
    required this.barColor,
    this.showEveryNthXLabel = 1,
  });

  @override
  Widget build(BuildContext context) {
    final max = rows.fold<double>(1, (m, row) => row.value > m ? row.value : m);

    return _ReportContainer(
      title: title,
      child: SizedBox(
        height: 250,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: rows.asMap().entries
              .map(
                (entry) => Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text(
                          entry.value.value.toStringAsFixed(0),
                          style: const TextStyle(
                            color: Color(0xFF36557C),
                            fontWeight: FontWeight.w700,
                            fontSize: 10,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Container(
                          height: (145 * (entry.value.value / max)).clamp(4, 145)
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

  @override
  Widget build(BuildContext context) {
    final scoped = _rangeRows(widget.rows, _range);
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
      width: 660,
      child: _ReportContainer(
        title: 'Traffic by Time',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _FilterChips(
              selected: _range,
              onChanged: (v) => setState(() => _range = v),
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 220,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: points
                    .map(
                      (point) => Expanded(
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
                                              (m, e) => e.value > m
                                                  ? e.value
                                                  : m,
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
  _RangeFilter _range = _RangeFilter.today;

  @override
  Widget build(BuildContext context) {
    final scoped = _rangeRows(widget.rows, _range);
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
      width: 660,
      child: _ReportContainer(
        title: 'Traffic by Day',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _FilterChips(
              selected: _range,
              onChanged: (v) => setState(() => _range = v),
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 220,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: points
                    .map(
                      (point) => Expanded(
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
                                height: (130 * (point.value / max)).clamp(4, 130)
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
  State<_AppointmentMetricsCard> createState() => _AppointmentMetricsCardState();
}

class _AppointmentMetricsCardState extends State<_AppointmentMetricsCard> {
  _RangeFilter _range = _RangeFilter.today;

  @override
  Widget build(BuildContext context) {
    final scoped = _rangeRows(widget.rows, _range);
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
      width: 660,
      child: _ReportContainer(
        title: 'Appointment Metrics',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _FilterChips(
              selected: _range,
              onChanged: (v) => setState(() => _range = v),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 10,
              runSpacing: 8,
              children: [
                _metricPill('Appointments', '$totalAppointments'),
                _metricPill('Money Earned', 'Rs ${totalEarned.toStringAsFixed(0)}'),
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
                        '${row.appointments} appts • Rs ${row.earned.toStringAsFixed(0)}',
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
  final Widget child;

  const _ReportContainer({
    required this.title,
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
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              color: Color(0xFF183A67),
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}
