import 'dart:math' as math;

import 'package:apexo/core/multi_stream_builder.dart';
import 'package:apexo/features/appointments/appointment_model.dart';
import 'package:apexo/features/appointments/appointments_store.dart';
import 'package:apexo/features/doctors/doctor_model.dart';
import 'package:apexo/features/doctors/doctors_store.dart';
import 'package:apexo/theme/material_date_picker_theme.dart';
import 'package:apexo/utils/uuid.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/material.dart' as material;
import 'package:intl/intl.dart';

class DoctorsScreenV2 extends StatefulWidget {
  const DoctorsScreenV2({super.key});

  @override
  State<DoctorsScreenV2> createState() => _DoctorsScreenV2State();
}

class _DoctorsScreenV2State extends State<DoctorsScreenV2> {
  DateTime _selectedDate = DateTime.now();
  String _handledRange = 'today';
  String _performanceRange = 'month';
  String _doneRange = 'month';
  String _workloadRange = 'week';
  bool _compareMode = false;
  DateTime? _customRangeStart;
  DateTime? _customRangeEnd;

  static DateTime _dateOnly(DateTime input) =>
      DateTime(input.year, input.month, input.day);

  @override
  void initState() {
    super.initState();
    _selectedDate = _dateOnly(DateTime.now());
  }

  void _changeDate(int days) {
    setState(() {
      _selectedDate = _dateOnly(_selectedDate.add(Duration(days: days)));
    });
  }

  Future<void> _pickDate(BuildContext context) async {
    final picked = await material.showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000, 1, 1),
      lastDate: DateTime(2100, 12, 31),
      helpText: 'Select date',
      builder: apexoDatePickerBuilder(context),
    );

    if (picked == null) return;
    setState(() => _selectedDate = _dateOnly(picked));
  }

  Future<void> _pickCustomRange(BuildContext context) async {
    final picked = await material.showDateRangePicker(
      context: context,
      firstDate: DateTime(2000, 1, 1),
      lastDate: DateTime(2100, 12, 31),
      initialDateRange: _customRangeStart != null && _customRangeEnd != null
          ? material.DateTimeRange(
              start: _customRangeStart!, end: _customRangeEnd!)
          : null,
      helpText: 'Select custom range',
      builder: apexoDatePickerBuilder(context),
    );

    if (picked == null) return;
    setState(() {
      _customRangeStart = _dateOnly(picked.start);
      _customRangeEnd = _dateOnly(picked.end);
      _handledRange = 'custom';
      _performanceRange = 'custom';
      _doneRange = 'custom';
      _workloadRange = 'custom';
    });
  }

  DateTime _rangeStart(DateTime anchor, String range) {
    switch (range) {
      case 'today':
        return _dateOnly(anchor);
      case 'week':
        return _dateOnly(anchor.subtract(const Duration(days: 6)));
      case 'month':
        return DateTime(anchor.year, anchor.month, 1);
      case '6months':
        return DateTime(anchor.year, anchor.month - 5, 1);
      case 'ytd':
        return DateTime(anchor.year, 1, 1);
      case 'year':
        return _dateOnly(anchor.subtract(const Duration(days: 364)));
      default:
        return _dateOnly(anchor);
    }
  }

  DateTime _rangeEndExclusive(DateTime anchor) {
    return _dateOnly(anchor).add(const Duration(days: 1));
  }

  String _customRangeLabel() {
    if (_customRangeStart == null || _customRangeEnd == null) {
      return 'Set Custom Range';
    }
    return '${DateFormat('dd MMM').format(_customRangeStart!)} - ${DateFormat('dd MMM').format(_customRangeEnd!)}';
  }

  Future<void> _openAddDoctorModal() async {
    await _openDoctorEntryModalV2(context);
  }

  ButtonStyle get _dateButtonStyle {
    return ButtonStyle(
      padding: WidgetStateProperty.all(
        const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      ),
      backgroundColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.pressed))
          return const Color(0x331A74DB);
        if (states.contains(WidgetState.hovered))
          return const Color(0x1F1A74DB);
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
    final now = DateTime.now();
    final isToday = _selectedDate.year == now.year &&
        _selectedDate.month == now.month &&
        _selectedDate.day == now.day;

    return ScaffoldPage.scrollable(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
      children: [
        MStreamBuilder(
          streams: [
            doctors.observableMap.stream,
            appointments.observableMap.stream,
          ],
          builder: (context, _) {
            final allDoctors = doctors.present.values.toList(growable: false)
              ..sort((a, b) =>
                  a.title.toLowerCase().compareTo(b.title.toLowerCase()));
            final allAppointments =
                appointments.present.values.toList(growable: false);

            final currentStart =
                _handledRange == 'custom' && _customRangeStart != null
                    ? _customRangeStart!
                    : _rangeStart(_selectedDate, _handledRange);
            final currentEnd =
                _handledRange == 'custom' && _customRangeEnd != null
                    ? _dateOnly(_customRangeEnd!).add(const Duration(days: 1))
                    : _rangeEndExclusive(_selectedDate);
            final currentSpanDays =
                math.max(1, currentEnd.difference(currentStart).inDays);
            final compareEnd = currentStart;
            final compareStart =
                compareEnd.subtract(Duration(days: currentSpanDays));

            final scopedCurrent = allAppointments
                .where((a) =>
                    !a.date.isBefore(currentStart) &&
                    a.date.isBefore(currentEnd))
                .toList(growable: false);

            final scopedCompare = allAppointments
                .where((a) =>
                    !a.date.isBefore(compareStart) &&
                    a.date.isBefore(compareEnd))
                .toList(growable: false);

            final startOfDay = _dateOnly(_selectedDate);
            final endOfDay = startOfDay.add(const Duration(days: 1));
            final todaysAppointments = allAppointments
                .where((a) =>
                    !a.date.isBefore(startOfDay) && a.date.isBefore(endOfDay))
                .toList(growable: false);

            final activeDoctorIdsToday = <String>{};
            double todayDoctorPay = 0;
            for (final appointment in todaysAppointments) {
              activeDoctorIdsToday.addAll(appointment.operatorsIDs);
              todayDoctorPay += appointment.paidToDoctor;
            }

            final handledRows = _doctorMetrics(
              doctorsList: allDoctors,
              scoped: scopedCurrent,
            );
            final compareRows = _doctorMetrics(
              doctorsList: allDoctors,
              scoped: scopedCompare,
            );
            final compareById = {
              for (final row in compareRows) row.doctor.id: row,
            };

            final doneRows = _doctorDoneMetrics(
              doctorsList: allDoctors,
              scoped: _scopedForRange(
                allAppointments: allAppointments,
                selectedDate: _selectedDate,
                range: _doneRange,
                customRangeStart: _customRangeStart,
                customRangeEnd: _customRangeEnd,
              ),
            );

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  height: 56,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      const Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Doctors',
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF12355F),
                          ),
                        ),
                      ),
                      Align(
                        alignment: Alignment.center,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(8),
                                border:
                                    Border.all(color: const Color(0xFFD6E2F0)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Button(
                                    onPressed: () => _changeDate(-1),
                                    style: _dateButtonStyle,
                                    child: const Icon(FluentIcons.chevron_left,
                                        size: 12),
                                  ),
                                  Button(
                                    onPressed: () => _pickDate(context),
                                    style: _dateButtonStyle,
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          DateFormat('MMMM d, yyyy')
                                              .format(_selectedDate),
                                          style: const TextStyle(
                                            color: Color(0xFF25466E),
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                        const SizedBox(height: 1),
                                        Text(
                                          DateFormat('EEEE')
                                              .format(_selectedDate),
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
                                    onPressed: () => _changeDate(1),
                                    style: _dateButtonStyle,
                                    child: const Icon(FluentIcons.chevron_right,
                                        size: 12),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            SizedBox(
                              width: 84,
                              child: Visibility(
                                visible: !isToday,
                                maintainSize: true,
                                maintainAnimation: true,
                                maintainState: true,
                                child: FilledButton(
                                  onPressed: () => setState(() =>
                                      _selectedDate =
                                          _dateOnly(DateTime.now())),
                                  child: const Text('Today'),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Align(
                        alignment: Alignment.centerRight,
                        child: FilledButton(
                          onPressed: _openAddDoctorModal,
                          style: ButtonStyle(
                            backgroundColor: WidgetStateProperty.all(
                                const Color(0xFF2D7BD8)),
                            foregroundColor:
                                WidgetStateProperty.all(Colors.white),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(FluentIcons.add, size: 12),
                              SizedBox(width: 6),
                              Text('Add Doctor'),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    _MetricCard(
                      title: 'Total Doctors',
                      value: '${allDoctors.length}',
                      color: const Color(0xFF1D3E67),
                    ),
                    _MetricCard(
                      title: 'Active Today',
                      value: '${activeDoctorIdsToday.length}',
                      color: const Color(0xFF2BA58D),
                    ),
                    _MetricCard(
                      title: 'Appointments Today',
                      value: '${todaysAppointments.length}',
                      color: const Color(0xFF2D7BD8),
                    ),
                    _MetricCard(
                      title: 'Paid to Doctors Today',
                      value: 'Rs ${todayDoctorPay.toStringAsFixed(0)}',
                      color: const Color(0xFFE09C31),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                _DoctorDirectoryCard(
                  doctors: allDoctors,
                  onEdit: (doctor) => _openDoctorEntryModalV2(
                    context,
                    existingDoctor: doctor,
                  ),
                ),
                const SizedBox(height: 8),
                _DoctorTodayEarningsCompactCard(rows: doneRows),
                const SizedBox(height: 10),
                Align(
                  alignment: Alignment.centerLeft,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 620),
                    child: _DoctorAppointmentDoneChartCard(
                      rows: doneRows,
                      selectedRange: _doneRange,
                      onSelectRange: (value) =>
                          setState(() => _doneRange = value),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ],
    );
  }
}

Future<void> _openDoctorEntryModalV2(
  BuildContext context, {
  Doctor? existingDoctor,
}) async {
  final isEdit = existingDoctor != null;
  final nameController =
      TextEditingController(text: existingDoctor?.title ?? '');
  final phoneController = TextEditingController(
    text: (existingDoctor?.phone ?? existingDoctor?.email ?? '').trim(),
  );
  final selectedDutyDays = List<String>.from(
    existingDoctor?.dutyDays ?? allDays,
    growable: true,
  );
  String? nameError;

  await showDialog<void>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (context, setStateDialog) => ContentDialog(
        title: Row(
          children: [
            Expanded(
              child: Text(
                isEdit ? 'Edit Doctor' : 'Add Doctor',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            IconButton(
              icon: const Icon(FluentIcons.chrome_close, size: 12),
              onPressed: () => Navigator.pop(dialogContext),
            ),
          ],
        ),
        content: SizedBox(
          width: 520,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                InfoLabel(
                  label: 'Doctor Name:',
                  child: TextBox(
                    controller: nameController,
                    placeholder: 'Enter doctor name',
                    onChanged: (_) {
                      if (nameError != null) {
                        setStateDialog(() => nameError = null);
                      }
                    },
                  ),
                ),
                if (nameError != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      nameError!,
                      style: const TextStyle(
                        color: Color(0xFFD6455D),
                        fontSize: 11,
                      ),
                    ),
                  ),
                const SizedBox(height: 10),
                InfoLabel(
                  label: 'Phone Number (optional):',
                  child: TextBox(
                    controller: phoneController,
                    placeholder: 'Enter phone number',
                  ),
                ),
                const SizedBox(height: 10),
                InfoLabel(
                  label: 'Duty Days:',
                  child: SizedBox.shrink(),
                ),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: allDays.map((day) {
                    final selected = selectedDutyDays.contains(day);
                    return GestureDetector(
                      onTap: () {
                        setStateDialog(() {
                          if (selected) {
                            selectedDutyDays.remove(day);
                          } else {
                            selectedDutyDays.add(day);
                          }
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: selected
                              ? const Color(0xFF2D7BD8)
                              : const Color(0xFFEFF4FB),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                            color: selected
                                ? const Color(0xFF2D7BD8)
                                : const Color(0xFFD4E2F3),
                          ),
                        ),
                        child: Text(
                          day,
                          style: TextStyle(
                            color: selected
                                ? Colors.white
                                : const Color(0xFF345982),
                            fontWeight: FontWeight.w600,
                            fontSize: 11,
                          ),
                        ),
                      ),
                    );
                  }).toList(growable: false),
                ),
              ],
            ),
          ),
        ),
        actions: [
          Button(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final name = nameController.text.trim();
              if (name.isEmpty) {
                setStateDialog(() => nameError = 'Doctor name is required.');
                return;
              }

              final doctor = Doctor.fromJson({
                'id': existingDoctor?.id ?? uuid(),
                'title': name,
                'email': existingDoctor?.email ?? '',
                'phone': phoneController.text.trim(),
                'dutyDays': selectedDutyDays,
              });
              doctors.set(doctor);
              Navigator.pop(dialogContext);
            },
            child: Text(isEdit ? 'Save Changes' : 'Save Doctor'),
          ),
        ],
      ),
    ),
  );
}

List<
    ({
      Doctor doctor,
      int appointmentCount,
      int patientCount,
      double earned,
    })> _doctorMetrics({
  required List<Doctor> doctorsList,
  required List<Appointment> scoped,
}) {
  return doctorsList
      .map((doctor) {
        final doctorRows = scoped
            .where((a) => a.operatorsIDs.contains(doctor.id))
            .toList(growable: false);

        final uniquePatients = <String>{};
        for (final appt in doctorRows) {
          final pid = appt.patientID;
          if (pid != null && pid.isNotEmpty) uniquePatients.add(pid);
        }

        final earned = doctorRows.fold<double>(0, (s, a) => s + a.paidToDoctor);

        return (
          doctor: doctor,
          appointmentCount: doctorRows.length,
          patientCount: uniquePatients.length,
          earned: earned,
        );
      })
      .where((row) => row.appointmentCount > 0)
      .toList(growable: false)
    ..sort((a, b) => b.appointmentCount.compareTo(a.appointmentCount));
}

List<({String procedure, int thisMonth, int lastMonth, int delta})>
    _procedureMonthOverMonth({
  required List<Appointment> allAppointments,
  required String? doctorId,
  required DateTime anchor,
}) {
  final currentMonthStart = DateTime(anchor.year, anchor.month, 1);
  final nextMonthStart = DateTime(anchor.year, anchor.month + 1, 1);
  final lastMonthStart = DateTime(anchor.year, anchor.month - 1, 1);

  final current = <String, int>{};
  final previous = <String, int>{};

  for (final appointment in allAppointments) {
    if (doctorId != null && !appointment.operatorsIDs.contains(doctorId))
      continue;

    final inCurrent = !appointment.date.isBefore(currentMonthStart) &&
        appointment.date.isBefore(nextMonthStart);
    final inPrevious = !appointment.date.isBefore(lastMonthStart) &&
        appointment.date.isBefore(currentMonthStart);

    if (!inCurrent && !inPrevious) continue;

    for (final treatment in appointment.selectedTreatments) {
      final name = treatment.trim();
      if (name.isEmpty) continue;
      if (inCurrent) current[name] = (current[name] ?? 0) + 1;
      if (inPrevious) previous[name] = (previous[name] ?? 0) + 1;
    }
  }

  final keys = <String>{...current.keys, ...previous.keys};
  final rows = keys.map((k) {
    final thisMonth = current[k] ?? 0;
    final lastMonth = previous[k] ?? 0;
    return (
      procedure: k,
      thisMonth: thisMonth,
      lastMonth: lastMonth,
      delta: thisMonth - lastMonth,
    );
  }).toList(growable: false)
    ..sort((a, b) => b.thisMonth.compareTo(a.thisMonth));

  return rows;
}

Map<int, Map<int, int>> _slotPressureHeatmap({
  required List<Appointment> appointmentsList,
  required String? doctorId,
}) {
  final heatmap = <int, Map<int, int>>{};
  for (final appointment in appointmentsList) {
    if (doctorId != null && !appointment.operatorsIDs.contains(doctorId))
      continue;
    final weekday = appointment.date.weekday;
    final hour = appointment.date.hour;
    final row = heatmap.putIfAbsent(weekday, () => <int, int>{});
    row[hour] = (row[hour] ?? 0) + 1;
  }
  return heatmap;
}

class _MetricCard extends StatelessWidget {
  final String title;
  final String value;
  final Color color;

  const _MetricCard({
    required this.title,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 270,
      height: 140,
      child: DecoratedBox(
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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 13,
                  color: Color(0xFF3C5E87),
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                value,
                style: TextStyle(
                  fontSize: 30,
                  color: color,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DoctorTodayEarningsCompactCard extends StatelessWidget {
  final List<({Doctor doctor, int doneCount, int totalCount, double earned})>
      rows;

  const _DoctorTodayEarningsCompactCard({required this.rows});

  @override
  Widget build(BuildContext context) {
    final totalAppointments = rows.fold<int>(0, (s, e) => s + e.totalCount);
    final totalDone = rows.fold<int>(0, (s, e) => s + e.doneCount);
    final totalEarned = rows.fold<double>(0, (s, e) => s + e.earned);

    return Align(
      alignment: Alignment.centerLeft,
      child: DecoratedBox(
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
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _miniPill('Appts', '$totalAppointments'),
              const SizedBox(width: 8),
              _miniPill('Done', '$totalDone'),
              const SizedBox(width: 8),
              _miniPill('Earned', 'Rs ${totalEarned.toStringAsFixed(0)}'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _miniPill(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
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

class _DoctorHandledRangeCard extends StatelessWidget {
  final String selectedRange;
  final bool compareMode;
  final String customRangeLabel;
  final VoidCallback onPickCustomRange;
  final ValueChanged<bool> onToggleCompare;
  final ValueChanged<String> onSelectRange;
  final List<
      ({
        Doctor doctor,
        int appointmentCount,
        int patientCount,
        double earned,
      })> rows;
  final Map<
      String,
      ({
        Doctor doctor,
        int appointmentCount,
        int patientCount,
        double earned,
      })> compareById;

  const _DoctorHandledRangeCard({
    required this.selectedRange,
    required this.compareMode,
    required this.customRangeLabel,
    required this.onPickCustomRange,
    required this.onToggleCompare,
    required this.onSelectRange,
    required this.rows,
    required this.compareById,
  });

  @override
  Widget build(BuildContext context) {
    Widget tab(String key, String label) {
      final selected = selectedRange == key;
      return GestureDetector(
        onTap: () => onSelectRange(key),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: selected ? const Color(0xFF2D7BD8) : const Color(0xFFEFF4FB),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color:
                  selected ? const Color(0xFF2D7BD8) : const Color(0xFFD6E2F0),
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: selected ? Colors.white : const Color(0xFF355279),
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
        ),
      );
    }

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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text(
                  'Patients Handled By Doctor',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF183A67),
                  ),
                ),
                const Spacer(),
                ToggleSwitch(
                  checked: compareMode,
                  content: const Text('Compare Mode'),
                  onChanged: onToggleCompare,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                tab('today', 'Today'),
                tab('week', 'Week'),
                tab('month', 'Month'),
                tab('6months', '6 Months'),
                tab('year', '1 Year'),
                tab('ytd', 'YTD'),
                GestureDetector(
                  onTap: onPickCustomRange,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: selectedRange == 'custom'
                          ? const Color(0xFF2D7BD8)
                          : const Color(0xFFEFF4FB),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: selectedRange == 'custom'
                            ? const Color(0xFF2D7BD8)
                            : const Color(0xFFD6E2F0),
                      ),
                    ),
                    child: Text(
                      customRangeLabel,
                      style: TextStyle(
                        color: selectedRange == 'custom'
                            ? Colors.white
                            : const Color(0xFF355279),
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Doctor',
                    style: TextStyle(
                      color: Color(0xFF5B789F),
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                ),
                Tooltip(
                  message:
                      'Appts = appointment count, Pts = unique patients, Earned = paid to doctor',
                  child: const Text(
                    'Appts G�� Pts G�� Earned',
                    style: TextStyle(
                      color: Color(0xFF5B789F),
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            if (rows.isEmpty)
              const Text(
                'No doctor activity in selected range.',
                style: TextStyle(color: Color(0xFF6D84A8)),
              )
            else ...[
              Builder(
                builder: (context) {
                  final peak = rows.fold<int>(1, (m, e) {
                    return e.appointmentCount > m ? e.appointmentCount : m;
                  });
                  return Column(
                    children: rows.take(12).map(
                      (row) {
                        final compare = compareById[row.doctor.id];
                        final appointmentDelta = row.appointmentCount -
                            (compare?.appointmentCount ?? 0);
                        final earnedDelta = row.earned - (compare?.earned ?? 0);

                        return GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () => _openDoctorEntryModalV2(
                            context,
                            existingDoctor: row.doctor,
                          ),
                          child: Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    row.doctor.title,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: Color(0xFF1F446E),
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                SizedBox(
                                  width: 120,
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: Container(
                                      height: 8,
                                      color: const Color(0xFFEAF2FC),
                                      child: FractionallySizedBox(
                                        alignment: Alignment.centerLeft,
                                        widthFactor:
                                            row.appointmentCount / peak,
                                        child: Container(
                                            color: const Color(0xFF2D7BD8)),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                SizedBox(
                                  width: compareMode ? 300 : 220,
                                  child: Text(
                                    compareMode
                                        ? '${row.appointmentCount} (${appointmentDelta >= 0 ? '+' : ''}$appointmentDelta) G�� ${row.patientCount} G�� Rs ${row.earned.toStringAsFixed(0)} (${earnedDelta >= 0 ? '+' : ''}${earnedDelta.toStringAsFixed(0)})'
                                        : '${row.appointmentCount} G�� ${row.patientCount} G�� Rs ${row.earned.toStringAsFixed(0)}',
                                    textAlign: TextAlign.right,
                                    style: const TextStyle(
                                      color: Color(0xFF5B789F),
                                      fontWeight: FontWeight.w700,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ).toList(growable: false),
                  );
                },
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _DoctorDirectoryCard extends StatefulWidget {
  final List<Doctor> doctors;
  final ValueChanged<Doctor> onEdit;

  const _DoctorDirectoryCard({
    required this.doctors,
    required this.onEdit,
  });

  @override
  State<_DoctorDirectoryCard> createState() => _DoctorDirectoryCardState();
}

class _DoctorDirectoryCardState extends State<_DoctorDirectoryCard> {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() {
        _query = _searchController.text.trim().toLowerCase();
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = widget.doctors.where((doctor) {
      if (_query.isEmpty) return false;
      final name = doctor.title.toLowerCase();
      final phone = doctor.phone.toLowerCase();
      return name.contains(_query) || phone.contains(_query);
    }).take(6).toList(growable: false);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFD7E3F0)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Doctor Directory',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: Color(0xFF183A67),
              ),
            ),
            const SizedBox(height: 1),
            const Text(
              'Search by name or phone and edit.',
              style: TextStyle(
                color: Color(0xFF6D84A8),
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 5),
            TextBox(
              controller: _searchController,
              placeholder: 'Search doctor name / phone',
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
              prefix: const Padding(
                padding: EdgeInsets.only(left: 6),
                child: Icon(
                  FluentIcons.search,
                  size: 12,
                  color: Color(0xFF6D84A8),
                ),
              ),
            ),
            const SizedBox(height: 5),
            if (widget.doctors.isEmpty)
              const Text(
                'No doctors added yet.',
                style: TextStyle(color: Color(0xFF6D84A8)),
              )
            else if (_query.isEmpty)
              const Text(
                'Type to find a doctor to edit.',
                style: TextStyle(color: Color(0xFF6D84A8)),
              )
            else if (filtered.isEmpty)
              const Text(
                'No matching doctors.',
                style: TextStyle(color: Color(0xFF6D84A8)),
              )
            else
              ...filtered.map((doctor) {
                final displayName =
                    doctor.title.trim().isEmpty ? 'Unnamed doctor' : doctor.title;
                final phone = doctor.phone.trim();
                return Padding(
                  padding: const EdgeInsets.only(bottom: 3),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              displayName,
                              style: const TextStyle(
                                color: Color(0xFF1F446E),
                                fontWeight: FontWeight.w700,
                                fontSize: 12,
                              ),
                            ),
                            Text(
                              phone.isEmpty ? 'Phone: -' : 'Phone: $phone',
                              style: const TextStyle(
                                color: Color(0xFF5B789F),
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Button(
                        style: ButtonStyle(
                          padding: WidgetStateProperty.all(
                            const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                          ),
                        ),
                        onPressed: () => widget.onEdit(doctor),
                        child: const Text('Edit'),
                      ),
                    ],
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }
}

List<
    ({
      Doctor doctor,
      int totalAppointments,
      double completionRate,
      double revenue,
      double avgRevenue,
      int treatmentsCount,
    })> _doctorPerformance({
  required List<Doctor> doctorsList,
  required List<Appointment> scoped,
}) {
  final rows = doctorsList
      .map((doctor) {
        final doctorRows = scoped
            .where((a) => a.operatorsIDs.contains(doctor.id))
            .toList(growable: false);
        final total = doctorRows.length;
        final completed = doctorRows.where((a) => a.isDone).length;
        final revenue = doctorRows.fold<double>(
          0,
          (s, a) => s + a.paid + a.prescriptionPaid,
        );
        final treatmentCount = doctorRows.fold<int>(
          0,
          (s, a) =>
              s + a.selectedTreatments.where((t) => t.trim().isNotEmpty).length,
        );
        return (
          doctor: doctor,
          totalAppointments: total,
          completionRate: total == 0 ? 0.0 : completed / total,
          revenue: revenue,
          avgRevenue: total == 0 ? 0.0 : revenue / total,
          treatmentsCount: treatmentCount,
        );
      })
      .where((row) => row.totalAppointments > 0)
      .toList(growable: false)
    ..sort((a, b) => b.totalAppointments.compareTo(a.totalAppointments));

  return rows;
}

List<Appointment> _scopedForRange({
  required List<Appointment> allAppointments,
  required DateTime selectedDate,
  required String range,
  required DateTime? customRangeStart,
  required DateTime? customRangeEnd,
}) {
  DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  DateTime rangeStart(DateTime anchor, String key) {
    switch (key) {
      case 'today':
        return dateOnly(anchor);
      case 'week':
        return dateOnly(anchor.subtract(const Duration(days: 6)));
      case 'month':
        return DateTime(anchor.year, anchor.month, 1);
      case '6months':
        return DateTime(anchor.year, anchor.month - 5, 1);
      case 'ytd':
        return DateTime(anchor.year, 1, 1);
      case 'year':
        return dateOnly(anchor.subtract(const Duration(days: 364)));
      default:
        return dateOnly(anchor);
    }
  }

  final start = range == 'custom' && customRangeStart != null
      ? dateOnly(customRangeStart)
      : rangeStart(selectedDate, range);
  final endExclusive = range == 'custom' && customRangeEnd != null
      ? dateOnly(customRangeEnd).add(const Duration(days: 1))
      : dateOnly(selectedDate).add(const Duration(days: 1));

  return allAppointments
      .where((a) => !a.date.isBefore(start) && a.date.isBefore(endExclusive))
      .toList(growable: false);
}

List<({Doctor doctor, int doneCount, int totalCount, double earned})>
    _doctorDoneMetrics({
  required List<Doctor> doctorsList,
  required List<Appointment> scoped,
}) {
  return doctorsList
      .map((doctor) {
        final rows = scoped
            .where((a) => a.operatorsIDs.contains(doctor.id))
            .toList(growable: false);
        final doneCount = rows.where((a) => a.isDone).length;
        final earned = rows.fold<double>(
          0,
          (sum, a) => sum + a.paid + a.prescriptionPaid,
        );
        return (
          doctor: doctor,
          doneCount: doneCount,
          totalCount: rows.length,
          earned: earned,
        );
      })
      .where((row) => row.totalCount > 0)
      .toList(growable: false)
    ..sort((a, b) => b.doneCount.compareTo(a.doneCount));
}

List<
    ({
      Doctor doctor,
      int appointments,
      int uniquePatients,
      double completionRate
    })> _doctorWorkloadMetrics({
  required List<Doctor> doctorsList,
  required List<Appointment> scoped,
}) {
  return doctorsList
      .map((doctor) {
        final rows = scoped
            .where((a) => a.operatorsIDs.contains(doctor.id))
            .toList(growable: false);
        final patients = <String>{
          for (final row in rows)
            if (row.patientID != null && row.patientID!.isNotEmpty)
              row.patientID!,
        };
        final done = rows.where((a) => a.isDone).length;
        return (
          doctor: doctor,
          appointments: rows.length,
          uniquePatients: patients.length,
          completionRate: rows.isEmpty ? 0.0 : done / rows.length,
        );
      })
      .where((row) => row.appointments > 0)
      .toList(growable: false)
    ..sort((a, b) => b.appointments.compareTo(a.appointments));
}

class _DoctorsActivityCard extends StatelessWidget {
  final List<({Doctor doctor, int count, double paid})> rows;

  const _DoctorsActivityCard({required this.rows});

  @override
  Widget build(BuildContext context) {
    final maxCount = rows.fold<int>(1, (m, e) => e.count > m ? e.count : m);

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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Doctor Activity Today',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Color(0xFF183A67),
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Legend: Blue bar shows relative appointment load today.',
              style: TextStyle(
                color: Color(0xFF6D84A8),
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 10),
            if (rows.isEmpty)
              const Text(
                'No doctors have appointments today.',
                style: TextStyle(color: Color(0xFF6D84A8)),
              )
            else
              ...rows.take(12).map(
                    (row) => GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => _openDoctorEntryModalV2(
                        context,
                        existingDoctor: row.doctor,
                      ),
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          children: [
                            SizedBox(
                              width: 180,
                              child: Text(
                                row.doctor.title,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Color(0xFF1F446E),
                                  fontWeight: FontWeight.w700,
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
                                    widthFactor: maxCount == 0
                                        ? 0
                                        : row.count / maxCount,
                                    child: Container(
                                        color: const Color(0xFF2D7BD8)),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            SizedBox(
                              width: 140,
                              child: Text(
                                '${row.count} appts | Rs ${row.paid.toStringAsFixed(0)}',
                                textAlign: TextAlign.right,
                                style: const TextStyle(
                                  color: Color(0xFF5B789F),
                                  fontWeight: FontWeight.w700,
                                  fontSize: 12,
                                ),
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
    );
  }
}

class _DoctorPerformanceCard extends StatelessWidget {
  final List<
      ({
        Doctor doctor,
        int totalAppointments,
        double completionRate,
        double revenue,
        double avgRevenue,
        int treatmentsCount,
      })> rows;
  final String selectedRange;
  final ValueChanged<String> onSelectRange;

  const _DoctorPerformanceCard({
    required this.rows,
    required this.selectedRange,
    required this.onSelectRange,
  });

  @override
  Widget build(BuildContext context) {
    Widget tab(String key, String label) {
      final selected = selectedRange == key;
      return GestureDetector(
        onTap: () => onSelectRange(key),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: selected ? const Color(0xFF2D7BD8) : const Color(0xFFEFF4FB),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color:
                  selected ? const Color(0xFF2D7BD8) : const Color(0xFFD6E2F0),
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: selected ? Colors.white : const Color(0xFF355279),
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
        ),
      );
    }

    final maxAppts = rows.fold<int>(
        1, (m, e) => e.totalAppointments > m ? e.totalAppointments : m);
    final maxRevenue =
        rows.fold<double>(1, (m, e) => e.revenue > m ? e.revenue : m);

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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Per Doctor Performance',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Color(0xFF183A67),
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                tab('today', 'Today'),
                tab('week', 'Week'),
                tab('month', 'Month'),
                tab('6months', '6 Months'),
                tab('year', '1 Year'),
                tab('ytd', 'YTD'),
                tab('custom', 'Custom'),
              ],
            ),
            const SizedBox(height: 10),
            const Text(
              'Appts G�� Completion G�� Revenue G�� Avg/Appt G�� Treatments',
              style: TextStyle(
                color: Color(0xFF5B789F),
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 8),
            if (rows.isEmpty)
              const Text(
                'No doctor performance data in selected range.',
                style: TextStyle(color: Color(0xFF6D84A8)),
              )
            else
              ...rows.take(12).map((row) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 170,
                        child: Text(
                          row.doctor.title,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Color(0xFF1F446E),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: Container(
                                      height: 8,
                                      color: const Color(0xFFEAF2FC),
                                      child: FractionallySizedBox(
                                        alignment: Alignment.centerLeft,
                                        widthFactor:
                                            row.totalAppointments / maxAppts,
                                        child: Container(
                                            color: const Color(0xFF2D7BD8)),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                SizedBox(
                                  width: 70,
                                  child: Text(
                                    '${row.totalAppointments} appts',
                                    textAlign: TextAlign.right,
                                    style: const TextStyle(
                                      color: Color(0xFF5B789F),
                                      fontWeight: FontWeight.w700,
                                      fontSize: 11,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Expanded(
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: Container(
                                      height: 8,
                                      color: const Color(0xFFEAF2FC),
                                      child: FractionallySizedBox(
                                        alignment: Alignment.centerLeft,
                                        widthFactor: row.revenue / maxRevenue,
                                        child: Container(
                                            color: const Color(0xFF2BA58D)),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                SizedBox(
                                  width: 70,
                                  child: Text(
                                    'Rs ${row.revenue.toStringAsFixed(0)}',
                                    textAlign: TextAlign.right,
                                    style: const TextStyle(
                                      color: Color(0xFF5B789F),
                                      fontWeight: FontWeight.w700,
                                      fontSize: 11,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      SizedBox(
                        width: 210,
                        child: Text(
                          '${(row.completionRate * 100).toStringAsFixed(0)}% G�� Avg Rs ${row.avgRevenue.toStringAsFixed(0)} G�� ${row.treatmentsCount} tx',
                          textAlign: TextAlign.right,
                          style: const TextStyle(
                            color: Color(0xFF5B789F),
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
    );
  }
}

class _DoctorAppointmentDoneChartCard extends StatelessWidget {
  final List<({Doctor doctor, int doneCount, int totalCount, double earned})>
      rows;
  final String selectedRange;
  final ValueChanged<String> onSelectRange;

  const _DoctorAppointmentDoneChartCard({
    required this.rows,
    required this.selectedRange,
    required this.onSelectRange,
  });

  @override
  Widget build(BuildContext context) {
    Widget tab(String key, String label) {
      final selected = selectedRange == key;
      return GestureDetector(
        onTap: () => onSelectRange(key),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: selected ? const Color(0xFF2D7BD8) : const Color(0xFFEFF4FB),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color:
                  selected ? const Color(0xFF2D7BD8) : const Color(0xFFD6E2F0),
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: selected ? Colors.white : const Color(0xFF355279),
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
        ),
      );
    }

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
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Appointment Done By Doctor',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Color(0xFF183A67),
              ),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                tab('today', 'Today'),
                tab('week', 'Week'),
                tab('month', 'Month'),
                tab('6months', '6 Months'),
                tab('year', '1 Year'),
                tab('ytd', 'YTD'),
                tab('custom', 'Custom'),
              ],
            ),
            const SizedBox(height: 10),
            if (rows.isEmpty)
              const Text(
                'No completion data in selected range.',
                style: TextStyle(color: Color(0xFF6D84A8)),
              )
            else
              ...rows.take(12).map((row) {
                final rate =
                    row.totalCount == 0 ? 0.0 : row.doneCount / row.totalCount;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          row.doctor.title,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Color(0xFF1F446E),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      SizedBox(
                        width: 160,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            height: 8,
                            color: const Color(0xFFEAF2FC),
                            child: FractionallySizedBox(
                              alignment: Alignment.centerLeft,
                              widthFactor: rate.clamp(0.0, 1.0),
                              child: Container(color: const Color(0xFF2D7BD8)),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${row.doneCount}/${row.totalCount}',
                        style: const TextStyle(
                          color: Color(0xFF5B789F),
                          fontWeight: FontWeight.w700,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }
}

class _DoctorWorkloadMetricsCard extends StatelessWidget {
  final List<
      ({
        Doctor doctor,
        int appointments,
        int uniquePatients,
        double completionRate
      })> rows;
  final String selectedRange;
  final ValueChanged<String> onSelectRange;

  const _DoctorWorkloadMetricsCard({
    required this.rows,
    required this.selectedRange,
    required this.onSelectRange,
  });

  @override
  Widget build(BuildContext context) {
    Widget tab(String key, String label) {
      final selected = selectedRange == key;
      return GestureDetector(
        onTap: () => onSelectRange(key),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: selected ? const Color(0xFF2D7BD8) : const Color(0xFFEFF4FB),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color:
                  selected ? const Color(0xFF2D7BD8) : const Color(0xFFD6E2F0),
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: selected ? Colors.white : const Color(0xFF355279),
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
        ),
      );
    }

    final totalAppointments =
        rows.fold<int>(0, (sum, row) => sum + row.appointments);
    final totalPatients =
        rows.fold<int>(0, (sum, row) => sum + row.uniquePatients);
    final avgCompletion = rows.isEmpty
        ? 0.0
        : rows.fold<double>(0, (sum, row) => sum + row.completionRate) /
            rows.length;

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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Doctor Workload Metrics',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Color(0xFF183A67),
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                tab('today', 'Today'),
                tab('week', 'Week'),
                tab('month', 'Month'),
                tab('6months', '6 Months'),
                tab('year', '1 Year'),
                tab('ytd', 'YTD'),
                tab('custom', 'Custom'),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              children: [
                _metricPill('Appointments', '$totalAppointments'),
                _metricPill('Unique Patients', '$totalPatients'),
                _metricPill('Avg Completion',
                    '${(avgCompletion * 100).toStringAsFixed(0)}%'),
              ],
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

class _DoctorDrilldownCard extends StatelessWidget {
  final List<Doctor> doctorsList;
  final String? selectedDoctorId;
  final ValueChanged<String?> onSelectDoctor;
  final List<Appointment> currentRows;
  final List<Appointment> compareRows;
  final DateTime currentStart;
  final DateTime currentEndExclusive;
  final DateTime compareStart;
  final DateTime compareEndExclusive;

  const _DoctorDrilldownCard({
    required this.doctorsList,
    required this.selectedDoctorId,
    required this.onSelectDoctor,
    required this.currentRows,
    required this.compareRows,
    required this.currentStart,
    required this.currentEndExclusive,
    required this.compareStart,
    required this.compareEndExclusive,
  });

  @override
  Widget build(BuildContext context) {
    final currentPatients = <String>{
      for (final a in currentRows)
        if (a.patientID != null && a.patientID!.isNotEmpty) a.patientID!,
    };
    final comparePatients = <String>{
      for (final a in compareRows)
        if (a.patientID != null && a.patientID!.isNotEmpty) a.patientID!,
    };

    final currentEarnings =
        currentRows.fold<double>(0, (s, a) => s + a.paidToDoctor);
    final compareEarnings =
        compareRows.fold<double>(0, (s, a) => s + a.paidToDoctor);

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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Per-Doctor Drilldown',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Color(0xFF183A67),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: 320,
              child: ComboBox<String>(
                isExpanded: true,
                value: selectedDoctorId,
                placeholder: const Text('Select doctor'),
                items: doctorsList
                    .map(
                      (d) => ComboBoxItem<String>(
                        value: d.id,
                        child: Text(d.title.trim().isEmpty
                            ? 'Unnamed doctor'
                            : d.title),
                      ),
                    )
                    .toList(growable: false),
                onChanged: onSelectDoctor,
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              children: [
                _deltaTile(
                  label:
                      '${DateFormat('dd MMM').format(currentStart)} - ${DateFormat('dd MMM').format(currentEndExclusive.subtract(const Duration(days: 1)))} appointments',
                  current: currentRows.length,
                  compare: compareRows.length,
                ),
                _deltaTile(
                  label: 'Unique patients',
                  current: currentPatients.length,
                  compare: comparePatients.length,
                ),
                _deltaTile(
                  label: 'Earnings (Rs)',
                  current: currentEarnings,
                  compare: compareEarnings,
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Compared against ${DateFormat('dd MMM').format(compareStart)} - ${DateFormat('dd MMM').format(compareEndExclusive.subtract(const Duration(days: 1)))}',
              style: const TextStyle(
                color: Color(0xFF6D84A8),
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _deltaTile({
    required String label,
    required num current,
    required num compare,
  }) {
    final delta = current - compare;
    final positive = delta >= 0;
    return SizedBox(
      width: 320,
      child: Container(
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
                label,
                style: const TextStyle(
                  color: Color(0xFF36557C),
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
            ),
            Text(
              '$current (${positive ? '+' : ''}$delta)',
              style: TextStyle(
                color: positive
                    ? const Color(0xFF2BA58D)
                    : const Color(0xFFD6455D),
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

class _ProcedureMixTrendCard extends StatelessWidget {
  final List<({String procedure, int thisMonth, int lastMonth, int delta})>
      rows;

  const _ProcedureMixTrendCard({required this.rows});

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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Procedure Mix Trends (MoM)',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Color(0xFF183A67),
              ),
            ),
            const SizedBox(height: 8),
            if (rows.isEmpty)
              const Text(
                'No procedure data for selected doctor and month.',
                style: TextStyle(color: Color(0xFF6D84A8)),
              )
            else
              ...rows.take(12).map((row) {
                final positive = row.delta >= 0;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          row.procedure,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Color(0xFF1F446E),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      SizedBox(
                        width: 220,
                        child: Text(
                          '${row.thisMonth} vs ${row.lastMonth} (${positive ? '+' : ''}${row.delta})',
                          textAlign: TextAlign.right,
                          style: TextStyle(
                            color: positive
                                ? const Color(0xFF2BA58D)
                                : const Color(0xFFD6455D),
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
    );
  }
}

class _SlotPressureHeatmapCard extends StatelessWidget {
  final Map<int, Map<int, int>> heatmap;

  const _SlotPressureHeatmapCard({required this.heatmap});

  static const _dayNames = {
    DateTime.monday: 'Mon',
    DateTime.tuesday: 'Tue',
    DateTime.wednesday: 'Wed',
    DateTime.thursday: 'Thu',
    DateTime.friday: 'Fri',
    DateTime.saturday: 'Sat',
    DateTime.sunday: 'Sun',
  };

  @override
  Widget build(BuildContext context) {
    int peak = 0;
    for (final row in heatmap.values) {
      for (final count in row.values) {
        if (count > peak) peak = count;
      }
    }
    peak = math.max(1, peak);

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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Slot Pressure Heatmap (Hour x Day)',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Color(0xFF183A67),
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Legend: darker cell means more bookings for that day/hour window.',
              style: TextStyle(
                color: Color(0xFF6D84A8),
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const SizedBox(width: 52),
                      ...List.generate(12, (i) {
                        final hour = 8 + i;
                        return SizedBox(
                          width: 34,
                          child: Text(
                            '$hour',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Color(0xFF6D84A8),
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        );
                      }),
                    ],
                  ),
                  const SizedBox(height: 4),
                  ...List.generate(7, (index) {
                    final weekday = DateTime.monday + index;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 52,
                            child: Text(
                              _dayNames[weekday]!,
                              style: const TextStyle(
                                color: Color(0xFF36557C),
                                fontWeight: FontWeight.w700,
                                fontSize: 12,
                              ),
                            ),
                          ),
                          ...List.generate(12, (i) {
                            final hour = 8 + i;
                            final count = heatmap[weekday]?[hour] ?? 0;
                            final ratio = count / peak;
                            final base = const Color(0xFFEAF2FC);
                            final hot = const Color(0xFF2D7BD8);
                            final color = Color.lerp(base, hot, ratio)!;

                            return Tooltip(
                              message:
                                  '${_dayNames[weekday]} $hour:00 - $count bookings',
                              child: Container(
                                width: 30,
                                height: 20,
                                margin:
                                    const EdgeInsets.symmetric(horizontal: 2),
                                decoration: BoxDecoration(
                                  color: color,
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(
                                      color: const Color(0xFFD3E2F4)),
                                ),
                              ),
                            );
                          }),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
