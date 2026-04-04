import 'package:apexo/core/multi_stream_builder.dart';
import 'package:apexo/features/appointments/appointment_model.dart';
import 'package:apexo/features/appointments/appointments_store.dart';
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
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: rows
                  .map(
                    (row) => Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 1),
                        child: Tooltip(
                          message: '${row.label}: ${row.value.toStringAsFixed(0)}',
                          child: Container(
                            height: (60 * (row.value / max)).clamp(2, 60).toDouble(),
                            decoration: BoxDecoration(
                              color: color,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),
                      ),
                    ),
                  )
                  .toList(growable: false),
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
