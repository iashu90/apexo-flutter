// ignore_for_file: unused_element, unused_field, unused_local_variable, unused_import

import 'dart:async';
import 'dart:math' as math;

import 'package:apexo/common_widgets/date_navigator_bar.dart';
import 'package:apexo/common_widgets/export_buttons.dart';
import 'package:apexo/common_widgets/patient_history_modal.dart';
import 'package:apexo/core/theme/app_colors.dart';
import 'package:apexo/core/theme/app_theme.dart';
import 'package:apexo/core/ui/components/app_button.dart';
import 'package:apexo/core/ui/components/top_widget_cards.dart';
import 'package:apexo/core/multi_stream_builder.dart';
import 'package:apexo/features/appointments/appointment_model.dart';
import 'package:apexo/features/appointments/appointment_financials.dart';
import 'package:apexo/features/appointments/appointments_store.dart';
import 'package:apexo/features/checkin/checkin_stage_modals.dart';
import 'package:apexo/features/checkin/checkin_screen.dart';
import 'package:apexo/features/doctors/doctor_model.dart';
import 'package:apexo/features/doctors/doctors_store.dart';
import 'package:apexo/features/expenses/expenses_store.dart';
import 'package:apexo/features/patients/open_add_patient_popup.dart';
import 'package:apexo/core/theme/app_text_theme.dart';
import 'package:apexo/theme/material_date_picker_theme.dart';
import 'package:apexo/utils/csv_export_utility.dart';
import 'package:apexo/utils/pdf_export_utility.dart';
import 'package:apexo/utils/appointment_analytics.dart';
import 'package:apexo/utils/indian_money.dart';
import 'package:apexo/utils/clinic_time.dart';
import 'package:apexo/utils/uuid.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/material.dart' as material;
import 'package:intl/intl.dart';

DateTime doctorPersistedDate = DateTime.now();

class DoctorsScreen extends StatefulWidget {
  const DoctorsScreen({super.key});

  @override
  State<DoctorsScreen> createState() => _DoctorsScreenState();
}

class _DoctorsScreenState extends State<DoctorsScreen> {
  DateTime _selectedDate = DateTime(
    doctorPersistedDate.year,
    doctorPersistedDate.month,
    doctorPersistedDate.day,
  );
  String _handledRange = 'today';
  String _performanceRange = 'month';
  String _doneRange = 'month';
  String _workloadRange = 'week';
  final DateTime _doneMonthAnchor =
      DateTime(DateTime.now().year, DateTime.now().month, 1);
  final bool _compareMode = false;
  DateTime? _customRangeStart;
  DateTime? _customRangeEnd;
  DateTime _topMonthAnchor =
      DateTime(DateTime.now().year, DateTime.now().month, 1);
  bool _showTopRangeLoadingOverlay = false;
  Timer? _topRangeLoadingTimer;

  static DateTime _dateOnly(DateTime input) =>
      DateTime(input.year, input.month, input.day);

  @override
  void initState() {
    super.initState();
    _selectedDate = _dateOnly(doctorPersistedDate);
    _topMonthAnchor = DateTime(_selectedDate.year, _selectedDate.month, 1);
  }

  @override
  void dispose() {
    _topRangeLoadingTimer?.cancel();
    super.dispose();
  }

  void _setTopRangeLoadingOverlay(bool show) {
    if (!mounted) return;
    if (_showTopRangeLoadingOverlay == show) return;
    setState(() {
      _showTopRangeLoadingOverlay = show;
    });
  }

  void _showTopRangeLoading() {
    _topRangeLoadingTimer?.cancel();
    _setTopRangeLoadingOverlay(true);
    _topRangeLoadingTimer = Timer(const Duration(milliseconds: 820), () {
      if (!mounted) return;
      _setTopRangeLoadingOverlay(false);
    });
  }

  List<DateTime> _topMonthOptions(List<Appointment> rows) {
    final months = <DateTime>{
      DateTime(DateTime.now().year, DateTime.now().month, 1),
      ...rows.map((a) => DateTime(a.date.year, a.date.month, 1)),
    }.toList(growable: false)
      ..sort((a, b) => b.compareTo(a));
    return months;
  }

  void _changeDate(int days) {
    _showTopRangeLoading();
    setState(() {
      _selectedDate = _dateOnly(_selectedDate.add(Duration(days: days)));
      _topMonthAnchor = DateTime(_selectedDate.year, _selectedDate.month, 1);
      doctorPersistedDate = _selectedDate;
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
    _showTopRangeLoading();
    setState(() {
      _selectedDate = _dateOnly(picked);
      _topMonthAnchor = DateTime(_selectedDate.year, _selectedDate.month, 1);
      doctorPersistedDate = _selectedDate;
    });
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
    _showTopRangeLoading();
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
    return '${formatClinicDate(_customRangeStart!, pattern: 'dd MMM')} - ${formatClinicDate(_customRangeEnd!, pattern: 'dd MMM')}';
  }

  void _setTopRange(String range) {
    if (range == 'custom') {
      _pickCustomRange(context);
      return;
    }
    _showTopRangeLoading();
    setState(() {
      _handledRange = range;
      _performanceRange = range;
      _doneRange = range;
      _workloadRange = range;
      if (range == 'month') {
        _topMonthAnchor = DateTime(_selectedDate.year, _selectedDate.month, 1);
      }
    });
  }

  Future<void> _openAddDoctorModal() async {
    await _openDoctorEntryModal(context);
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Container(
        color: AppTheme.light.scaffoldBackgroundColor,
        child: ScaffoldPage.scrollable(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
          children: [
            MStreamBuilder(
              streams: [
                doctors.observableMap.stream,
                appointments.observableMap.stream,
              ],
              builder: (context, _) {
                final allDoctors = doctors.present.values
                    .toList(growable: false)
                  ..sort((a, b) =>
                      a.title.toLowerCase().compareTo(b.title.toLowerCase()));
                final allAppointments =
                    appointments.present.values.toList(growable: false);

                final currentStart =
                    _handledRange == 'custom' && _customRangeStart != null
                        ? _customRangeStart!
                        : _handledRange == 'month'
                            ? _topMonthAnchor
                            : _rangeStart(_selectedDate, _handledRange);
                final currentEnd = _handledRange == 'custom' &&
                        _customRangeEnd != null
                    ? _dateOnly(_customRangeEnd!).add(const Duration(days: 1))
                    : _handledRange == 'month'
                        ? DateTime(
                            _topMonthAnchor.year,
                            _topMonthAnchor.month + 1,
                            1,
                          )
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
                            child: _handledRange == 'today'
                                ? DateNavigatorBar(
                                    selectedDate: _selectedDate,
                                    onPrevious: () => _changeDate(-1),
                                    onNext: () => _changeDate(1),
                                    onPick: () => _pickDate(context),
                                    onToday: () {
                                      _showTopRangeLoading();
                                      setState(() {
                                        _selectedDate =
                                            _dateOnly(DateTime.now());
                                        _topMonthAnchor = DateTime(
                                          _selectedDate.year,
                                          _selectedDate.month,
                                          1,
                                        );
                                        doctorPersistedDate = _selectedDate;
                                      });
                                    },
                                  )
                                : _handledRange == 'month'
                                    ? SizedBox(
                                        width: 220,
                                        child: ComboBox<DateTime>(
                                          isExpanded: true,
                                          value: _topMonthAnchor,
                                          items:
                                              _topMonthOptions(allAppointments)
                                                  .map(
                                                    (m) =>
                                                        ComboBoxItem<DateTime>(
                                                      value: m,
                                                      child: Text(
                                                        DateFormat('MMMM yyyy')
                                                            .format(m),
                                                      ),
                                                    ),
                                                  )
                                                  .toList(growable: false),
                                          onChanged: (value) {
                                            if (value == null) return;
                                            _showTopRangeLoading();
                                            setState(() {
                                              _topMonthAnchor = value;
                                              _selectedDate = value;
                                              doctorPersistedDate = value;
                                            });
                                          },
                                        ),
                                      )
                                    : const SizedBox.shrink(),
                          ),
                          Align(
                            alignment: Alignment.centerRight,
                            child: AppButton(
                              onPressed: _openAddDoctorModal,
                              label: 'Add Doctor',
                              leading: const Icon(FluentIcons.add, size: 12),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _TopScopeChip(
                            label: 'Day',
                            selected: _handledRange == 'today',
                            onTap: () => _setTopRange('today'),
                          ),
                          _TopScopeChip(
                            label: 'Month',
                            selected: _handledRange == 'month',
                            onTap: () => _setTopRange('month'),
                          ),
                          _TopScopeChip(
                            label: _handledRange == 'custom'
                                ? _customRangeLabel()
                                : 'Custom',
                            selected: _handledRange == 'custom',
                            onTap: () => _setTopRange('custom'),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        return _DoctorTodayDetailCard(
                          doctors: allDoctors,
                          todaysAppointments: scopedCurrent,
                          selectedDate: _selectedDate,
                          selectedRange: _handledRange,
                        );
                      },
                    ),
                  ],
                );
              },
            ),
          ],
        )),
        if (_showTopRangeLoadingOverlay)
          Positioned.fill(
            child: IgnorePointer(
              child: Container(
                color: const Color(0x220F1F33),
                alignment: Alignment.topCenter,
                padding: const EdgeInsets.only(top: 86),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFD7E3F0)),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x180D2F5B),
                        blurRadius: 10,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        height: 16,
                        width: 16,
                        child: ProgressRing(strokeWidth: 2),
                      ),
                      SizedBox(width: 8),
                      Text(
                        'Loading data...',
                        style: TextStyle(
                          color: Color(0xFF244A77),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

String _doctorTitleCase(String input) {
  final cleaned = input.trim();
  if (cleaned.isEmpty) return cleaned;
  return cleaned
      .split(RegExp(r'\s+'))
      .map((word) => word.isEmpty
          ? word
          : '${word[0].toUpperCase()}${word.length > 1 ? word.substring(1).toLowerCase() : ''}')
      .join(' ');
}

class _TopScopeChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _TopScopeChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: selected ? const Color(0xFF2D7BD8) : Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color:
                  selected ? const Color(0xFF2D7BD8) : const Color(0xFFD7E3F0),
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: selected ? Colors.white : const Color(0xFF36557C),
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
        ),
      ),
    );
  }
}

Future<void> _openDoctorEntryModal(
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
                  child: const SizedBox.shrink(),
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
          AppButton(
            label: 'Cancel',
            onPressed: () => Navigator.pop(dialogContext),
            variant: AppButtonVariant.secondary,
          ),
          AppButton(
            label: isEdit ? 'Save Changes' : 'Add Doctor',
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

        final earned =
            doctorRows.fold<double>(0, (s, a) => s + a.doctorPayableAmount);

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
    if (doctorId != null && !appointment.operatorsIDs.contains(doctorId)) {
      continue;
    }

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
    if (doctorId != null && !appointment.operatorsIDs.contains(doctorId)) {
      continue;
    }
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
      width: 200,
      height: 100,
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
          padding: const EdgeInsets.all(10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF3C5E87),
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                value,
                style: TextStyle(
                  fontSize: 24,
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
            const Row(
              children: [
                Expanded(
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
                  child: Text(
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
                          onTap: () => _openDoctorEntryModal(
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

  Widget _buildDoctorItem(Doctor doctor) {
    final displayName =
        doctor.title.trim().isEmpty ? 'Unnamed doctor' : doctor.title;
    final phone = doctor.phone.trim();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFFF7FBFF),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFFE2ECF8)),
      ),
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
                  phone.isEmpty ? '-' : phone,
                  style: const TextStyle(
                    color: Color(0xFF5B789F),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            width: 72,
            child: AppButton(
              label: 'Edit',
              onPressed: () => widget.onEdit(doctor),
              variant: AppButtonVariant.secondary,
              expanded: true,
            ),
          ),
        ],
      ),
    );
  }

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
    }).toList(growable: true);

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
              'Search to filter or click Edit to update.',
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
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
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
                'Start typing to find a doctor.',
                style: TextStyle(color: Color(0xFF6D84A8)),
              )
            else if (filtered.isEmpty)
              const Text(
                'No matching doctors.',
                style: TextStyle(color: Color(0xFF6D84A8)),
              )
            else
              LayoutBuilder(
                builder: (context, constraints) {
                  final twoCol = constraints.maxWidth >= 560;
                  if (twoCol) {
                    final rows = <Widget>[];
                    for (var i = 0; i < filtered.length; i += 2) {
                      rows.add(
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(child: _buildDoctorItem(filtered[i])),
                            const SizedBox(width: 8),
                            if (i + 1 < filtered.length)
                              Expanded(child: _buildDoctorItem(filtered[i + 1]))
                            else
                              const Expanded(child: SizedBox.shrink()),
                          ],
                        ),
                      );
                      rows.add(const SizedBox(height: 3));
                    }
                    return Column(children: rows);
                  }
                  return Column(
                    children: filtered
                        .map((doctor) => Padding(
                              padding: const EdgeInsets.only(bottom: 3),
                              child: _buildDoctorItem(doctor),
                            ))
                        .toList(growable: false),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Doctor Today Detail Card
// ─────────────────────────────────────────────────────────────────────────────

class _DoctorTodayDetailCard extends StatefulWidget {
  final List<Doctor> doctors;
  final List<Appointment> todaysAppointments;
  final DateTime selectedDate;
  final String selectedRange;

  const _DoctorTodayDetailCard({
    required this.doctors,
    required this.todaysAppointments,
    required this.selectedDate,
    required this.selectedRange,
  });

  @override
  State<_DoctorTodayDetailCard> createState() => _DoctorTodayDetailCardState();
}

class _DoctorTodayDetailCardState extends State<_DoctorTodayDetailCard> {
  final Set<String> _expandedDoctorIds = {};
  bool _isExportingCsv = false;
  bool _isExportingPdf = false;

  Future<void> _openPatientEditor(Appointment appointment) async {
    final patient = appointment.patient;
    if (patient == null) return;
    await openAddPatientPopup(
      context: context,
      existingPatient: patient,
    );
  }

  Future<void> _openTreatmentEditorById(String appointmentId) async {
    final target = appointments.present[appointmentId];
    if (target == null) return;
    await openAppointmentJourneyDialog(
      context,
      target,
      initialStep: 1,
    );
  }

  Future<void> _openPatientHistory(Appointment appointment) async {
    final patient = appointment.patient;
    if (patient == null) return;

    await showPatientHistoryDialog(
      context: context,
      patient: patient,
      rows: patient.patientDetails,
      onEditTreatment: _openTreatmentEditorById,
    );
  }

  String _groupedDateLabel(List<Appointment> groupedAppointments) {
    if (groupedAppointments.isEmpty) {
      return formatClinicDate(widget.selectedDate, pattern: 'dd MMM yyyy');
    }

    final uniqueDates = groupedAppointments
        .map((appointment) => DateTime(
              appointment.date.year,
              appointment.date.month,
              appointment.date.day,
            ))
        .toSet()
        .toList(growable: false)
      ..sort((a, b) => a.compareTo(b));

    if (uniqueDates.length == 1) {
      return formatClinicDate(uniqueDates.first, pattern: 'dd MMM yyyy');
    }

    final sameMonthYear = uniqueDates.every(
      (date) =>
          date.month == uniqueDates.first.month &&
          date.year == uniqueDates.first.year,
    );

    if (sameMonthYear) {
      final dayCsv = uniqueDates
          .map((date) => DateFormat('dd').format(date))
          .join(', ');
      return '$dayCsv ${DateFormat('MMM yyyy').format(uniqueDates.first)}';
    }

    return uniqueDates
        .map((date) => formatClinicDate(date, pattern: 'dd MMM yyyy'))
        .join(', ');
  }

  double _appointmentTreatmentTotal(Appointment appointment) {
    final discountedTotal = appointment.discountType == 'percent'
        ? (appointment.price - (appointment.price * appointment.discount / 100))
            .clamp(0, double.infinity)
        : (appointment.price - appointment.discount).clamp(0, double.infinity);
    return discountedTotal + appointment.prescriptionPrice;
  }

  String _paymentStatusForAppointment(Appointment appointment) {
    final treatmentTotal = _appointmentTreatmentTotal(appointment);
    final paid = appointment.paid + appointment.prescriptionPaid;

    if (treatmentTotal <= 0 && paid <= 0) return 'Free';
    if (treatmentTotal > 0 && paid <= 0) return 'Nil';
    if (paid < treatmentTotal) return 'Partial';
    return 'Paid';
  }

  String _paymentStatusForGroupedAppointments(List<Appointment> appointments) {
    final treatmentTotal = appointments.fold<double>(
      0,
      (sum, appointment) => sum + _appointmentTreatmentTotal(appointment),
    );
    final paid = appointments.fold<double>(
      0,
      (sum, appointment) => sum + appointment.paid + appointment.prescriptionPaid,
    );

    if (treatmentTotal <= 0 && paid <= 0) return 'Free';
    if (treatmentTotal > 0 && paid <= 0) return 'Nil';
    if (paid < treatmentTotal) return 'Partial';
    return 'Paid';
  }

  bool get _showTimeOnly => widget.selectedRange == 'today';
  bool get _groupRowsByPatient =>
      widget.selectedRange == 'month' || widget.selectedRange == 'custom';

  List<({Appointment primary, List<Appointment> rows})> _patientGroupedRows(
    List<Appointment> doctorAppts,
  ) {
    if (!_groupRowsByPatient) {
      return doctorAppts
          .map((row) => (primary: row, rows: <Appointment>[row]))
          .toList(growable: false);
    }

    final grouped = <String, List<Appointment>>{};
    for (final row in doctorAppts) {
      final patientId = row.patientID?.trim() ?? '';
      final key = patientId.isNotEmpty
          ? 'id:$patientId'
          : 'name:${row.title.trim().toLowerCase()}';
      grouped.putIfAbsent(key, () => <Appointment>[]).add(row);
    }

    final result = grouped.values.map((rows) {
      rows.sort((a, b) => b.date.compareTo(a.date));
      return (primary: rows.first, rows: rows);
    }).toList(growable: false)
      ..sort((a, b) => b.primary.date.compareTo(a.primary.date));
    return result;
  }

  List<MapEntry<Doctor, List<Appointment>>> _doctorEntries() {
    final rowsByDoctor = <Doctor, List<Appointment>>{};
    for (final doctor in widget.doctors) {
      final doctorRows = widget.todaysAppointments
          .where((a) =>
              a.operatorsIDs.contains(doctor.id) ||
              a.consultantDoctorID == doctor.id)
          .toList(growable: false);
      if (doctorRows.isNotEmpty) {
        rowsByDoctor[doctor] = doctorRows;
      }
    }

    final doctorEntries = rowsByDoctor.entries.toList(growable: false)
      ..sort((a, b) {
        final byPatients = b.value.length.compareTo(a.value.length);
        if (byPatients != 0) return byPatients;
        return a.key.title.toLowerCase().compareTo(b.key.title.toLowerCase());
      });
    return doctorEntries;
  }

  Future<void> _exportVisibleCsv() async {
    if (_isExportingCsv) return;
    final doctorEntries = _doctorEntries();
    if (doctorEntries.isEmpty) return;

    setState(() => _isExportingCsv = true);
    try {
      final rows = <List<String>>[
        [
          'Date',
          'Doctor',
          'Patient',
          'Treatment',
          'Tooth/Area',
          'Paid',
          'Doctor Fee',
          'Net',
          'Status',
        ],
      ];

      for (final entry in doctorEntries) {
        final doctor = entry.key;
        for (final appointment in entry.value) {
          final end = appointment.date.add(const Duration(minutes: 40));
          final treatment = appointment.selectedTreatments
              .where((t) => t.trim().isNotEmpty)
              .join(', ');
          final tooth = appointment.selectedTeeth.isEmpty
              ? '-'
              : appointment.selectedTeeth.first;
          final paid = appointment.paid + appointment.prescriptionPaid;
          final fee = appointment.doctorPayableAmount;
          final net = paid - fee;
          final paymentStatus = _paymentStatusForAppointment(appointment);

          rows.add([
            formatClinicDate(appointment.date, pattern: 'dd/MM/yyyy'),
            doctor.title.trim().isEmpty
                ? 'Unnamed doctor'
                : _doctorTitleCase(doctor.title),
            appointment.title.trim().isEmpty
                ? 'Unnamed patient'
                : _doctorTitleCase(appointment.title),
            treatment.isEmpty ? '-' : treatment,
            tooth,
            paid.toStringAsFixed(0),
            fee.toStringAsFixed(0),
            net.toStringAsFixed(0),
            paymentStatus,
          ]);
        }
      }

      await CsvExportUtility.saveCsv(
        rows: rows,
        fileName:
            'doctor_activity_${DateFormat('yyyyMMdd').format(widget.selectedDate)}.csv',
      );
    } finally {
      if (mounted) setState(() => _isExportingCsv = false);
    }
  }

  Future<void> _exportVisiblePdf() async {
    if (_isExportingPdf) return;
    final doctorEntries = _doctorEntries();
    if (doctorEntries.isEmpty) return;

    setState(() => _isExportingPdf = true);
    try {
      final rows = <List<String>>[
        [
          'Date',
          'Doctor',
          'Patient',
          'Treatment',
          'Tooth/Area',
          'Paid',
          'Doctor Fee',
          'Net',
          'Status',
        ],
      ];

      for (final entry in doctorEntries) {
        final doctor = entry.key;
        for (final appointment in entry.value) {
          final end = appointment.date.add(const Duration(minutes: 40));
          final treatment = appointment.selectedTreatments
              .where((t) => t.trim().isNotEmpty)
              .join(', ');
          final tooth = appointment.selectedTeeth.isEmpty
              ? '-'
              : appointment.selectedTeeth.first;
          final paid = appointment.paid + appointment.prescriptionPaid;
          final fee = appointment.doctorPayableAmount;
          final net = paid - fee;
          final paymentStatus = _paymentStatusForAppointment(appointment);

          rows.add([
            formatClinicDate(appointment.date, pattern: 'dd/MM/yyyy'),
            doctor.title.trim().isEmpty
                ? 'Unnamed doctor'
                : _doctorTitleCase(doctor.title),
            appointment.title.trim().isEmpty
                ? 'Unnamed patient'
                : _doctorTitleCase(appointment.title),
            treatment.isEmpty ? '-' : treatment,
            tooth,
            'Rs ${paid.toStringAsFixed(0)}',
            'Rs ${fee.toStringAsFixed(0)}',
            'Rs ${net.toStringAsFixed(0)}',
            paymentStatus,
          ]);
        }
      }

      await PdfExportUtility.savePdf(
        title: 'Doctor Activity Export',
        subtitle: formatClinicDate(widget.selectedDate, pattern: 'dd/MM/yyyy'),
        data: rows,
        fileName:
            'doctor_activity_${DateFormat('dd-M-yyyy').format(widget.selectedDate)}.pdf',
      );
    } finally {
      if (mounted) setState(() => _isExportingPdf = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final doctorEntries = _doctorEntries();

    final totalPatients = widget.todaysAppointments.length;
    final revenue = widget.todaysAppointments.fold<double>(
      0,
      (sum, a) => sum + a.paid + a.prescriptionPaid,
    );
    final doctorsFee = widget.todaysAppointments.fold<double>(
      0,
      (sum, a) => sum + a.doctorPayableAmount,
    );
    final netProfit = revenue - doctorsFee;
    final netProfitPct = revenue <= 0 ? 0.0 : (netProfit / revenue) * 100;

    return Column(
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFD7E3F0)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      FluentIcons.health,
                      size: 16,
                      color: Color(0xFF2D7BD8),
                    ),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Doctor Activity',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF183A67),
                        ),
                      ),
                    ),
                    Text(
                      DateFormat('EEEE, dd MMMM yyyy')
                          .format(widget.selectedDate),
                      style: const TextStyle(
                        color: Color(0xFF6D84A8),
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(width: 8),
                    ExportButtons(
                      csvBusy: _isExportingCsv,
                      pdfBusy: _isExportingPdf,
                      onCsv: (_isExportingCsv || doctorEntries.isEmpty) ? null : _exportVisibleCsv,
                      onPdf: (_isExportingPdf || doctorEntries.isEmpty) ? null : _exportVisiblePdf,
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                const Text(
                  'Overview',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF183A67),
                  ),
                ),
                const SizedBox(height: 6),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final cardWidth = (constraints.maxWidth - 24) / 4;
                    return Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        SizedBox(
                          width: cardWidth,
                          child: TopWidgetSmallCard(
                            title: 'Patients Seen',
                            value: NumberFormat.compact(locale: 'en_IN')
                                .format(totalPatients),
                            valueColor: const Color(0xFF1B3557),
                            cardColor: const Color(0xFFFBFDFF),
                            borderColor: const Color(0xFFEAF1FB),
                          ),
                        ),
                        SizedBox(
                          width: cardWidth,
                          child: TopWidgetSmallCard(
                            title: 'Revenue',
                            value: formatIndianShortCurrency(revenue),
                            valueColor: const Color(0xFF2BA58D),
                            cardColor: const Color(0xFFFAFEFC),
                            borderColor: const Color(0xFFE6F4EE),
                          ),
                        ),
                        SizedBox(
                          width: cardWidth,
                          child: TopWidgetSmallCard(
                            title: 'Doctors Fee',
                            value: formatIndianShortCurrency(doctorsFee),
                            valueColor: const Color(0xFFD6455D),
                            cardColor: const Color(0xFFFFFBFC),
                            borderColor: const Color(0xFFF7E8EC),
                          ),
                        ),
                        SizedBox(
                          width: cardWidth,
                          child: TopWidgetSmallCard(
                            title: 'Net Profit',
                            value:
                                '${formatIndianShortCurrency(netProfit)} (${netProfitPct.toStringAsFixed(1)}%)',
                            valueColor: netProfit >= 0
                                ? const Color(0xFF2BA58D)
                                : const Color(0xFFD6455D),
                            cardColor: netProfit >= 0
                                ? const Color(0xFFFAFEFC)
                                : const Color(0xFFFFFBFC),
                            borderColor: netProfit >= 0
                                ? const Color(0xFFE6F4EE)
                                : const Color(0xFFF7E8EC),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
        DecoratedBox(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFD7E3F0)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Doctor List',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF183A67),
                  ),
                ),
                const SizedBox(height: 6),
                const Divider(size: 1),
                if (doctorEntries.isEmpty)
                  Container(
                    width: double.infinity,
                    constraints: const BoxConstraints(minHeight: 220),
                    alignment: Alignment.center,
                    child: const Text(
                      'No doctors entry available',
                      style: TextStyle(color: Color(0xFF8AAAC6)),
                    ),
                  )
                else ...[
                  const SizedBox(height: 10),
                  ...doctorEntries.map((entry) {
                    final doctor = entry.key;
                    final doctorAppts = entry.value;
                    final expanded = _expandedDoctorIds.contains(doctor.id);
                    final earned = doctorAppts.fold<double>(
                      0,
                      (sum, a) => sum + a.paid + a.prescriptionPaid,
                    );
                    final doctorFee = doctorAppts.fold<double>(
                      0,
                      (sum, a) => sum + a.doctorPayableAmount,
                    );
                    final doctorNet = earned - doctorFee;
                    final doctorNetPct =
                        earned <= 0 ? 0.0 : (doctorNet / earned) * 100;
                    final screenWidth = MediaQuery.of(context).size.width;
                    final compact = screenWidth < 1440;
                    final basePatientWidth = compact ? 170.0 : 210.0;
                    final baseTimeWidth = compact ? 120.0 : 140.0;
                    final baseTreatmentWidth = compact ? 170.0 : 200.0;
                    final baseToothWidth = compact ? 90.0 : 110.0;
                    final baseStageWidth = compact ? 90.0 : 110.0;
                    final basePaidWidth = compact ? 100.0 : 110.0;
                    final baseFeeWidth = compact ? 100.0 : 120.0;
                    final baseNetWidth = compact ? 100.0 : 120.0;
                    final baseStatusWidth = compact ? 82.0 : 90.0;
                    final baseActionWidth = compact ? 104.0 : 118.0;
                    final baseTableWidth = basePatientWidth +
                        baseTimeWidth +
                        baseTreatmentWidth +
                        baseToothWidth +
                        baseStageWidth +
                        basePaidWidth +
                        baseFeeWidth +
                        baseNetWidth +
                        baseStatusWidth +
                        baseActionWidth;
                    final minTableWidth =
                        math.max(baseTableWidth, screenWidth - 90);
                    final widthScale = minTableWidth / baseTableWidth;
                    final patientWidth = basePatientWidth * widthScale;
                    final timeWidth = baseTimeWidth * widthScale;
                    final treatmentWidth = baseTreatmentWidth * widthScale;
                    final toothWidth = baseToothWidth * widthScale;
                    final stageWidth = baseStageWidth * widthScale;
                    final paidWidth = basePaidWidth * widthScale;
                    final feeWidth = baseFeeWidth * widthScale;
                    final netWidth = baseNetWidth * widthScale;
                    final statusWidth = baseStatusWidth * widthScale;
                    final actionWidth = baseActionWidth * widthScale;
                    final groupedRows = _patientGroupedRows(doctorAppts);

                    return Container(
                      margin: const EdgeInsets.only(bottom: 6),
                      decoration: const BoxDecoration(
                        border: Border(
                          bottom: BorderSide(
                            color: Color(0xFFEFF4FB),
                            width: 0.8,
                          ),
                        ),
                      ),
                      child: Expander(
                        initiallyExpanded: expanded,
                        onStateChanged: (isExpanded) {
                          setState(() {
                            if (isExpanded) {
                              _expandedDoctorIds.add(doctor.id);
                            } else {
                              _expandedDoctorIds.remove(doctor.id);
                            }
                          });
                        },
                        header: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  doctor.title.trim().isEmpty
                                      ? 'Unnamed doctor'
                                      : _doctorTitleCase(doctor.title),
                                  style: const TextStyle(
                                    color: Color(0xFF143C6B),
                                    fontWeight: FontWeight.w600,
                                    fontSize: 16,
                                  ),
                                ),
                              ),
                              _inlineMetric(
                                'Patients Seen',
                                '${doctorAppts.length}',
                                const Color(0xFF2D7BD8),
                              ),
                              const SizedBox(width: 8),
                              _inlineMetric(
                                'Revenue',
                                formatIndianShortCurrency(earned),
                                const Color(0xFF2BA58D),
                              ),
                              const SizedBox(width: 8),
                              _inlineMetric(
                                'Doctors Fee',
                                formatIndianShortCurrency(doctorFee),
                                const Color(0xFFD6455D),
                              ),
                              const SizedBox(width: 8),
                              _inlineMetric(
                                'Net Profit',
                                '${formatIndianShortCurrency(doctorNet)} (${doctorNetPct.toStringAsFixed(1)}%)',
                                doctorNet >= 0
                                    ? const Color(0xFF2BA58D)
                                    : const Color(0xFFD6455D),
                                width: 186,
                              ),
                            ],
                          ),
                        ),
                        content: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: ConstrainedBox(
                            constraints:
                                BoxConstraints(minWidth: minTableWidth),
                            child: Column(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFEFF5FF),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Row(
                                    children: [
                                      SizedBox(
                                          width: patientWidth,
                                          child: const Text('Patient',
                                              style: TextStyle(
                                                  fontWeight: FontWeight.w700,
                                                  color: Color(0xFF355279)))),
                                      SizedBox(
                                          width: timeWidth,
                                          child: Text(
                                            _showTimeOnly ? 'Time' : 'Date',
                                              style: TextStyle(
                                                  fontWeight: FontWeight.w700,
                                                  color: Color(0xFF355279)))),
                                      SizedBox(
                                          width: treatmentWidth,
                                          child: const Text('Treatment',
                                              style: TextStyle(
                                                  fontWeight: FontWeight.w700,
                                                  color: Color(0xFF355279)))),
                                      SizedBox(
                                          width: toothWidth,
                                          child: const Text('Tooth/Area',
                                              style: TextStyle(
                                                  fontWeight: FontWeight.w700,
                                                  color: Color(0xFF355279)))),
                                      SizedBox(
                                          width: stageWidth,
                                          child: const Text('Stage',
                                              style: TextStyle(
                                                  fontWeight: FontWeight.w700,
                                                  color: Color(0xFF355279)))),
                                      SizedBox(
                                          width: paidWidth,
                                          child: const Text('Paid',
                                              style: TextStyle(
                                                  fontWeight: FontWeight.w700,
                                                  color: Color(0xFF355279)))),
                                      SizedBox(
                                          width: feeWidth,
                                          child: const Text('Fee',
                                              style: TextStyle(
                                                  fontWeight: FontWeight.w700,
                                                  color: Color(0xFF355279)))),
                                      SizedBox(
                                          width: netWidth,
                                          child: const Text('Net',
                                              style: TextStyle(
                                                  fontWeight: FontWeight.w700,
                                                  color: Color(0xFF355279)))),
                                      SizedBox(
                                          width: statusWidth,
                                          child: const Text('Status',
                                              style: TextStyle(
                                                  fontWeight: FontWeight.w700,
                                                  color: Color(0xFF355279)))),
                                      SizedBox(
                                          width: actionWidth,
                                          child: const Text('Actions',
                                              style: TextStyle(
                                                  fontWeight: FontWeight.w700,
                                                  color: Color(0xFF355279)))),
                                    ],
                                  ),
                                ),
                                ...groupedRows.map((groupedRow) {
                                  final appointment = groupedRow.primary;
                                  final groupedAppointments = groupedRow.rows;
                                  final end = appointment.date
                                      .add(const Duration(minutes: 40));
                                  final groupedCount = groupedAppointments.length;
                                  final treatmentSet = groupedAppointments
                                    .expand((a) => a.selectedTreatments)
                                    .map((t) => t.trim())
                                    .where((t) => t.isNotEmpty)
                                    .toSet()
                                    .toList(growable: false);
                                  final treatment = treatmentSet.join(', ');
                                  final toothSet = groupedAppointments
                                    .expand((a) => a.selectedTeeth)
                                    .map((t) => t.trim())
                                    .where((t) => t.isNotEmpty)
                                    .toSet()
                                    .toList(growable: false);
                                  final tooth = toothSet.isEmpty
                                    ? '-'
                                    : toothSet.join(', ');
                                  final stageSet = groupedAppointments
                                    .map((a) => _stageLabel(a))
                                    .toSet();
                                  final stage = stageSet.length > 1
                                    ? 'Mixed'
                                    : _stageLabel(appointment);
                                  final stageColor = _stageColor(stage);
                                  final paid = groupedAppointments.fold<double>(
                                  0,
                                  (sum, a) => sum + a.paid + a.prescriptionPaid,
                                  );
                                  final consultantFee = groupedAppointments.fold<double>(
                                  0,
                                  (sum, a) => sum + a.doctorPayableAmount,
                                  );
                                  final appointmentNet = paid - consultantFee;
                                  final paymentStatus = groupedCount > 1
                                    ? _paymentStatusForGroupedAppointments(
                                      groupedAppointments,
                                    )
                                    : _paymentStatusForAppointment(appointment);
                                  final patientLabel = groupedCount > 1
                                    ? '${appointment.title.trim().isEmpty ? 'Unnamed patient' : _doctorTitleCase(appointment.title)} ($groupedCount records)'
                                    : (appointment.title.trim().isEmpty
                                      ? 'Unnamed patient'
                                      : _doctorTitleCase(appointment.title));

                                  return Container(
                                    margin: const EdgeInsets.only(bottom: 0),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(0),
                                      border: const Border(
                                        bottom: BorderSide(
                                          color: Color(0xFFE2ECF8),
                                        ),
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        SizedBox(
                                          width: patientWidth,
                                          child: Row(
                                            children: [
                                              Expanded(
                                                child: GestureDetector(
                                                  onTap: () =>
                                                      _openPatientEditor(
                                                          appointment),
                                                  child: Text(
                                                    patientLabel,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                    style: const TextStyle(
                                                      color:
                                                          AppColors.textActive,
                                                      fontWeight:
                                                          FontWeight.w700,
                                                      fontSize: 13,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        SizedBox(
                                          width: timeWidth,
                                          child: Text(
                                            _showTimeOnly
                                                ? '${formatClinicDateTime(appointment.date, pattern: 'hh:mm a')} - ${formatClinicDateTime(end, pattern: 'hh:mm a')}'
                                                : groupedCount > 1
                                                ? _groupedDateLabel(groupedAppointments)
                                                    : formatClinicDate(appointment.date, pattern: 'dd MMM yyyy'),
                                            style: const TextStyle(
                                              color: Color(0xFF4D6488),
                                              fontWeight: FontWeight.w600,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ),
                                        SizedBox(
                                          width: treatmentWidth,
                                          child: Text(
                                            treatment.isEmpty ? '-' : treatment,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              color: Color(0xFF34567D),
                                              fontWeight: FontWeight.w600,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ),
                                        SizedBox(
                                          width: toothWidth,
                                          child: Text(
                                            tooth,
                                            style: const TextStyle(
                                              color: Color(0xFF34567D),
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ),
                                        SizedBox(
                                          width: stageWidth,
                                          child: Text(
                                            stage,
                                            style: TextStyle(
                                              color: stageColor,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ),
                                        SizedBox(
                                          width: paidWidth,
                                          child: Text(
                                            '₹${paid.toStringAsFixed(0)}',
                                            style: const TextStyle(
                                              color: Color(0xFF34567D),
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ),
                                        SizedBox(
                                          width: feeWidth,
                                          child: Text(
                                            '₹${consultantFee.toStringAsFixed(0)}',
                                            style: const TextStyle(
                                              color: Color(0xFFD6455D),
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ),
                                        SizedBox(
                                          width: netWidth,
                                          child: Text(
                                            formatIndianShortCurrency(
                                                appointmentNet),
                                            style: TextStyle(
                                              color: appointmentNet >= 0
                                                  ? const Color(0xFF2BA58D)
                                                  : const Color(0xFFD6455D),
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ),
                                        SizedBox(
                                          width: statusWidth,
                                          child: _statusPill(
                                            paymentStatus,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        SizedBox(
                                          width: actionWidth,
                                          child: Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.start,
                                            children: [
                                              Tooltip(
                                                message: 'Patient History',
                                                child: IconButton(
                                                  icon: const Icon(
                                                    FluentIcons.history,
                                                    size: 13,
                                                  ),
                                                  onPressed: () =>
                                                      _openPatientHistory(
                                                          appointment),
                                                ),
                                              ),
                                              const SizedBox(width: 4),
                                              Tooltip(
                                                message: 'Edit treatment',
                                                child: IconButton(
                                                  icon: const Icon(
                                                    FluentIcons.edit,
                                                    size: 14,
                                                  ),
                                                  onPressed: () {
                                                    openAppointmentJourneyDialog(
                                                      context,
                                                      appointment,
                                                      initialStep: 1,
                                                    );
                                                  },
                                                ),
                                              ),
                                            ],
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
                    );
                  }),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  String _stageLabel(Appointment appointment) {
    final stage = normalizeCheckinStage(appointment.checkinStage);
    switch (stage) {
      case 'waiting':
        return 'Waiting';
      case 'treatment':
        return 'Treatment';
      case 'billing':
        return 'Billing';
      case 'complete':
        return 'Completed';
      case 'scheduled':
        return 'Waiting';
      default:
        return appointment.isDone ? 'Completed' : 'Waiting';
    }
  }

  Color _stageColor(String stage) {
    switch (stage) {
      case 'Waiting':
        return const Color(0xFFE09C31);
      case 'Treatment':
        return const Color(0xFF2D7BD8);
      case 'Billing':
        return const Color(0xFF7B61D1);
      case 'Completed':
        return const Color(0xFF2BA58D);
      default:
        return const Color(0xFF5E738F);
    }
  }

  Widget _inlineMetric(String label, String value, Color color,
      {double width = 132}) {
    return SizedBox(
      width: width,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              style: AppTextTheme.textTheme.titleMedium?.copyWith(
                color: color,
                fontWeight: FontWeight.w800,
                fontSize: 16,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              label,
              style: AppTextTheme.textTheme.bodySmall?.copyWith(
                color: const Color(0xFF5D789D),
                fontWeight: FontWeight.w500,
                fontSize: 11,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _statusPill(String text) {
    final normalized = text.trim().toLowerCase();
    final isPaid = normalized == 'paid';
    final isPartial = normalized == 'partial';
    final isNil = normalized == 'nil';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isPaid
            ? const Color(0xFFE7F6EC)
            : isPartial
                ? const Color(0xFFFFF6CC)
                : isNil
                    ? const Color(0xFFFDECEC)
                    : const Color(0xFFEFF2F6),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: TextStyle(
          color: isPaid
              ? const Color(0xFF1E8B66)
              : isPartial
                  ? const Color(0xFF8A6D00)
                  : isNil
                      ? const Color(0xFFB42336)
                      : const Color(0xFF5E738F),
          fontSize: 11,
          fontWeight: FontWeight.w700,
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
  DateTime? monthAnchor,
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
        final month = monthAnchor ?? anchor;
        return DateTime(month.year, month.month, 1);
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
      : range == 'month'
          ? DateTime(start.year, start.month + 1, 1)
          : dateOnly(selectedDate).add(const Duration(days: 1));

  return allAppointments
      .where((a) => !a.date.isBefore(start) && a.date.isBefore(endExclusive))
      .toList(growable: false);
}

List<
    ({
      Doctor doctor,
      int doneCount,
      int totalCount,
      double earned,
      double consultFee,
      double revenue,
    })> _doctorDoneMetrics({
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
        final consultFee = rows.fold<double>(
          0,
          (sum, a) => sum + a.doctorPayableAmount,
        );
        final revenue = rows.fold<double>(
          0,
          (sum, a) => sum + a.price + a.prescriptionPrice,
        );
        return (
          doctor: doctor,
          doneCount: doneCount,
          totalCount: rows.length,
          earned: earned,
          consultFee: consultFee,
          revenue: revenue,
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
                      onTap: () => _openDoctorEntryModal(
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

enum _DoctorDoneSortKey { doctor, appointments, fee, revenue }

class _DoctorAppointmentDoneChartCard extends StatefulWidget {
  final List<
      ({
        Doctor doctor,
        int doneCount,
        int totalCount,
        double earned,
        double consultFee,
        double revenue,
      })> rows;
  final String selectedRange;
  final DateTime monthAnchor;
  final List<DateTime> monthOptions;
  final ValueChanged<DateTime> onMonthChanged;
  final ValueChanged<String> onSelectRange;

  const _DoctorAppointmentDoneChartCard({
    required this.rows,
    required this.selectedRange,
    required this.monthAnchor,
    required this.monthOptions,
    required this.onMonthChanged,
    required this.onSelectRange,
  });

  @override
  State<_DoctorAppointmentDoneChartCard> createState() =>
      _DoctorAppointmentDoneChartCardState();
}

class _DoctorAppointmentDoneChartCardState
    extends State<_DoctorAppointmentDoneChartCard> {
  _DoctorDoneSortKey _sortKey = _DoctorDoneSortKey.appointments;
  bool _ascending = false;
  bool _isExportingCsv = false;
  bool _isExportingPdf = false;

  Future<void> _exportCsv() async {
    if (_isExportingCsv || widget.rows.isEmpty) return;
    setState(() => _isExportingCsv = true);
    try {
      final rows = <List<String>>[
        ['Doctor', 'Appointments', 'Doctor Fee', 'Revenue'],
        ...widget.rows.map(
          (row) => [
            row.doctor.title,
            row.totalCount.toString(),
            row.consultFee.toStringAsFixed(0),
            row.earned.toStringAsFixed(0),
          ],
        ),
      ];
      await CsvExportUtility.saveCsv(
        rows: rows,
        fileName:
            'doctor_appointments_${DateFormat('yyyyMMdd').format(DateTime.now())}.csv',
      );
    } finally {
      if (mounted) setState(() => _isExportingCsv = false);
    }
  }

  Future<void> _exportPdf() async {
    if (_isExportingPdf || widget.rows.isEmpty) return;
    setState(() => _isExportingPdf = true);
    try {
      final rows = <List<String>>[
        ['Doctor', 'Appointments', 'Doctor Fee', 'Revenue'],
        ...widget.rows.map(
          (row) => [
            row.doctor.title,
            row.totalCount.toString(),
            'Rs ${row.consultFee.toStringAsFixed(0)}',
            'Rs ${row.earned.toStringAsFixed(0)}',
          ],
        ),
      ];
      await PdfExportUtility.savePdf(
        title: 'Doctor Appointments Export',
        subtitle: formatClinicDate(DateTime.now(), pattern: 'dd/MM/yyyy'),
        data: rows,
        fileName:
            'doctor_appointments_${DateFormat('yyyyMMdd').format(DateTime.now())}.pdf',
      );
    } finally {
      if (mounted) setState(() => _isExportingPdf = false);
    }
  }

  void _toggleSort(_DoctorDoneSortKey key) {
    setState(() {
      if (_sortKey == key) {
        _ascending = !_ascending;
      } else {
        _sortKey = key;
        _ascending = false;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    Widget tab(String key, String label) {
      final selected = widget.selectedRange == key;
      return GestureDetector(
        onTap: () => widget.onSelectRange(key),
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
        widget.rows.fold<int>(0, (s, r) => s + r.totalCount);
    final totalDoctorFee =
        widget.rows.fold<double>(0, (s, r) => s + r.consultFee);
    final totalRevenue = widget.rows.fold<double>(0, (s, r) => s + r.earned);

    final sortedRows = widget.rows.toList(growable: false)
      ..sort((a, b) {
        int compare;
        switch (_sortKey) {
          case _DoctorDoneSortKey.doctor:
            compare = a.doctor.title
                .toLowerCase()
                .compareTo(b.doctor.title.toLowerCase());
          case _DoctorDoneSortKey.appointments:
            compare = a.totalCount.compareTo(b.totalCount);
          case _DoctorDoneSortKey.fee:
            compare = a.consultFee.compareTo(b.consultFee);
          case _DoctorDoneSortKey.revenue:
            compare = a.earned.compareTo(b.earned);
        }
        return _ascending ? compare : -compare;
      });

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
            Row(
              children: [
                const Icon(FluentIcons.health,
                    size: 16, color: Color(0xFF2D7BD8)),
                const SizedBox(width: 8),
                const Text(
                  'Appointments Done By Doctor',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF183A67),
                  ),
                ),
                const Spacer(),
                ExportButtons(
                  csvBusy: _isExportingCsv,
                  pdfBusy: _isExportingPdf,
                  onCsv: (_isExportingCsv || widget.rows.isEmpty) ? null : _exportCsv,
                  onPdf: (_isExportingPdf || widget.rows.isEmpty) ? null : _exportPdf,
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: _summaryTile(
                    title: 'Appointments',
                    value: NumberFormat.compact(locale: 'en_IN')
                        .format(totalAppointments),
                    valueColor: const Color(0xFF1B3557),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _summaryTile(
                    title: 'Doctors Fee',
                    value: formatIndianShortCurrency(totalDoctorFee),
                    valueColor: const Color(0xFFD6455D),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _summaryTile(
                    title: 'Revenue',
                    value: formatIndianShortCurrency(totalRevenue),
                    valueColor: const Color(0xFF2BA58D),
                  ),
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
                tab('custom', 'Custom'),
              ],
            ),
            if (widget.selectedRange == 'month' &&
                widget.monthOptions.isNotEmpty) ...[
              const SizedBox(height: 8),
              SizedBox(
                width: 200,
                child: ComboBox<DateTime>(
                  isExpanded: true,
                  value: widget.monthAnchor,
                  items: widget.monthOptions
                      .map(
                        (m) => ComboBoxItem<DateTime>(
                          value: m,
                          child: Text(formatClinicDate(m, pattern: 'MMMM yyyy')),
                        ),
                      )
                      .toList(growable: false),
                  onChanged: (v) {
                    if (v != null) widget.onMonthChanged(v);
                  },
                ),
              ),
            ],
            const SizedBox(height: 10),
            if (sortedRows.isEmpty)
              const Text(
                'No completion data in selected range.',
                style: TextStyle(color: Color(0xFF6D84A8)),
              )
            else
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFDCE8F6)),
                ),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 8),
                      decoration: const BoxDecoration(
                        color: Color(0xFFEFF5FF),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            flex: 4,
                            child: _sortableHeader(
                              'Doctor',
                              _DoctorDoneSortKey.doctor,
                            ),
                          ),
                          Expanded(
                            child: _sortableHeader(
                              'Appointments',
                              _DoctorDoneSortKey.appointments,
                            ),
                          ),
                          Expanded(
                            child: _sortableHeader(
                              'Doctors Fee',
                              _DoctorDoneSortKey.fee,
                            ),
                          ),
                          Expanded(
                            child: _sortableHeader(
                              'Revenue',
                              _DoctorDoneSortKey.revenue,
                            ),
                          ),
                        ],
                      ),
                    ),
                    ...sortedRows.take(12).map((row) => Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 9),
                          decoration: const BoxDecoration(
                            border: Border(
                              top: BorderSide(color: Color(0xFFE2ECF8)),
                            ),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                flex: 4,
                                child: Text(
                                  _doctorTitleCase(row.doctor.title),
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Color(0xFF1F446E),
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              Expanded(
                                child: Text(
                                  NumberFormat.compact(locale: 'en_IN')
                                      .format(row.totalCount),
                                  style: const TextStyle(
                                    color: Color(0xFF1F2B40),
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              Expanded(
                                child: Text(
                                  formatIndianShortCurrency(row.consultFee),
                                  style: const TextStyle(
                                    color: Color(0xFFD6455D),
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              Expanded(
                                child: Text(
                                  formatIndianShortCurrency(row.earned),
                                  style: const TextStyle(
                                    color: Color(0xFF2BA58D),
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        )),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _sortableHeader(String title, _DoctorDoneSortKey key) {
    final selected = _sortKey == key;
    return GestureDetector(
      onTap: () => _toggleSort(key),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Color(0xFF355279),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 4),
          Icon(
            selected
                ? (_ascending
                    ? FluentIcons.chevron_up
                    : FluentIcons.chevron_down)
                : FluentIcons.sort,
            size: 10,
            color: selected ? const Color(0xFF2D7BD8) : const Color(0xFF6D84A8),
          ),
        ],
      ),
    );
  }

  Widget _summaryTile({
    required String title,
    required String value,
    required Color valueColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F7FF),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFDCE8F6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: TextStyle(
              color: valueColor,
              fontWeight: FontWeight.w800,
              fontSize: 34,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            title,
            style: const TextStyle(
              color: Color(0xFF4D6488),
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
        ],
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
        currentRows.fold<double>(0, (s, a) => s + a.doctorPayableAmount);
    final compareEarnings =
        compareRows.fold<double>(0, (s, a) => s + a.doctorPayableAmount);

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
                      '${formatClinicDate(currentStart, pattern: 'dd MMM')} - ${formatClinicDate(currentEndExclusive.subtract(const Duration(days: 1)), pattern: 'dd MMM')} appointments',
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
              'Compared against ${formatClinicDate(compareStart, pattern: 'dd MMM')} - ${formatClinicDate(compareEndExclusive.subtract(const Duration(days: 1)), pattern: 'dd MMM')}',
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
                            const base = Color(0xFFEAF2FC);
                            const hot = Color(0xFF2D7BD8);
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

