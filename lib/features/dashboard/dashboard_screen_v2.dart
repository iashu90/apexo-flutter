import 'dart:math' as math;

import 'package:apexo/features/appointments/appointment_model.dart';
import 'package:apexo/features/appointments/appointments_store.dart';
import 'package:apexo/features/appointments/open_appointment_panel.dart';
import 'package:apexo/features/dashboard/dashboard_controller.dart';
import 'package:apexo/features/dashboard/overall_due_helper.dart';
import 'package:apexo/features/dashboard/patient_look_up.dart';
import 'package:apexo/features/doctors/doctors_store.dart';
import 'package:apexo/features/patients/open_patient_panel.dart';
import 'package:apexo/features/patients/patient_model.dart';
import 'package:apexo/features/patients/patients_store.dart';
import 'package:apexo/utils/indian_money.dart';
import 'package:apexo/common_widgets/patients_report_dialog.dart';
import 'package:apexo/common_widgets/patient_history_modal_v2.dart';
import 'package:apexo/theme/material_date_picker_theme.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/material.dart' as material;
import 'package:intl/intl.dart';

DateTime dashboardV2PersistedDate = DateTime.now();

class DashboardScreenV2 extends StatefulWidget {
  const DashboardScreenV2({super.key});

  @override
  State<DashboardScreenV2> createState() => _DashboardScreenV2State();
}

class _DashboardScreenV2State extends State<DashboardScreenV2> {
  static const String _filterAll = '__all__';
  static const String _filterUnassigned = '__unassigned__';
  static const String _treatmentFilterAll = '__all_treatments__';

  late DateTime selectedDate;
  String _sortBy = 'time';
  bool _sortAscending = true;
  String _searchQuery = '';
  String _selectedDoctorFilter = _filterAll;
  String _selectedTreatmentFilter = _treatmentFilterAll;
  bool _showAllTreatmentStats = false;
  final TextEditingController _searchController = TextEditingController();

  String? _doctorFilterChipLabel() {
    if (_selectedDoctorFilter == _filterAll) return null;
    if (_selectedDoctorFilter == _filterUnassigned) {
      return 'Doctor: Unassigned';
    }
    final doctorName = doctors.get(_selectedDoctorFilter)?.title ?? 'Unknown';
    return 'Doctor: $doctorName';
  }

  String? _treatmentFilterChipLabel() {
    if (_selectedTreatmentFilter == _treatmentFilterAll) return null;
    return 'Treatment: $_selectedTreatmentFilter';
  }

  @override
  void initState() {
    super.initState();
    selectedDate = _dateOnly(dashboardV2PersistedDate);
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text;
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _changeDate(int days) {
    setState(() {
      selectedDate = _dateOnly(selectedDate.add(Duration(days: days)));
      dashboardV2PersistedDate = selectedDate;
    });
  }

  void _goToday() {
    setState(() {
      selectedDate = _dateOnly(DateTime.now());
      dashboardV2PersistedDate = selectedDate;
    });
  }

  Future<void> _pickDate(BuildContext context) async {
    final picked = await material.showDatePicker(
      context: context,
      initialDate: selectedDate,
      firstDate: DateTime(2000, 1, 1),
      lastDate: DateTime(2100, 12, 31),
      helpText: 'Select date',
      builder: apexoDatePickerBuilder(context),
    );

    if (picked == null) return;
    setState(() {
      selectedDate = _dateOnly(picked);
      dashboardV2PersistedDate = selectedDate;
    });
  }

  void _onSort(String key) {
    setState(() {
      if (_sortBy == key) {
        _sortAscending = !_sortAscending;
      } else {
        _sortBy = key;
        _sortAscending = true;
      }
    });
  }

  List<Appointment> _filteredAndSorted(List<Appointment> source) {
    final q = _searchQuery.trim().toLowerCase();

    final filtered = source.where((a) {
      if (q.isEmpty) return true;
      final name = a.title.toLowerCase();
      final phone = (a.patient?.phone ?? '').toLowerCase();
      return name.contains(q) || phone.contains(q);
    }).toList();

    int compare(Appointment a, Appointment b) {
      switch (_sortBy) {
        case 'patient':
          return a.title.toLowerCase().compareTo(b.title.toLowerCase());
        case 'doctor':
          final aDoctor = a.operators.isEmpty
              ? 'unassigned'
              : a.operators.map((d) => d.title).join(', ');
          final bDoctor = b.operators.isEmpty
              ? 'unassigned'
              : b.operators.map((d) => d.title).join(', ');
          return aDoctor.toLowerCase().compareTo(bDoctor.toLowerCase());
        case 'treatment':
          final aTreatment = a.selectedTreatments.isEmpty
              ? ''
              : a.selectedTreatments.join(', ');
          final bTreatment = b.selectedTreatments.isEmpty
              ? ''
              : b.selectedTreatments.join(', ');
          return aTreatment.toLowerCase().compareTo(bTreatment.toLowerCase());
        case 'status':
          return a.isDone == b.isDone ? 0 : (a.isDone ? 1 : -1);
        case 'paymentMode':
          return _paymentMode(a).compareTo(_paymentMode(b));
        case 'payment':
          final aPayment = a.paid + a.prescriptionPaid;
          final bPayment = b.paid + b.prescriptionPaid;
          return aPayment.compareTo(bPayment);
        case 'actions':
          return a.id.compareTo(b.id);
        case 'time':
        default:
          return a.date.compareTo(b.date);
      }
    }

    filtered.sort(compare);
    if (!_sortAscending) {
      return filtered.reversed.toList();
    }
    return filtered;
  }

  String _paymentMode(Appointment a) {
    final digital = a.treatmentGpayPaid || a.prescriptionGpayPaid;
    return digital ? 'digital' : 'cash';
  }

  static DateTime _dateOnly(DateTime input) {
    return DateTime(input.year, input.month, input.day);
  }

  List<Appointment> _doctorFiltered(List<Appointment> source) {
    if (_selectedDoctorFilter == _filterAll) return source;
    if (_selectedDoctorFilter == _filterUnassigned) {
      return source.where((a) => a.operatorsIDs.isEmpty).toList();
    }
    return source
        .where((a) => a.operatorsIDs.contains(_selectedDoctorFilter))
        .toList();
  }

  List<Appointment> _treatmentFiltered(List<Appointment> source) {
    if (_selectedTreatmentFilter == _treatmentFilterAll) return source;
    final treatment = _selectedTreatmentFilter.toLowerCase();
    return source
        .where(
          (a) => a.selectedTreatments.any(
            (t) => t.trim().toLowerCase() == treatment,
          ),
        )
        .toList();
  }

  List<({DateTime day, double value})> _dailyRevenueRows(
    List<Appointment> source,
    DateTime anchor,
    int days,
  ) {
    final start = _dateOnly(anchor).subtract(Duration(days: days - 1));
    final map = <DateTime, double>{
      for (int i = 0; i < days; i++) start.add(Duration(days: i)): 0,
    };
    for (final a in source) {
      final d = _dateOnly(a.date);
      if (d.isBefore(start) || d.isAfter(_dateOnly(anchor))) continue;
      map[d] = (map[d] ?? 0) + a.paid + a.prescriptionPaid;
    }
    return map.entries
        .map((e) => (day: e.key, value: e.value))
        .toList(growable: false);
  }

  List<({DateTime day, int count})> _appointmentTrendRows(
    List<Appointment> source,
    DateTime anchor,
    int days,
  ) {
    final start = _dateOnly(anchor).subtract(Duration(days: days - 1));
    final map = <DateTime, int>{
      for (int i = 0; i < days; i++) start.add(Duration(days: i)): 0,
    };
    for (final a in source) {
      final d = _dateOnly(a.date);
      if (d.isBefore(start) || d.isAfter(_dateOnly(anchor))) continue;
      map[d] = (map[d] ?? 0) + 1;
    }
    return map.entries
        .map((e) => (day: e.key, count: e.value))
        .toList(growable: false);
  }

  List<MapEntry<String, int>> _treatmentDistributionRows(List<Appointment> source) {
    final counts = <String, int>{};
    for (final a in source) {
      for (final t in a.selectedTreatments) {
        final name = t.trim();
        if (name.isEmpty) continue;
        counts[name] = (counts[name] ?? 0) + 1;
      }
    }
    final rows = counts.entries.toList(growable: false)
      ..sort((a, b) => b.value.compareTo(a.value));
    return rows.take(6).toList(growable: false);
  }

  void _openOutstandingDialog() {
    final result = OverallDueHelper.compute(
      appointments: appointments.present.values,
      patientsById: patients.present,
    );

    showDialog(
      context: context,
      builder: (_) => Align(
        alignment: Alignment.center,
        child: Container(
          color: Colors.white,
          child: PatientDetailsDialog(
            rows: result.rows,
            hiddenColumns: const [
              'Treatment',
              'Teeth',
              'Prescription',
              'Date',
              'T.Mode',
              'P.Mode',
              'Doc Paid',
              'TotalDocPay',
            ],
          ),
        ),
      ),
    );
  }

  void _openNewPatientsDialog(List<Appointment> todaysAppointments) {
    final newPatientAppointments = todaysAppointments
        .where((a) => a.firstAppointmentForThisPatient)
        .toList()
      ..sort((a, b) => a.date.compareTo(b.date));

    showDialog(
      context: context,
      builder: (_) => ContentDialog(
        title: const Text(
          'New Patients Today',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: Color(0xFF183A67),
          ),
        ),
        content: SizedBox(
          width: 520,
          child: newPatientAppointments.isEmpty
              ? const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    'No new patients for this date.',
                    style: TextStyle(color: Color(0xFF5B7498)),
                  ),
                )
              : ListView.separated(
                  shrinkWrap: true,
                  itemCount: newPatientAppointments.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 6),
                  itemBuilder: (_, index) {
                    final appointment = newPatientAppointments[index];
                    final patient = appointment.patient;
                    final patientName = appointment.title.trim().isEmpty
                        ? 'Unnamed patient'
                        : appointment.title;
                    final phone = (patient?.phone ?? '').trim();
                    final age = patient?.age ?? 0;
                    final address = (patient?.address ?? '').trim();

                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF5F9FF),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFD7E5F7)),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 28,
                            height: 28,
                            decoration: BoxDecoration(
                              color: const Color(0xFFDDEBFF),
                              borderRadius: BorderRadius.circular(7),
                            ),
                            alignment: Alignment.center,
                            child: const Icon(
                              FluentIcons.contact,
                              size: 14,
                              color: Color(0xFF1468CC),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  patientName,
                                  style: const TextStyle(
                                    color: Color(0xFF1D3C64),
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 4,
                                  children: [
                                    Text(
                                      age > 0 ? 'Age: $age' : 'Age: -',
                                      style: const TextStyle(
                                        color: Color(0xFF5B7498),
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    if (phone.isNotEmpty)
                                      Text(
                                        phone,
                                        style: const TextStyle(
                                          color: Color(0xFF5B7498),
                                          fontSize: 12,
                                        ),
                                      ),
                                  ],
                                ),
                                if (address.isNotEmpty) ...[
                                  const SizedBox(height: 4),
                                  Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Icon(
                                        FluentIcons.location,
                                        size: 12,
                                        color: Color(0xFF6B83A6),
                                      ),
                                      const SizedBox(width: 5),
                                      Expanded(
                                        child: Text(
                                          address,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            color: Color(0xFF5B7498),
                                            fontSize: 11,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
        actions: [
          FilledButton(
            style: ButtonStyle(
              backgroundColor: WidgetStateProperty.all(const Color(0xFF2D7BD8)),
            ),
            child: const Text('Close'),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
      stream: appointments.observableMap.stream,
      builder: (context, _) {
        final todaysAppointments = appointments.forDate(selectedDate)
          ..sort((a, b) => a.date.compareTo(b.date));
        final allAppointments = appointments.present.values.toList(growable: false);

        final completed = todaysAppointments.where((a) => a.isDone).length;
        final pending = todaysAppointments.length - completed;
        final newPatients = todaysAppointments
            .where((a) => a.firstAppointmentForThisPatient)
            .length;
        final returningPatients = math.max(0, todaysAppointments.length - newPatients);
        final revenueToday = todaysAppointments.fold<double>(
            0, (sum, a) => sum + a.paid + a.prescriptionPaid);

        final treatmentRevenue =
            todaysAppointments.fold<double>(0, (sum, a) => sum + a.paid);
        final prescriptionRevenue = todaysAppointments.fold<double>(
            0, (sum, a) => sum + a.prescriptionPaid);
        final outstandingBalance = dashboardCtrl.totalDueAmount();
        final doctorScopedAppointments = _doctorFiltered(todaysAppointments);
        final treatmentStats = _TreatmentStats.from(doctorScopedAppointments);
        final treatmentScopedAppointments =
          _treatmentFiltered(doctorScopedAppointments);
        final tableAppointments = _filteredAndSorted(treatmentScopedAppointments);
        final duplicatePatientKeys =
          _duplicatePatientKeys(treatmentScopedAppointments);
        final isDoctorFilterApplied =
          _selectedDoctorFilter != _DashboardScreenV2State._filterAll ||
            _selectedTreatmentFilter !=
              _DashboardScreenV2State._treatmentFilterAll;
        final doctorFilterChip = _doctorFilterChipLabel();
        final treatmentFilterChip = _treatmentFilterChipLabel();

        final doctorRevenueSplit = <String, double>{};
        final paymentModeCounts = <String, int>{'Cash': 0, 'GPay': 0};

        for (final a in todaysAppointments) {
            final totalPayment = a.paid + a.prescriptionPaid;
            final doctorIds =
              a.operatorsIDs.isEmpty ? const ['__unassigned__'] : a.operatorsIDs;
          final perDoctor = totalPayment / doctorIds.length;
          for (final doctorId in doctorIds) {
            final label = doctorId == '__unassigned__'
                ? 'Unassigned'
                : (doctors.get(doctorId)?.title ?? 'Unknown');
            doctorRevenueSplit[label] =
                (doctorRevenueSplit[label] ?? 0) + perDoctor;
          }

          final isDigital = a.treatmentGpayPaid || a.prescriptionGpayPaid;
          if (isDigital) {
            paymentModeCounts['GPay'] = (paymentModeCounts['GPay'] ?? 0) + 1;
          } else {
            paymentModeCounts['Cash'] = (paymentModeCounts['Cash'] ?? 0) + 1;
          }
        }

        final firstVisitByPatient = <String, DateTime>{};
        for (final a in allAppointments) {
          final pid = a.patientID;
          if (pid == null || pid.isEmpty) continue;
          final visitDate = _dateOnly(a.date);
          final existing = firstVisitByPatient[pid];
          if (existing == null || visitDate.isBefore(existing)) {
            firstVisitByPatient[pid] = visitDate;
          }
        }

        final dailyRevenueRows = _dailyRevenueRows(allAppointments, selectedDate, 30);
        final appointmentTrendRows = _appointmentTrendRows(allAppointments, selectedDate, 30);
        final dailyTreatmentDistribution = _treatmentDistributionRows(todaysAppointments);

        return Container(
          color: const Color(0xFFF3F7FC),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _OverviewHeader(
                  selectedDate: selectedDate,
                  onPrevious: () => _changeDate(-1),
                  onNext: () => _changeDate(1),
                  onPick: () => _pickDate(context),
                  onToday: _goToday,
                ),
                const SizedBox(height: 10),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final width = constraints.maxWidth;
                    final cards = [
                      _StatCard(
                        title: 'Appointments Today',
                        value: '${todaysAppointments.length}',
                        icon: FluentIcons.calendar,
                        iconColor: const Color(0xFF2D7BD8),
                        iconBackground: const Color(0xFFDDEBFF),
                      ),
                      _StatusSummaryCard(completed: completed, pending: pending),
                      _NewReturningPatientsCard(
                        newPatients: newPatients,
                        returningPatients: returningPatients,
                        onTap: () => _openNewPatientsDialog(todaysAppointments),
                      ),
                      _RevenueCard(
                        title: 'Revenue Today',
                        value: _money(revenueToday),
                      ),
                      _TopDonutMetricCard(
                        title: 'Payment Mode',
                        centerValue:
                            '${paymentModeCounts.values.fold<int>(0, (s, v) => s + v)}',
                        segments: [
                          _TopDonutSegment(
                            label: 'Cash',
                            value: paymentModeCounts['Cash'] ?? 0,
                            color: const Color(0xFF7D8FA7),
                          ),
                          _TopDonutSegment(
                            label: 'GPay',
                            value: paymentModeCounts['GPay'] ?? 0,
                            color: const Color(0xFF2D7BD8),
                          ),
                        ],
                      ),
                      _TopDailyTreatmentCard(
                        rows: dailyTreatmentDistribution,
                      ),
                      _TopTimingSummaryCard(
                        appointmentsForView: todaysAppointments,
                      ),
                    ];

                    int columns;
                    if (width >= 2100) {
                      columns = 7;
                    } else if (width >= 1720) {
                      columns = 6;
                    } else if (width >= 1420) {
                      columns = 5;
                    } else if (width >= 1140) {
                      columns = 4;
                    } else if (width >= 860) {
                      columns = 3;
                    } else if (width >= 580) {
                      columns = 2;
                    } else {
                      columns = 1;
                    }

                    final gap = 10.0;
                    final cardWidth =
                        (width - (columns - 1) * gap) / columns;

                    return Wrap(
                      spacing: gap,
                      runSpacing: gap,
                      children: cards
                          .map(
                            (card) => SizedBox(
                              width: cardWidth,
                              child: card,
                            ),
                          )
                          .toList(growable: false),
                    );
                  },
                ),
                const SizedBox(height: 16),
                const _SectionTitle('Trends & Mix'),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    SizedBox(
                      width: 420,
                      child: _DailyRevenueChartCard(rows: dailyRevenueRows),
                    ),
                    SizedBox(
                      width: 420,
                      child: _AppointmentTrendChartCard(rows: appointmentTrendRows),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const _SectionTitle('Financial Summary'),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: _FinanceCard(
                        title: 'Treatment Revenue',
                        value: _money(treatmentRevenue),
                        icon: FluentIcons.money,
                        iconColor: const Color(0xFF16A4AF),
                        iconBackground: const Color(0xFFD6F2F4),
                        valueColor: const Color(0xFF1468CC),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _FinanceCard(
                        title: 'Prescription Revenue',
                        value: _money(prescriptionRevenue),
                        icon: FluentIcons.precipitation,
                        iconColor: const Color(0xFF16A084),
                        iconBackground: const Color(0xFFD3F4EA),
                        valueColor: const Color(0xFF1468CC),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _FinanceCard(
                        title: 'Outstanding Balance',
                        value: _money(outstandingBalance),
                        icon: FluentIcons.status_error_full,
                        iconColor: const Color(0xFFD6455D),
                        iconBackground: const Color(0xFFF8D5DB),
                        valueColor: const Color(0xFF213B5F),
                        onTap: _openOutstandingDialog,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final useColumn = constraints.maxWidth < 1080;
                    if (useColumn) {
                      return Column(
                        children: [
                          _QuickCheckInCard(selectedDate: selectedDate),
                          const SizedBox(height: 10),
                          _DoctorScheduleCard(
                            todaysAppointments: todaysAppointments,
                            doctorRevenueSplit: doctorRevenueSplit,
                            selectedFilter: _selectedDoctorFilter,
                            onFilterChanged: (v) => setState(() {
                              _selectedDoctorFilter = _selectedDoctorFilter == v
                                  ? _DashboardScreenV2State._filterAll
                                  : v;
                            }),
                          ),
                          const SizedBox(height: 10),
                          _TreatmentStatsCard(
                            stats: treatmentStats,
                            selectedTreatment: _selectedTreatmentFilter,
                            showAll: _showAllTreatmentStats,
                            onFilterChanged: (v) => setState(() {
                              _selectedTreatmentFilter =
                                  _selectedTreatmentFilter == v
                                      ? _DashboardScreenV2State
                                          ._treatmentFilterAll
                                      : v;
                            }),
                            onToggleShowAll: () => setState(
                              () => _showAllTreatmentStats = !_showAllTreatmentStats,
                            ),
                          ),
                          const SizedBox(height: 10),
                          _RightDashboardColumn(
                            tableAppointments: tableAppointments,
                            duplicatePatientKeys: duplicatePatientKeys,
                            isFilterApplied: isDoctorFilterApplied,
                            doctorFilterChip: doctorFilterChip,
                            treatmentFilterChip: treatmentFilterChip,
                            searchController: _searchController,
                            sortBy: _sortBy,
                            sortAscending: _sortAscending,
                            onSort: _onSort,
                            onClearDoctorFilter: () => setState(() {
                              _selectedDoctorFilter =
                                  _DashboardScreenV2State._filterAll;
                            }),
                            onClearTreatmentFilter: () => setState(() {
                              _selectedTreatmentFilter =
                                  _DashboardScreenV2State._treatmentFilterAll;
                            }),
                            onClearFilters: () => setState(() {
                              _selectedDoctorFilter =
                                  _DashboardScreenV2State._filterAll;
                              _selectedTreatmentFilter =
                                  _DashboardScreenV2State._treatmentFilterAll;
                            }),
                          ),
                        ],
                      );
                    }
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          width: 320,
                          child: Column(
                            children: [
                              _QuickCheckInCard(selectedDate: selectedDate),
                              const SizedBox(height: 10),
                              _DoctorScheduleCard(
                                todaysAppointments: todaysAppointments,
                                doctorRevenueSplit: doctorRevenueSplit,
                                selectedFilter: _selectedDoctorFilter,
                                onFilterChanged: (v) => setState(() {
                                  _selectedDoctorFilter =
                                      _selectedDoctorFilter == v
                                          ? _DashboardScreenV2State._filterAll
                                          : v;
                                }),
                              ),
                              const SizedBox(height: 10),
                              _TreatmentStatsCard(
                                stats: treatmentStats,
                                selectedTreatment: _selectedTreatmentFilter,
                                showAll: _showAllTreatmentStats,
                                onFilterChanged: (v) => setState(() {
                                  _selectedTreatmentFilter =
                                      _selectedTreatmentFilter == v
                                          ? _DashboardScreenV2State
                                              ._treatmentFilterAll
                                          : v;
                                }),
                                onToggleShowAll: () => setState(
                                  () =>
                                      _showAllTreatmentStats = !_showAllTreatmentStats,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _RightDashboardColumn(
                            tableAppointments: tableAppointments,
                            duplicatePatientKeys: duplicatePatientKeys,
                            isFilterApplied: isDoctorFilterApplied,
                            doctorFilterChip: doctorFilterChip,
                            treatmentFilterChip: treatmentFilterChip,
                            searchController: _searchController,
                            sortBy: _sortBy,
                            sortAscending: _sortAscending,
                            onSort: _onSort,
                            onClearDoctorFilter: () => setState(() {
                              _selectedDoctorFilter =
                                  _DashboardScreenV2State._filterAll;
                            }),
                            onClearTreatmentFilter: () => setState(() {
                              _selectedTreatmentFilter =
                                  _DashboardScreenV2State._treatmentFilterAll;
                            }),
                            onClearFilters: () => setState(() {
                              _selectedDoctorFilter =
                                  _DashboardScreenV2State._filterAll;
                              _selectedTreatmentFilter =
                                  _DashboardScreenV2State._treatmentFilterAll;
                            }),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  static String _money(double value) {
    final formatter = NumberFormat('#,##0.##');
    return '₹${formatter.format(value)}';
  }
}

class _RevenueSplitCard extends StatelessWidget {
  final String title;
  final Map<String, double> split;
  final Color accent;
  final Map<String, int>? secondaryCounts;
  final String? secondaryBadgeLabel;
  final bool compact;

  const _RevenueSplitCard({
    required this.title,
    required this.split,
    required this.accent,
    this.secondaryCounts,
    this.secondaryBadgeLabel,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final sorted = split.entries.toList(growable: false)
      ..sort((a, b) => b.value.compareTo(a.value));
    final rows = sorted.take(compact ? 4 : 5).toList(growable: false);
    final total = sorted.fold<double>(0, (sum, e) => sum + e.value);

    return _CardShell(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: compact ? 16 : 18,
              fontWeight: FontWeight.w700,
              color: Color(0xFF183A67),
            ),
          ),
          SizedBox(height: compact ? 8 : 10),
          if (rows.isEmpty)
            const Text(
              'No revenue data for this date.',
              style: TextStyle(color: Color(0xFF607B9F)),
            )
          else
            ...rows.map((entry) {
              final pct = total == 0 ? 0 : (entry.value / total) * 100;
              return Padding(
                padding: EdgeInsets.only(bottom: compact ? 6 : 8),
                child: Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: accent,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        entry.key,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFF36557C),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    if (secondaryCounts != null)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE5F1FF),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(color: const Color(0xFFBFDAFA)),
                        ),
                        child: Text(
                          '${secondaryCounts![entry.key] ?? 0} ${secondaryBadgeLabel ?? ''}'
                              .trim(),
                          style: TextStyle(
                            color: Color(0xFF1459AD),
                            fontSize: compact ? 10 : 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    const SizedBox(width: 6),
                    Text(
                      '₹${entry.value.toStringAsFixed(0)} (${pct.toStringAsFixed(0)}%)',
                      style: TextStyle(
                        color: Color(0xFF1F446E),
                        fontWeight: FontWeight.w700,
                        fontSize: compact ? 12 : 13,
                      ),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }
}

class _PatientGrowthMetricsCard extends StatelessWidget {
  final int newPatientsToday;
  final int newPatientsWeek;
  final int newPatientsPrevWeek;
  final double growthPct;

  const _PatientGrowthMetricsCard({
    required this.newPatientsToday,
    required this.newPatientsWeek,
    required this.newPatientsPrevWeek,
    required this.growthPct,
  });

  @override
  Widget build(BuildContext context) {
    return _CardShell(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Patient Growth Metrics',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Color(0xFF183A67),
            ),
          ),
          const SizedBox(height: 10),
          _InsightLine(label: 'New patients today', value: '$newPatientsToday'),
          _InsightLine(label: 'New patients this week', value: '$newPatientsWeek'),
          _InsightLine(label: 'New patients prev week', value: '$newPatientsPrevWeek'),
          _InsightLine(
            label: 'Week-over-week growth',
            value: '${growthPct.toStringAsFixed(1)}%',
          ),
        ],
      ),
    );
  }
}

class _RightDashboardColumn extends StatelessWidget {
  final List<Appointment> tableAppointments;
  final Set<String> duplicatePatientKeys;
  final bool isFilterApplied;
  final String? doctorFilterChip;
  final String? treatmentFilterChip;
  final TextEditingController searchController;
  final String sortBy;
  final bool sortAscending;
  final ValueChanged<String> onSort;
  final VoidCallback onClearDoctorFilter;
  final VoidCallback onClearTreatmentFilter;
  final VoidCallback onClearFilters;

  const _RightDashboardColumn({
    required this.tableAppointments,
    required this.duplicatePatientKeys,
    required this.isFilterApplied,
    required this.doctorFilterChip,
    required this.treatmentFilterChip,
    required this.searchController,
    required this.sortBy,
    required this.sortAscending,
    required this.onSort,
    required this.onClearDoctorFilter,
    required this.onClearTreatmentFilter,
    required this.onClearFilters,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _AppointmentsTableCard(
          tableAppointments: tableAppointments,
          duplicatePatientKeys: duplicatePatientKeys,
          isFilterApplied: isFilterApplied,
          doctorFilterChip: doctorFilterChip,
          treatmentFilterChip: treatmentFilterChip,
          searchController: searchController,
          sortBy: sortBy,
          sortAscending: sortAscending,
          onSort: onSort,
          onClearDoctorFilter: onClearDoctorFilter,
          onClearTreatmentFilter: onClearTreatmentFilter,
          onClearFilters: onClearFilters,
        ),
      ],
    );
  }
}

class _DoctorScheduleCard extends StatelessWidget {
  final List<Appointment> todaysAppointments;
  final Map<String, double> doctorRevenueSplit;
  final String selectedFilter;
  final ValueChanged<String> onFilterChanged;

  const _DoctorScheduleCard({
    required this.todaysAppointments,
    required this.doctorRevenueSplit,
    required this.selectedFilter,
    required this.onFilterChanged,
  });

  @override
  Widget build(BuildContext context) {
    final doctorRows = <_DoctorScheduleRow>[];

    final counts = <String, int>{};
    for (final a in todaysAppointments) {
      for (final id in a.operatorsIDs) {
        counts[id] = (counts[id] ?? 0) + 1;
      }
    }

    for (final entry in counts.entries) {
      final doctor = doctors.get(entry.key);
      if (doctor == null) continue;
      doctorRows.add(
        _DoctorScheduleRow(
          id: doctor.id,
          title: doctor.title,
          count: entry.value,
          revenue: doctorRevenueSplit[doctor.title] ?? 0,
        ),
      );
    }

    final totalDoctorRevenue = doctorRows.fold<double>(
      0,
      (sum, row) => sum + row.revenue,
    );
    final unassignedRevenue = doctorRevenueSplit['Unassigned'] ?? 0;

    doctorRows.sort((a, b) => b.count.compareTo(a.count));

    final unassigned =
        todaysAppointments.where((a) => a.operatorsIDs.isEmpty).length;

    return _CardShell(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Doctors Insights',
            style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: Color(0xFF183A67)),
          ),
          if (doctorRows.isEmpty) ...[
            const SizedBox(height: 6),
            const Text(
              'No doctors assigned for this day',
              style: TextStyle(color: Color(0xFF637EA3)),
            ),
          ],
          const SizedBox(height: 8),
          _ScheduleLine(
            title: 'All',
            count: todaysAppointments.length,
            secondaryMoney: '₹${totalDoctorRevenue.toStringAsFixed(0)}',
            secondaryPct: '100%',
            selected: selectedFilter == _DashboardScreenV2State._filterAll,
            onTap: () => onFilterChanged(_DashboardScreenV2State._filterAll),
          ),
          _ScheduleLine(
            title: 'Unassigned',
            count: unassigned,
            secondaryMoney: '₹${unassignedRevenue.toStringAsFixed(0)}',
            secondaryPct: totalDoctorRevenue <= 0
              ? '0%'
              : '${(unassignedRevenue / totalDoctorRevenue * 100).toStringAsFixed(0)}%',
            selected:
                selectedFilter == _DashboardScreenV2State._filterUnassigned,
            onTap: () =>
                onFilterChanged(_DashboardScreenV2State._filterUnassigned),
          ),
          const SizedBox(height: 6),
          ...doctorRows.take(6).map(
                (row) => _ScheduleLine(
                  title: row.title,
                  count: row.count,
                  secondaryMoney: '₹${row.revenue.toStringAsFixed(0)}',
                  secondaryPct: totalDoctorRevenue <= 0
                      ? '0%'
                      : '${(row.revenue / totalDoctorRevenue * 100).toStringAsFixed(0)}%',
                  selected: selectedFilter == row.id,
                  onTap: () => onFilterChanged(row.id),
                ),
              ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: () => openAppointment(Appointment.fromJson({})),
            style: ButtonStyle(
              backgroundColor: WidgetStateProperty.all(const Color(0xFF2D7BD8)),
              shape: WidgetStateProperty.all(
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(FluentIcons.add, size: 14, color: Colors.white),
                SizedBox(width: 8),
                Text(
                  'Add Appointment',
                  style: TextStyle(
                      color: Colors.white, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DoctorScheduleRow {
  final String id;
  final String title;
  final int count;
  final double revenue;

  _DoctorScheduleRow(
      {required this.id,
      required this.title,
      required this.count,
      required this.revenue});
}

class _AppointmentTimingSummaryCard extends StatelessWidget {
  final List<Appointment> appointmentsForView;

  const _AppointmentTimingSummaryCard({required this.appointmentsForView});

  @override
  Widget build(BuildContext context) {
    final morning = _countRange(appointmentsForView, 6, 11);
    final afternoon = _countRange(appointmentsForView, 12, 16);
    final evening = _countRange(appointmentsForView, 17, 21);
    final other = appointmentsForView.length - morning - afternoon - evening;

    return _CardShell(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Appointment Timing Summary',
            style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: Color(0xFF183A67)),
          ),
          const SizedBox(height: 10),
          _TimingLine(label: 'Morning (6 AM - 11:59 AM)', count: morning),
          _TimingLine(label: 'Afternoon (12 PM - 4:59 PM)', count: afternoon),
          _TimingLine(label: 'Evening (5 PM - 9:59 PM)', count: evening),
          if (other > 0) _TimingLine(label: 'Other Hours', count: other),
          const SizedBox(height: 8),
          Text(
            'Total visible appointments: ${appointmentsForView.length}',
            style: const TextStyle(
              color: Color(0xFF2A4A73),
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  int _countRange(List<Appointment> list, int startHour, int endHour) {
    return list
        .where((a) => a.date.hour >= startHour && a.date.hour <= endHour)
        .length;
  }
}

class _TimingLine extends StatelessWidget {
  final String label;
  final int count;

  const _TimingLine({required this.label, required this.count});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(6),
        color: const Color(0xFFF6F9FE),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                color: Color(0xFF27456D),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Text(
            '$count',
            style: const TextStyle(
              color: Color(0xFF1A3D69),
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _AppointmentsTableCard extends StatelessWidget {
  final List<Appointment> tableAppointments;
  final Set<String> duplicatePatientKeys;
  final bool isFilterApplied;
  final String? doctorFilterChip;
  final String? treatmentFilterChip;
  final TextEditingController searchController;
  final String sortBy;
  final bool sortAscending;
  final ValueChanged<String> onSort;
  final VoidCallback onClearDoctorFilter;
  final VoidCallback onClearTreatmentFilter;
  final VoidCallback onClearFilters;

  const _AppointmentsTableCard({
    required this.tableAppointments,
    required this.duplicatePatientKeys,
    required this.isFilterApplied,
    required this.doctorFilterChip,
    required this.treatmentFilterChip,
    required this.searchController,
    required this.sortBy,
    required this.sortAscending,
    required this.onSort,
    required this.onClearDoctorFilter,
    required this.onClearTreatmentFilter,
    required this.onClearFilters,
  });

  @override
  Widget build(BuildContext context) {
    final rows = tableAppointments.take(100).toList(growable: false);
    final duplicateCount = duplicatePatientKeys.length;
    final duplicateText = duplicateCount == 1
        ? '1 patient has duplicate appointment in this list'
        : '$duplicateCount patients have duplicate appointments in this list';

    return _CardShell(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Today\'s Appointments',
                    style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF183A67)),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    duplicateText,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF637EA3),
                    ),
                  ),
                  if (doctorFilterChip != null || treatmentFilterChip != null) ...[
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        if (doctorFilterChip != null)
                          _FilterChipTag(
                            label: doctorFilterChip!,
                            onRemove: onClearDoctorFilter,
                          ),
                        if (treatmentFilterChip != null)
                          _FilterChipTag(
                            label: treatmentFilterChip!,
                            onRemove: onClearTreatmentFilter,
                          ),
                        Text(
                          '${rows.length} results',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF5A7397),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        GestureDetector(
                          onTap: onClearFilters,
                          child: const Text(
                            'Clear all',
                            style: TextStyle(
                              color: Color(0xFF2D7BD8),
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
              Row(
                children: [
                  SizedBox(
                    width: 280,
                    child: TextBox(
                      placeholder: 'Search patient name or phone',
                      controller: searchController,
                      prefix: const Padding(
                        padding: EdgeInsets.only(left: 8),
                        child: Icon(
                          FluentIcons.search,
                          size: 12,
                          color: Color(0xFF6D84A8),
                        ),
                      ),
                      suffix: searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(FluentIcons.clear),
                              onPressed: () => searchController.clear(),
                            )
                          : null,
                      placeholderStyle:
                          const TextStyle(color: Color(0xFF6D84A8)),
                    ),
                  ),
                  const SizedBox(width: 10),
                  FilledButton(
                    onPressed: () => openAppointment(Appointment.fromJson({})),
                    style: ButtonStyle(
                      backgroundColor:
                          WidgetStateProperty.all(const Color(0xFF1A74DB)),
                      shape: WidgetStateProperty.all(
                        RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                    child: const Row(
                      children: [
                        Icon(FluentIcons.add, size: 13, color: Colors.white),
                        SizedBox(width: 6),
                        Text(
                          'Add Appointment',
                          style: TextStyle(color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            decoration: BoxDecoration(
              border: Border.all(color: const Color(0xFFD6E2F0)),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              children: [
                _TableHeader(
                  sortBy: sortBy,
                  sortAscending: sortAscending,
                  isFilterApplied: isFilterApplied,
                  onSort: onSort,
                ),
                if (rows.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    'No appointments today',
                    style: TextStyle(color: Color(0xFF557195)),
                  ),
                )
                else ...[
                  ...rows.map(
                    (a) => _AppointmentRow(
                      appointment: a,
                      isDuplicatePatient: duplicatePatientKeys.contains(
                        _duplicatePatientKey(a),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TableHeader extends StatelessWidget {
  final String sortBy;
  final bool sortAscending;
  final bool isFilterApplied;
  final ValueChanged<String> onSort;

  const _TableHeader({
    required this.sortBy,
    required this.sortAscending,
    required this.isFilterApplied,
    required this.onSort,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color:
            isFilterApplied ? const Color(0xFF1A74DB) : const Color(0xFFEFF4FB),
        borderRadius: BorderRadius.vertical(top: Radius.circular(10)),
      ),
      child: Row(
        children: [
          Expanded(
              flex: 11,
              child: _SortableHeader(
                  label: 'Time',
                  keyName: 'time',
                  current: sortBy,
                  ascending: sortAscending,
                  onSort: onSort,
                  onDark: isFilterApplied)),
          Expanded(
              flex: 15,
              child: _SortableHeader(
                  label: 'Patient',
                  keyName: 'patient',
                  current: sortBy,
                  ascending: sortAscending,
                  onSort: onSort,
                  onDark: isFilterApplied)),
          Expanded(
              flex: 13,
              child: _SortableHeader(
                  label: 'Doctor',
                  keyName: 'doctor',
                  current: sortBy,
                  ascending: sortAscending,
                  onSort: onSort,
                  onDark: isFilterApplied)),
          Expanded(
              flex: 14,
              child: _SortableHeader(
                  label: 'Treatment',
                  keyName: 'treatment',
                  current: sortBy,
                  ascending: sortAscending,
                  onSort: onSort,
                  onDark: isFilterApplied)),
          Expanded(
              flex: 12,
              child: _SortableHeader(
                  label: 'Status',
                  keyName: 'status',
                  current: sortBy,
                  ascending: sortAscending,
                  onSort: onSort,
                  onDark: isFilterApplied)),
          Expanded(
              flex: 12,
              child: _SortableHeader(
                  label: 'P.Mode',
                  keyName: 'paymentMode',
                  current: sortBy,
                  ascending: sortAscending,
                  onSort: onSort,
                  onDark: isFilterApplied)),
          Expanded(
              flex: 12,
              child: _SortableHeader(
                  label: 'Payment',
                  keyName: 'payment',
                  current: sortBy,
                  ascending: sortAscending,
                  onSort: onSort,
                  onDark: isFilterApplied)),
          Expanded(
              flex: 10,
              child: _SortableHeader(
                  label: 'Actions',
                  keyName: 'actions',
                  current: sortBy,
                  ascending: sortAscending,
                  onSort: onSort,
                  onDark: isFilterApplied)),
        ],
      ),
    );
  }
}

class _SortableHeader extends StatelessWidget {
  final String label;
  final String keyName;
  final String current;
  final bool ascending;
  final ValueChanged<String> onSort;
  final bool onDark;

  const _SortableHeader({
    required this.label,
    required this.keyName,
    required this.current,
    required this.ascending,
    required this.onSort,
    this.onDark = false,
  });

  @override
  Widget build(BuildContext context) {
    final active = current == keyName;
    return GestureDetector(
      onTap: () => onSort(keyName),
      child: Row(
        children: [
          Text(label,
              style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: onDark ? Colors.white : const Color(0xFF2C4468))),
          const SizedBox(width: 4),
          Icon(
            active
                ? (ascending
                    ? FluentIcons.chevron_up
                    : FluentIcons.chevron_down)
                : FluentIcons.switch_user,
            size: 10,
            color: onDark ? Colors.white : const Color(0xFF6D84A8),
          ),
        ],
      ),
    );
  }
}

class _AppointmentRow extends StatelessWidget {
  final Appointment appointment;
  final bool isDuplicatePatient;

  const _AppointmentRow({
    required this.appointment,
    required this.isDuplicatePatient,
  });

  void _openPatientHistoryDialog(BuildContext context) {
    final patient = appointment.patient;
    if (patient == null) return;
    showPatientHistoryDialogV2(
      context: context,
      patient: patient,
      rows: patient.patientDetails,
    );
  }

  void _deleteAppointment(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => ContentDialog(
        title: const Text('Delete Appointment'),
        content: Text(
          'Delete appointment for ${appointment.title.trim().isEmpty ? 'this patient' : appointment.title}?',
        ),
        actions: [
          Button(
            child: const Text('Cancel'),
            onPressed: () => Navigator.pop(context),
          ),
          FilledButton(
            child: const Text('Delete'),
            onPressed: () {
              appointments.delete(appointment.id);
              Navigator.pop(context);
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final doctorName = appointment.operators.isEmpty
        ? 'Unassigned'
        : appointment.operators.map((d) => d.title).join(', ');
    final treatment = appointment.selectedTreatments.isEmpty
        ? '-'
        : appointment.selectedTreatments.join(', ');
    final time = DateFormat('h:mm a').format(appointment.date);
    final payment = appointment.paid + appointment.prescriptionPaid;
    final isDigital =
        appointment.treatmentGpayPaid || appointment.prescriptionGpayPaid;
    final patientPhone = appointment.patient?.phone ?? '-';
    final patientAge = appointment.patient?.age ?? 0;
    final previousVisit = _previousVisitForPatient(appointment);
    final previousVisitText = previousVisit == null
      ? 'Prev: -'
      : 'Prev: ${DateFormat('dd MMM yyyy').format(previousVisit)}';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color:
            isDuplicatePatient ? const Color(0xFFFFF1F1) : Colors.transparent,
        border: const Border(top: BorderSide(color: Color(0xFFE2ECF8))),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 11,
            child: Text(time, style: const TextStyle(color: Color(0xFF355279))),
          ),
          Expanded(
            flex: 15,
            child: GestureDetector(
              onTap: () => openAppointment(appointment),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    appointment.title,
                    style: const TextStyle(
                      color: Color(0xFF1459AD),
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    '$patientPhone • ${patientAge}y',
                    style: const TextStyle(
                      color: Color(0xFF7C93B1),
                      fontSize: 11,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    previousVisitText,
                    style: const TextStyle(
                      color: Color(0xFF7C93B1),
                      fontSize: 11,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            flex: 13,
            child: Text(doctorName,
                style: const TextStyle(color: Color(0xFF2D476D))),
          ),
          Expanded(
            flex: 14,
            child: Text(
              treatment,
              style: const TextStyle(color: Color(0xFF2D476D)),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Expanded(
            flex: 12,
            child: _StatusBadge(done: appointment.isDone),
          ),
          Expanded(
            flex: 12,
            child: Row(
              children: [
                isDigital
                    ? Image.asset(
                        'assets/gpay.jpg',
                        width: 14,
                        height: 14,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const Icon(
                          FluentIcons.receipt_processing,
                          size: 14,
                          color: Color(0xFF2D7BD8),
                        ),
                      )
                    : const Icon(
                        FluentIcons.money,
                        size: 14,
                        color: Color(0xFF3B9A42),
                      ),
                const SizedBox(width: 4),
                Text(
                  isDigital ? 'GPay' : 'Cash',
                  style: const TextStyle(
                    color: Color(0xFF2D476D),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            flex: 12,
            child: Text(
              '₹${payment.toStringAsFixed(0)}',
              style: const TextStyle(
                color: Color(0xFF2D476D),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            flex: 10,
            child: Row(
              children: [
                _ActionIconButton(
                  tooltip: 'History',
                  icon: FluentIcons.history,
                  color: const Color(0xFF2D7BD8),
                  hoverColor: const Color(0xFFE7F1FF),
                  onTap: () => _openPatientHistoryDialog(context),
                ),
                const SizedBox(width: 10),
                _ActionIconButton(
                  tooltip: 'Delete',
                  icon: FluentIcons.delete,
                  color: const Color(0xFFD6455D),
                  hoverColor: const Color(0xFFFFECEF),
                  onTap: () => _deleteAppointment(context),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

DateTime? _previousVisitForPatient(Appointment current) {
  final patientId = current.patientID;
  if (patientId == null || patientId.isEmpty) return null;

  DateTime? previous;
  for (final row in appointments.present.values) {
    if (row.id == current.id) continue;
    if (row.patientID != patientId) continue;
    if (!row.date.isBefore(current.date)) continue;
    if (previous == null || row.date.isAfter(previous)) {
      previous = row.date;
    }
  }

  return previous;
}

class _ActionIconButton extends StatefulWidget {
  final String tooltip;
  final IconData icon;
  final Color color;
  final Color hoverColor;
  final VoidCallback onTap;

  const _ActionIconButton({
    required this.tooltip,
    required this.icon,
    required this.color,
    required this.hoverColor,
    required this.onTap,
  });

  @override
  State<_ActionIconButton> createState() => _ActionIconButtonState();
}

class _ActionIconButtonState extends State<_ActionIconButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: widget.tooltip,
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: _hovered ? widget.hoverColor : Colors.transparent,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(
              widget.icon,
              size: 13,
              color: widget.color,
            ),
          ),
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final bool done;

  const _StatusBadge({required this.done});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          done ? material.Icons.check_circle : material.Icons.circle,
          size: 12,
          color: done ? const Color(0xFF3B9A42) : const Color(0xFFE4A11B),
        ),
        const SizedBox(width: 4),
        Text(
          done ? 'Completed' : 'Pending',
          style: TextStyle(
            fontSize: 12,
            color: done ? const Color(0xFF3B9A42) : const Color(0xFFE4A11B),
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _ScheduleLine extends StatelessWidget {
  final String title;
  final int count;
  final String? secondaryMoney;
  final String? secondaryPct;
  final bool selected;
  final VoidCallback onTap;

  const _ScheduleLine({
    required this.title,
    required this.count,
    this.secondaryMoney,
    this.secondaryPct,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(top: 2),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(6),
          color: selected ? const Color(0xFFDDEBFF) : const Color(0xFFF6F9FE),
          border: Border.all(
            color: selected ? const Color(0xFF8CB6E8) : Colors.transparent,
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: selected
                      ? const Color(0xFF123D71)
                      : const Color(0xFF27456D),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (secondaryMoney != null) ...[
                  Text(
                    secondaryMoney!,
                    style: TextStyle(
                      color: selected
                          ? const Color(0xFF1459AD)
                          : const Color(0xFF2D7BD8),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
                if (secondaryPct != null) ...[
                  const SizedBox(width: 6),
                  Text(
                    secondaryPct!,
                    style: TextStyle(
                      color: selected
                          ? const Color(0xFF2BA58D)
                          : const Color(0xFF4A8B73),
                      fontWeight: FontWeight.w700,
                      fontSize: 11,
                    ),
                  ),
                ],
                const SizedBox(width: 6),
                Text(
                  '($count)',
                  style: TextStyle(
                    color: selected
                        ? const Color(0xFF1A4B88)
                        : const Color(0xFF637EA3),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _CardShell extends StatelessWidget {
  final Widget child;

  const _CardShell({required this.child});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
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
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: child,
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;

  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 28,
        fontWeight: FontWeight.w600,
        color: Color(0xFF112E54),
        letterSpacing: 0.1,
      ),
    );
  }
}

class _OverviewHeader extends StatelessWidget {
  final DateTime selectedDate;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final VoidCallback onPick;
  final VoidCallback onToday;

  const _OverviewHeader({
    required this.selectedDate,
    required this.onPrevious,
    required this.onNext,
    required this.onPick,
    required this.onToday,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Expanded(
          child: Align(
            alignment: Alignment.centerLeft,
            child: _SectionTitle('Today\'s Overview'),
          ),
        ),
        Expanded(
          child: Align(
            alignment: Alignment.center,
            child: _DateNavigator(
              selectedDate: selectedDate,
              onPrevious: onPrevious,
              onNext: onNext,
              onPick: onPick,
              onToday: onToday,
            ),
          ),
        ),
        const Expanded(child: SizedBox()),
      ],
    );
  }
}

class _DateNavigator extends StatelessWidget {
  final DateTime selectedDate;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final VoidCallback onPick;
  final VoidCallback onToday;

  const _DateNavigator({
    required this.selectedDate,
    required this.onPrevious,
    required this.onNext,
    required this.onPick,
    required this.onToday,
  });

  ButtonStyle get _dateButtonStyle {
    return ButtonStyle(
      padding: WidgetStateProperty.all(
        const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      ),
      backgroundColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.pressed)) {
          return const Color(0x331A74DB);
        }
        if (states.contains(WidgetState.hovered)) {
          return const Color(0x1F1A74DB);
        }
        return Colors.transparent;
      }),
      foregroundColor: WidgetStateProperty.all(const Color(0xFF1468CC)),
      shape: WidgetStateProperty.all(
        const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final isToday = selectedDate.year == today.year &&
        selectedDate.month == today.month &&
        selectedDate.day == today.day;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFD6E2F0)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Button(
                onPressed: onPrevious,
                style: _dateButtonStyle,
                child: const Icon(FluentIcons.chevron_left, size: 12),
              ),
              Button(
                onPressed: onPick,
                style: _dateButtonStyle,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      DateFormat('MMMM d, yyyy').format(selectedDate),
                      style: const TextStyle(
                        color: Color(0xFF25466E),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      DateFormat('EEEE').format(selectedDate),
                      style: const TextStyle(
                        color: Color(0xFF557195),
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              Button(
                onPressed: onNext,
                style: _dateButtonStyle,
                child: const Icon(FluentIcons.chevron_right, size: 12),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 84,
          child: Visibility(
            visible: !isToday,
            maintainAnimation: true,
            maintainState: true,
            maintainSize: true,
            child: FilledButton(
              onPressed: onToday,
              style: ButtonStyle(
                backgroundColor: WidgetStateProperty.resolveWith((states) {
                  if (states.contains(WidgetState.pressed)) {
                    return const Color(0xFF0B5BBC);
                  }
                  if (states.contains(WidgetState.hovered)) {
                    return const Color(0xFF1468CC);
                  }
                  return const Color(0xFF1A74DB);
                }),
                foregroundColor: WidgetStateProperty.all(Colors.white),
              ),
              child: const Text('Today'),
            ),
          ),
        ),
      ],
    );
  }
}

class _QuickCheckInCard extends StatelessWidget {
  final DateTime selectedDate;

  const _QuickCheckInCard({required this.selectedDate});

  DateTime _withCurrentTime(DateTime d) {
    final now = DateTime.now();
    return DateTime(d.year, d.month, d.day, now.hour, now.minute);
  }

  @override
  Widget build(BuildContext context) {
    return _CardShell(
      child: SizedBox(
        width: double.infinity,
        child: PatientLookup(
          patientCheckIn: (patient) {
            if (patient == null) return;
            final todays = appointments
                .forDate(selectedDate)
                .where((a) => a.patientID == patient.id)
                .toList(growable: false)
              ..sort((a, b) => a.date.compareTo(b.date));

            if (todays.isNotEmpty) {
              final appt = todays.first;
              appt.isCheckedIn = true;
              appt.checkedInAt = DateTime.now();
              appointments.set(appt);
              return;
            }

            final dt = _withCurrentTime(selectedDate);
            appointments.set(Appointment.fromJson({
              'patientID': patient.id,
              'date': dt.millisecondsSinceEpoch,
              'isCheckedIn': true,
              'checkedInAt': DateTime.now().millisecondsSinceEpoch,
            }));
          },
          addAppointment: (patient) {
            final dt = _withCurrentTime(selectedDate);
            openAppointment(Appointment.fromJson({
              'patientID': patient.id,
              'date': dt.millisecondsSinceEpoch,
            }));
          },
          onCreateNew: (searchQuery) {
            final isDigitsOnly = searchQuery.isNotEmpty &&
                searchQuery.runes.every((c) => c >= 48 && c <= 57);
            openPatient(
              Patient.fromJson({
                if (isDigitsOnly)
                  'phone': searchQuery
                else
                  'title': searchQuery,
              }),
              0,
            );
          },
        ),
      ),
    );
  }
}

String _duplicatePatientKey(Appointment appointment) {
  final patientId = appointment.patientID;
  if (patientId != null && patientId.isNotEmpty) {
    return 'id:$patientId';
  }
  final title = appointment.title.trim().toLowerCase();
  final phone = (appointment.patient?.phone ?? '').trim().toLowerCase();
  return 'name:$title|phone:$phone';
}

Set<String> _duplicatePatientKeys(List<Appointment> appointmentsForView) {
  final counts = <String, int>{};
  for (final appointment in appointmentsForView) {
    final key = _duplicatePatientKey(appointment);
    counts[key] = (counts[key] ?? 0) + 1;
  }
  return counts.entries
      .where((entry) => entry.value > 1)
      .map((entry) => entry.key)
      .toSet();
}

class _TreatmentStats {
  final List<MapEntry<String, int>> topTreatments;
  final int totalTreatments;

  _TreatmentStats({required this.topTreatments, required this.totalTreatments});

  factory _TreatmentStats.from(List<Appointment> appointmentsOnDay) {
    final counts = <String, int>{};
    for (final a in appointmentsOnDay) {
      for (final t in a.selectedTreatments) {
        final key = t.trim();
        if (key.isEmpty) continue;
        counts[key] = (counts[key] ?? 0) + 1;
      }
    }

    final sorted = counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final total = sorted.fold<int>(0, (sum, e) => sum + e.value);

    return _TreatmentStats(
      topTreatments: sorted.toList(),
      totalTreatments: total,
    );
  }
}

class _TreatmentStatsCard extends StatelessWidget {
  final _TreatmentStats stats;
  final String selectedTreatment;
  final bool showAll;
  final ValueChanged<String> onFilterChanged;
  final VoidCallback onToggleShowAll;

  const _TreatmentStatsCard({
    required this.stats,
    required this.selectedTreatment,
    required this.showAll,
    required this.onFilterChanged,
    required this.onToggleShowAll,
  });

  @override
  Widget build(BuildContext context) {
    final visibleTreatments = showAll
        ? stats.topTreatments
        : stats.topTreatments.take(5).toList(growable: false);

    return _CardShell(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Treatment Stats',
            style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: Color(0xFF183A67)),
          ),
          const SizedBox(height: 8),
          _ScheduleLine(
            title: 'Total',
            count: stats.totalTreatments,
            selected:
                selectedTreatment == _DashboardScreenV2State._treatmentFilterAll,
            onTap: () => onFilterChanged(
              _DashboardScreenV2State._treatmentFilterAll,
            ),
          ),
          if (stats.topTreatments.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 6),
              child: Text(
                'No treatments recorded for this day',
                style: TextStyle(color: Color(0xFF637EA3)),
              ),
            )
          else
            ...visibleTreatments.map(
              (entry) => _ScheduleLine(
                title: entry.key,
                count: entry.value,
                selected:
                    selectedTreatment.toLowerCase() == entry.key.toLowerCase(),
                onTap: () => onFilterChanged(entry.key),
              ),
            ),
          if (stats.topTreatments.length > 5) ...[
            const SizedBox(height: 8),
            FilledButton(
              onPressed: onToggleShowAll,
              style: ButtonStyle(
                backgroundColor: WidgetStateProperty.all(const Color(0xFF2D7BD8)),
                shape: WidgetStateProperty.all(
                  RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
              child: Text(showAll ? 'Show Top 5' : 'Show More'),
            ),
          ],
        ],
      ),
    );
  }
}

class _InsightLine extends StatelessWidget {
  final String label;
  final String value;

  const _InsightLine({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                  color: Color(0xFF36557C), fontWeight: FontWeight.w600),
            ),
          ),
          Text(
            value,
            style: const TextStyle(
                color: Color(0xFF1A3D69), fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class _NewReturningPatientsCard extends StatelessWidget {
  final int newPatients;
  final int returningPatients;
  final VoidCallback? onTap;

  const _NewReturningPatientsCard({
    required this.newPatients,
    required this.returningPatients,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 220, maxWidth: 300),
        child: SizedBox(
          height: 140,
          child: _CardShell(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Patients Today',
                  style: TextStyle(fontSize: 13, color: Color(0xFF496489), fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Text(
                      '$newPatients',
                      style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w700, color: Color(0xFF2D7BD8)),
                    ),
                    const SizedBox(width: 6),
                    const Text(
                      'New',
                      style: TextStyle(fontSize: 12, color: Color(0xFF2D7BD8), fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(
                      '$returningPatients',
                      style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w700, color: Color(0xFF2BA58D)),
                    ),
                    const SizedBox(width: 6),
                    const Text(
                      'Returning',
                      style: TextStyle(fontSize: 12, color: Color(0xFF2BA58D), fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TopDailyTreatmentCard extends StatelessWidget {
  final List<MapEntry<String, int>> rows;

  const _TopDailyTreatmentCard({required this.rows});

  @override
  Widget build(BuildContext context) {
    final palette = [
      const Color(0xFF2D7BD8),
      const Color(0xFF2BA58D),
      const Color(0xFFE09C31),
      const Color(0xFF7D8FA7),
      const Color(0xFFD6455D),
      const Color(0xFF8D5CF6),
    ];
    final topRows = rows.take(10).toList(growable: false);
    final splitAt = (topRows.length / 2).ceil();
    final leftRows = topRows.take(splitAt).toList(growable: false);
    final rightRows = topRows.skip(splitAt).toList(growable: false);

    Widget buildColumn(List<MapEntry<String, int>> source, int paletteOffset) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: source.asMap().entries.map((entry) {
          final color = palette[(entry.key + paletteOffset) % palette.length];
          final row = entry.value;
          return Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(
              '${row.key} (${row.value})',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w700,
                fontSize: 11,
              ),
            ),
          );
        }).toList(growable: false),
      );
    }

    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 220, maxWidth: 320),
      child: SizedBox(
        height: 148,
        child: _CardShell(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Daily Treatment',
                style: TextStyle(
                  fontSize: 14,
                  color: Color(0xFF496489),
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              if (topRows.isEmpty)
                const Text(
                  'No treatments today',
                  style: TextStyle(color: Color(0xFF6D84A8), fontSize: 12),
                )
              else
                Expanded(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: buildColumn(leftRows, 0)),
                      const SizedBox(width: 8),
                      Expanded(child: buildColumn(rightRows, leftRows.length)),
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

class _TopCurrentMonthRevenueCard extends StatelessWidget {
  final String monthLabel;
  final double value;

  const _TopCurrentMonthRevenueCard({
    required this.monthLabel,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 220, maxWidth: 300),
      child: SizedBox(
        height: 140,
        child: _CardShell(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$monthLabel Daily Avg Revenue',
                style: const TextStyle(
                  fontSize: 13,
                  color: Color(0xFF496489),
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '₹${value.toStringAsFixed(0)}',
                style: const TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1468CC),
                ),
              ),
              const Spacer(),
              const Text(
                'Fixed to current month progression',
                style: TextStyle(
                  color: Color(0xFF6D84A8),
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TopCurrentMonthAppointmentsCard extends StatelessWidget {
  final String monthLabel;
  final double avgPerDay;
  final int total;

  const _TopCurrentMonthAppointmentsCard({
    required this.monthLabel,
    required this.avgPerDay,
    required this.total,
  });

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 220, maxWidth: 300),
      child: SizedBox(
        height: 140,
        child: _CardShell(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$monthLabel Appointment Trend',
                style: const TextStyle(
                  fontSize: 13,
                  color: Color(0xFF496489),
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '${avgPerDay.toStringAsFixed(1)}/day',
                style: const TextStyle(
                  fontSize: 33,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF2BA58D),
                ),
              ),
              const Spacer(),
              Text(
                '$total total appointments this month',
                style: const TextStyle(
                  color: Color(0xFF6D84A8),
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TopMonthRevenueCard extends StatelessWidget {
  final double thisMonthRevenue;
  final double lastMonthRevenue;
  final double twoMonthsAgoRevenue;
  final double threeMonthsAgoRevenue;
  final double changePct;
  final String thisMonthLabel;
  final String lastMonthLabel;
  final String twoMonthsAgoLabel;
  final String threeMonthsAgoLabel;

  const _TopMonthRevenueCard({
    required this.thisMonthRevenue,
    required this.lastMonthRevenue,
    required this.twoMonthsAgoRevenue,
    required this.threeMonthsAgoRevenue,
    required this.changePct,
    required this.thisMonthLabel,
    required this.lastMonthLabel,
    required this.twoMonthsAgoLabel,
    required this.threeMonthsAgoLabel,
  });

  @override
  Widget build(BuildContext context) {
    final up = changePct >= 0;
    final color = up ? const Color(0xFF2BA58D) : const Color(0xFFD6455D);
    final maxBar = math.max(
      1.0,
      math.max(
        math.max(thisMonthRevenue, lastMonthRevenue),
        math.max(twoMonthsAgoRevenue, threeMonthsAgoRevenue),
      ),
    );

    Widget barLine(String label, double value, Color barColor) {
      return Tooltip(
        message: '$label: ₹${value.toStringAsFixed(0)}',
        child: Row(
          children: [
            SizedBox(
              width: 64,
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 11,
                  color: Color(0xFF456284),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: Container(
                  height: 8,
                  color: const Color(0xFFEAF2FC),
                  child: FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: (value / maxBar).clamp(0.0, 1.0),
                    child: Container(color: barColor),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 6),
            SizedBox(
              width: 54,
              child: Text(
                formatIndianShortCurrency(value),
                textAlign: TextAlign.right,
                style: const TextStyle(
                  fontSize: 10,
                  color: Color(0xFF456284),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 220, maxWidth: 320),
      child: SizedBox(
        height: 140,
        child: _CardShell(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '$thisMonthLabel Revenue',
                      style: const TextStyle(fontSize: 13, color: Color(0xFF496489), fontWeight: FontWeight.w600),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    formatIndianShortCurrency(thisMonthRevenue),
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Color(0xFF1468CC)),
                  ),
                  const SizedBox(width: 6),
                  Icon(up ? material.Icons.trending_up : material.Icons.trending_down, size: 11, color: color),
                  const SizedBox(width: 4),
                  Text(
                    '${changePct.toStringAsFixed(1)}%',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              barLine(thisMonthLabel, thisMonthRevenue, const Color(0xFF2D7BD8)),
              const SizedBox(height: 4),
              barLine(lastMonthLabel, lastMonthRevenue, const Color(0xFF9BB9DD)),
              const SizedBox(height: 4),
              barLine(twoMonthsAgoLabel, twoMonthsAgoRevenue, const Color(0xFFC6D8EE)),
              const SizedBox(height: 4),
              barLine(threeMonthsAgoLabel, threeMonthsAgoRevenue, const Color(0xFFDCE8F6)),
            ],
          ),
        ),
      ),
    );
  }
}

class _TopMonthlyRevenueBarsCard extends StatelessWidget {
  final List<({String month, double value})> rows;

  const _TopMonthlyRevenueBarsCard({required this.rows});

  @override
  Widget build(BuildContext context) {
    final maxValue = rows.fold<double>(1, (m, e) => e.value > m ? e.value : m);
    final latest = rows.isEmpty ? 0.0 : rows.last.value;

    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 240, maxWidth: 360),
      child: SizedBox(
        height: 160,
        child: _CardShell(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Monthly Revenue Snapshot',
                      style: TextStyle(
                        fontSize: 13,
                        color: Color(0xFF496489),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Text(
                    formatIndianShortCurrency(latest),
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF1468CC),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    for (final item in rows)
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 1.5),
                          child: Tooltip(
                            message: '${item.month}: ${formatIndianShortCurrency(item.value)}',
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                Expanded(
                                  child: Align(
                                    alignment: Alignment.bottomCenter,
                                    child: FractionallySizedBox(
                                      heightFactor: (item.value / maxValue).clamp(0.0, 1.0),
                                      child: Container(
                                        decoration: BoxDecoration(
                                          borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                                          color: item.value == latest
                                              ? const Color(0xFF2D7BD8)
                                              : const Color(0xFFB8CCE6),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  item.month,
                                  style: const TextStyle(
                                    fontSize: 9,
                                    color: Color(0xFF6D84A8),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
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

class _DailyRevenueChartCard extends StatelessWidget {
  final List<({DateTime day, double value})> rows;

  const _DailyRevenueChartCard({required this.rows});

  @override
  Widget build(BuildContext context) {
    final peak = rows.fold<double>(1, (m, e) => e.value > m ? e.value : m);
    const tickCount = 7;
    final yTicks = List<double>.generate(
      tickCount,
      (index) => peak * ((tickCount - 1 - index) / (tickCount - 1)),
      growable: false,
    );
    final startLabel =
        rows.isEmpty ? '-' : DateFormat('dd MMM').format(rows.first.day);
    final endLabel =
        rows.isEmpty ? '-' : DateFormat('dd MMM').format(rows.last.day);

    return _CardShell(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Daily Revenue (Last 30 Days)',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Color(0xFF183A67),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 190,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  width: 48,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: yTicks
                        .map(
                          (tick) => Text(
                            formatIndianShortCurrency(tick),
                            style: const TextStyle(
                              fontSize: 9,
                              color: Color(0xFF5B789F),
                            ),
                          ),
                        )
                        .toList(growable: false),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Column(
                    children: [
                      Expanded(
                        child: Stack(
                          children: [
                            Column(
                              children: List.generate(
                                tickCount,
                                (index) => Expanded(
                                  child: Container(
                                    decoration: const BoxDecoration(
                                      border: Border(
                                        bottom: BorderSide(
                                          color: Color(0xFFE5EFFA),
                                          width: 1,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: rows.map((row) {
                                return Expanded(
                                  child: Padding(
                                    padding:
                                        const EdgeInsets.symmetric(horizontal: 1),
                                    child: Tooltip(
                                      message:
                                          'Revenue\n${DateFormat('dd MMM').format(row.day)}\n₹${row.value.toStringAsFixed(0)}',
                                      child: Container(
                                        height: 140 * (row.value / peak).clamp(0.0, 1.0),
                                        decoration: BoxDecoration(
                                          gradient: const LinearGradient(
                                            colors: [
                                              Color(0xFF66A8F0),
                                              Color(0xFF2D7BD8),
                                            ],
                                            begin: Alignment.topCenter,
                                            end: Alignment.bottomCenter,
                                          ),
                                          borderRadius: BorderRadius.circular(2),
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              }).toList(growable: false),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            startLabel,
                            style: const TextStyle(
                              fontSize: 10,
                              color: Color(0xFF5B789F),
                            ),
                          ),
                          const Text(
                            'Date',
                            style: TextStyle(
                              fontSize: 10,
                              color: Color(0xFF5B789F),
                            ),
                          ),
                          Text(
                            endLabel,
                            style: const TextStyle(
                              fontSize: 10,
                              color: Color(0xFF5B789F),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 2),
          const Text(
            'Last 30 days overview. Hover bars for exact values.',
            style: TextStyle(
              fontSize: 9,
              color: Color(0xFF8AA0BC),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _AppointmentTrendChartCard extends StatelessWidget {
  final List<({DateTime day, int count})> rows;

  const _AppointmentTrendChartCard({required this.rows});

  @override
  Widget build(BuildContext context) {
    final peak = rows.fold<int>(1, (m, e) => e.count > m ? e.count : m);
    const tickCount = 7;
    final yTicks = List<int>.generate(
      tickCount,
      (index) => ((peak * ((tickCount - 1 - index) / (tickCount - 1))).round()),
      growable: false,
    );
    final startLabel =
        rows.isEmpty ? '-' : DateFormat('dd MMM').format(rows.first.day);
    final endLabel =
        rows.isEmpty ? '-' : DateFormat('dd MMM').format(rows.last.day);

    return _CardShell(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Appointment Trend',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Color(0xFF183A67),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 190,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  width: 38,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: yTicks
                        .map(
                          (tick) => Text(
                            '$tick',
                            style: const TextStyle(
                              fontSize: 9,
                              color: Color(0xFF5B789F),
                            ),
                          ),
                        )
                        .toList(growable: false),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Column(
                    children: [
                      Expanded(
                        child: Stack(
                          children: [
                            Column(
                              children: List.generate(
                                tickCount,
                                (index) => Expanded(
                                  child: Container(
                                    decoration: const BoxDecoration(
                                      border: Border(
                                        bottom: BorderSide(
                                          color: Color(0xFFE5EFFA),
                                          width: 1,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: rows.map((row) {
                                return Expanded(
                                  child: Padding(
                                    padding:
                                        const EdgeInsets.symmetric(horizontal: 1),
                                    child: Tooltip(
                                      message:
                                          'Appointments\n${DateFormat('dd MMM').format(row.day)}\n${row.count}',
                                      child: Container(
                                        height: 140 * (row.count / peak).clamp(0.0, 1.0),
                                        decoration: BoxDecoration(
                                          gradient: const LinearGradient(
                                            colors: [
                                              Color(0xFF6ED1B3),
                                              Color(0xFF2BA58D),
                                            ],
                                            begin: Alignment.topCenter,
                                            end: Alignment.bottomCenter,
                                          ),
                                          borderRadius: BorderRadius.circular(2),
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              }).toList(growable: false),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            startLabel,
                            style: const TextStyle(
                              fontSize: 10,
                              color: Color(0xFF5B789F),
                            ),
                          ),
                          const Text(
                            'Date',
                            style: TextStyle(
                              fontSize: 10,
                              color: Color(0xFF5B789F),
                            ),
                          ),
                          Text(
                            endLabel,
                            style: const TextStyle(
                              fontSize: 10,
                              color: Color(0xFF5B789F),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 2),
          const Text(
            'Trend reflects appointment count by day (30-day window).',
            style: TextStyle(
              fontSize: 9,
              color: Color(0xFF8AA0BC),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _NewVsReturningPieCard extends StatelessWidget {
  final int newCount;
  final int returningCount;

  const _NewVsReturningPieCard({
    required this.newCount,
    required this.returningCount,
  });

  @override
  Widget build(BuildContext context) {
    return _TopDonutMetricCard(
      title: 'New vs Returning (Current Month)',
      centerValue: '${newCount + returningCount}',
      segments: [
        _TopDonutSegment(
          label: 'New',
          value: newCount,
          color: const Color(0xFF2D7BD8),
        ),
        _TopDonutSegment(
          label: 'Returning',
          value: returningCount,
          color: const Color(0xFF2BA58D),
        ),
      ],
    );
  }
}

class _MonthlyTreatmentDistributionCard extends StatelessWidget {
  final List<MapEntry<String, int>> rows;

  const _MonthlyTreatmentDistributionCard({required this.rows});

  @override
  Widget build(BuildContext context) {
    final segments = _topTreatmentSegments(rows);
    final total = rows.fold<int>(0, (s, e) => s + e.value);

    return SizedBox(
      height: 250,
      child: _CardShell(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Monthly Treatment Distribution',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Color(0xFF183A67),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: Row(
                children: [
                  SizedBox(
                    width: 140,
                    height: 140,
                    child: CustomPaint(
                      painter: _TopDonutPainter(segments: segments),
                      child: Center(
                        child: Text(
                          '$total',
                          style: const TextStyle(
                            color: Color(0xFF1D3E67),
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: segments.map((s) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: Row(
                              children: [
                                Container(
                                  width: 10,
                                  height: 10,
                                  decoration: BoxDecoration(
                                    color: s.color,
                                    borderRadius: BorderRadius.circular(2),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    '${s.label} (${s.value})',
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: Color(0xFF36557C),
                                      fontWeight: FontWeight.w600,
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
            const SizedBox(height: 2),
            const Text(
              'Distribution is based on current month treatment entries.',
              style: TextStyle(
                fontSize: 9,
                color: Color(0xFF8AA0BC),
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

List<_TopDonutSegment> _topTreatmentSegments(List<MapEntry<String, int>> rows) {
  final palette = [
    const Color(0xFF2D7BD8),
    const Color(0xFF2BA58D),
    const Color(0xFFE09C31),
    const Color(0xFF7D8FA7),
    const Color(0xFF8D5CF6),
    const Color(0xFFD6455D),
  ];

  return rows
      .asMap()
      .entries
      .map(
        (entry) => _TopDonutSegment(
          label: entry.value.key,
          value: entry.value.value,
          color: palette[entry.key % palette.length],
        ),
      )
      .toList(growable: false);
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color iconColor;
  final Color iconBackground;
  final VoidCallback? onTap;

  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.iconColor,
    required this.iconBackground,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 180, maxWidth: 260),
        child: SizedBox(
          height: 140,
          child: _CardShell(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title,
                          style: const TextStyle(
                              fontSize: 13,
                              color: Color(0xFF496489),
                              fontWeight: FontWeight.w600)),
                      const SizedBox(height: 8),
                      Text(value,
                          style: const TextStyle(
                              fontSize: 38,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF1B3557))),
                    ],
                  ),
                ),
                Container(
                  width: 38,
                  height: 38,
                  margin: const EdgeInsets.only(top: 2),
                  decoration: BoxDecoration(
                    color: iconBackground,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: iconColor, size: 18),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RevenueCard extends StatelessWidget {
  final String title;
  final String value;

  const _RevenueCard({required this.title, required this.value});

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 200, maxWidth: 280),
      child: SizedBox(
        height: 140,
        child: _CardShell(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 13,
                  color: Color(0xFF496489),
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 7),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 40,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1468CC),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TopPatientGrowthCard extends StatelessWidget {
  final Map<String, DateTime> firstVisitByPatient;
  final DateTime anchorDate;

  const _TopPatientGrowthCard({
    required this.firstVisitByPatient,
    required this.anchorDate,
  });

  @override
  Widget build(BuildContext context) {
    return _TopPatientGrowthCardBody(
      firstVisitByPatient: firstVisitByPatient,
      anchorDate: anchorDate,
    );
  }
}

class _TopPatientGrowthCardBody extends StatefulWidget {
  final Map<String, DateTime> firstVisitByPatient;
  final DateTime anchorDate;

  const _TopPatientGrowthCardBody({
    required this.firstVisitByPatient,
    required this.anchorDate,
  });

  @override
  State<_TopPatientGrowthCardBody> createState() =>
      _TopPatientGrowthCardBodyState();
}

class _TopPatientGrowthCardBodyState extends State<_TopPatientGrowthCardBody> {
  int _weekOffset = 0;

  static DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  DateTime _startOfWeek(DateTime input) {
    final d = _dateOnly(input);
    return d.subtract(Duration(days: d.weekday - 1));
  }

  @override
  Widget build(BuildContext context) {
    final anchor = _dateOnly(widget.anchorDate);
    final currentWeekStart = _startOfWeek(anchor);
    final weekStart = currentWeekStart.subtract(Duration(days: _weekOffset * 7));
    final weekDays = List<DateTime>.generate(
      7,
      (i) => weekStart.add(Duration(days: i)),
      growable: false,
    );

    final counts = <DateTime, int>{for (final day in weekDays) day: 0};
    for (final firstVisit in widget.firstVisitByPatient.values) {
      final day = _dateOnly(firstVisit);
      if (counts.containsKey(day)) {
        counts[day] = (counts[day] ?? 0) + 1;
      }
    }

    final maxBar = counts.values.fold<int>(1, (m, e) => e > m ? e : m);

    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 240, maxWidth: 340),
      child: SizedBox(
        height: 180,
        child: _CardShell(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Text(
                    'Patient Growth',
                    style: TextStyle(
                      fontSize: 13,
                      color: Color(0xFF496489),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: IconButton(
                      icon: const Icon(FluentIcons.chevron_left, size: 10),
                      onPressed: () => setState(() => _weekOffset += 1),
                    ),
                  ),
                  const SizedBox(width: 2),
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: IconButton(
                      icon: const Icon(FluentIcons.chevron_right, size: 10),
                      onPressed: () => setState(() => _weekOffset -= 1),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                '${DateFormat('dd MMM').format(weekDays.first)} - ${DateFormat('dd MMM').format(weekDays.last)}',
                style: const TextStyle(
                  color: Color(0xFF6D84A8),
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: weekDays.map((day) {
                    final value = counts[day] ?? 0;
                    return Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 2),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Text(
                              '$value',
                              style: const TextStyle(
                                color: Color(0xFF36557C),
                                fontWeight: FontWeight.w700,
                                fontSize: 9,
                              ),
                            ),
                            const SizedBox(height: 1),
                            Container(
                              height: (80 * (value / maxBar)).clamp(0, 80).toDouble(),
                              decoration: BoxDecoration(
                                color: const Color(0xFF2D7BD8),
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              DateFormat('E').format(day),
                              style: const TextStyle(
                                color: Color(0xFF5A7397),
                                fontWeight: FontWeight.w700,
                                fontSize: 9,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(growable: false),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusSummaryCard extends StatelessWidget {
  final int completed;
  final int pending;

  const _StatusSummaryCard({required this.completed, required this.pending});

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 220, maxWidth: 320),
      child: SizedBox(
        height: 140,
        child: _CardShell(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Status Today',
                style: TextStyle(
                  fontSize: 13,
                  color: Color(0xFF496489),
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Text(
                    '$completed',
                    style: const TextStyle(
                      color: Color(0xFF3B9A42),
                      fontWeight: FontWeight.w700,
                      fontSize: 30,
                    ),
                  ),
                  const SizedBox(width: 6),
                  const Text(
                    'Completed',
                    style: TextStyle(
                      fontSize: 12,
                      color: Color(0xFF3B9A42),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Text(
                    '$pending',
                    style: const TextStyle(
                      color: Color(0xFFE4A11B),
                      fontWeight: FontWeight.w700,
                      fontSize: 30,
                    ),
                  ),
                  const SizedBox(width: 6),
                  const Text(
                    'Pending',
                    style: TextStyle(
                      fontSize: 12,
                      color: Color(0xFFE4A11B),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TopTimingSummaryCard extends StatelessWidget {
  final List<Appointment> appointmentsForView;

  const _TopTimingSummaryCard({required this.appointmentsForView});

  @override
  Widget build(BuildContext context) {
    final morning = appointmentsForView
        .where((a) => a.date.hour >= 6 && a.date.hour <= 11)
        .length;
    final afternoon = appointmentsForView
        .where((a) => a.date.hour >= 12 && a.date.hour <= 16)
        .length;
    final evening = appointmentsForView
        .where((a) => a.date.hour >= 17 && a.date.hour <= 21)
        .length;
    final maxCount = math.max(1, math.max(morning, math.max(afternoon, evening)));

    Widget miniBar(String label, int value, Color color) {
      return Row(
        children: [
          SizedBox(
            width: 132,
            child: Text(
              label,
              style: const TextStyle(
                color: Color(0xFF496489),
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: Container(
                height: 8,
                color: const Color(0xFFEAF2FC),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: FractionallySizedBox(
                    widthFactor: value / maxCount,
                    child: Container(color: color),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 6),
          Text(
            '$value',
            style: const TextStyle(
              color: Color(0xFF1F446E),
              fontWeight: FontWeight.w700,
              fontSize: 11,
            ),
          ),
        ],
      );
    }

    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 220, maxWidth: 300),
      child: SizedBox(
        height: 140,
        child: _CardShell(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Appointment Timing',
                style: TextStyle(
                  fontSize: 13,
                  color: Color(0xFF496489),
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Expanded(
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: miniBar('Morning (6:00-11:59)', morning, const Color(0xFF2D7BD8)),
                ),
              ),
              Expanded(
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: miniBar('Afternoon (12:00-16:59)', afternoon, const Color(0xFF2BA58D)),
                ),
              ),
              Expanded(
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: miniBar('Evening (17:00-21:59)', evening, const Color(0xFFE09C31)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TopDonutSegment {
  final String label;
  final int value;
  final Color color;

  const _TopDonutSegment({
    required this.label,
    required this.value,
    required this.color,
  });
}

class _TopDonutMetricCard extends StatelessWidget {
  final String title;
  final String centerValue;
  final List<_TopDonutSegment> segments;

  const _TopDonutMetricCard({
    required this.title,
    required this.centerValue,
    required this.segments,
  });

  @override
  Widget build(BuildContext context) {
    final total = segments.fold<int>(0, (sum, s) => sum + s.value);

    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 220, maxWidth: 280),
      child: SizedBox(
        height: 140,
        child: _CardShell(
          child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 13,
                color: Color(0xFF496489),
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                SizedBox(
                  width: 74,
                  height: 74,
                  child: CustomPaint(
                    painter: _TopDonutPainter(segments: segments),
                    child: Center(
                      child: Text(
                        centerValue,
                        style: const TextStyle(
                          color: Color(0xFF1D3E67),
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: segments
                        .map(
                          (s) => Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: Row(
                              children: [
                                Container(
                                  width: 10,
                                  height: 10,
                                  decoration: BoxDecoration(
                                    color: s.color,
                                    borderRadius: BorderRadius.circular(2),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    '${s.label} (${s.value})',
                                    style: const TextStyle(
                                      color: Color(0xFF36557C),
                                      fontWeight: FontWeight.w600,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                                Text(
                                  total == 0
                                      ? '0%'
                                      : '${((s.value / total) * 100).round()}%',
                                  style: const TextStyle(
                                    color: Color(0xFF1F446E),
                                    fontWeight: FontWeight.w700,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                        .toList(growable: false),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      ),
    );
  }
}

class _FilterChipTag extends StatelessWidget {
  final String label;
  final VoidCallback onRemove;

  const _FilterChipTag({required this.label, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFEAF2FC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFD0E2F7)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            FluentIcons.filter,
            size: 11,
            color: Color(0xFF1F4E85),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1F4E85),
            ),
          ),
          const SizedBox(width: 6),
          GestureDetector(
            onTap: onRemove,
            child: const Icon(
              FluentIcons.chrome_close,
              size: 10,
              color: Color(0xFF2D7BD8),
            ),
          ),
        ],
      ),
    );
  }
}

class _TopDonutPainter extends CustomPainter {
  final List<_TopDonutSegment> segments;

  const _TopDonutPainter({required this.segments});

  @override
  void paint(Canvas canvas, Size size) {
    final total = segments.fold<int>(0, (sum, s) => sum + s.value);
    final stroke = size.width * 0.2;
    final rect = Offset.zero & size;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;

    if (total == 0) {
      paint.color = const Color(0xFFD8E6F5);
      canvas.drawArc(
        rect.deflate(stroke / 2),
        -math.pi / 2,
        math.pi * 2,
        false,
        paint,
      );
      return;
    }

    double start = -math.pi / 2;
    const gap = 0.04;
    for (final segment in segments) {
      if (segment.value <= 0) continue;
      final sweep = (segment.value / total) * math.pi * 2;
      paint.color = segment.color;
      final adjustedSweep = math.max(0.0, sweep - gap);
      canvas.drawArc(
        rect.deflate(stroke / 2),
        start,
        adjustedSweep,
        false,
        paint,
      );
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant _TopDonutPainter oldDelegate) {
    return oldDelegate.segments != segments;
  }
}

class _FinanceCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color iconColor;
  final Color iconBackground;
  final Color valueColor;
  final VoidCallback? onTap;

  const _FinanceCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.iconColor,
    required this.iconBackground,
    required this.valueColor,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: _CardShell(
        child: Row(
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: iconBackground,
                borderRadius: BorderRadius.circular(7),
              ),
              child: Icon(icon, size: 15, color: iconColor),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(

                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF2E4E76),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Text(
              value,
              style: TextStyle(
                fontSize: 30,
                fontWeight: FontWeight.w700,
                color: valueColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
