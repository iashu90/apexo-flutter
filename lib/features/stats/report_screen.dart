import 'dart:math' as math;

import 'package:apexo/common_widgets/app_screen_title.dart';
import 'package:apexo/core/multi_stream_builder.dart';
import 'package:apexo/common_widgets/export_buttons.dart';
import 'package:apexo/core/theme/app_colors.dart';
import 'package:apexo/core/ui/components/app_button.dart';
import 'package:apexo/features/appointments/appointment_model.dart';
import 'package:apexo/features/appointments/appointment_financials.dart';
import 'package:apexo/features/appointments/appointments_store.dart';
import 'package:apexo/features/doctors/doctors_store.dart';
import 'package:apexo/features/doctors/doctor_model.dart';
import 'package:apexo/features/expenses/expense_model.dart';
import 'package:apexo/features/expenses/expenses_store.dart';
import 'package:apexo/features/patients/patients_store.dart';
import 'package:apexo/utils/appointment_analytics.dart';
import 'package:apexo/utils/clinic_time.dart';
import 'package:apexo/utils/csv_export_utility.dart';
import 'package:apexo/utils/indian_money.dart';
import 'package:apexo/utils/pdf_export_utility.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:intl/intl.dart';

class ReportScreen extends StatefulWidget {
  const ReportScreen({super.key});

  @override
  State<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends State<ReportScreen> {
  bool _showHeavyCards = false;
  int _monthlyOffset = 0;

  void _reloadHeavyCardsForMonthChange(int offsetDelta) {
    setState(() {
      _monthlyOffset = (_monthlyOffset + offsetDelta).clamp(0, 240);
      _showHeavyCards = false;
    });
    Future<void>.delayed(const Duration(milliseconds: 120), () {
      if (!mounted) return;
      setState(() => _showHeavyCards = true);
    });
  }

  @override
  void initState() {
    super.initState();
    Future<void>.delayed(const Duration(milliseconds: 80), () {
      if (!mounted) return;
      setState(() => _showHeavyCards = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    return ScaffoldPage.scrollable(
      padding: const EdgeInsets.fromLTRB(8, 6, 8, 10),
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

            return LayoutBuilder(
              builder: (context, constraints) {
                final available = constraints.maxWidth;
                const spacing = 8.0;
                const maxCrossAxisExtent = 320.0;
                final columnCount = math.max(
                  1,
                  ((available + spacing) / (maxCrossAxisExtent + spacing))
                      .floor(),
                );
                final tileWidth =
                    (available - ((columnCount - 1) * spacing)) / columnCount;

                Widget responsiveGrid(List<Widget> cards) {
                  final allowWideTiles = columnCount >= 3;
                  return Wrap(
                    spacing: spacing,
                    runSpacing: spacing,
                    children: [
                      for (int i = 0; i < cards.length; i++)
                        SizedBox(
                          width: cards[i] is _WideReportTile
                              ? (columnCount >= 2
                                  ? (tileWidth * 2) + spacing
                                  : tileWidth)
                              : cards[i] is _CompactReportTile
                                  ? tileWidth
                                  : allowWideTiles &&
                                          (i % 7 == 0 || i % 11 == 0)
                                      ? (tileWidth * 2) + spacing
                                      : tileWidth,
                          child: cards[i] is _WideReportTile
                              ? (cards[i] as _WideReportTile).child
                              : cards[i] is _CompactReportTile
                                  ? SizedBox(
                                      height: 300,
                                      child: (cards[i] as _CompactReportTile)
                                          .child,
                                    )
                                  : cards[i],
                        ),
                    ],
                  );
                }

                return MediaQuery(
                  data: MediaQuery.of(context)
                      .copyWith(textScaler: const TextScaler.linear(0.9)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                AppScreenTitle(title: 'Reports'),
                              ],
                            ),
                          ),
                          _ReportMonthNavigator(
                            label: formatClinicDate(
                              DateTime(
                                DateTime.now().year,
                                DateTime.now().month - _monthlyOffset,
                                1,
                              ),
                              pattern: 'MMM yyyy',
                            ),
                            canGoForward: _monthlyOffset > 0,
                            onBack: () => _reloadHeavyCardsForMonthChange(1),
                            onForward: _monthlyOffset > 0
                                ? () => _reloadHeavyCardsForMonthChange(-1)
                                : null,
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      if (!_showHeavyCards)
                        responsiveGrid(
                          List<Widget>.generate(
                            10,
                            (_) => _ReportSkeletonCard(width: tileWidth),
                            growable: false,
                          ),
                        )
                      else
                        responsiveGrid(
                          [
                            _DailyAppointmentsGrossTrendCard(
                              rows: allAppointments,
                            ),
                            _WideReportTile(
                              child: _DailyAppointmentsGrossBarTrendCard(
                                rows: allAppointments,
                              ),
                            ),
                            _MonthlyAppointmentsTrendSection(
                              rows: allAppointments,
                              windowOffset: _monthlyOffset,
                            ),
                            _MonthlyRevenueTrendSection(
                              rows: allAppointments,
                              windowOffset: _monthlyOffset,
                            ),
                            _MonthlyExpensesTrendSection(
                              rows: allExpenses,
                              windowOffset: _monthlyOffset,
                            ),
                            _MonthlyNetRevenueTrendSection(
                              appointmentsRows: allAppointments,
                              expenseRows: allExpenses,
                              windowOffset: _monthlyOffset,
                            ),
                            _CompactReportTile(
                              child: _TrafficByTimeCard(
                                rows: allAppointments,
                                monthOffset: _monthlyOffset,
                              ),
                            ),
                            _CompactReportTile(
                              child: _TrafficByDayCard(rows: allAppointments),
                            ),
                            _CompactReportTile(
                              child: _ReportAgeDistributionCard(
                                rows: allAppointments,
                                monthOffset: _monthlyOffset,
                              ),
                            ),
                            _CompactReportTile(
                              child: _ReferralSourceDistributionCard(
                                rows: allAppointments,
                                monthOffset: _monthlyOffset,
                              ),
                            ),
                            _CompactReportTile(
                              child: _MonthlyTreatmentDistributionCard(
                                rows: allAppointments,
                                monthOffset: _monthlyOffset,
                              ),
                            ),
                            _CompactReportTile(
                              child: _ReportGenderDistributionCard(
                                rows: allAppointments,
                                monthOffset: _monthlyOffset,
                              ),
                            ),
                            _CompactReportTile(
                              child: _NewVsReturningCard(
                                rows: allAppointments,
                                monthOffset: _monthlyOffset,
                              ),
                            ),
                            _CompactReportTile(
                              child: _PaymentModeStatusCard(
                                rows: allAppointments,
                                monthOffset: _monthlyOffset,
                              ),
                            ),
                            _WideReportTile(
                              child: _ReportDoctorAppointmentDoneCard(
                                rows: allAppointments,
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                );
              },
            );
          },
        ),
      ],
    );
  }
}

class _ReportSkeletonCard extends StatelessWidget {
  final double width;

  const _ReportSkeletonCard({required this.width});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: 220,
      decoration: BoxDecoration(
        color: FluentTheme.of(context).scaffoldBackgroundColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.borderSoft),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 180,
              height: 14,
              decoration: BoxDecoration(
                color: AppColors.violet1003,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              height: 10,
              decoration: BoxDecoration(
                color: AppColors.slate100,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              height: 10,
              decoration: BoxDecoration(
                color: AppColors.slate100,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(height: 8),
            Container(
              width: width * 0.5,
              height: 10,
              decoration: BoxDecoration(
                color: AppColors.slate100,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WideReportTile extends StatelessWidget {
  final Widget child;

  const _WideReportTile({required this.child});

  @override
  Widget build(BuildContext context) => child;
}

class _CompactReportTile extends StatelessWidget {
  final Widget child;

  const _CompactReportTile({required this.child});

  @override
  Widget build(BuildContext context) => child;
}

enum _RangeFilter { lastMonth, month, ytd, year, all }

extension _RangeFilterLabel on _RangeFilter {
  String get label {
    switch (this) {
      case _RangeFilter.month:
        return 'Monthly';
      case _RangeFilter.lastMonth:
        return 'Last Month';
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
    case _RangeFilter.month:
      final anchor = monthAnchor ?? today;
      start = DateTime(anchor.year, anchor.month, 1);
      endExclusive = DateTime(anchor.year, anchor.month + 1, 1);
      break;
    case _RangeFilter.lastMonth:
      final prev = DateTime(today.year, today.month - 1, 1);
      start = prev;
      endExclusive = DateTime(prev.year, prev.month + 1, 1);
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

String _genderBucket(dynamic rawGender) {
  if (rawGender == null) return '';
  final normalized = rawGender is num
      ? rawGender.toInt().toString()
      : rawGender.toString().trim().toLowerCase();
  if (normalized == 'male' || normalized == 'm' || normalized == '1') {
    return 'male';
  }
  if (normalized == 'female' || normalized == 'f' || normalized == '0') {
    return 'female';
  }
  return '';
}

class _AgeGenderCount {
  int male = 0;
  int female = 0;

  int get total => male + female;
}

class _ReportGenderDistributionCard extends StatelessWidget {
  final List<Appointment> rows;
  final int monthOffset;

  const _ReportGenderDistributionCard({
    required this.rows,
    required this.monthOffset,
  });

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final monthStart = DateTime(now.year, now.month - monthOffset, 1);
    final monthEnd = DateTime(monthStart.year, monthStart.month + 1, 1);
    final scoped = rows
        .where((a) => !a.date.isBefore(monthStart) && a.date.isBefore(monthEnd))
        .toList(growable: false);

    int male = 0;
    int female = 0;
    for (final row in scoped) {
      final bucket = _genderBucket(row.patient?.gender);
      if (bucket == 'female') {
        female += 1;
      } else if (bucket == 'male') {
        male += 1;
      }
    }

    final total = male + female;

    return _ReportContainer(
      title: 'Gender Distribution',
      subtitle: formatClinicDate(monthStart, pattern: 'MMMM yyyy'),
      child: SizedBox(
        height: 220,
        child: total == 0
            ? const Align(
                alignment: Alignment.center,
                child: Text(
                  'No gender data found.',
                  style: TextStyle(color: AppColors.textBlueMuted),
                ),
              )
            : _PieLegendLayout(
                pie: PieChart(
                  PieChartData(
                    sectionsSpace: 2,
                    centerSpaceRadius: 28,
                    sections: [
                      PieChartSectionData(
                        value: male.toDouble(),
                        color: AppColors.brandBlue,
                        title: '${((male / total) * 100).toStringAsFixed(0)}%',
                        titleStyle: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 10,
                        ),
                        radius: 42,
                      ),
                      PieChartSectionData(
                        value: female.toDouble(),
                        color: AppColors.successTeal,
                        title:
                            '${((female / total) * 100).toStringAsFixed(0)}%',
                        titleStyle: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 10,
                        ),
                        radius: 42,
                      ),
                    ],
                  ),
                ),
                legend: [
                  Text(
                    'Total: $total',
                    style: const TextStyle(color: AppColors.textBlueMuted),
                  ),
                  const SizedBox(height: 8),
                  _LegendDot(color: AppColors.brandBlue, label: 'Male $male'),
                  const SizedBox(height: 6),
                  _LegendDot(
                    color: AppColors.successTeal,
                    label: 'Female $female',
                  ),
                ],
              ),
      ),
    );
  }
}

class _ReportAgeDistributionCard extends StatelessWidget {
  final List<Appointment> rows;
  final int monthOffset;

  const _ReportAgeDistributionCard({
    required this.rows,
    required this.monthOffset,
  });

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final monthStart = DateTime(now.year, now.month - monthOffset, 1);
    final monthEnd = DateTime(monthStart.year, monthStart.month + 1, 1);
    final scoped = rows
        .where((a) => !a.date.isBefore(monthStart) && a.date.isBefore(monthEnd))
        .toList(growable: false);

    final buckets = <String, _AgeGenderCount>{
      '<13': _AgeGenderCount(),
      '13-17': _AgeGenderCount(),
      '18-24': _AgeGenderCount(),
      '25-34': _AgeGenderCount(),
      '35-44': _AgeGenderCount(),
      '45-54': _AgeGenderCount(),
      '55-64': _AgeGenderCount(),
      '65+': _AgeGenderCount(),
    };

    for (final row in scoped) {
      final age = row.patient?.age ?? 0;
      final gender = _genderBucket(row.patient?.gender);
      String key;
      if (age < 13) {
        key = '<13';
      } else if (age <= 17) {
        key = '13-17';
      } else if (age <= 24) {
        key = '18-24';
      } else if (age <= 34) {
        key = '25-34';
      } else if (age <= 44) {
        key = '35-44';
      } else if (age <= 54) {
        key = '45-54';
      } else if (age <= 64) {
        key = '55-64';
      } else {
        key = '65+';
      }

      final bucket = buckets[key];
      if (bucket == null) continue;
      if (gender == 'male') {
        bucket.male += 1;
      } else if (gender == 'female') {
        bucket.female += 1;
      }
    }

    final labels = buckets.keys.toList(growable: false);
    final values = buckets.values
        .map((bucket) => bucket.total.toDouble())
        .toList(growable: false);

    return _ReportContainer(
      title: 'Age Distribution',
      subtitle: formatClinicDate(monthStart, pattern: 'MMMM yyyy'),
      child: SizedBox(
        height: 220,
        child: _FormattedBarChart(
          labels: labels,
          values: values,
          barColor: AppColors.successTeal,
        ),
      ),
    );
  }
}

class _ReportDoctorAppointmentDoneCard extends StatefulWidget {
  final List<Appointment> rows;

  const _ReportDoctorAppointmentDoneCard({required this.rows});

  @override
  State<_ReportDoctorAppointmentDoneCard> createState() =>
      _ReportDoctorAppointmentDoneCardState();
}

class _ReportDoctorAppointmentDoneCardState
    extends State<_ReportDoctorAppointmentDoneCard> {
  _RangeFilter _range = _RangeFilter.month;
  DateTime _monthAnchor =
      DateTime(DateTime.now().year, DateTime.now().month, 1);
  bool _showAllRows = false;
  bool _isExportingCsv = false;
  bool _isExportingPdf = false;

  String _fileStem() {
    final stamp = DateFormat('dd_MMM_yyyy_HH_mm').format(DateTime.now());
    return 'appointments_done_by_doctor_$stamp';
  }

  Future<void> _exportCsv(
    List<
            ({
              Doctor doctor,
              int done,
              int appointments,
              double fee,
              double revenue,
              double hospitalGained,
              double profitPct,
            })>
        rows,
  ) async {
    if (_isExportingCsv || _isExportingPdf || rows.isEmpty) return;
    setState(() => _isExportingCsv = true);
    try {
      final csvRows = <List<String>>[
        const [
          'Doctor',
          'Appointments Done',
          'Total Appointments',
          'Revenue',
          'Doctor Fee',
          'Net Profit',
          'Profit %',
        ],
        ...rows.map((row) => [
              row.doctor.title.trim().isEmpty
                  ? 'Unnamed doctor'
                  : row.doctor.title,
              '${row.done}',
              '${row.appointments}',
              row.revenue.toStringAsFixed(2),
              row.fee.toStringAsFixed(2),
              row.hospitalGained.toStringAsFixed(2),
              row.profitPct.toStringAsFixed(2),
            ]),
      ];
      await CsvExportUtility.saveCsv(
        rows: csvRows,
        fileName: '${_fileStem()}.csv',
      );
    } catch (error) {
      if (!mounted) return;
      displayInfoBar(
        context,
        builder: (ctx, close) => InfoBar(
          title: const Text('CSV export failed'),
          content: Text('$error'),
          severity: InfoBarSeverity.error,
          action: IconButton(
            icon: const Icon(FluentIcons.clear),
            onPressed: close,
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _isExportingCsv = false);
    }
  }

  Future<void> _exportPdf(
    List<
            ({
              Doctor doctor,
              int done,
              int appointments,
              double fee,
              double revenue,
              double hospitalGained,
              double profitPct,
            })>
        rows,
  ) async {
    if (_isExportingCsv || _isExportingPdf || rows.isEmpty) return;
    setState(() => _isExportingPdf = true);
    try {
      final tableRows = <List<String>>[
        const [
          'Doctor',
          'Done',
          'Appointments',
          'Revenue',
          'Doctor Fee',
          'Net Profit',
          'Profit %',
        ],
        ...rows.map((row) => [
              row.doctor.title.trim().isEmpty
                  ? 'Unnamed doctor'
                  : row.doctor.title,
              '${row.done}',
              '${row.appointments}',
              row.revenue.toStringAsFixed(2),
              row.fee.toStringAsFixed(2),
              row.hospitalGained.toStringAsFixed(2),
              '${row.profitPct.toStringAsFixed(1)}%',
            ]),
      ];
      await PdfExportUtility.savePdf(
        title: 'Appointments Done By Doctor',
        subtitle: 'Total rows: ${rows.length}',
        data: tableRows,
        fileName: '${_fileStem()}.pdf',
      );
    } catch (error) {
      if (!mounted) return;
      displayInfoBar(
        context,
        builder: (ctx, close) => InfoBar(
          title: const Text('PDF export failed'),
          content: Text('$error'),
          severity: InfoBarSeverity.error,
          action: IconButton(
            icon: const Icon(FluentIcons.clear),
            onPressed: close,
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _isExportingPdf = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scoped = _rangeRows(widget.rows, _range, monthAnchor: _monthAnchor);
    final doctorsList = doctors.present.values.toList(growable: false)
      ..sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));

    final rows = doctorsList
        .map((doctor) {
          final doctorRows = scoped
              .where((a) => a.operatorsIDs.contains(doctor.id))
              .toList(growable: false);
          if (doctorRows.isEmpty) return null;
          final done = doctorRows.where((a) => a.isDone).length;
          final fee = doctorRows.fold<double>(
            0,
            (sum, a) => sum + a.doctorPayableAmount,
          );
          final revenue = doctorRows.fold<double>(
            0,
            (sum, a) => sum + a.paid + a.prescriptionPaid,
          );
          final hospitalGained = revenue - fee;
          final profitPct =
              revenue <= 0 ? 0.0 : (hospitalGained / revenue) * 100;
          return (
            doctor: doctor,
            done: done,
            appointments: doctorRows.length,
            fee: fee,
            revenue: revenue,
            hospitalGained: hospitalGained,
            profitPct: profitPct,
          );
        })
        .whereType<
            ({
              Doctor doctor,
              int done,
              int appointments,
              double fee,
              double revenue,
              double hospitalGained,
              double profitPct,
            })>()
        .toList(growable: false)
      ..sort((a, b) => b.done.compareTo(a.done));

    final totalDone = rows.fold<int>(0, (s, r) => s + r.done);
    final totalFee = rows.fold<double>(0, (s, r) => s + r.fee);
    final totalRevenue = rows.fold<double>(0, (s, r) => s + r.revenue);
    final totalNet = rows.fold<double>(0, (s, r) => s + r.hospitalGained);
    final totalProfitPct =
        totalRevenue <= 0 ? 0.0 : (totalNet / totalRevenue) * 100;

    return _ReportContainer(
      title: 'Appointments Done By Doctor',
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ExportButtons(
            csvBusy: _isExportingCsv,
            pdfBusy: _isExportingPdf,
            onCsv: (_isExportingCsv || _isExportingPdf || rows.isEmpty)
                ? null
                : () => _exportCsv(rows),
            onPdf: (_isExportingCsv || _isExportingPdf || rows.isEmpty)
                ? null
                : () => _exportPdf(rows),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: _summaryTile(
                  value: '$totalDone',
                  label: 'Appointments',
                  color: AppColors.brandBlue,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _summaryTile(
                  value: formatIndianShortCurrency(totalRevenue),
                  label: 'Revenue',
                  color: AppColors.brandBlue,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _summaryTile(
                  value: formatIndianShortCurrency(totalFee),
                  label: 'Doctor Fee',
                  color: AppColors.dangerRose,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _summaryTile(
                  value: formatIndianShortCurrency(totalNet),
                  label: 'Net Profit',
                  color: AppColors.successTeal,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _summaryTile(
                  value: '${totalProfitPct.toStringAsFixed(1)}%',
                  label: '%',
                  color: AppColors.textBlueStrong,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              SizedBox(
                width: 200,
                child: ComboBox<DateTime>(
                  isExpanded: true,
                  value: _monthAnchor,
                  items: _monthOptions(widget.rows)
                      .map(
                        (m) => ComboBoxItem<DateTime>(
                          value: m,
                          child:
                              Text(formatClinicDate(m, pattern: 'MMMM yyyy')),
                        ),
                      )
                      .toList(growable: false),
                  onChanged: (v) {
                    if (v == null) return;
                    setState(() {
                      _monthAnchor = v;
                      _range = _RangeFilter.month;
                    });
                  },
                ),
              ),
              const SizedBox(width: 8),
              AppButton(
                label: _showAllRows ? 'Collapse' : 'Expand',
                variant: AppButtonVariant.secondary,
                compact: false,
                onPressed: () => setState(() => _showAllRows = !_showAllRows),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (rows.isEmpty)
            const Text(
              'No completion data in selected range.',
              style: TextStyle(color: AppColors.blue5004),
            )
          else
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.borderBlueSoft),
              ),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SizedBox(
                  width: 760,
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 8,
                        ),
                        decoration: const BoxDecoration(
                          color: AppColors.surfaceBlueSoft,
                        ),
                        child: const Row(
                          children: [
                            SizedBox(
                              width: 190,
                              child: Text(
                                'Doctor',
                                style: TextStyle(
                                  color: AppColors.textBlueStrong,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                            SizedBox(
                              width: 95,
                              child: Text(
                                'Appointments',
                                style: TextStyle(
                                  color: AppColors.textBlueStrong,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                            SizedBox(
                              width: 110,
                              child: Text(
                                'Revenue',
                                style: TextStyle(
                                  color: AppColors.textBlueStrong,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                            SizedBox(
                              width: 110,
                              child: Text(
                                'Doctor Fee',
                                style: TextStyle(
                                  color: AppColors.textBlueStrong,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                            SizedBox(
                              width: 150,
                              child: Text(
                                'Net Profit',
                                style: TextStyle(
                                  color: AppColors.textBlueStrong,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                            SizedBox(
                              width: 75,
                              child: Text(
                                '%',
                                style: TextStyle(
                                  color: AppColors.textBlueStrong,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      ...rows.take(_showAllRows ? rows.length : 5).map((row) {
                        return Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 9,
                          ),
                          decoration: const BoxDecoration(
                            border: Border(
                              top: BorderSide(color: AppColors.violet1002),
                            ),
                          ),
                          child: Row(
                            children: [
                              SizedBox(
                                width: 190,
                                child: Text(
                                  row.doctor.title,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: AppColors.blue7505,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                              SizedBox(
                                width: 95,
                                child: Text(
                                  '${row.done}',
                                  style: const TextStyle(
                                    color: AppColors.blue8003,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                              SizedBox(
                                width: 110,
                                child: Text(
                                  formatIndianShortCurrency(row.revenue),
                                  style: const TextStyle(
                                    color: AppColors.brandBlue,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                              SizedBox(
                                width: 110,
                                child: Text(
                                  formatIndianShortCurrency(row.fee),
                                  style: const TextStyle(
                                    color: AppColors.dangerRose,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                              SizedBox(
                                width: 150,
                                child: Text(
                                  formatIndianShortCurrency(row.hospitalGained),
                                  style: TextStyle(
                                    color: row.hospitalGained < 0
                                        ? AppColors.dangerRose
                                        : AppColors.successTeal,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                              SizedBox(
                                width: 75,
                                child: Text(
                                  '${row.profitPct.toStringAsFixed(1)}%',
                                  style: const TextStyle(
                                    color: AppColors.textBlueStrong,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _summaryTile({
    required String value,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.slate1009,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.borderBlueSoft),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 22,
              fontWeight: FontWeight.w800,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            label,
            style: const TextStyle(
              color: AppColors.blue6005,
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _NewVsReturningCard extends StatelessWidget {
  final List<Appointment> rows;
  final int monthOffset;

  const _NewVsReturningCard({
    required this.rows,
    required this.monthOffset,
  });

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final monthStart = DateTime(now.year, now.month - monthOffset, 1);
    final monthEnd = DateTime(monthStart.year, monthStart.month + 1, 1);

    final firstVisitByPatient = <String, DateTime>{};
    for (final row in rows) {
      final pid = row.patientID;
      if (pid == null || pid.isEmpty) continue;
      final existing = firstVisitByPatient[pid];
      if (existing == null || row.date.isBefore(existing)) {
        firstVisitByPatient[pid] = row.date;
      }
    }

    final scoped = rows
        .where((a) => !a.date.isBefore(monthStart) && a.date.isBefore(monthEnd))
        .toList(growable: false);
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

    return _ReportContainer(
      title: 'New vs Returning',
      subtitle: formatClinicDate(monthStart, pattern: 'MMMM yyyy'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 220,
            child: total == 0
                ? const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'No data for this month.',
                      style: TextStyle(color: AppColors.textBlueMuted),
                    ),
                  )
                : Row(
                    children: [
                      SizedBox(
                        width: 130,
                        height: 130,
                        child: PieChart(
                          PieChartData(
                            sectionsSpace: 2,
                            centerSpaceRadius: 28,
                            sections: [
                              PieChartSectionData(
                                value: newCount.toDouble(),
                                color: AppColors.brandBlue,
                                title: '${newPct.toStringAsFixed(0)}%',
                                titleStyle: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 10,
                                ),
                                radius: 42,
                              ),
                              PieChartSectionData(
                                value: returningCount.toDouble(),
                                color: AppColors.successTeal,
                                title: '${returningPct.toStringAsFixed(0)}%',
                                titleStyle: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 10,
                                ),
                                radius: 42,
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _LegendDot(
                                color: AppColors.brandBlue,
                                label: 'New: $newCount'),
                            const SizedBox(height: 8),
                            _LegendDot(
                              color: AppColors.successTeal,
                              label: 'Returning: $returningCount',
                            ),
                            const SizedBox(height: 8),
                            _LegendDot(
                              color: AppColors.textBlueMuted,
                              label: 'Total: $total',
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class _MonthlyTreatmentDistributionCard extends StatelessWidget {
  final List<Appointment> rows;
  final int monthOffset;

  const _MonthlyTreatmentDistributionCard({
    required this.rows,
    required this.monthOffset,
  });

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final monthStart = DateTime(now.year, now.month - monthOffset, 1);
    final monthEnd = DateTime(monthStart.year, monthStart.month + 1, 1);
    final scoped = rows
        .where((a) => !a.date.isBefore(monthStart) && a.date.isBefore(monthEnd))
        .toList(growable: false);
    final distributionRows = _treatmentDistributionRows(scoped);
    final total = distributionRows.fold<int>(0, (s, e) => s + e.value);
    const colors = [
      AppColors.brandBlue,
      AppColors.successTeal,
      AppColors.amber400,
      AppColors.violet4502,
      AppColors.dangerRose,
      AppColors.violet5502,
    ];

    return IntrinsicWidth(
      child: _ReportContainer(
        title: 'Monthly Treatment Distribution',
        subtitle: formatClinicDate(monthStart, pattern: 'MMMM yyyy'),
        child: SizedBox(
          height: 220,
          child: distributionRows.isEmpty
              ? const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'No treatment data for this month.',
                    style: TextStyle(color: AppColors.blue5004),
                  ),
                )
              : Row(
                  children: [
                    SizedBox(
                      width: 130,
                      height: 130,
                      child: PieChart(
                        PieChartData(
                          sectionsSpace: 2,
                          centerSpaceRadius: 28,
                          sections:
                              distributionRows.asMap().entries.map((entry) {
                            final row = entry.value;
                            final pct =
                                total == 0 ? 0.0 : (row.value / total) * 100;
                            return PieChartSectionData(
                              value: row.value.toDouble(),
                              color: colors[entry.key % colors.length],
                              title:
                                  pct >= 8 ? '${pct.toStringAsFixed(0)}%' : '',
                              titleStyle: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 10,
                              ),
                              radius: 42,
                            );
                          }).toList(growable: false),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children:
                              distributionRows.asMap().entries.map((entry) {
                            final row = entry.value;
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 6),
                              child: _LegendDot(
                                color: colors[entry.key % colors.length],
                                label: '${row.key} (${row.value})',
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
    final all =
        _RangeFilter.values.where((r) => includeToday).toList(growable: false);
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
                          ? AppColors.brandBlue
                          : AppColors.slate1004,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: selected == range
                            ? AppColors.brandBlue
                            : AppColors.violet1506,
                      ),
                    ),
                    child: Text(
                      range.label,
                      style: TextStyle(
                        color: selected == range
                            ? Colors.white
                            : AppColors.textBlueStrong,
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
                      child: Text(formatClinicDate(m, pattern: 'MMMM yyyy')),
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

List<DateTime> _monthOptions(List<Appointment> rows) =>
    monthOptionsFromAppointments(rows);

class _DailyAppointmentsGrossTrendCard extends StatefulWidget {
  final List<Appointment> rows;

  const _DailyAppointmentsGrossTrendCard({required this.rows});

  @override
  State<_DailyAppointmentsGrossTrendCard> createState() =>
      _DailyAppointmentsGrossTrendCardState();
}

class _DailyAppointmentsGrossTrendCardState
    extends State<_DailyAppointmentsGrossTrendCard> {
  int _monthOffset = 0;

  @override
  Widget build(BuildContext context) {
    final currentMonth = DateTime(DateTime.now().year, DateTime.now().month, 1);
    final monthStart =
        DateTime(currentMonth.year, currentMonth.month - _monthOffset, 1);
    final monthEnd = DateTime(monthStart.year, monthStart.month + 1, 1);
    final dayCount = monthEnd.difference(monthStart).inDays;

    final starts = List<DateTime>.generate(
      dayCount,
      (i) => monthStart.add(Duration(days: i)),
      growable: false,
    );

    final points = starts.map((start) {
      final end = start.add(const Duration(days: 1));
      final dayRows = widget.rows
          .where((a) => !a.date.isBefore(start) && a.date.isBefore(end))
          .toList(growable: false);
      final count = dayRows.length.toDouble();
      final gross = dayRows.fold<double>(
        0,
        (sum, a) => sum + a.paid + a.prescriptionPaid,
      );
      return (
        label: formatClinicDate(start, pattern: 'dd'),
        count: count,
        gross: gross,
      );
    }).toList(growable: false);

    final maxCount =
        points.fold<double>(1, (m, p) => p.count > m ? p.count : m);
    final maxGross =
        points.fold<double>(1, (m, p) => p.gross > m ? p.gross : m);

    return _ReportContainer(
      title: 'Appointment + Gross Trend (Daily)',
      subtitle: formatClinicDate(monthStart, pattern: 'MMMM yyyy'),
      trailing: _TrendNavButtons(
        canGoForward: _monthOffset > 0,
        onBack: () => setState(() => _monthOffset += 1),
        onForward:
            _monthOffset > 0 ? () => setState(() => _monthOffset -= 1) : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              _LegendDot(color: AppColors.brandBlue, label: 'Appointments'),
              SizedBox(width: 10),
              _LegendDot(color: AppColors.successTeal, label: 'Gross Revenue'),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 220,
            child: LineChart(
              LineChartData(
                minY: 0,
                maxY: 110,
                gridData: FlGridData(
                  show: true,
                  horizontalInterval: 25,
                  getDrawingHorizontalLine: (_) => const FlLine(
                    color: AppColors.slate100,
                    strokeWidth: 1,
                  ),
                  drawVerticalLine: false,
                ),
                borderData: FlBorderData(
                  show: true,
                  border: const Border(
                    left: BorderSide(color: AppColors.borderSoft),
                    bottom: BorderSide(color: AppColors.borderSoft),
                  ),
                ),
                titlesData: FlTitlesData(
                  leftTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 24,
                      getTitlesWidget: (value, meta) {
                        final index = value.toInt();
                        if (index < 0 || index >= points.length) {
                          return const SizedBox.shrink();
                        }
                        if (points.length > 12 && index % 2 == 1) {
                          return const SizedBox.shrink();
                        }
                        return SideTitleWidget(
                          axisSide: meta.axisSide,
                          child: Text(
                            points[index].label,
                            style: const TextStyle(
                              color: AppColors.textBlueMuted,
                              fontWeight: FontWeight.w700,
                              fontSize: 10,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                lineTouchData: LineTouchData(
                  handleBuiltInTouches: true,
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipColor: (_) => AppColors.blue750,
                    getTooltipItems: (spots) {
                      return spots.map((spot) {
                        final day = points[spot.x.toInt()];
                        if (spot.barIndex == 0) {
                          return LineTooltipItem(
                            '${day.label}: ${day.count.toStringAsFixed(0)} appts',
                            const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                            ),
                          );
                        }
                        return LineTooltipItem(
                          '${day.label}: ₹${formatIndianCompactNumber(day.gross, fractionDigits: 1)}',
                          const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                        );
                      }).toList(growable: false);
                    },
                  ),
                ),
                lineBarsData: [
                  LineChartBarData(
                    spots: [
                      for (var i = 0; i < points.length; i++)
                        FlSpot(
                            i.toDouble(), (points[i].count / maxCount) * 100),
                    ],
                    isCurved: true,
                    barWidth: 2.5,
                    color: AppColors.brandBlue,
                    dotData: const FlDotData(show: false),
                  ),
                  LineChartBarData(
                    spots: [
                      for (var i = 0; i < points.length; i++)
                        FlSpot(
                            i.toDouble(), (points[i].gross / maxGross) * 100),
                    ],
                    isCurved: true,
                    barWidth: 2.5,
                    color: AppColors.successTeal,
                    dotData: const FlDotData(show: false),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DailyAppointmentsGrossBarTrendCard extends StatefulWidget {
  final List<Appointment> rows;

  const _DailyAppointmentsGrossBarTrendCard({required this.rows});

  @override
  State<_DailyAppointmentsGrossBarTrendCard> createState() =>
      _DailyAppointmentsGrossBarTrendCardState();
}

class _DailyAppointmentsGrossBarTrendCardState
    extends State<_DailyAppointmentsGrossBarTrendCard> {
  int _monthOffset = 0;

  @override
  Widget build(BuildContext context) {
    final currentMonth = DateTime(DateTime.now().year, DateTime.now().month, 1);
    final monthStart =
        DateTime(currentMonth.year, currentMonth.month - _monthOffset, 1);
    final monthEnd = DateTime(monthStart.year, monthStart.month + 1, 1);
    final dayCount = monthEnd.difference(monthStart).inDays;

    final starts = List<DateTime>.generate(
      dayCount,
      (i) => monthStart.add(Duration(days: i)),
      growable: false,
    );

    final points = starts.map((start) {
      final end = start.add(const Duration(days: 1));
      final dayRows = widget.rows
          .where((a) => !a.date.isBefore(start) && a.date.isBefore(end))
          .toList(growable: false);
      final count = dayRows.length.toDouble();
      final gross = dayRows.fold<double>(
        0,
        (sum, a) => sum + a.paid + a.prescriptionPaid,
      );
      return (
        label: formatClinicDate(start, pattern: 'dd'),
        count: count,
        gross: gross,
      );
    }).toList(growable: false);

    final maxCount =
        points.fold<double>(1, (m, p) => p.count > m ? p.count : m);
    final maxGross =
        points.fold<double>(1, (m, p) => p.gross > m ? p.gross : m);

    return _ReportContainer(
      title: 'Appointment + Gross Trend (Daily Bars)',
      subtitle: formatClinicDate(monthStart, pattern: 'MMMM yyyy'),
      trailing: _TrendNavButtons(
        canGoForward: _monthOffset > 0,
        onBack: () => setState(() => _monthOffset += 1),
        onForward:
            _monthOffset > 0 ? () => setState(() => _monthOffset -= 1) : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              _LegendDot(color: AppColors.brandBlue, label: 'Appointments'),
              SizedBox(width: 10),
              _LegendDot(color: AppColors.successTeal, label: 'Gross Revenue'),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 220,
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceBetween,
                maxY: 110,
                gridData: FlGridData(
                  show: true,
                  horizontalInterval: 25,
                  getDrawingHorizontalLine: (_) => const FlLine(
                    color: AppColors.slate100,
                    strokeWidth: 1,
                  ),
                  drawVerticalLine: false,
                ),
                borderData: FlBorderData(
                  show: true,
                  border: const Border(
                    left: BorderSide(color: AppColors.borderSoft),
                    bottom: BorderSide(color: AppColors.borderSoft),
                  ),
                ),
                titlesData: FlTitlesData(
                  leftTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 24,
                      getTitlesWidget: (value, meta) {
                        final index = value.toInt();
                        if (index < 0 || index >= points.length) {
                          return const SizedBox.shrink();
                        }
                        if (points.length > 12 && index % 2 == 1) {
                          return const SizedBox.shrink();
                        }
                        return SideTitleWidget(
                          axisSide: meta.axisSide,
                          child: Text(
                            points[index].label,
                            style: const TextStyle(
                              color: AppColors.textBlueMuted,
                              fontWeight: FontWeight.w700,
                              fontSize: 10,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                barTouchData: BarTouchData(
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipColor: (_) => AppColors.blue750,
                    getTooltipItem: (group, groupIndex, rod, rodIndex) {
                      final day = points[groupIndex];
                      if (rodIndex != 0) {
                        return null;
                      }
                      return BarTooltipItem(
                        '${day.label}\nAppts: ${day.count.toStringAsFixed(0)}\nGross: ₹${formatIndianCompactNumber(day.gross, fractionDigits: 1)}',
                        const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      );
                    },
                  ),
                ),
                barGroups: List<BarChartGroupData>.generate(
                  points.length,
                  (index) => BarChartGroupData(
                    x: index,
                    barsSpace: 3,
                    barRods: [
                      BarChartRodData(
                        toY: (points[index].count / maxCount) * 100,
                        width: 6,
                        color: AppColors.brandBlue,
                        borderRadius: BorderRadius.circular(3),
                      ),
                      BarChartRodData(
                        toY: (points[index].gross / maxGross) * 100,
                        width: 6,
                        color: AppColors.successTeal,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;

  const _LegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 9,
          height: 9,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: const TextStyle(
            color: AppColors.textBlueStrong,
            fontWeight: FontWeight.w700,
            fontSize: 11,
          ),
        ),
      ],
    );
  }
}

class _DailyAppointmentsTrendSection extends StatefulWidget {
  final List<Appointment> rows;

  const _DailyAppointmentsTrendSection({required this.rows});

  @override
  State<_DailyAppointmentsTrendSection> createState() =>
      _DailyAppointmentsTrendSectionState();
}

class _DailyAppointmentsTrendSectionState
    extends State<_DailyAppointmentsTrendSection> {
  int _monthOffset = 0;

  @override
  Widget build(BuildContext context) {
    return _DailyAppointmentsTrendWindowCard(
      rows: widget.rows,
      monthOffset: _monthOffset,
      onBack: () => setState(() => _monthOffset += 1),
      onForward:
          _monthOffset > 0 ? () => setState(() => _monthOffset -= 1) : null,
    );
  }
}

class _DailyRevenueTrendSection extends StatefulWidget {
  final List<Appointment> rows;

  const _DailyRevenueTrendSection({required this.rows});

  @override
  State<_DailyRevenueTrendSection> createState() =>
      _DailyRevenueTrendSectionState();
}

class _DailyRevenueTrendSectionState extends State<_DailyRevenueTrendSection> {
  int _monthOffset = 0;

  @override
  Widget build(BuildContext context) {
    return _DailyRevenueTrendWindowCard(
      rows: widget.rows,
      monthOffset: _monthOffset,
      onBack: () => setState(() => _monthOffset += 1),
      onForward:
          _monthOffset > 0 ? () => setState(() => _monthOffset -= 1) : null,
    );
  }
}

class _MonthlyAppointmentsTrendSection extends StatelessWidget {
  final List<Appointment> rows;
  final int windowOffset;

  const _MonthlyAppointmentsTrendSection({
    required this.rows,
    required this.windowOffset,
  });

  @override
  Widget build(BuildContext context) {
    return _MonthlyAppointmentsTrendWindowCard(
      rows: rows,
      windowOffset: windowOffset,
    );
  }
}

class _MonthlyRevenueTrendSection extends StatelessWidget {
  final List<Appointment> rows;
  final int windowOffset;

  const _MonthlyRevenueTrendSection({
    required this.rows,
    required this.windowOffset,
  });

  @override
  Widget build(BuildContext context) {
    return _MonthlyRevenueTrendWindowCard(
      rows: rows,
      windowOffset: windowOffset,
    );
  }
}

class _MonthlyExpensesTrendSection extends StatelessWidget {
  final List<Expense> rows;
  final int windowOffset;

  const _MonthlyExpensesTrendSection({
    required this.rows,
    required this.windowOffset,
  });

  @override
  Widget build(BuildContext context) {
    return _MonthlyExpensesTrendWindowCard(
      rows: rows,
      windowOffset: windowOffset,
    );
  }
}

class _MonthlyNetRevenueTrendSection extends StatelessWidget {
  final List<Appointment> appointmentsRows;
  final List<Expense> expenseRows;
  final int windowOffset;

  const _MonthlyNetRevenueTrendSection({
    required this.appointmentsRows,
    required this.expenseRows,
    required this.windowOffset,
  });

  @override
  Widget build(BuildContext context) {
    return _MonthlyNetRevenueTrendWindowCard(
      appointmentsRows: appointmentsRows,
      expenseRows: expenseRows,
      windowOffset: windowOffset,
    );
  }
}

class _DailyAppointmentsTrendWindowCard extends StatelessWidget {
  final List<Appointment> rows;
  final int monthOffset;
  final VoidCallback onBack;
  final VoidCallback? onForward;

  const _DailyAppointmentsTrendWindowCard({
    required this.rows,
    required this.monthOffset,
    required this.onBack,
    required this.onForward,
  });

  @override
  Widget build(BuildContext context) {
    final currentMonth = DateTime(DateTime.now().year, DateTime.now().month, 1);
    final monthStart =
        DateTime(currentMonth.year, currentMonth.month - monthOffset, 1);
    final monthEnd = DateTime(monthStart.year, monthStart.month + 1, 1);
    final dayCount = monthEnd.difference(monthStart).inDays;

    final starts = List<DateTime>.generate(
        dayCount, (i) => monthStart.add(Duration(days: i)),
        growable: false);

    final points = starts.map((start) {
      final end = start.add(const Duration(days: 1));
      final count = rows
          .where((a) => !a.date.isBefore(start) && a.date.isBefore(end))
          .length
          .toDouble();
      return (label: formatClinicDate(start, pattern: 'dd'), value: count);
    }).toList(growable: false);

    return SizedBox(
      width: 560,
      child: _SimpleBarsCard(
        title: 'Appointment Trend (Daily)',
        subtitle: formatClinicDate(monthStart, pattern: 'MMMM yyyy'),
        rows: points,
        barColor: AppColors.brandBlue,
        trailing: _TrendNavButtons(
          canGoForward: monthOffset > 0,
          onBack: onBack,
          onForward: onForward,
        ),
      ),
    );
  }
}

class _MonthlyAppointmentsTrendWindowCard extends StatelessWidget {
  final List<Appointment> rows;
  final int windowOffset;

  const _MonthlyAppointmentsTrendWindowCard({
    required this.rows,
    required this.windowOffset,
  });

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final windowEnd = DateTime(now.year, now.month - windowOffset + 1, 1);
    final windowStart = DateTime(windowEnd.year, windowEnd.month - 12, 1);
    final starts = List<DateTime>.generate(
      12,
      (i) => DateTime(windowStart.year, windowStart.month + i, 1),
      growable: false,
    );

    final points = starts.map((start) {
      final end = DateTime(start.year, start.month + 1, 1);
      final count = rows
          .where((a) => !a.date.isBefore(start) && a.date.isBefore(end))
          .length
          .toDouble();
      return (label: formatClinicDate(start, pattern: 'MMM'), value: count);
    }).toList(growable: false);

    return SizedBox(
      width: 560,
      child: _SimpleBarsCard(
        title: 'Appointment Trend (Monthly)',
        subtitle:
            '${formatClinicDate(starts.first, pattern: 'MMM yyyy')} - ${formatClinicDate(starts.last, pattern: 'MMM yyyy')}',
        rows: points,
        barColor: AppColors.successTeal,
      ),
    );
  }
}

class _DailyRevenueTrendWindowCard extends StatelessWidget {
  final List<Appointment> rows;
  final int monthOffset;
  final VoidCallback onBack;
  final VoidCallback? onForward;

  const _DailyRevenueTrendWindowCard({
    required this.rows,
    required this.monthOffset,
    required this.onBack,
    required this.onForward,
  });

  @override
  Widget build(BuildContext context) {
    final currentMonth = DateTime(DateTime.now().year, DateTime.now().month, 1);
    final monthStart =
        DateTime(currentMonth.year, currentMonth.month - monthOffset, 1);
    final monthEnd = DateTime(monthStart.year, monthStart.month + 1, 1);
    final dayCount = monthEnd.difference(monthStart).inDays;

    final starts = List<DateTime>.generate(
        dayCount, (i) => monthStart.add(Duration(days: i)),
        growable: false);

    final points = starts.map((start) {
      final end = start.add(const Duration(days: 1));
      final value = rows
          .where((a) => !a.date.isBefore(start) && a.date.isBefore(end))
          .fold<double>(0, (sum, a) => sum + a.paid + a.prescriptionPaid);
      return (label: formatClinicDate(start, pattern: 'dd'), value: value);
    }).toList(growable: false);

    return SizedBox(
      width: 560,
      child: _SimpleBarsCard(
        title: 'Gross Revenue Trend (Daily)',
        subtitle: formatClinicDate(monthStart, pattern: 'MMMM yyyy'),
        rows: points,
        barColor: AppColors.blue600,
        valueFormatter: formatIndianShortCurrency,
        verticalValueLabels: true,
        trailing: _TrendNavButtons(
          canGoForward: monthOffset > 0,
          onBack: onBack,
          onForward: onForward,
        ),
      ),
    );
  }
}

class _MonthlyRevenueTrendWindowCard extends StatelessWidget {
  final List<Appointment> rows;
  final int windowOffset;

  const _MonthlyRevenueTrendWindowCard({
    required this.rows,
    required this.windowOffset,
  });

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final windowEnd = DateTime(now.year, now.month - windowOffset + 1, 1);
    final windowStart = DateTime(windowEnd.year, windowEnd.month - 12, 1);
    final starts = List<DateTime>.generate(
      12,
      (i) => DateTime(windowStart.year, windowStart.month + i, 1),
      growable: false,
    );

    final points = starts.map((start) {
      final end = DateTime(start.year, start.month + 1, 1);
      final value = rows
          .where((a) => !a.date.isBefore(start) && a.date.isBefore(end))
          .fold<double>(0, (sum, a) => sum + a.paid + a.prescriptionPaid);
      return (label: formatClinicDate(start, pattern: 'MMM'), value: value);
    }).toList(growable: false);

    return SizedBox(
      width: 560,
      child: _SimpleBarsCard(
        title: 'Gross Revenue Trend (Monthly)',
        subtitle:
            '${formatClinicDate(starts.first, pattern: 'MMM yyyy')} - ${formatClinicDate(starts.last, pattern: 'MMM yyyy')}',
        rows: points,
        barColor: AppColors.brandBlue,
        valueFormatter: (value) =>
            '₹${formatIndianCompactNumber(value, fractionDigits: 1)}',
        showValueLabels: false,
      ),
    );
  }
}

class _MonthlyExpensesTrendWindowCard extends StatelessWidget {
  final List<Expense> rows;
  final int windowOffset;

  const _MonthlyExpensesTrendWindowCard({
    required this.rows,
    required this.windowOffset,
  });

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final windowEnd = DateTime(now.year, now.month - windowOffset + 1, 1);
    final windowStart = DateTime(windowEnd.year, windowEnd.month - 12, 1);
    final starts = List<DateTime>.generate(
      12,
      (i) => DateTime(windowStart.year, windowStart.month + i, 1),
      growable: false,
    );

    final points = starts.map((start) {
      final end = DateTime(start.year, start.month + 1, 1);
      final value = rows
          .where((e) => !e.date.isBefore(start) && e.date.isBefore(end))
          .fold<double>(0, (sum, e) => sum + e.amount);
      return (label: formatClinicDate(start, pattern: 'MMM'), value: value);
    }).toList(growable: false);

    return SizedBox(
      width: 560,
      child: _SimpleBarsCard(
        title: 'Expenses Trend (Monthly)',
        subtitle:
            '${formatClinicDate(starts.first, pattern: 'MMM yyyy')} - ${formatClinicDate(starts.last, pattern: 'MMM yyyy')}',
        rows: points,
        barColor: AppColors.dangerRose,
        valueFormatter: (value) =>
            '₹${formatIndianCompactNumber(value, fractionDigits: 1)}',
        showValueLabels: false,
      ),
    );
  }
}

class _MonthlyNetRevenueTrendWindowCard extends StatelessWidget {
  final List<Appointment> appointmentsRows;
  final List<Expense> expenseRows;
  final int windowOffset;

  const _MonthlyNetRevenueTrendWindowCard({
    required this.appointmentsRows,
    required this.expenseRows,
    required this.windowOffset,
  });

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final windowEnd = DateTime(now.year, now.month - windowOffset + 1, 1);
    final windowStart = DateTime(windowEnd.year, windowEnd.month - 12, 1);
    final starts = List<DateTime>.generate(
      12,
      (i) => DateTime(windowStart.year, windowStart.month + i, 1),
      growable: false,
    );

    final points = starts.map((start) {
      final end = DateTime(start.year, start.month + 1, 1);
      final gross = appointmentsRows
          .where((a) => !a.date.isBefore(start) && a.date.isBefore(end))
          .fold<double>(0, (sum, a) => sum + a.paid + a.prescriptionPaid);
      final expensesSum = expenseRows
          .where((e) => !e.date.isBefore(start) && e.date.isBefore(end))
          .fold<double>(0, (sum, e) => sum + e.amount);
      final net = gross - expensesSum;
      return (label: formatClinicDate(start, pattern: 'MMM'), value: net);
    }).toList(growable: false);

    return SizedBox(
      width: 560,
      child: _SimpleBarsCard(
        title: 'Net Revenue Trend (Monthly)',
        subtitle:
            '${formatClinicDate(starts.first, pattern: 'MMM yyyy')} - ${formatClinicDate(starts.last, pattern: 'MMM yyyy')}',
        rows: points,
        barColor: AppColors.successTeal,
        valueFormatter: (value) =>
            '₹${formatIndianCompactNumber(value, fractionDigits: 1)}',
        showValueLabels: false,
      ),
    );
  }
}

class _PaymentModeStatusCard extends StatelessWidget {
  final List<Appointment> rows;
  final int monthOffset;

  const _PaymentModeStatusCard({
    required this.rows,
    required this.monthOffset,
  });

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final monthStart = DateTime(now.year, now.month - monthOffset, 1);
    final monthEnd = DateTime(monthStart.year, monthStart.month + 1, 1);
    final scoped = rows
        .where((a) => !a.date.isBefore(monthStart) && a.date.isBefore(monthEnd))
        .toList(growable: false);

    var upiCount = 0;
    var cashCount = 0;
    for (final appointment in scoped) {
      final hasPayment =
          appointment.paid > 0 || appointment.prescriptionPaid > 0;
      if (!hasPayment) continue;
      final isUpi =
          appointment.treatmentGpayPaid || appointment.prescriptionGpayPaid;
      if (isUpi) {
        upiCount += 1;
      } else {
        cashCount += 1;
      }
    }
    final total = upiCount + cashCount;
    final upiPct = total == 0 ? 0.0 : (upiCount * 100) / total;
    final cashPct = total == 0 ? 0.0 : (cashCount * 100) / total;

    return _ReportContainer(
      title: 'Total Payment Status ($total)',
      subtitle: formatClinicDate(monthStart, pattern: 'MMMM yyyy'),
      child: SizedBox(
        height: 220,
        child: total == 0
            ? const Align(
                alignment: Alignment.center,
                child: Text(
                  'No payment data found.',
                  style: TextStyle(color: AppColors.textBlueMuted),
                ),
              )
            : _PieLegendLayout(
                pie: PieChart(
                  PieChartData(
                    sectionsSpace: 2,
                    centerSpaceRadius: 28,
                    sections: [
                      PieChartSectionData(
                        value: upiCount.toDouble(),
                        color: AppColors.brandBlue,
                        title: '${upiPct.toStringAsFixed(0)}%',
                        titleStyle: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 10,
                        ),
                        radius: 42,
                      ),
                      PieChartSectionData(
                        value: cashCount.toDouble(),
                        color: AppColors.dangerRose,
                        title: '${cashPct.toStringAsFixed(0)}%',
                        titleStyle: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 10,
                        ),
                        radius: 42,
                      ),
                    ],
                  ),
                ),
                legend: [
                  _LegendDot(
                    color: AppColors.brandBlue,
                    label: 'UPI: $upiCount',
                  ),
                  const SizedBox(height: 8),
                  _LegendDot(
                    color: AppColors.dangerRose,
                    label: 'Cash: $cashCount',
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Total: $total',
                    style: const TextStyle(
                      color: AppColors.textBlueMuted,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

class _ReferralSourceDistributionCard extends StatelessWidget {
  final List<Appointment> rows;
  final int monthOffset;

  const _ReferralSourceDistributionCard({
    required this.rows,
    required this.monthOffset,
  });

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final monthStart = DateTime(now.year, now.month - monthOffset, 1);
    final monthEnd = DateTime(monthStart.year, monthStart.month + 1, 1);
    final scoped = rows
        .where((a) => !a.date.isBefore(monthStart) && a.date.isBefore(monthEnd))
        .toList(growable: false);

    final counts = <String, int>{};
    for (final row in scoped) {
      final patient = row.patient;
      if (patient == null) continue;
      final source = patient.referralSource.trim().isEmpty
          ? 'None'
          : patient.referralSource.trim();
      counts[source] = (counts[source] ?? 0) + 1;
    }

    final sourceRows = counts.entries.toList(growable: false)
      ..sort((a, b) => b.value.compareTo(a.value));
    final total = sourceRows.fold<int>(0, (sum, e) => sum + e.value);
    const colors = [
      AppColors.brandBlue,
      AppColors.successTeal,
      AppColors.amber400,
      AppColors.dangerRose,
      AppColors.violet4502,
      AppColors.violet5502,
    ];

    return IntrinsicWidth(
      child: _ReportContainer(
        title: 'Referral Source Report',
        subtitle: formatClinicDate(monthStart, pattern: 'MMMM yyyy'),
        child: SizedBox(
          height: 220,
          child: sourceRows.isEmpty
              ? const Align(
                  alignment: Alignment.center,
                  child: Text(
                    'No referral source data found.',
                    style: TextStyle(color: AppColors.blue5004),
                  ),
                )
              : _PieLegendLayout(
                  pie: PieChart(
                    PieChartData(
                      sectionsSpace: 2,
                      centerSpaceRadius: 28,
                      sections: sourceRows.asMap().entries.map((entry) {
                        final row = entry.value;
                        final pct =
                            total == 0 ? 0.0 : (row.value / total) * 100;
                        return PieChartSectionData(
                          value: row.value.toDouble(),
                          color: colors[entry.key % colors.length],
                          title: pct >= 8 ? '${pct.toStringAsFixed(0)}%' : '',
                          titleStyle: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 10,
                          ),
                          radius: 42,
                        );
                      }).toList(growable: false),
                    ),
                  ),
                  legend: [
                    ...sourceRows.asMap().entries.map((entry) {
                      final row = entry.value;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: _LegendDot(
                          color: colors[entry.key % colors.length],
                          label: '${row.key} (${row.value})',
                        ),
                      );
                    }),
                  ],
                ),
        ),
      ),
    );
  }
}

class _PieLegendLayout extends StatelessWidget {
  final Widget pie;
  final List<Widget> legend;

  const _PieLegendLayout({
    required this.pie,
    required this.legend,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(width: 130, height: 130, child: pie),
          const SizedBox(width: 12),
          SizedBox(
            width: 150,
            child: SingleChildScrollView(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: legend,
              ),
            ),
          ),
        ],
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

class _ReportMonthNavigator extends StatelessWidget {
  final String label;
  final VoidCallback onBack;
  final VoidCallback? onForward;
  final bool canGoForward;

  const _ReportMonthNavigator({
    required this.label,
    required this.onBack,
    required this.onForward,
    required this.canGoForward,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.borderSoft),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 24,
            height: 24,
            child: IconButton(
              icon: const Icon(FluentIcons.chevron_left, size: 11),
              onPressed: onBack,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: AppColors.textBlueStrong,
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
          const SizedBox(width: 6),
          SizedBox(
            width: 24,
            height: 24,
            child: IconButton(
              icon: const Icon(FluentIcons.chevron_right, size: 11),
              onPressed: canGoForward ? onForward : null,
            ),
          ),
        ],
      ),
    );
  }
}

class _SimpleBarsCard extends StatelessWidget {
  final String title;
  final String? subtitle;
  final List<({String label, double value})> rows;
  final Color barColor;
  final Widget? trailing;
  final String Function(double value)? valueFormatter;
  final bool verticalValueLabels;
  final bool showValueLabels;

  const _SimpleBarsCard({
    required this.title,
    this.subtitle,
    required this.rows,
    required this.barColor,
    this.trailing,
    this.valueFormatter,
    this.verticalValueLabels = false,
    this.showValueLabels = true,
  });

  @override
  Widget build(BuildContext context) {
    final labels = rows.map((row) => row.label).toList(growable: false);
    final values = rows.map((row) => row.value).toList(growable: false);

    return _ReportContainer(
      title: title,
      subtitle: subtitle,
      trailing: trailing,
      child: SizedBox(
        height: 220,
        child: _FormattedBarChart(
          labels: labels,
          values: values,
          barColor: barColor,
          valueFormatter: valueFormatter,
        ),
      ),
    );
  }
}

class _FormattedBarChart extends StatelessWidget {
  final List<String> labels;
  final List<double> values;
  final Color barColor;
  final String Function(double value)? valueFormatter;

  const _FormattedBarChart({
    required this.labels,
    required this.values,
    required this.barColor,
    this.valueFormatter,
  });

  String _format(double value) {
    if (valueFormatter != null) return valueFormatter!(value);
    if (value == value.roundToDouble()) return value.toStringAsFixed(0);
    return value.toStringAsFixed(1);
  }

  double _axisStep(double maxValue) {
    if (maxValue <= 0) return 50;
    final rough = maxValue / 4;
    final exponent = (math.log(rough) / math.ln10).floorToDouble();
    final magnitude = math.pow(10, exponent).toDouble();
    final normalized = rough / magnitude;
    if (normalized <= 1) return 1 * magnitude;
    if (normalized <= 2) return 2 * magnitude;
    if (normalized <= 5) return 5 * magnitude;
    return 10 * magnitude;
  }

  @override
  Widget build(BuildContext context) {
    if (values.isEmpty) {
      return const Center(
        child: Text(
          'No data found',
          style: TextStyle(color: AppColors.textBlueMuted),
        ),
      );
    }

    final maxValue = values.fold<double>(0, (m, v) => v > m ? v : m);
    final step = _axisStep(maxValue);
    final maxY = math.max(step, (maxValue / step).ceilToDouble() * step);

    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceBetween,
        maxY: maxY,
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: step,
          getDrawingHorizontalLine: (_) => const FlLine(
            color: AppColors.slate100,
            strokeWidth: 1,
          ),
        ),
        borderData: FlBorderData(
          show: true,
          border: const Border(
            left: BorderSide(color: AppColors.borderSoft),
            bottom: BorderSide(color: AppColors.borderSoft),
          ),
        ),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 42,
              interval: step,
              getTitlesWidget: (value, meta) => SideTitleWidget(
                axisSide: meta.axisSide,
                child: Text(
                  _format(value),
                  style: const TextStyle(
                    color: AppColors.textBlueMuted,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 28,
              getTitlesWidget: (value, meta) {
                final index = value.toInt();
                if (index < 0 || index >= labels.length) {
                  return const SizedBox.shrink();
                }
                return SideTitleWidget(
                  axisSide: meta.axisSide,
                  child: Text(
                    labels[index],
                    style: const TextStyle(
                      color: AppColors.textBlueMuted,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            getTooltipColor: (_) => AppColors.blue750,
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              return BarTooltipItem(
                '${labels[groupIndex]}\n${_format(rod.toY)}',
                const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              );
            },
          ),
        ),
        barGroups: List<BarChartGroupData>.generate(
          values.length,
          (index) => BarChartGroupData(
            x: index,
            barRods: [
              BarChartRodData(
                toY: values[index],
                width: 16,
                borderRadius: BorderRadius.circular(4),
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [
                    barColor.withValues(alpha: 0.35),
                    barColor,
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TrafficByTimeCard extends StatelessWidget {
  final List<Appointment> rows;
  final int monthOffset;

  const _TrafficByTimeCard({required this.rows, required this.monthOffset});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final monthStart = DateTime(now.year, now.month - monthOffset, 1);
    final monthEnd = DateTime(monthStart.year, monthStart.month + 1, 1);
    final scoped = rows
        .where((a) => !a.date.isBefore(monthStart) && a.date.isBefore(monthEnd))
        .toList(growable: false);
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

    return _ReportContainer(
      title: 'Traffic by Time',
      subtitle: formatClinicDate(monthStart, pattern: 'MMMM yyyy'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 220,
            child: _FormattedBarChart(
              labels: points.map((e) => e.label).toList(growable: false),
              values: points.map((e) => e.value).toList(growable: false),
              barColor: AppColors.brandBlue,
            ),
          ),
        ],
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
  _RangeFilter _range = _RangeFilter.lastMonth;
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

    return _ReportContainer(
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
            child: _FormattedBarChart(
              labels: points.map((e) => e.label).toList(growable: false),
              values: points.map((e) => e.value).toList(growable: false),
              barColor: AppColors.successTeal,
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
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.borderSoft),
        boxShadow: const [
          BoxShadow(
            color: AppColors.overlay22,
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
                    fontSize: 14,
                    color: AppColors.blue750,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (trailing != null) trailing!,
            ],
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 2),
            Text(
              subtitle!,
              style: const TextStyle(
                color: AppColors.textBlueMuted,
                fontWeight: FontWeight.w700,
                fontSize: 11,
              ),
            ),
          ],
          const SizedBox(height: 6),
          child,
        ],
      ),
    );
  }
}
