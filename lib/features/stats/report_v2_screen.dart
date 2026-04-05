import 'package:apexo/core/multi_stream_builder.dart';
import 'package:apexo/features/appointments/appointment_model.dart';
import 'package:apexo/features/appointments/appointments_store.dart';
import 'package:apexo/features/doctors/doctors_store.dart';
import 'package:apexo/features/patients/patients_store.dart';
import 'package:fl_chart/fl_chart.dart';
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
            patients.observableMap.stream,
          ],
          builder: (context, _) {
            final allAppointments =
                appointments.present.values.toList(growable: false);
            final now = DateTime.now();
            final weeklyRevenue = _aggregateRevenue(
              allAppointments,
              List.generate(
                8,
                (i) => DateTime(now.year, now.month, now.day)
                    .subtract(Duration(days: (7 - i) * 7)),
              ),
              (d) => 'W${_weekOfYear(d)}',
              (d) => DateTime(d.year, d.month, d.day).add(const Duration(days: 7)),
            );
            final monthlyRevenue = _aggregateRevenue(
              allAppointments,
              List.generate(6, (i) => DateTime(now.year, now.month - (5 - i), 1)),
              (d) => DateFormat('MMM').format(d),
              (d) => DateTime(d.year, d.month + 1, 1),
            );
            final yearlyRevenue = _aggregateRevenue(
              allAppointments,
              List.generate(4, (i) => DateTime(now.year - (3 - i), 1, 1)),
              (d) => '${d.year}',
              (d) => DateTime(d.year + 1, 1, 1),
            );

            final dailyAppointments = _aggregateAppointments(
              allAppointments,
              List.generate(
                10,
                (i) => DateTime(now.year, now.month, now.day).subtract(Duration(days: 9 - i)),
              ),
              (d) => DateFormat('dd').format(d),
              (d) => DateTime(d.year, d.month, d.day).add(const Duration(days: 1)),
            );
            final weeklyAppointments = _aggregateAppointments(
              allAppointments,
              List.generate(
                8,
                (i) => DateTime(now.year, now.month, now.day)
                    .subtract(Duration(days: (7 - i) * 7)),
              ),
              (d) => 'W${_weekOfYear(d)}',
              (d) => DateTime(d.year, d.month, d.day).add(const Duration(days: 7)),
            );
            final monthlyAppointments = _aggregateAppointments(
              allAppointments,
              List.generate(6, (i) => DateTime(now.year, now.month - (5 - i), 1)),
              (d) => DateFormat('MMM').format(d),
              (d) => DateTime(d.year, d.month + 1, 1),
            );

            final timeSpider = _timeOfDaySpider(allAppointments);
            final daySpider = _dayOfWeekSpider(allAppointments);
            final trafficByTime = _trafficByTime(allAppointments);
            final trafficByDay = _trafficByDay(allAppointments);
            final doctorWorkload = _doctorWorkloadRows(allAppointments);

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
                Text(
                  'Advanced analytics for revenue, trends, and patient traffic patterns',
                  style: const TextStyle(
                    color: Color(0xFF5A7397),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    _RevenuePeriodsCard(
                      weekly: weeklyRevenue,
                      monthly: monthlyRevenue,
                      yearly: yearlyRevenue,
                    ),
                    _AppointmentsTrendsCard(
                      daily: dailyAppointments,
                      weekly: weeklyAppointments,
                      monthly: monthlyAppointments,
                    ),
                    _SpiderCard(
                      title: 'Traffic by Time (Spider)',
                      labels: const ['6-9', '9-12', '12-15', '15-18', '18-21', '21+'],
                      values: timeSpider,
                    ),
                    _SpiderCard(
                      title: 'Traffic by Day (Spider)',
                      labels: const ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'],
                      values: daySpider,
                    ),
                    _TrafficBarsCard(
                      title: 'Traffic by Time',
                      rows: trafficByTime,
                      barColor: const Color(0xFF2D7BD8),
                    ),
                    _TrafficBarsCard(
                      title: 'Traffic by Day',
                      rows: trafficByDay,
                      barColor: const Color(0xFF2BA58D),
                    ),
                    _DoctorWorkloadMetricsReportCard(rows: doctorWorkload),
                  ],
                ),
              ],
            );
          },
        ),
      ],
    );
  }

  static int _weekOfYear(DateTime date) {
    final firstDay = DateTime(date.year, 1, 1);
    return ((date.difference(firstDay).inDays + firstDay.weekday) / 7).ceil();
  }
}

List<({String label, double value})> _aggregateRevenue(
  List<Appointment> list,
  List<DateTime> starts,
  String Function(DateTime start) labelBuilder,
  DateTime Function(DateTime start) nextBuilder,
) {
  return starts
      .map((start) {
        final end = nextBuilder(start);
        final value = list
            .where((a) => !a.date.isBefore(start) && a.date.isBefore(end))
            .fold<double>(0, (sum, a) => sum + a.paid + a.prescriptionPaid);
        return (label: labelBuilder(start), value: value);
      })
      .toList(growable: false);
}

List<({String label, double value})> _aggregateAppointments(
  List<Appointment> list,
  List<DateTime> starts,
  String Function(DateTime start) labelBuilder,
  DateTime Function(DateTime start) nextBuilder,
) {
  return starts
      .map((start) {
        final end = nextBuilder(start);
        final value = list
            .where((a) => !a.date.isBefore(start) && a.date.isBefore(end))
            .length
            .toDouble();
        return (label: labelBuilder(start), value: value);
      })
      .toList(growable: false);
}

List<double> _timeOfDaySpider(List<Appointment> rows) {
  final buckets = List<double>.filled(6, 0);
  for (final a in rows) {
    final h = a.date.hour;
    if (h < 9) {
      buckets[0]++;
    } else if (h < 12) {
      buckets[1]++;
    } else if (h < 15) {
      buckets[2]++;
    } else if (h < 18) {
      buckets[3]++;
    } else if (h < 21) {
      buckets[4]++;
    } else {
      buckets[5]++;
    }
  }
  return buckets;
}

List<double> _dayOfWeekSpider(List<Appointment> rows) {
  final buckets = List<double>.filled(7, 0);
  for (final a in rows) {
    buckets[a.date.weekday - 1]++;
  }
  return buckets;
}

List<({String label, double value})> _trafficByTime(List<Appointment> rows) {
  final buckets = <String, double>{
    '6-9': 0,
    '9-12': 0,
    '12-15': 0,
    '15-18': 0,
    '18-21': 0,
    '21+': 0,
  };
  for (final appointment in rows) {
    final h = appointment.date.hour;
    if (h < 9) {
      buckets['6-9'] = (buckets['6-9'] ?? 0) + 1;
    } else if (h < 12) {
      buckets['9-12'] = (buckets['9-12'] ?? 0) + 1;
    } else if (h < 15) {
      buckets['12-15'] = (buckets['12-15'] ?? 0) + 1;
    } else if (h < 18) {
      buckets['15-18'] = (buckets['15-18'] ?? 0) + 1;
    } else if (h < 21) {
      buckets['18-21'] = (buckets['18-21'] ?? 0) + 1;
    } else {
      buckets['21+'] = (buckets['21+'] ?? 0) + 1;
    }
  }

  return buckets.entries
      .map((entry) => (label: entry.key, value: entry.value))
      .toList(growable: false);
}

List<({String label, double value})> _trafficByDay(List<Appointment> rows) {
  final buckets = <String, double>{
    'Mon': 0,
    'Tue': 0,
    'Wed': 0,
    'Thu': 0,
    'Fri': 0,
    'Sat': 0,
    'Sun': 0,
  };
  for (final appointment in rows) {
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

  return buckets.entries
      .map((entry) => (label: entry.key, value: entry.value))
      .toList(growable: false);
}

List<({String doctor, int appointments, int uniquePatients, double completionRate})>
    _doctorWorkloadRows(List<Appointment> allAppointments) {
  final now = DateTime.now();
  final start = DateTime(now.year, now.month, now.day);
  final end = start.add(const Duration(days: 1));

  final rows = <({String doctor, int appointments, int uniquePatients, double completionRate})>[];
  for (final doctor in doctors.present.values) {
    final scoped = allAppointments
        .where((a) =>
            !a.date.isBefore(start) &&
            a.date.isBefore(end) &&
            a.operatorsIDs.contains(doctor.id))
        .toList(growable: false);
    if (scoped.isEmpty) continue;

    final patientIds = <String>{
      for (final appointment in scoped)
        if (appointment.patientID != null && appointment.patientID!.isNotEmpty)
          appointment.patientID!,
    };
    final doneCount = scoped.where((a) => a.isDone).length;
    rows.add((
      doctor: doctor.title.trim().isEmpty ? 'Unnamed doctor' : doctor.title,
      appointments: scoped.length,
      uniquePatients: patientIds.length,
      completionRate: doneCount / scoped.length,
    ));
  }

  rows.sort((a, b) => b.appointments.compareTo(a.appointments));
  return rows;
}

class _RevenuePeriodsCard extends StatelessWidget {
  final List<({String label, double value})> weekly;
  final List<({String label, double value})> monthly;
  final List<({String label, double value})> yearly;

  const _RevenuePeriodsCard({
    required this.weekly,
    required this.monthly,
    required this.yearly,
  });

  @override
  Widget build(BuildContext context) {
    Widget line(String title, List<({String label, double value})> rows, Color color) {
      final total = rows.fold<double>(0, (sum, row) => sum + row.value);
      final recent = rows.isEmpty ? '-' : rows.last.label;
      final recentValue = rows.isEmpty ? 0.0 : rows.last.value;
      return Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFFF6FAFF),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFDCE8F6)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                '$title Revenue',
                style: const TextStyle(
                  color: Color(0xFF36557C),
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
            ),
            Text(
              'Rs ${total.toStringAsFixed(0)}',
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w800,
                fontSize: 12,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              'Latest $recent: Rs ${recentValue.toStringAsFixed(0)}',
              style: const TextStyle(
                color: Color(0xFF6D84A8),
                fontWeight: FontWeight.w600,
                fontSize: 11,
              ),
            ),
          ],
        ),
      );
    }

    return SizedBox(
      width: 660,
      child: _ReportContainer(
        title: 'Revenue by Week / Month / Year',
        child: Column(
          children: [
            line('Weekly', weekly, const Color(0xFF2D7BD8)),
            line('Monthly', monthly, const Color(0xFF2BA58D)),
            line('Yearly', yearly, const Color(0xFFE09C31)),
          ],
        ),
      ),
    );
  }
}

class _AppointmentsTrendsCard extends StatelessWidget {
  final List<({String label, double value})> daily;
  final List<({String label, double value})> weekly;
  final List<({String label, double value})> monthly;

  const _AppointmentsTrendsCard({
    required this.daily,
    required this.weekly,
    required this.monthly,
  });

  @override
  Widget build(BuildContext context) {
    Widget trend(String title, List<({String label, double value})> rows, Color color) {
      final max = rows.fold<double>(1, (m, row) => row.value > m ? row.value : m);
      return Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                color: Color(0xFF36557C),
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 6),
            SizedBox(
              height: 96,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: rows
                    .map(
                      (row) => Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 2),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              Text(
                                row.value.toStringAsFixed(0),
                                style: const TextStyle(
                                  fontSize: 10,
                                  color: Color(0xFF36557C),
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Tooltip(
                                message: '${row.label}: ${row.value.toStringAsFixed(0)}',
                                child: Container(
                                  height: (54 * (row.value / max)).clamp(3, 54).toDouble(),
                                  decoration: BoxDecoration(
                                    color: color,
                                    borderRadius: BorderRadius.circular(3),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                row.label,
                                style: const TextStyle(
                                  fontSize: 10,
                                  color: Color(0xFF6D84A8),
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
      );
    }

    return SizedBox(
      width: 660,
      child: _ReportContainer(
        title: 'Appointment Trends (Daily / Weekly / Monthly)',
        child: Column(
          children: [
            trend('Daily', daily, const Color(0xFF2D7BD8)),
            trend('Weekly', weekly, const Color(0xFF2BA58D)),
            trend('Monthly', monthly, const Color(0xFFE09C31)),
          ],
        ),
      ),
    );
  }
}

class _TrafficBarsCard extends StatelessWidget {
  final String title;
  final List<({String label, double value})> rows;
  final Color barColor;

  const _TrafficBarsCard({
    required this.title,
    required this.rows,
    required this.barColor,
  });

  @override
  Widget build(BuildContext context) {
    final max = rows.fold<double>(1, (m, row) => row.value > m ? row.value : m);
    return SizedBox(
      width: 430,
      child: _ReportContainer(
        title: title,
        child: SizedBox(
          height: 250,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: rows
                .map(
                  (row) => Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 3),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Text(
                            row.value.toStringAsFixed(0),
                            style: const TextStyle(
                              color: Color(0xFF36557C),
                              fontWeight: FontWeight.w700,
                              fontSize: 11,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Container(
                            height: (150 * (row.value / max)).clamp(4, 150).toDouble(),
                            decoration: BoxDecoration(
                              color: barColor,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            row.label,
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
      ),
    );
  }
}

class _DoctorWorkloadMetricsReportCard extends StatelessWidget {
  final List<({String doctor, int appointments, int uniquePatients, double completionRate})>
      rows;

  const _DoctorWorkloadMetricsReportCard({required this.rows});

  @override
  Widget build(BuildContext context) {
    final totalAppointments =
        rows.fold<int>(0, (sum, row) => sum + row.appointments);
    final totalPatients =
        rows.fold<int>(0, (sum, row) => sum + row.uniquePatients);

    return SizedBox(
      width: 660,
      child: _ReportContainer(
        title: 'Doctor Workload Metrics (Today)',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 10,
              runSpacing: 8,
              children: [
                _metricPill('Appointments', '$totalAppointments'),
                _metricPill('Unique Patients', '$totalPatients'),
                _metricPill('Active Doctors', '${rows.length}'),
              ],
            ),
            const SizedBox(height: 10),
            if (rows.isEmpty)
              const Text(
                'No doctor workload data for today.',
                style: TextStyle(color: Color(0xFF6D84A8)),
              )
            else
              ...rows.take(10).map(
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
                        '${row.appointments} appts • ${row.uniquePatients} patients • ${(row.completionRate * 100).toStringAsFixed(0)}% done',
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

class _SpiderCard extends StatelessWidget {
  final String title;
  final List<String> labels;
  final List<double> values;

  const _SpiderCard({
    required this.title,
    required this.labels,
    required this.values,
  });

  @override
  Widget build(BuildContext context) {
    final max = values.fold<double>(1, (m, v) => v > m ? v : m);
    return SizedBox(
      width: 430,
      child: _ReportContainer(
        title: title,
        child: SizedBox(
          height: 280,
          child: RadarChart(
            RadarChartData(
              radarShape: RadarShape.circle,
              tickBorderData: const BorderSide(color: Color(0xFFE1ECF8)),
              gridBorderData: const BorderSide(color: Color(0xFFE1ECF8)),
              titlePositionPercentageOffset: 0.18,
              radarBackgroundColor: Colors.transparent,
              dataSets: [
                RadarDataSet(
                  fillColor: const Color(0x332D7BD8),
                  borderColor: const Color(0xFF2D7BD8),
                  entryRadius: 2,
                  dataEntries: values
                      .map((v) => RadarEntry(value: max == 0 ? 0 : (v / max) * 10))
                      .toList(growable: false),
                ),
              ],
              radarBorderData: const BorderSide(color: Color(0xFFD6E2F0)),
              getTitle: (index, _) {
                return RadarChartTitle(
                  text: labels[index],
                  angle: 0,
                );
              },
              tickCount: 5,
            ),
          ),
        ),
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
    return SizedBox(
      child: Container(
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
      ),
    );
  }
}
