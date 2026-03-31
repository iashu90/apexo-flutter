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
import 'package:apexo/common_widgets/patients_report_dialog.dart';
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

  late DateTime selectedDate;
  String _sortBy = 'time';
  bool _sortAscending = true;
  String _searchQuery = '';
  String _selectedDoctorFilter = _filterAll;
  final TextEditingController _searchController = TextEditingController();

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
          final aDoctor = a.operators.isEmpty ? 'unassigned' : a.operators.map((d) => d.title).join(', ');
          final bDoctor = b.operators.isEmpty ? 'unassigned' : b.operators.map((d) => d.title).join(', ');
          return aDoctor.toLowerCase().compareTo(bDoctor.toLowerCase());
        case 'treatment':
          final aTreatment = a.selectedTreatments.isEmpty ? '' : a.selectedTreatments.join(', ');
          final bTreatment = b.selectedTreatments.isEmpty ? '' : b.selectedTreatments.join(', ');
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

  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
      stream: appointments.observableMap.stream,
      builder: (context, _) {
        final todaysAppointments = appointments.forDate(selectedDate)
          ..sort((a, b) => a.date.compareTo(b.date));

        final completed = todaysAppointments.where((a) => a.isDone).length;
        final pending = todaysAppointments.length - completed;
        final newPatients =
            todaysAppointments.where((a) => a.firstAppointmentForThisPatient).length;
        final revenueToday =
            todaysAppointments.fold<double>(0, (sum, a) => sum + a.paid + a.prescriptionPaid);

        final treatmentRevenue =
            todaysAppointments.fold<double>(0, (sum, a) => sum + a.paid);
        final prescriptionRevenue =
            todaysAppointments.fold<double>(0, (sum, a) => sum + a.prescriptionPaid);
        final outstandingBalance = dashboardCtrl.totalDueAmount();
        final patientInsights = _PatientInsights.from(todaysAppointments);
        final treatmentStats = _TreatmentStats.from(todaysAppointments);
        final doctorScopedAppointments = _doctorFiltered(todaysAppointments);
        final tableAppointments = _filteredAndSorted(doctorScopedAppointments);

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
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    _StatCard(
                      title: 'Appointments Today',
                      value: '${todaysAppointments.length}',
                      icon: FluentIcons.calendar,
                      iconColor: const Color(0xFF2D7BD8),
                      iconBackground: const Color(0xFFDDEBFF),
                    ),
                    _StatCard(
                      title: 'Completed',
                      value: '$completed',
                      icon: FluentIcons.favorite_star_fill,
                      iconColor: const Color(0xFFDA9A05),
                      iconBackground: const Color(0xFFFDF1CF),
                    ),
                    _StatCard(
                      title: 'Pending',
                      value: '$pending',
                      icon: FluentIcons.checkbox_indeterminate,
                      iconColor: const Color(0xFF5A9D39),
                      iconBackground: const Color(0xFFD8F0CD),
                    ),
                    _StatCard(
                      title: 'New Patients',
                      value: '$newPatients',
                      icon: FluentIcons.contact,
                      iconColor: const Color(0xFF4CA046),
                      iconBackground: const Color(0xFFDFF2D8),
                    ),
                    _RevenueCard(
                      title: 'Revenue Today',
                      value: _money(revenueToday),
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
                            selectedFilter: _selectedDoctorFilter,
                            onFilterChanged: (v) =>
                                setState(() => _selectedDoctorFilter = v),
                          ),
                          const SizedBox(height: 10),
                          _AppointmentTimingSummaryCard(
                            appointmentsForView: doctorScopedAppointments,
                          ),
                          const SizedBox(height: 10),
                          _RightDashboardColumn(
                            tableAppointments: tableAppointments,
                            searchController: _searchController,
                            sortBy: _sortBy,
                            sortAscending: _sortAscending,
                            onSort: _onSort,
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
                                selectedFilter: _selectedDoctorFilter,
                                onFilterChanged: (v) =>
                                    setState(() => _selectedDoctorFilter = v),
                              ),
                              const SizedBox(height: 10),
                              _AppointmentTimingSummaryCard(
                                appointmentsForView: doctorScopedAppointments,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _RightDashboardColumn(
                            tableAppointments: tableAppointments,
                            searchController: _searchController,
                            sortBy: _sortBy,
                            sortAscending: _sortAscending,
                            onSort: _onSort,
                          ),
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 14),
                _InsightsRow(
                  patientInsights: patientInsights,
                  treatmentStats: treatmentStats,
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

class _RightDashboardColumn extends StatelessWidget {
  final List<Appointment> todaysAppointments;
  final List<Appointment> tableAppointments;
  final TextEditingController searchController;
  final String sortBy;
  final bool sortAscending;
  final ValueChanged<String> onSort;

  const _RightDashboardColumn({
    required this.todaysAppointments,
    required this.tableAppointments,
    required this.searchController,
    required this.sortBy,
    required this.sortAscending,
    required this.onSort,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _HourChartCard(todaysAppointments: todaysAppointments),
        const SizedBox(height: 10),
        _AppointmentsTableCard(
          tableAppointments: tableAppointments,
          searchController: searchController,
          sortBy: sortBy,
          sortAscending: sortAscending,
          onSort: onSort,
        ),
      ],
    );
  }
}

class _DoctorScheduleCard extends StatelessWidget {
  final List<Appointment> todaysAppointments;

  const _DoctorScheduleCard({required this.todaysAppointments});

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
      doctorRows.add(_DoctorScheduleRow(title: doctor.title, count: entry.value));
    }

    doctorRows.sort((a, b) => b.count.compareTo(a.count));

    final unassigned =
        todaysAppointments.where((a) => a.operatorsIDs.isEmpty).length;

    return _CardShell(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Doctor Schedule',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: Color(0xFF183A67)),
          ),
          const SizedBox(height: 8),
          _ScheduleLine(title: 'All', count: todaysAppointments.length),
          _ScheduleLine(title: 'Unassigned', count: unassigned),
          const SizedBox(height: 6),
          if (doctorRows.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text(
                'No doctors assigned for this day',
                style: TextStyle(color: Color(0xFF637EA3)),
              ),
            ),
          ...doctorRows.take(6).map(
                (row) => _ScheduleLine(title: row.title, count: row.count),
              ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: () => openAppointment(Appointment.fromJson({})),
            style: ButtonStyle(
              backgroundColor: WidgetStateProperty.all(const Color(0xFF1A74DB)),
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
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
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
  final String title;
  final int count;

  _DoctorScheduleRow({required this.title, required this.count});
}

class _HourChartCard extends StatelessWidget {
  final List<Appointment> todaysAppointments;

  const _HourChartCard({required this.todaysAppointments});

  @override
  Widget build(BuildContext context) {
    final buckets = _hourBuckets(todaysAppointments);

    return _CardShell(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Appointments by Hour',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: Color(0xFF183A67)),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 140,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final maxCount = buckets.values.fold<int>(0, (a, b) => a > b ? a : b);
                final columnCount = buckets.length;
                final itemWidth = (constraints.maxWidth / (columnCount == 0 ? 1 : columnCount)) - 6;

                return Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: buckets.entries.map((entry) {
                    final ratio = maxCount == 0 ? 0.0 : entry.value / maxCount;
                    final barHeight = 24 + (88 * ratio);
                    return SizedBox(
                      width: itemWidth,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Container(
                            height: barHeight,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                begin: Alignment.bottomCenter,
                                end: Alignment.topCenter,
                                colors: [Color(0xFF2D7BD8), Color(0xFFAED0F7)],
                              ),
                              borderRadius: BorderRadius.circular(6),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            _hourLabel(entry.key),
                            style: const TextStyle(fontSize: 11, color: Color(0xFF4D678E)),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Map<int, int> _hourBuckets(List<Appointment> list) {
    final result = <int, int>{};
    for (int hour = 9; hour <= 18; hour++) {
      result[hour] = 0;
    }

    for (final a in list) {
      if (result.containsKey(a.date.hour)) {
        result[a.date.hour] = result[a.date.hour]! + 1;
      }
    }

    return result;
  }

  String _hourLabel(int hour) {
    if (hour == 12) return '12 PM';
    if (hour > 12) return '${hour - 12} PM';
    return '$hour AM';
  }
}

class _AppointmentsTableCard extends StatelessWidget {
  final List<Appointment> tableAppointments;
  final TextEditingController searchController;
  final String sortBy;
  final bool sortAscending;
  final ValueChanged<String> onSort;

  const _AppointmentsTableCard({
    required this.tableAppointments,
    required this.searchController,
    required this.sortBy,
    required this.sortAscending,
    required this.onSort,
  });

  @override
  Widget build(BuildContext context) {
    final rows = tableAppointments.take(100).toList();

    return _CardShell(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Today\'s Appointments',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: Color(0xFF183A67)),
              ),
              Row(
                children: [
                  SizedBox(
                    width: 280,
                    child: TextBox(
                      placeholder: 'Search patient name or phone',
                      controller: searchController,
                      placeholderStyle: const TextStyle(color: Color(0xFF6D84A8)),
                    ),
                  ),
                  const SizedBox(width: 10),
                  FilledButton(
                    onPressed: () => openAppointment(Appointment.fromJson({})),
                    style: ButtonStyle(
                      backgroundColor: WidgetStateProperty.all(const Color(0xFF1A74DB)),
                      shape: WidgetStateProperty.all(
                        RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
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
                else
                  ...rows.map((a) => _AppointmentRow(appointment: a)),
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
  final ValueChanged<String> onSort;

  const _TableHeader({
    required this.sortBy,
    required this.sortAscending,
    required this.onSort,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: const BoxDecoration(
        color: Color(0xFFEFF4FB),
        borderRadius: BorderRadius.vertical(top: Radius.circular(10)),
      ),
      child: Row(
        children: [
          Expanded(flex: 11, child: _SortableHeader(label: 'Time', keyName: 'time', current: sortBy, ascending: sortAscending, onSort: onSort)),
          Expanded(flex: 15, child: _SortableHeader(label: 'Patient', keyName: 'patient', current: sortBy, ascending: sortAscending, onSort: onSort)),
          Expanded(flex: 13, child: _SortableHeader(label: 'Doctor', keyName: 'doctor', current: sortBy, ascending: sortAscending, onSort: onSort)),
          Expanded(flex: 14, child: _SortableHeader(label: 'Treatment', keyName: 'treatment', current: sortBy, ascending: sortAscending, onSort: onSort)),
          Expanded(flex: 12, child: _SortableHeader(label: 'Status', keyName: 'status', current: sortBy, ascending: sortAscending, onSort: onSort)),
          Expanded(flex: 12, child: _SortableHeader(label: 'P.Mode', keyName: 'paymentMode', current: sortBy, ascending: sortAscending, onSort: onSort)),
          Expanded(flex: 12, child: _SortableHeader(label: 'Payment', keyName: 'payment', current: sortBy, ascending: sortAscending, onSort: onSort)),
          Expanded(flex: 10, child: _SortableHeader(label: 'Actions', keyName: 'actions', current: sortBy, ascending: sortAscending, onSort: onSort)),
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

  const _SortableHeader({
    required this.label,
    required this.keyName,
    required this.current,
    required this.ascending,
    required this.onSort,
  });

  @override
  Widget build(BuildContext context) {
    final active = current == keyName;
    return GestureDetector(
      onTap: () => onSort(keyName),
      child: Row(
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF2C4468))),
          const SizedBox(width: 4),
          Icon(
            active
                ? (ascending ? FluentIcons.chevron_up : FluentIcons.chevron_down)
                : FluentIcons.switch_user,
            size: 10,
            color: const Color(0xFF6D84A8),
          ),
        ],
      ),
    );
  }
}

class _AppointmentRow extends StatelessWidget {
  final Appointment appointment;

  const _AppointmentRow({required this.appointment});

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
    final isDigital = appointment.treatmentGpayPaid || appointment.prescriptionGpayPaid;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: Color(0xFFE2ECF8))),
      ),
      child: Row(
        children: [
          Expanded(flex: 11, child: Text(time, style: const TextStyle(color: Color(0xFF355279)))),
          Expanded(flex: 15, child: Text(appointment.title, style: const TextStyle(color: Color(0xFF1459AD), fontWeight: FontWeight.w600))),
          Expanded(flex: 13, child: Text(doctorName, style: const TextStyle(color: Color(0xFF2D476D)))),
          Expanded(flex: 14, child: Text(treatment, style: const TextStyle(color: Color(0xFF2D476D)), maxLines: 1, overflow: TextOverflow.ellipsis)),
          Expanded(
            flex: 12,
            child: _StatusBadge(done: appointment.isDone),
          ),
          Expanded(
            flex: 12,
            child: Row(
              children: [
                Icon(
                  isDigital ? FluentIcons.receipt_processing : FluentIcons.money,
                  size: 14,
                  color: isDigital ? const Color(0xFF2D7BD8) : const Color(0xFF3B9A42),
                ),
                const SizedBox(width: 4),
                Text(
                  isDigital ? 'GPay' : 'Cash',
                  style: const TextStyle(color: Color(0xFF2D476D), fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
          Expanded(flex: 12, child: Text('₹${payment.toStringAsFixed(0)}', style: const TextStyle(color: Color(0xFF2D476D), fontWeight: FontWeight.w600))),
          Expanded(
            flex: 10,
            child: GestureDetector(
              onTap: () => openAppointment(appointment),
              child: const Row(
                children: [
                  Icon(FluentIcons.view, size: 12, color: Color(0xFF1A74DB)),
                  SizedBox(width: 4),
                  Text('View', style: TextStyle(color: Color(0xFF1A74DB), fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          ),
        ],
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
          done ? FluentIcons.completed : FluentIcons.clock,
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

  const _ScheduleLine({required this.title, required this.count});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 2),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(6),
        color: const Color(0xFFF6F9FE),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Color(0xFF27456D), fontWeight: FontWeight.w600),
            ),
          ),
          Text('($count)', style: const TextStyle(color: Color(0xFF637EA3))),
        ],
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
                child: Text(
                  DateFormat('MMMM d, yyyy').format(selectedDate),
                  style: const TextStyle(
                    color: Color(0xFF25466E),
                    fontWeight: FontWeight.w700,
                  ),
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
        FilledButton(
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
    return SizedBox(
      width: double.infinity,
      child: PatientLookup(
        patientCheckIn: (patient) {
          if (patient == null) return;
          final dt = _withCurrentTime(selectedDate);
          appointments.set(Appointment.fromJson({
            'patientID': patient.id,
            'date': dt.millisecondsSinceEpoch,
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
          final isDigitsOnly =
              searchQuery.isNotEmpty && searchQuery.runes.every((c) => c >= 48 && c <= 57);
          openPatient(
            Patient.fromJson({
              if (isDigitsOnly) 'phone': searchQuery else 'title': searchQuery,
            }),
            0,
          );
        },
      ),
    );
  }
}

class _InsightsRow extends StatelessWidget {
  final _PatientInsights patientInsights;
  final _TreatmentStats treatmentStats;

  const _InsightsRow({
    required this.patientInsights,
    required this.treatmentStats,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: _PatientInsightsCard(insights: patientInsights)),
        const SizedBox(width: 10),
        Expanded(child: _TreatmentStatsCard(stats: treatmentStats)),
      ],
    );
  }
}

class _PatientInsights {
  final int uniquePatients;
  final int newPatients;
  final int returningPatients;
  final int completedCount;
  final int total;

  _PatientInsights({
    required this.uniquePatients,
    required this.newPatients,
    required this.returningPatients,
    required this.completedCount,
    required this.total,
  });

  double get completionRate {
    if (total == 0) return 0;
    return (completedCount / total) * 100;
  }

  factory _PatientInsights.from(List<Appointment> appointmentsOnDay) {
    final uniqueIds = appointmentsOnDay
        .map((a) => a.patientID ?? a.id)
        .toSet()
        .length;

    final newCount = appointmentsOnDay
        .where((a) => a.firstAppointmentForThisPatient)
        .length;

    final completed = appointmentsOnDay.where((a) => a.isDone).length;

    return _PatientInsights(
      uniquePatients: uniqueIds,
      newPatients: newCount,
      returningPatients: uniqueIds - newCount < 0 ? 0 : uniqueIds - newCount,
      completedCount: completed,
      total: appointmentsOnDay.length,
    );
  }
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
      topTreatments: sorted.take(4).toList(),
      totalTreatments: total,
    );
  }
}

class _PatientInsightsCard extends StatelessWidget {
  final _PatientInsights insights;

  const _PatientInsightsCard({required this.insights});

  @override
  Widget build(BuildContext context) {
    return _CardShell(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Patient Insights',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: Color(0xFF183A67)),
          ),
          const SizedBox(height: 10),
          _InsightLine(label: 'Unique Patients', value: '${insights.uniquePatients}'),
          _InsightLine(label: 'New Patients', value: '${insights.newPatients}'),
          _InsightLine(label: 'Returning Patients', value: '${insights.returningPatients}'),
          _InsightLine(label: 'Completion Rate', value: '${insights.completionRate.toStringAsFixed(0)}%'),
        ],
      ),
    );
  }
}

class _TreatmentStatsCard extends StatelessWidget {
  final _TreatmentStats stats;

  const _TreatmentStatsCard({required this.stats});

  @override
  Widget build(BuildContext context) {
    return _CardShell(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Treatment Stats',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: Color(0xFF183A67)),
          ),
          const SizedBox(height: 10),
          _InsightLine(label: 'Total Treatments', value: '${stats.totalTreatments}'),
          if (stats.topTreatments.isEmpty)
            const Text(
              'No treatments recorded for this day',
              style: TextStyle(color: Color(0xFF637EA3)),
            )
          else
            ...stats.topTreatments.map(
              (entry) => _InsightLine(label: entry.key, value: '${entry.value}'),
            ),
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
              style: const TextStyle(color: Color(0xFF36557C), fontWeight: FontWeight.w600),
            ),
          ),
          Text(
            value,
            style: const TextStyle(color: Color(0xFF1A3D69), fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color iconColor;
  final Color iconBackground;

  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.iconColor,
    required this.iconBackground,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 242,
      child: _CardShell(
        child: SizedBox(
          height: 82,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontSize: 13, color: Color(0xFF496489), fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    Text(value, style: const TextStyle(fontSize: 38, fontWeight: FontWeight.w700, color: Color(0xFF1B3557))),
                  ],
                ),
              ),
              Container(
                width: 38,
                height: 38,
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
    );
  }
}

class _RevenueCard extends StatelessWidget {
  final String title;
  final String value;

  const _RevenueCard({required this.title, required this.value});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 290,
      child: _CardShell(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontSize: 13, color: Color(0xFF496489))),
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
    );
  }
}

class _FinanceCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color iconColor;
  final Color iconBackground;
  final Color valueColor;

  const _FinanceCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.iconColor,
    required this.iconBackground,
    required this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return _CardShell(
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
    );
  }
}
