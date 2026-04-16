import 'dart:async';
import 'dart:io';

import 'package:apexo/common_widgets/date_navigator_bar.dart';
import 'package:apexo/common_widgets/patient_checkin_lookup_dialog.dart';
import 'package:apexo/common_widgets/patients_report_dialog.dart';
import 'package:apexo/common_widgets/export_progress_dialog.dart';
import 'package:apexo/common_widgets/tag_input.dart';
import 'package:apexo/common_widgets/teeth_picker.dart';
import 'package:apexo/features/appointments/open_appointment_panel.dart';
import 'package:apexo/features/appointments/appointment_model.dart';
import 'package:apexo/features/appointments/appointments_store.dart';
import 'package:apexo/features/checkin/odontogram/odontogram_picker.dart';
import 'package:apexo/features/checkin/checkin_stage_modals.dart';
import 'package:apexo/features/checkin/odontogram/tooth_model.dart';
import 'package:apexo/features/doctors/doctors_store.dart';
import 'package:apexo/features/patients/open_add_patient_popup.dart';
import 'package:apexo/features/patients/patient_model.dart';
import 'package:apexo/features/patients/patients_store.dart';
import 'package:apexo/theme/material_date_picker_theme.dart';
import 'package:apexo/utils/uuid.dart';
import 'package:apexo/utils/share_actions.dart';
import 'package:file_picker/file_picker.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' as material;
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:apexo/common_widgets/pick_doctor_dialog.dart';

DateTime checkinPersistedDate = DateTime.now();

String _toTitleCase(String input) {
  final cleaned = input.trim();
  if (cleaned.isEmpty) return cleaned;
  final parts = cleaned.split(RegExp(r'\s+'));
  return parts.map((word) {
    if (word.isEmpty) return word;
    final first = word.substring(0, 1).toUpperCase();
    final rest = word.length > 1 ? word.substring(1).toLowerCase() : '';
    return '$first$rest';
  }).join(' ');
}

Future<bool> _confirmMoveToCompleted(BuildContext context) async {
  final shouldComplete = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => ContentDialog(
      title: const Text('Move to Completed?'),
      content: const Text('This appointment will be moved to Completed.'),
      actions: [
        Button(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(dialogContext, true),
          style: ButtonStyle(
            backgroundColor: WidgetStateProperty.all(const Color(0xFF3B9A42)),
          ),
          child: const Text('Complete'),
        ),
      ],
    ),
  );
  return shouldComplete == true;
}

Future<void> openCheckinAppointmentModal(
  BuildContext context,
  Appointment appointment,
) async {
  final screenWidth = MediaQuery.of(context).size.width;
  final isCheckoutStage =
      appointment.checkinStage.trim().toLowerCase() == 'checkout';
  final popupWidth = screenWidth < 760
      ? screenWidth - 20
      : isCheckoutStage
          ? (screenWidth * 0.75).clamp(760.0, 1000.0)
          : 540.0;
  final normalizedStage = appointment.checkinStage.trim().toLowerCase();
  final stageLabel =
      normalizedStage == 'with_doctor' || normalizedStage == 'treatment'
          ? 'Treatment'
          : normalizedStage == 'checkout'
              ? 'Billing'
              : normalizedStage == 'completed'
                  ? 'Complete'
                  : 'Check-in';
  final patientName = appointment.title.trim().isEmpty
      ? 'Unnamed patient'
      : _toTitleCase(appointment.title);
  final patientAge = appointment.patient?.age ?? 0;
  final patientGender = appointment.patient?.gender == 1 ? 'M' : 'F';
  final patientPhone = (appointment.patient?.phone ?? '').trim();

  await showDialog<void>(
    context: context,
    barrierColor: const Color(0x660A1B33),
    builder: (dialogContext) => SafeArea(
      child: Align(
        alignment: Alignment.center,
        child: Container(
          width: popupWidth,
          height: screenWidth < 760
              ? null
              : MediaQuery.of(context).size.height * 0.9,
          margin: const EdgeInsets.fromLTRB(10, 12, 12, 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            boxShadow: const [
              BoxShadow(
                color: Color(0x2A0D2F5B),
                blurRadius: 24,
                offset: Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            children: [
              Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: appointment.checkinStage == 'completed'
                        ? const [Color(0xFF2BA58D), Color(0xFF1D8D77)]
                        : appointment.checkinStage == 'checkout'
                            ? const [Color(0xFF8B5CF6), Color(0xFF6D3FD2)]
                            : (appointment.checkinStage == 'with_doctor' ||
                                    appointment.checkinStage == 'treatment')
                                ? const [Color(0xFF5A84E6), Color(0xFF3F68CC)]
                                : const [Color(0xFFE4A11B), Color(0xFFD28C02)],
                  ),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(14),
                    topRight: Radius.circular(14),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            stageLabel,
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '$patientName • ${patientAge}y • $patientGender • ${patientPhone.isEmpty ? '-' : patientPhone}',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFFEAF2FF),
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(FluentIcons.cancel, size: 12),
                      style: ButtonStyle(
                        foregroundColor: WidgetStateProperty.all(Colors.white),
                      ),
                      onPressed: () => Navigator.pop(dialogContext),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: _CheckinHistoryDetails(
                  appointment: appointment,
                  rootContext: context,
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class CheckinScreen extends StatefulWidget {
  const CheckinScreen({super.key});

  @override
  State<CheckinScreen> createState() => _CheckinScreenState();
}

class _CheckinScreenState extends State<CheckinScreen> {
  DateTime _selectedDate = _dateOnly(checkinPersistedDate);
  String _selectedDoctor = '__all__';
  Appointment? _selectedAppointment;
  Timer? _waitingTimer;
  final Map<String, bool> _expandedStages = {
    'waiting': true,
    'with_doctor': true,
    'billing_completed': true,
  };

  @override
  void initState() {
    super.initState();
    _waitingTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (!mounted) return;
      setState(() {});
    });
  }

  @override
  void dispose() {
    _waitingTimer?.cancel();
    super.dispose();
  }

  static DateTime _dateOnly(DateTime input) {
    return DateTime(input.year, input.month, input.day);
  }

  void _changeDate(int days) {
    setState(() {
      _selectedDate = _dateOnly(_selectedDate.add(Duration(days: days)));
      checkinPersistedDate = _selectedDate;
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
    setState(() {
      _selectedDate = _dateOnly(picked);
      checkinPersistedDate = _selectedDate;
    });
  }

  DateTime _withCurrentTime(DateTime date) {
    final now = DateTime.now();
    return DateTime(date.year, date.month, date.day, now.hour, now.minute);
  }

  void _checkInPatient(Patient patient) {
    final appointment = Appointment.fromJson({
      'id': uuid(),
      'patientID': patient.id,
      'date': _withCurrentTime(_selectedDate).millisecondsSinceEpoch,
      'isCheckedIn': true,
      'checkinStage': 'waiting',
      'checkedInAt': DateTime.now().millisecondsSinceEpoch,
    });
    appointments.set(appointment);
    setState(() => _selectedAppointment = appointment);
  }

  String _billingCombinedRowStage(Appointment appointment) {
    if (appointment.checkinStage == 'completed' || appointment.isDone) {
      return 'completed';
    }
    return 'checkout';
  }

  Future<void> _openAppointmentPopup(Appointment appointment) async {
    await openCheckinAppointmentModal(context, appointment);
  }

  void _selectAndOpenAppointment(Appointment appointment) {
    setState(() => _selectedAppointment = appointment);
    _openAppointmentPopup(appointment);
  }

  Future<Patient?> _openAddPatientPopup(String query) {
    return openAddPatientPopup(
      context: context,
      initialInput: query,
    );
  }

  Future<void> _openQuickPatientSearchDialog() async {
    await showPatientCheckinLookupDialog(
      context: context,
      selectedDate: _selectedDate,
      title: 'Patient Check-in',
      onAddPatient: _openAddPatientPopup,
      onOpenExisting: (existing) async {
        if (!mounted) return;
        setState(() => _selectedAppointment = existing);
      },
      onCheckInPatient: (patient) async {
        if (!mounted) return;
        _checkInPatient(patient);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
      stream: appointments.observableMap.stream,
      builder: (context, _) {
        return StreamBuilder(
          stream: patients.observableMap.stream,
          builder: (context, __) {
            final todaysAppointments = appointments.forDate(_selectedDate)
              ..sort((a, b) => a.date.compareTo(b.date));

            final doctorOptions = <String>{};
            for (final appt in todaysAppointments) {
              if (appt.operatorsIDs.isEmpty) {
                doctorOptions.add('__unassigned__');
              } else {
                doctorOptions.addAll(appt.operatorsIDs);
              }
            }

            final filtered = todaysAppointments.where((a) {
              if (_selectedDoctor == '__all__') return true;
              if (_selectedDoctor == '__unassigned__')
                return a.operatorsIDs.isEmpty;
              return a.operatorsIDs.contains(_selectedDoctor);
            }).toList(growable: false);

            final waiting = filtered
                .where((a) =>
                    a.checkinStage == 'waiting' || a.checkinStage == 'pending')
                .toList(growable: false);
            final withDoctor = filtered
                .where((a) =>
                    a.checkinStage == 'with_doctor' ||
                    a.checkinStage == 'treatment')
                .toList(growable: false);
            final billingAndCompleted = filtered
                .where(
                  (a) =>
                      a.checkinStage == 'checkout' ||
                      a.checkinStage == 'completed' ||
                      a.isDone,
                )
                .toList(growable: true)
              ..sort((a, b) {
                final aCompleted =
                    a.checkinStage == 'completed' || a.isDone ? 1 : 0;
                final bCompleted =
                    b.checkinStage == 'completed' || b.isDone ? 1 : 0;
                if (aCompleted != bCompleted) return aCompleted - bCompleted;
                return a.date.compareTo(b.date);
              });

            final now = DateTime.now();
            final isToday = _selectedDate.year == now.year &&
                _selectedDate.month == now.month &&
                _selectedDate.day == now.day;
            final screenWidth = MediaQuery.of(context).size.width;
            final isMobile = screenWidth < 760;

            return Container(
              color: const Color(0xFFF3F7FC),
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (isMobile)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              const Text(
                                'Check-in',
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF183A67),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 5,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFEAF2FC),
                                  borderRadius: BorderRadius.circular(999),
                                  border: Border.all(
                                      color: const Color(0xFFD5E5F7)),
                                ),
                                child: Text(
                                  'Patients: ${todaysAppointments.length}',
                                  style: const TextStyle(
                                    color: Color(0xFF1459AD),
                                    fontWeight: FontWeight.w700,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton(
                              onPressed: _openQuickPatientSearchDialog,
                              child: const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(FluentIcons.search, size: 12),
                                  SizedBox(width: 8),
                                  Text('Check-in'),
                                ],
                              ),
                            ),
                          ),
                        ],
                      )
                    else
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text(
                                'Check-in',
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF183A67),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 5,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFEAF2FC),
                                  borderRadius: BorderRadius.circular(999),
                                  border: Border.all(
                                      color: const Color(0xFFD5E5F7)),
                                ),
                                child: Text(
                                  'Patients: ${todaysAppointments.length}',
                                  style: const TextStyle(
                                    color: Color(0xFF1459AD),
                                    fontWeight: FontWeight.w700,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                DateNavigatorBar(
                                  selectedDate: _selectedDate,
                                  onPrevious: () => _changeDate(-1),
                                  onNext: () => _changeDate(1),
                                  onPick: () => _pickDate(context),
                                  onToday: () => setState(() {
                                    _selectedDate = _dateOnly(DateTime.now());
                                    checkinPersistedDate = _selectedDate;
                                  }),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          FilledButton(
                            onPressed: _openQuickPatientSearchDialog,
                            style: ButtonStyle(
                              padding: WidgetStateProperty.all(
                                const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 11,
                                ),
                              ),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(FluentIcons.add, size: 12),
                                SizedBox(width: 8),
                                Text('Check-in'),
                              ],
                            ),
                          ),
                        ],
                      ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _DoctorFilterChip(
                          label: 'All Doctors',
                          selected: _selectedDoctor == '__all__',
                          onTap: () =>
                              setState(() => _selectedDoctor = '__all__'),
                        ),
                        _DoctorFilterChip(
                          label: 'Unassigned',
                          selected: _selectedDoctor == '__unassigned__',
                          onTap: () => setState(
                              () => _selectedDoctor = '__unassigned__'),
                        ),
                        ...doctorOptions
                            .where((id) => id != '__unassigned__')
                            .map((id) {
                          final isSelected = _selectedDoctor == id;
                          return _DoctorFilterChip(
                            label: doctors.get(id)?.title ?? 'Unknown',
                            selected: isSelected,
                            onTap: () => setState(
                              () =>
                                  _selectedDoctor = isSelected ? '__all__' : id,
                            ),
                          );
                        }),
                      ],
                    ),
                    const SizedBox(height: 12),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final stacked = constraints.maxWidth < 1120;

                        final waitingColumn = _WorkflowColumn(
                          title: 'Scheduled / Waiting (${waiting.length})',
                          stage: 'waiting',
                          color: const Color(0xFFE4A11B),
                          rows: waiting,
                          showHistoryAction: false,
                          onSelect: _selectAndOpenAppointment,
                          selectedAppointmentId: _selectedAppointment?.id,
                          expanded: _expandedStages['waiting'] ?? true,
                          onToggleExpanded: () => setState(() {
                            _expandedStages['waiting'] =
                                !(_expandedStages['waiting'] ?? true);
                          }),
                          rowStageBuilder: (a) => a.checkinStage == 'pending'
                              ? 'scheduled'
                              : 'waiting',
                        );

                        final withDoctorColumn = _WorkflowColumn(
                          title: 'Treatment (${withDoctor.length})',
                          stage: 'with_doctor',
                          color: const Color(0xFF2D7BD8),
                          rows: withDoctor,
                          showHistoryAction: false,
                          onSelect: _selectAndOpenAppointment,
                          selectedAppointmentId: _selectedAppointment?.id,
                          expanded: _expandedStages['with_doctor'] ?? true,
                          onToggleExpanded: () => setState(() {
                            _expandedStages['with_doctor'] =
                                !(_expandedStages['with_doctor'] ?? true);
                          }),
                        );

                        final billingColumn = _WorkflowColumn(
                          title:
                              'Billing & Completed (${billingAndCompleted.length})',
                          stage: 'billing_completed',
                          color: const Color(0xFF6C4CCF),
                          rows: billingAndCompleted,
                          rowStageBuilder: _billingCombinedRowStage,
                          onSelect: _selectAndOpenAppointment,
                          selectedAppointmentId: _selectedAppointment?.id,
                          expanded:
                              _expandedStages['billing_completed'] ?? true,
                          onToggleExpanded: () => setState(() {
                            _expandedStages['billing_completed'] =
                                !(_expandedStages['billing_completed'] ?? true);
                          }),
                        );

                        if (stacked) {
                          return Column(
                            children: [
                              waitingColumn,
                              const SizedBox(height: 10),
                              withDoctorColumn,
                              const SizedBox(height: 10),
                              billingColumn,
                            ],
                          );
                        }

                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(child: waitingColumn),
                            const SizedBox(width: 10),
                            Expanded(child: withDoctorColumn),
                            const SizedBox(width: 10),
                            Expanded(child: billingColumn),
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
      },
    );
  }
}

class _DoctorFilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _DoctorFilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF2D7BD8) : const Color(0xFFF4F8FD),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected ? const Color(0xFF2D7BD8) : const Color(0xFFD6E2F0),
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
}

class _WorkflowColumn extends StatelessWidget {
  final String title;
  final String stage;
  final Color color;
  final List<Appointment> rows;
  final String Function(Appointment)? rowStageBuilder;
  final bool showHistoryAction;
  final bool expanded;
  final VoidCallback onToggleExpanded;
  final ValueChanged<Appointment>? onSelect;
  final String? selectedAppointmentId;

  const _WorkflowColumn({
    required this.title,
    required this.stage,
    required this.color,
    required this.rows,
    this.rowStageBuilder,
    required this.expanded,
    required this.onToggleExpanded,
    this.showHistoryAction = false,
    this.onSelect,
    this.selectedAppointmentId,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFD6E2F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(11)),
            ),
            child: Row(
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: Icon(
                    expanded
                        ? FluentIcons.chevron_down
                        : FluentIcons.chevron_right,
                    size: 11,
                  ),
                  onPressed: onToggleExpanded,
                ),
              ],
            ),
          ),
          if (!expanded)
            const Padding(
              padding: EdgeInsets.all(12),
              child: Text(
                'Collapsed',
                style: TextStyle(color: Color(0xFF6D84A8)),
              ),
            )
          else if (rows.isEmpty)
            const Padding(
              padding: EdgeInsets.all(12),
              child: Text(
                'No appointments in this state.',
                style: TextStyle(color: Color(0xFF6D84A8)),
              ),
            )
          else
            ...rows.map(
              (a) => _WorkflowRow(
                appointment: a,
                stage: rowStageBuilder?.call(a) ?? stage,
                showHistoryAction: showHistoryAction,
                selected: selectedAppointmentId == a.id,
                onSelect: onSelect,
              ),
            ),
        ],
      ),
    );
  }
}

class _WorkflowRow extends StatelessWidget {
  final Appointment appointment;
  final String stage;
  final bool showHistoryAction;
  final bool selected;
  final ValueChanged<Appointment>? onSelect;

  const _WorkflowRow({
    required this.appointment,
    required this.stage,
    this.showHistoryAction = false,
    this.selected = false,
    this.onSelect,
  });

  Future<void> _openNextAppointmentPrompt(
    BuildContext context,
    Appointment appointment,
  ) async {
    final p = appointment.patient;
    if (p == null) return;

    DateTime nextDate = DateTime.now().add(const Duration(days: 7));
    material.TimeOfDay nextTime = material.TimeOfDay(
      hour: nextDate.hour,
      minute: nextDate.minute,
    );
    final selectedDoctors = appointment.operatorsIDs.toSet();

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setStateDialog) {
          final doctorRows = doctors.present.values.toList(growable: false)
            ..sort((a, b) =>
                a.title.toLowerCase().compareTo(b.title.toLowerCase()));

          return ContentDialog(
            title: Text(
              'Schedule • ${_toTitleCase(p.title)} • ${p.age}y • ${p.phone.trim().isEmpty ? '-' : p.phone}',
            ),
            content: SizedBox(
              width: 560,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text('Date:',
                          style: TextStyle(fontWeight: FontWeight.w700)),
                      const SizedBox(width: 8),
                      Button(
                        onPressed: () async {
                          final picked = await material.showDatePicker(
                            context: context,
                            initialDate: nextDate,
                            firstDate: DateTime.now(),
                            lastDate: DateTime(2100, 12, 31),
                            builder: apexoDatePickerBuilder(context),
                          );
                          if (picked == null) return;
                          setStateDialog(() {
                            nextDate = DateTime(
                              picked.year,
                              picked.month,
                              picked.day,
                              nextTime.hour,
                              nextTime.minute,
                            );
                          });
                        },
                        child: Text(DateFormat('dd MMM yyyy').format(nextDate)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Text(
                        'Time:',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(width: 8),
                      Button(
                        onPressed: () async {
                          final picked = await material.showTimePicker(
                            context: context,
                            initialTime: nextTime,
                          );
                          if (picked == null) return;
                          setStateDialog(() {
                            nextTime = picked;
                            nextDate = DateTime(
                              nextDate.year,
                              nextDate.month,
                              nextDate.day,
                              picked.hour,
                              picked.minute,
                            );
                          });
                        },
                        child: Text(nextTime.format(context)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Consultant/Doctor',
                    style: TextStyle(
                      color: Color(0xFF355279),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (doctorRows.isEmpty)
                    const Text('No doctors available to assign.')
                  else
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: doctorRows.map((doctor) {
                        final selected = selectedDoctors.contains(doctor.id);
                        return GestureDetector(
                          onTap: () {
                            setStateDialog(() {
                              if (selected) {
                                selectedDoctors.remove(doctor.id);
                              } else {
                                selectedDoctors
                                  ..clear()
                                  ..add(doctor.id);
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
                              doctor.title.trim().isEmpty
                                  ? 'Unnamed doctor'
                                  : doctor.title,
                              style: TextStyle(
                                color: selected
                                    ? Colors.white
                                    : const Color(0xFF355A84),
                                fontWeight: FontWeight.w700,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        );
                      }).toList(growable: false),
                    ),
                ],
              ),
            ),
            actions: [
              Button(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Skip'),
              ),
              FilledButton(
                onPressed: () {
                  final scheduledDate = DateTime(
                    nextDate.year,
                    nextDate.month,
                    nextDate.day,
                    nextTime.hour,
                    nextTime.minute,
                  );
                  Navigator.pop(dialogContext);
                  final nextAppointment = Appointment.fromJson({
                    'patientID': p.id,
                    'operatorsIDs': selectedDoctors.toList(growable: false),
                    'date': scheduledDate.millisecondsSinceEpoch,
                    'checkinStage': 'pending',
                  });
                  appointments.set(nextAppointment);
                },
                child: const Text('Schedule'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _moveStage(BuildContext context) async {
    await CheckinStageModalRouter.openForStage(
      context: context,
      appointment: appointment,
      openTreatmentModal: openCheckinAppointmentModal,
      openBillingModal: openCheckinAppointmentModal,
      openCompleteModal: openCheckinAppointmentModal,
      onUpdated: () => onSelect?.call(appointment),
    );
  }

  Future<void> _undoStage(BuildContext context) async {
    if (stage == 'with_doctor') {
      final shouldMove = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => ContentDialog(
          title: const Text('Move back to Waiting?'),
          content: const Text('Doctor assignment will be removed.'),
          actions: [
            Button(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Move to Waiting'),
            ),
          ],
        ),
      );
      if (shouldMove != true) return;
      appointment.operatorsIDs = [];
      appointment.checkinStage = 'waiting';
      appointment.isDone = false;
      appointments.set(appointment);
      return;
    }

    if (stage == 'checkout') {
      final shouldMove = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => ContentDialog(
          title: const Text('Move back to Treatment?'),
          content:
              const Text('This appointment will be moved back to Treatment.'),
          actions: [
            Button(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Move to Treatment'),
            ),
          ],
        ),
      );
      if (shouldMove != true) return;
      appointment.checkinStage = 'with_doctor';
      appointment.isDone = false;
      appointments.set(appointment);
      return;
    }

    if (stage == 'completed') {
      final shouldMove = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => ContentDialog(
          title: const Text('Move back to Billing?'),
          content:
              const Text('This appointment will be moved back to Billing.'),
          actions: [
            Button(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Move to Billing'),
            ),
          ],
        ),
      );
      if (shouldMove != true) return;
      appointment.checkinStage = 'checkout';
      appointment.isDone = false;
      appointments.set(appointment);
    }
  }

  String _waitingLabel() {
    final started = appointment.checkedInAt;
    if (started == null) return 'Waiting';
    final elapsed = DateTime.now().difference(started);
    if (elapsed.inMinutes < 1) return 'Waiting 0m';
    if (elapsed.inHours < 1) return 'Waiting ${elapsed.inMinutes}m';
    final hours = elapsed.inHours;
    final mins = elapsed.inMinutes.remainder(60);
    return 'Waiting ${hours}h ${mins}m';
  }

  void _openPatientHistoryDialog(BuildContext context) {
    final patient = appointment.patient;
    if (patient == null) return;

    showDialog(
      context: context,
      builder: (_) => Align(
        alignment: Alignment.center,
        child: Container(
          color: Colors.white,
          child: PatientDetailsDialog(
            rows: patient.patientDetails,
            patient: patient,
            hiddenColumns: const [
              'Prescription',
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
    final patientName = appointment.title.trim().isEmpty
        ? 'Unnamed patient'
        : _toTitleCase(appointment.title);
    final doctorsList = appointment.operators.isEmpty
        ? const <String>['Unassigned']
        : appointment.operators.map((d) => d.title).toList(growable: false);

    final phone = appointment.patient?.phone ?? '-';
    final age = appointment.patient?.age ?? 0;
    final rawGender = appointment.patient?.gender;
    final genderLabel = rawGender == 1 ? 'M' : 'F';
    final doctorLabel = doctorsList.join(', ');
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: stage == 'scheduled'
            ? const Color(0xFFFCF4E3) // Mild Orange (Orange 50)
            : stage == 'completed'
                ? const Color.fromARGB(
                    255, 235, 250, 230) // Mild Green (Green 50)
                : Colors.transparent,
        border: const Border(
          top: BorderSide(color: Color(0xFFE2ECF8)),
        ),
      ),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: (stage == 'waiting' || stage == 'scheduled')
            ? () => _moveStage(context)
            : (onSelect == null ? null : () => onSelect!(appointment)),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    patientName,
                    style: const TextStyle(
                      color: Color(0xFF000000),
                      fontWeight: FontWeight.w600,
                      fontSize: 18,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Text(
                        '$age$genderLabel · $phone',
                        style: const TextStyle(
                          color: Color(0xFF6B7280),
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(width: 12),
                      if (stage == 'waiting') ...[
                        const SizedBox(width: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFE8A3),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            _waitingLabel(),
                            style: const TextStyle(
                              color: Color(0xFF7A5A00),
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                      if (stage == 'scheduled') ...[
                        const SizedBox(width: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE0EEFF),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            'Scheduled · ${DateFormat('h:mm a').format(appointment.date)}',
                            style: const TextStyle(
                              color: Color(0xFF1459AD),
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: (stage == 'with_doctor' && selected)
                          ? () async {
                              final pickedDoctorIds = await pickDoctorDialog(
                                context,
                                initialSelected: appointment.operatorsIDs,
                              );
                              if (pickedDoctorIds == null ||
                                  pickedDoctorIds.isEmpty) {
                                return;
                              }
                              appointment.operatorsIDs = pickedDoctorIds;
                              appointments.set(appointment);
                            }
                          : null,
                      child: Row(
                        children: [
                          const Icon(
                            FluentIcons.contact,
                            size: 12,
                            color: Color(0xFF3B82F6),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            doctorLabel,
                            style: const TextStyle(
                              color: Color(0xFF3B82F6),
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (stage != 'waiting' && stage != 'scheduled')
                  Tooltip(
                    message: 'Undo',
                    child: IconButton(
                      icon: const Icon(material.Icons.undo_rounded, size: 18),
                      style: ButtonStyle(
                        padding: WidgetStateProperty.all(
                          const EdgeInsets.all(8),
                        ),
                        shape: WidgetStateProperty.all(
                          RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        backgroundColor:
                            WidgetStateProperty.all(const Color(0xFFFFF4E8)),
                        foregroundColor:
                            WidgetStateProperty.all(const Color(0xFFC97A11)),
                      ),
                      onPressed: () => _undoStage(context),
                    ),
                  ),
                if (stage != 'waiting' && stage != 'scheduled')
                  const SizedBox(width: 8),
                if (stage == 'scheduled')
                  Tooltip(
                    message: 'Check In',
                    child: IconButton(
                      icon: const Icon(material.Icons.person_add_rounded, size: 18),
                      style: ButtonStyle(
                        padding: WidgetStateProperty.all(
                          const EdgeInsets.all(8),
                        ),
                        shape: WidgetStateProperty.all(
                          RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        backgroundColor:
                            WidgetStateProperty.all(const Color(0xFFF1D992)),
                        foregroundColor:
                            WidgetStateProperty.all(const Color(0xFF91721C)),
                      ),
                      onPressed: () => _moveStage(context),
                    ),
                  ),
                if (stage == 'waiting' || stage == 'checkout')
                  Tooltip(
                    message: stage == 'waiting' ? 'Check-in' : 'Complete',
                    child: IconButton(
                      icon: Icon(
                        stage == 'waiting'
                            ? material.Icons.login_rounded
                            : material.Icons.task_alt_rounded,
                        size: 18,
                      ),
                      style: ButtonStyle(
                        padding: WidgetStateProperty.all(
                          const EdgeInsets.all(8),
                        ),
                        shape: WidgetStateProperty.all(
                          RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        backgroundColor: WidgetStateProperty.all(
                          stage == 'waiting'
                              ? const Color(0xFFEAF2FF)
                              : const Color(0xFFE8F8ED),
                        ),
                        foregroundColor: WidgetStateProperty.all(
                          stage == 'waiting'
                              ? const Color(0xFF2D7BD8)
                              : const Color(0xFF2A8D3F),
                        ),
                      ),
                      onPressed: () => _moveStage(context),
                    ),
                  ),
                if (stage == 'completed')
                  Tooltip(
                    message: 'Schedule Appointment',
                    child: IconButton(
                      icon: const Icon(material.Icons.calendar_month, size: 18),
                      style: ButtonStyle(
                        padding: WidgetStateProperty.all(
                          const EdgeInsets.all(8),
                        ),
                        shape: WidgetStateProperty.all(
                          RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        backgroundColor:
                            WidgetStateProperty.all(const Color(0xFFEAF2FF)),
                        foregroundColor:
                            WidgetStateProperty.all(const Color(0xFF2D7BD8)),
                      ),
                      onPressed: () =>
                          _openNextAppointmentPrompt(context, appointment),
                    ),
                  ),
              ],
            ),
            if (showHistoryAction) ...[
              const SizedBox(width: 8),
              Button(
                onPressed: () => _openPatientHistoryDialog(context),
                child: const Text('History'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _CheckinHistoryDetails extends StatefulWidget {
  final Appointment appointment;
  final BuildContext rootContext;

  const _CheckinHistoryDetails({
    required this.appointment,
    required this.rootContext,
  });

  @override
  State<_CheckinHistoryDetails> createState() => _CheckinHistoryDetailsState();
}

class _CheckinHistoryDetailsState extends State<_CheckinHistoryDetails> {
  static bool _sameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  Future<void> _changeDoctor(Appointment appointment) async {
    final pickedDoctorIds = await showDialog<List<String>>(
      context: context,
      builder: (dialogContext) {
        final doctorRows = doctors.present.values.toList(growable: false)
          ..sort(
              (a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
        final selected = appointment.operatorsIDs.toSet();
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            final selectedRows = doctorRows
                .where((d) => selected.contains(d.id))
                .toList(growable: false);
            final otherRows = doctorRows
                .where((d) => !selected.contains(d.id))
                .toList(growable: false);
            return ContentDialog(
              title: Row(
                children: [
                  const Expanded(child: Text('Change Doctors')),
                  IconButton(
                    icon: const Icon(FluentIcons.chrome_close, size: 12),
                    onPressed: () => Navigator.pop(dialogContext),
                  ),
                ],
              ),
              content: SizedBox(
                width: 420,
                child: doctorRows.isEmpty
                    ? const Text('No doctors available to assign.')
                    : ConstrainedBox(
                        constraints: const BoxConstraints(maxHeight: 360),
                        child: SingleChildScrollView(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (selectedRows.isNotEmpty) ...[
                                const Text(
                                  'Selected Doctors',
                                  style: TextStyle(
                                    color: Color(0xFF15803D),
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: selectedRows.map((doctor) {
                                    final doctorName =
                                        doctor.title.trim().isEmpty
                                            ? 'Unnamed doctor'
                                            : doctor.title;
                                    return GestureDetector(
                                      onTap: () {
                                        setStateDialog(() {
                                          selected.remove(doctor.id);
                                        });
                                      },
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 10, vertical: 6),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFDFF7E8),
                                          borderRadius:
                                              BorderRadius.circular(999),
                                          border: Border.all(
                                            color: const Color(0xFF22C55E),
                                          ),
                                        ),
                                        child: Text(
                                          doctorName,
                                          style: const TextStyle(
                                            color: Color(0xFF166534),
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                    );
                                  }).toList(growable: false),
                                ),
                                const SizedBox(height: 10),
                                const Divider(size: 1),
                                const SizedBox(height: 10),
                              ],
                              const Text(
                                'Other Doctors',
                                style: TextStyle(
                                  color: Color(0xFF355A84),
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: otherRows.map((doctor) {
                                  final doctorName = doctor.title.trim().isEmpty
                                      ? 'Unnamed doctor'
                                      : doctor.title;
                                  return GestureDetector(
                                    onTap: () {
                                      setStateDialog(() {
                                        selected.add(doctor.id);
                                      });
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 10, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFEFF4FB),
                                        borderRadius:
                                            BorderRadius.circular(999),
                                        border: Border.all(
                                          color: const Color(0xFFD2E1F2),
                                        ),
                                      ),
                                      child: Text(
                                        doctorName,
                                        style: const TextStyle(
                                          color: Color(0xFF355A84),
                                          fontWeight: FontWeight.w700,
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
              ),
              actions: [
                Button(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(
                      dialogContext, selected.toList(growable: false)),
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );

    if (pickedDoctorIds == null || pickedDoctorIds.isEmpty) return;
    appointment.operatorsIDs = pickedDoctorIds;
    appointments.set(appointment);
  }

  Future<void> _moveCompletedToBilling(Appointment appointment) async {
    final shouldMove = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => ContentDialog(
        title: const Text('Move back to Billing?'),
        content:
            const Text('This appointment will be moved back to Billing stage.'),
        actions: [
          Button(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: ButtonStyle(
              backgroundColor: WidgetStateProperty.all(const Color(0xFFE56E7D)),
            ),
            child: const Text('Billing'),
          ),
        ],
      ),
    );
    if (shouldMove != true) return;
    appointment.checkinStage = 'checkout';
    appointment.isDone = false;
    appointments.set(appointment);
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  Future<void> _openNextAppointmentPrompt(Appointment appointment) async {
    final patient = appointment.patient;
    if (patient == null) return;

    DateTime nextDate = DateTime.now().add(const Duration(days: 7));
    material.TimeOfDay nextTime = material.TimeOfDay(
      hour: nextDate.hour,
      minute: nextDate.minute,
    );
    final selectedDoctors = appointment.operatorsIDs.toSet();

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setStateDialog) {
          final doctorRows = doctors.present.values.toList(growable: false)
            ..sort((a, b) =>
                a.title.toLowerCase().compareTo(b.title.toLowerCase()));

          return ContentDialog(
            title: Text(
              'Schedule • ${_toTitleCase(patient.title)} • ${patient.age}y • ${patient.phone.trim().isEmpty ? '-' : patient.phone}',
            ),
            content: SizedBox(
              width: 560,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text('Date:',
                          style: TextStyle(fontWeight: FontWeight.w700)),
                      const SizedBox(width: 8),
                      Button(
                        onPressed: () async {
                          final picked = await material.showDatePicker(
                            context: context,
                            initialDate: nextDate,
                            firstDate: DateTime.now(),
                            lastDate: DateTime(2100, 12, 31),
                            builder: apexoDatePickerBuilder(context),
                          );
                          if (picked == null) return;
                          setStateDialog(() {
                            nextDate = DateTime(
                              picked.year,
                              picked.month,
                              picked.day,
                              nextTime.hour,
                              nextTime.minute,
                            );
                          });
                        },
                        child: Text(DateFormat('dd MMM yyyy').format(nextDate)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Text(
                        'Time:',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(width: 8),
                      Button(
                        onPressed: () async {
                          final picked = await material.showTimePicker(
                            context: context,
                            initialTime: nextTime,
                          );
                          if (picked == null) return;
                          setStateDialog(() {
                            nextTime = picked;
                            nextDate = DateTime(
                              nextDate.year,
                              nextDate.month,
                              nextDate.day,
                              picked.hour,
                              picked.minute,
                            );
                          });
                        },
                        child: Text(nextTime.format(context)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Consultant/Doctor',
                    style: TextStyle(
                      color: Color(0xFF355279),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (doctorRows.isEmpty)
                    const Text('No doctors available to assign.')
                  else
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: doctorRows.map((doctor) {
                        final selected = selectedDoctors.contains(doctor.id);
                        return GestureDetector(
                          onTap: () {
                            setStateDialog(() {
                              if (selected) {
                                selectedDoctors.remove(doctor.id);
                              } else {
                                selectedDoctors
                                  ..clear()
                                  ..add(doctor.id);
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
                              doctor.title.trim().isEmpty
                                  ? 'Unnamed doctor'
                                  : doctor.title,
                              style: TextStyle(
                                color: selected
                                    ? Colors.white
                                    : const Color(0xFF355A84),
                                fontWeight: FontWeight.w700,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        );
                      }).toList(growable: false),
                    ),
                ],
              ),
            ),
            actions: [
              Button(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Skip'),
              ),
              FilledButton(
                onPressed: () {
                  final scheduledDate = DateTime(
                    nextDate.year,
                    nextDate.month,
                    nextDate.day,
                    nextTime.hour,
                    nextTime.minute,
                  );
                  Navigator.pop(dialogContext);
                  final nextAppointment = Appointment.fromJson({
                    'patientID': patient.id,
                    'operatorsIDs': selectedDoctors.toList(growable: false),
                    'date': scheduledDate.millisecondsSinceEpoch,
                    'checkinStage': 'pending',
                  });
                  appointments.set(nextAppointment);
                },
                child: const Text('Schedule'),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final appointment = widget.appointment;
    final patient = appointment.patient;

    final doctorName = appointment.operators.isEmpty
        ? 'Unassigned'
        : appointment.operators.map((d) => d.title).join(', ');
    final patientNotes = patient?.notes.trim() ?? '';
    final medicalHistoryEntries = <String>{
      ...?patient?.tags,
      ...?patient?.drugHistorySuggestions,
      ...?patient?.maternalHistorySuggestions,
      ...?patient?.habitsSuggestions,
    }.where((entry) => entry.trim().isNotEmpty).toList(growable: false);
    final isCheckout = appointment.checkinStage == 'checkout';
    final pid = appointment.patientID;

    final all = appointments.present.values
        .where((a) => pid != null && pid.isNotEmpty && a.patientID == pid)
        .toList(growable: false)
      ..sort((a, b) => b.date.compareTo(a.date));

    final otherRows = all
        .where((a) => !_sameDay(a.date, appointment.date))
        .take(20)
        .toList(growable: false);

    final lastAppointment = otherRows.isNotEmpty ? otherRows.first : null;

    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isCheckout
                      ? 'Today\'s Appointment Details'
                      : 'Current Appointment Details',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF183A67),
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(bottom: 8),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFE7EA),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFF7A8B1)),
                  ),
                  child: Text(
                    medicalHistoryEntries.isEmpty
                        ? 'Medical History: No history recorded'
                        : 'Medical History: ${medicalHistoryEntries.join(', ')}',
                    style: const TextStyle(
                      color: Color(0xFFC63A4D),
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                ),
                if (!isCheckout)
                  GestureDetector(
                    onTap: () => _changeDoctor(appointment),
                    behavior: HitTestBehavior.opaque,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 6),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text(
                            'Doctor:',
                            style: TextStyle(
                              color: Color(0xFF6D84A8),
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            doctorName.trim().isEmpty
                                ? 'Unnamed doctor'
                                : doctorName,
                            style: const TextStyle(
                              color: Color(0xFF1459AD),
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Icon(FluentIcons.chevron_down, size: 10),
                        ],
                      ),
                    ),
                  ),
                const SizedBox(height: 10),
                if (isCheckout)
                  TodayAppointmentInsightCard(appointment: appointment)
                else
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: _LastAppointmentInsightCard(
                          lastAppointment: lastAppointment,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _PatientJourneyTimeline(
                          appointments: all,
                          excludeDate: appointment.date,
                        ),
                      ),
                    ],
                  ),
                const SizedBox(height: 10),
                if (appointment.checkinStage == 'with_doctor' ||
                    appointment.checkinStage == 'checkout')
                  _CheckinOperativeForm(
                    appointment: appointment,
                    allAppointmentsForPatient: all,
                    showInlineBottomActions: false,
                  )
                else
                  const SizedBox.shrink(),
                if (appointment.checkinStage == 'completed') ...[
                  const SizedBox(height: 8),
                  TodayAppointmentInsightCard(appointment: appointment),
                ],
                const SizedBox(height: 10),
                if (patientNotes.isNotEmpty)
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(bottom: 10),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF7FBFF),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFE2ECF8)),
                    ),
                    child: Text(
                      'Patient Notes: $patientNotes',
                      style: const TextStyle(
                          color: Color(0xFF5F789B), fontSize: 12),
                    ),
                  ),
                if (otherRows.isEmpty) const SizedBox.shrink(),
              ],
            ),
          ),
        ),
        _buildFixedFooterActions(appointment),
      ],
    );
  }

  Widget _buildFixedFooterActions(Appointment appointment) {
    final stage = appointment.checkinStage.trim().toLowerCase();
    if (stage == 'waiting' || stage == 'pending') {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: Color(0xFFE2ECF8))),
        ),
        child: SizedBox(
          width: double.infinity,
          child: FilledButton(
            style: ButtonStyle(
              backgroundColor: WidgetStateProperty.all(const Color(0xFF2D7BD8)),
            ),
            onPressed: () async {
              Navigator.of(context).pop();
              final pickedDoctorIds = await pickDoctorDialog(
                widget.rootContext,
                initialSelected: appointment.operatorsIDs,
              );
              if (pickedDoctorIds == null || pickedDoctorIds.isEmpty) return;
              appointment.operatorsIDs = pickedDoctorIds;
              appointment.checkinStage = 'with_doctor';
              appointment.isDone = false;
              appointment.checkedInAt = DateTime.now();
              appointments.set(appointment);
              if (mounted) setState(() {});
            },
            child: const Text('Check-in'),
          ),
        ),
      );
    }

    if (stage == 'with_doctor') {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: Color(0xFFE2ECF8))),
        ),
        child: Row(
          children: [
            Expanded(
              child: FilledButton(
                style: ButtonStyle(
                  backgroundColor:
                      WidgetStateProperty.all(const Color(0xFFD6455D)),
                  foregroundColor: WidgetStateProperty.all(Colors.white),
                ),
                onPressed: () async {
                  final shouldMove = await showDialog<bool>(
                    context: context,
                    builder: (dialogContext) => ContentDialog(
                      title: const Text('Move back to Waiting?'),
                      content: const Text(
                        'This patient will be moved back to Waiting and doctor assignment will be removed.',
                      ),
                      actions: [
                        Button(
                          onPressed: () => Navigator.pop(dialogContext, false),
                          child: const Text('Cancel'),
                        ),
                        FilledButton(
                          onPressed: () => Navigator.pop(dialogContext, true),
                          child: const Text('Move'),
                        ),
                      ],
                    ),
                  );
                  if (shouldMove != true) return;
                  appointment.checkinStage = 'waiting';
                  appointment.operatorsIDs = [];
                  appointment.isDone = false;
                  appointments.set(appointment);
                  if (mounted) {
                    Navigator.of(context).pop();
                  }
                  if (mounted) setState(() {});
                },
                child: const Text('Move Back to Waiting'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: FilledButton(
                style: ButtonStyle(
                  backgroundColor:
                      WidgetStateProperty.all(const Color(0xFF7C3AED)),
                  foregroundColor: WidgetStateProperty.all(Colors.white),
                ),
                onPressed: () {
                  appointment.checkinStage = 'checkout';
                  appointment.isDone = false;
                  appointments.set(appointment);
                  if (mounted) {
                    Navigator.of(context).pop();
                  }
                  if (mounted) setState(() {});
                },
                child: const Text('Billing'),
              ),
            ),
          ],
        ),
      );
    }

    if (stage == 'checkout') {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: Color(0xFFE2ECF8))),
        ),
        child: Row(
          children: [
            Expanded(
              child: Button(
                onPressed: () {
                  appointment.checkinStage = 'with_doctor';
                  appointment.isDone = false;
                  appointments.set(appointment);
                  if (mounted) {
                    Navigator.of(context).pop();
                  }
                  if (mounted) setState(() {});
                },
                child: const Text('Move Back to Treatment'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: FilledButton(
                style: ButtonStyle(
                  backgroundColor:
                      WidgetStateProperty.all(const Color(0xFF3B9A42)),
                ),
                onPressed: () async {
                  final shouldComplete = await _confirmMoveToCompleted(context);
                  if (!shouldComplete) return;
                  appointment.checkinStage = 'completed';
                  appointment.isDone = true;
                  appointments.set(appointment);
                  if (mounted) {
                    Navigator.of(context).pop();
                  }
                  await _openNextAppointmentPrompt(appointment);
                  if (mounted) setState(() {});
                },
                child: StreamBuilder(
                  stream: appointments.observableMap.stream,
                  builder: (context, _) {
                    final latest = appointments.present.values.firstWhere(
                        (a) => a.id == appointment.id,
                        orElse: () => appointment);
                    final paid = latest.paid;
                    return Text('Collect (₹${paid.toStringAsFixed(0)})');
                  },
                ),
              ),
            ),
          ],
        ),
      );
    }

    if (stage == 'completed') {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: Color(0xFFE2ECF8))),
        ),
        child: Row(
          children: [
            Expanded(
              child: FilledButton(
                style: ButtonStyle(
                  backgroundColor:
                      WidgetStateProperty.all(const Color(0xFFE56E7D)),
                ),
                onPressed: () => _moveCompletedToBilling(appointment),
                child: const Text('Move Back to Billing'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: FilledButton(
                style: ButtonStyle(
                  backgroundColor:
                      WidgetStateProperty.all(const Color(0xFF2D7BD8)),
                ),
                onPressed: () {
                  final patient = appointment.patient;
                  if (patient == null) return;
                  final nextAppointment = Appointment.fromJson({
                    'patientID': patient.id,
                    'operatorsIDs': appointment.operatorsIDs,
                    'date': DateTime.now()
                        .add(const Duration(days: 7))
                        .millisecondsSinceEpoch,
                  });
                  openAppointment(nextAppointment);
                },
                child: const Text('New Appointment'),
              ),
            ),
          ],
        ),
      );
    }

    return const SizedBox.shrink();
  }
}

class _LastAppointmentInsightCard extends StatelessWidget {
  final Appointment? lastAppointment;

  const _LastAppointmentInsightCard({required this.lastAppointment});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      decoration: BoxDecoration(
        color: const Color(0xFFF7FBFF),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE2ECF8)),
      ),
      child: lastAppointment == null
          ? const Text(
              'Last Appointment Summary: no previous appointment found.',
              style: TextStyle(color: Color(0xFF5F789B), fontSize: 12),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Last Appointment Summary',
                  style: TextStyle(
                    color: Color(0xFF2C4E76),
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  DateFormat('dd MMM yyyy • h:mm a')
                      .format(lastAppointment!.date),
                  style: const TextStyle(
                    color: Color(0xFF1F446E),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  lastAppointment!.selectedTreatments.isEmpty
                      ? 'Treatments: -'
                      : 'Treatments: ${lastAppointment!.selectedTreatments.join(', ')}',
                  style:
                      const TextStyle(color: Color(0xFF5F789B), fontSize: 12),
                ),
                const SizedBox(height: 2),
                Text(
                  'Paid: ${lastAppointment!.paid.toStringAsFixed(0)} | Price: ${lastAppointment!.price.toStringAsFixed(0)}',
                  style:
                      const TextStyle(color: Color(0xFF5F789B), fontSize: 12),
                ),
              ],
            ),
    );
  }
}

class TodayAppointmentInsightCard extends StatelessWidget {
  final Appointment appointment;

  const TodayAppointmentInsightCard({super.key, required this.appointment});

  @override
  Widget build(BuildContext context) {
    final treatments = appointment.selectedTreatments
        .where((t) => t.trim().isNotEmpty)
        .join(', ');
    final teeth =
        appointment.selectedTeeth.where((t) => t.trim().isNotEmpty).join(', ');

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      decoration: BoxDecoration(
        color: const Color(0xFFF7FBFF),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE2ECF8)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Today's Appointment Details",
            style: TextStyle(
              color: Color(0xFF2C4E76),
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            DateFormat('dd MMM yyyy • h:mm a').format(appointment.date),
            style: const TextStyle(
              color: Color(0xFF1F446E),
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            treatments.isEmpty ? 'Treatments: -' : 'Treatments: $treatments',
            style: const TextStyle(color: Color(0xFF5F789B), fontSize: 12),
          ),
          const SizedBox(height: 2),
          Text(
            teeth.isEmpty ? 'Teeth: -' : 'Teeth: $teeth',
            style: const TextStyle(color: Color(0xFF5F789B), fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _CheckinOperativeForm extends StatefulWidget {
  final Appointment appointment;
  final List<Appointment> allAppointmentsForPatient;
  final bool showInlineBottomActions;

  const _CheckinOperativeForm({
    required this.appointment,
    required this.allAppointmentsForPatient,
    this.showInlineBottomActions = true,
  });

  @override
  State<_CheckinOperativeForm> createState() => _CheckinOperativeFormState();
}

class _CheckinOperativeFormState extends State<_CheckinOperativeForm> {
  late final TextEditingController _postOpController;
  late final TextEditingController _priceController;
  late final TextEditingController _paidController;
  late final TextEditingController _discountController;

  bool _discountEnabled = false;
  Set<String> _selectedTreatments = {};
  String? _selectedPostOpParent;
  Set<String> _selectedTeeth = {};
  Map<String, ToothState> _teethStates = {};

  static const Map<String, List<String>> _postOpSuggestions = {
    'Post Tooth Extraction': [
      'Bite on the gauze for 30-45 minutes.',
      'Do not spit, rinse, or use a straw for 24 hours.',
      'Eat soft foods and drink cool liquids.',
      'Avoid hot food, smoking, and alcohol.',
      'Take medicines as prescribed.',
      'Apply ice pack outside cheek for swelling (10 minutes on, 10 minutes off).',
      'Rest today and avoid heavy work.',
      'Brush gently, avoid extraction area.',
    ],
    'Bleeding Control': [
      'Bite on gauze for 30-45 mins',
      'Minor oozing is normal for 24h',
      'Do not spit',
      'Apply tea bag if bleeding persists',
    ],
    'Pain Management': [
      'Take first dose before numbness wears off',
      'Ibuprofen 400-600mg every 6h',
      'Alternate Tylenol/Advil',
      'Avoid Aspirin',
    ],
    'Swelling & Inflammation': [
      'Ice pack: 20 mins on / 20 mins off',
      'Keep head elevated while sleeping',
      'Swelling peaks at 48-72 hours',
      'Warm compress after 48 hours',
    ],
    'Activity Restrictions': [
      'Rest for the remainder of the day',
      'No heavy lifting/exercise for 48h',
      'Avoid bending over',
    ],
    'Diet & Nutrition': [
      'Soft foods only (Yogurt, Soup, Mashed Potatoes)',
      'Cold/Room temp foods only for 24h',
      'Chew on the opposite side',
      'High protein/Hydrate well',
    ],
    'Oral Hygiene': [
      'No rinsing for the first 24h',
      'Gentle warm salt water rinse (Day 2)',
      'Brush other teeth carefully',
      'Do not disturb the surgical site',
    ],
    'Habits to Avoid': [
      'No Straws',
      'No Smoking for 72h',
      'No Alcohol',
      'No Vaping',
    ],
    'Suture (Stitch) Care': [
      'Dissolvable: will fall out in 5-10 days',
      'Non-dissolvable: return in 1 week for removal',
      'Do not pull on loose ends',
    ],
    'Medicated Rinses/Antibiotics': [
      'Chlorhexidine rinse 2x daily',
      'Finish the full course of antibiotics',
      'Apply prescribed topical gel with Q-tip',
    ],
    'Warning Signs': [
      'Uncontrolled bleeding',
      'Severe pain not relieved by meds',
      'Fever or chills',
      'Persistent numbness after 6 hours',
    ],
  };

  static const List<String> _allToothIds = [
    '18',
    '17',
    '16',
    '15',
    '14',
    '13',
    '12',
    '11',
    '21',
    '22',
    '23',
    '24',
    '25',
    '26',
    '27',
    '28',
    '48',
    '47',
    '46',
    '45',
    '44',
    '43',
    '42',
    '41',
    '31',
    '32',
    '33',
    '34',
    '35',
    '36',
    '37',
    '38',
  ];

  @override
  void initState() {
    super.initState();
    final a = widget.appointment;
    _postOpController = TextEditingController(text: a.postOpNotes);
    _priceController = TextEditingController(
        text: a.price == 0 ? '' : a.price.toStringAsFixed(0));
    _paidController = TextEditingController(
        text: a.paid == 0 ? '' : a.paid.toStringAsFixed(0));
    _discountController = TextEditingController(
        text: a.discount == 0 ? '' : a.discount.toStringAsFixed(0));
    _discountEnabled = a.discount > 0;
    _selectedTreatments = a.selectedTreatments.toSet();
    _selectedTeeth = a.selectedTeeth.toSet();
    _teethStates = {
      for (final id in _allToothIds) id: ToothState(toothId: id),
    };
    for (final id in _selectedTeeth) {
      if (!_teethStates.containsKey(id)) {
        _teethStates[id] = ToothState(toothId: id);
      }
      _teethStates[id]!.surfaces[ToothSurface.occlusal] = TreatmentType.filling;
    }
  }

  @override
  void dispose() {
    _postOpController.dispose();
    _priceController.dispose();
    _paidController.dispose();
    _discountController.dispose();
    super.dispose();
  }

  List<String> _topTreatmentsForPatient() {
    final counts = <String, int>{};
    for (final appointment in widget.allAppointmentsForPatient) {
      for (final treatment in appointment.selectedTreatments) {
        final key = treatment.trim();
        if (key.isEmpty) continue;
        counts[key] = (counts[key] ?? 0) + 1;
      }
    }
    final rows = counts.entries.toList(growable: false)
      ..sort((a, b) => b.value.compareTo(a.value));
    return rows.take(10).map((e) => e.key).toList(growable: false);
  }

  List<String> _topTreatmentsAcrossClinic() {
    final counts = <String, int>{};
    for (final appointment in appointments.present.values) {
      for (final treatment in appointment.selectedTreatments) {
        final key = treatment.trim();
        if (key.isEmpty) continue;
        counts[key] = (counts[key] ?? 0) + 1;
      }
    }
    final rows = counts.entries.toList(growable: false)
      ..sort((a, b) => b.value.compareTo(a.value));
    return rows.take(10).map((e) => e.key).toList(growable: false);
  }

  Future<void> _confirmDoneToggle() async {
    final a = widget.appointment;
    if (a.isDone) {
      a.checkinStage = 'checkout';
      setState(() => a.isDone = false);
      appointments.set(a);
      return;
    }

    final paymentMode = a.treatmentGpayPaid ? 'UPI' : 'Cash';
    final discountLabel = a.discount <= 0
        ? 'No discount'
        : a.discountType == 'percent'
            ? '${a.discount.toStringAsFixed(0)}%'
            : 'Rs ${a.discount.toStringAsFixed(0)}';
    final treatmentLabel =
        a.selectedTreatments.where((t) => t.trim().isNotEmpty).join(', ');

    final shouldComplete = await showDialog<bool>(
      context: context,
      builder: (context) => ContentDialog(
        title: const Text('Complete appointment?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Price: Rs ${a.price.toStringAsFixed(0)}'),
            Text('Paid: Rs ${a.paid.toStringAsFixed(0)}'),
            Text(
              'Balance: Rs ${(a.price - a.paid).clamp(0, double.infinity).toStringAsFixed(0)}',
            ),
            Text('Payment Mode: $paymentMode'),
            Text('Discount: $discountLabel'),
            Text('Treatment: ${treatmentLabel.isEmpty ? '-' : treatmentLabel}'),
            const SizedBox(height: 8),
            const Text('This will move the appointment to completed list.'),
          ],
        ),
        actions: [
          Button(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: ButtonStyle(
              backgroundColor: WidgetStateProperty.all(const Color(0xFF2BA58D)),
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Complete'),
          ),
        ],
      ),
    );

    if (shouldComplete != true) return;
    a.checkinStage = 'completed';
    setState(() => a.isDone = true);
    appointments.set(a);
    await _openNextAppointmentPrompt(a);
  }

  Future<void> _openNextAppointmentPrompt(Appointment appointment) async {
    final patient = appointment.patient;
    if (patient == null) return;

    DateTime nextDate = DateTime.now().add(const Duration(days: 7));
    material.TimeOfDay nextTime = material.TimeOfDay(
      hour: nextDate.hour,
      minute: nextDate.minute,
    );
    final selectedDoctors = appointment.operatorsIDs.toSet();

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setStateDialog) {
          final doctorRows = doctors.present.values.toList(growable: false)
            ..sort((a, b) =>
                a.title.toLowerCase().compareTo(b.title.toLowerCase()));

          return ContentDialog(
            title: Text(
              'Schedule • ${_toTitleCase(patient.title)} • ${patient.age}y • ${patient.phone.trim().isEmpty ? '-' : patient.phone}',
            ),
            content: SizedBox(
              width: 560,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text('Date:',
                          style: TextStyle(fontWeight: FontWeight.w700)),
                      const SizedBox(width: 8),
                      Button(
                        onPressed: () async {
                          final picked = await material.showDatePicker(
                            context: context,
                            initialDate: nextDate,
                            firstDate: DateTime.now(),
                            lastDate: DateTime(2100, 12, 31),
                            builder: apexoDatePickerBuilder(context),
                          );
                          if (picked == null) return;
                          setStateDialog(() {
                            nextDate = DateTime(
                              picked.year,
                              picked.month,
                              picked.day,
                              nextTime.hour,
                              nextTime.minute,
                            );
                          });
                        },
                        child: Text(DateFormat('dd MMM yyyy').format(nextDate)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Text(
                        'Time:',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(width: 8),
                      Button(
                        onPressed: () async {
                          final picked = await material.showTimePicker(
                            context: context,
                            initialTime: nextTime,
                          );
                          if (picked == null) return;
                          setStateDialog(() {
                            nextTime = picked;
                            nextDate = DateTime(
                              nextDate.year,
                              nextDate.month,
                              nextDate.day,
                              picked.hour,
                              picked.minute,
                            );
                          });
                        },
                        child: Text(nextTime.format(context)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Consultant/Doctor',
                    style: TextStyle(
                      color: Color(0xFF355279),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (doctorRows.isEmpty)
                    const Text('No doctors available to assign.')
                  else
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: doctorRows.map((doctor) {
                        final selected = selectedDoctors.contains(doctor.id);
                        return GestureDetector(
                          onTap: () {
                            setStateDialog(() {
                              if (selected) {
                                selectedDoctors.remove(doctor.id);
                              } else {
                                selectedDoctors
                                  ..clear()
                                  ..add(doctor.id);
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
                              doctor.title.trim().isEmpty
                                  ? 'Unnamed doctor'
                                  : doctor.title,
                              style: TextStyle(
                                color: selected
                                    ? Colors.white
                                    : const Color(0xFF355A84),
                                fontWeight: FontWeight.w700,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        );
                      }).toList(growable: false),
                    ),
                ],
              ),
            ),
            actions: [
              Button(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Skip'),
              ),
              FilledButton(
                onPressed: () {
                  final scheduledDate = DateTime(
                    nextDate.year,
                    nextDate.month,
                    nextDate.day,
                    nextTime.hour,
                    nextTime.minute,
                  );
                  Navigator.pop(dialogContext);
                  final nextAppointment = Appointment.fromJson({
                    'patientID': patient.id,
                    'operatorsIDs': selectedDoctors.toList(growable: false),
                    'date': scheduledDate.millisecondsSinceEpoch,
                    'checkinStage': 'pending',
                  });
                  appointments.set(nextAppointment);
                },
                child: const Text('Schedule'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _moveBackToWaiting() async {
    final shouldMove = await showDialog<bool>(
      context: context,
      builder: (context) => ContentDialog(
        title: const Text('Move back to Waiting?'),
        content: const Text(
          'This patient will be moved back to Waiting and doctor assignment will be removed.',
        ),
        actions: [
          Button(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Move to Waiting'),
          ),
        ],
      ),
    );
    if (shouldMove != true) return;
    final a = widget.appointment;
    a.operatorsIDs = [];
    a.checkinStage = 'waiting';
    a.isDone = false;
    appointments.set(a);
  }

  Future<void> _moveBackToWithDoctor() async {
    final shouldMove = await showDialog<bool>(
      context: context,
      builder: (context) => ContentDialog(
        title: const Text('Move back to Treatment?'),
        content:
            const Text('This patient will be moved back to Treatment stage.'),
        actions: [
          Button(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Move to Treatment'),
          ),
        ],
      ),
    );
    if (shouldMove != true) return;
    final a = widget.appointment;
    a.checkinStage = 'with_doctor';
    a.isDone = false;
    appointments.set(a);
  }

  @override
  Widget build(BuildContext context) {
    final a = widget.appointment;
    final isWithDoctor = a.checkinStage == 'with_doctor';
    final isCheckout = a.checkinStage == 'checkout';

    if (isCheckout) {
      return _CheckoutPaymentCard(
        appointment: a,
        priceController: _priceController,
        paidController: _paidController,
        discountController: _discountController,
        discountEnabled: _discountEnabled,
        onToggleDiscount: (value) => setState(() => _discountEnabled = value),
        onCollectFullBalance: () {
          final discount = a.discount;
          final discountedTotal = (a.discountType == 'percent'
                  ? (a.price - (a.price * discount / 100))
                      .clamp(0, double.infinity)
                  : (a.price - discount).clamp(0, double.infinity))
              .toDouble();
          _paidController.text = discountedTotal.toStringAsFixed(0);
          a.paid = discountedTotal;
          appointments.set(a);
          setState(() {});
        },
      );
    }

    final topTreatments = _topTreatmentsForPatient();
    final globalTopTreatments = _topTreatmentsAcrossClinic();
    final mergedTopTreatments = [
      ...topTreatments,
      ...globalTopTreatments,
    ].toSet().take(10).toList(growable: false);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFF8FBFF), Color(0xFFF1F7FF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFD8E7F8)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x120D2F5B),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isWithDoctor)
            const Text(
              'Treatment',
              style: TextStyle(
                color: Color(0xFF2C4E76),
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
          if (isWithDoctor) const SizedBox(height: 14),
          if (isWithDoctor)
            LayoutBuilder(
              builder: (context, constraints) {
                final firstColumn = Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    InfoLabel(
                      label: 'Teeth:',
                      child: TeethPicker(
                        selectedTeeth: _selectedTeeth,
                        isAdult: (a.patient?.age ?? 0) >= 13,
                        onChanged: (teeth) {
                          setState(() {
                            _selectedTeeth = teeth;
                            for (final id in teeth) {
                              _teethStates.putIfAbsent(
                                id,
                                () => ToothState(toothId: id),
                              );
                            }
                            a.selectedTeeth = teeth.toList(growable: false);
                            appointments.set(a);
                          });
                        },
                      ),
                    ),
                    const SizedBox(height: 10),
                    InfoLabel(
                      label: 'Diagnosis:',
                      child: _CheckinSearchableTagInput(
                        initialValues: a.diagnosis,
                        suggestions: allDiagnosis,
                        placeholder: 'Add diagnosis...',
                        onChanged: (values) {
                          a.diagnosis = values;
                          appointments.set(a);
                        },
                      ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: allDiagnosis
                          .take(16)
                          .map(
                            (diagnosis) => _quickChip(
                              label: diagnosis,
                              selected: a.diagnosis.contains(diagnosis),
                              onTap: () {
                                setState(() {
                                  final updated =
                                      a.diagnosis.toList(growable: true);
                                  if (updated.contains(diagnosis)) {
                                    updated.remove(diagnosis);
                                  } else {
                                    updated.add(diagnosis);
                                  }
                                  a.diagnosis = updated;
                                  appointments.set(a);
                                });
                              },
                            ),
                          )
                          .toList(growable: false),
                    ),
                    const SizedBox(height: 16),
                    InfoLabel(
                      label: 'Treatment:',
                      child: _CheckinSearchableTagInput(
                        initialValues:
                            _selectedTreatments.toList(growable: false),
                        suggestions: allTreatments
                            .map((t) => t.name)
                            .toList(growable: false),
                        placeholder: 'Add treatment...',
                        onChanged: (values) {
                          _selectedTreatments = values.toSet();
                          a.selectedTreatments = values;
                          appointments.set(a);
                          setState(() {});
                        },
                      ),
                    ),
                    if (mergedTopTreatments.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Text(
                        topTreatments.isNotEmpty
                            ? 'Top 10 treatments (includes patient history):'
                            : 'Top 10 provided treatments:',
                        style: TextStyle(
                          color: Color(0xFF5A7397),
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: mergedTopTreatments
                            .map(
                              (t) => _quickChip(
                                label: t,
                                selected: _selectedTreatments.contains(t),
                                onTap: () {
                                  setState(() {
                                    if (_selectedTreatments.contains(t)) {
                                      _selectedTreatments.remove(t);
                                    } else {
                                      _selectedTreatments.add(t);
                                    }
                                    a.selectedTreatments = _selectedTreatments
                                        .toList(growable: false);
                                    appointments.set(a);
                                  });
                                },
                              ),
                            )
                            .toList(growable: false),
                      ),
                    ],
                    const SizedBox(height: 10),
                    InfoLabel(
                      label: 'Treatment Price:',
                      child: CupertinoTextField(
                        controller: _priceController,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                        ],
                        prefix: const Padding(
                          padding: EdgeInsets.only(left: 10),
                          child: Text('₹',
                              style: TextStyle(color: Color(0xFF355279))),
                        ),
                        placeholder: 'Treatment price',
                        onChanged: (value) {
                          a.price = double.tryParse(value) ?? 0;
                          appointments.set(a);
                        },
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [100, 200, 500, 1000, 2000, 2500]
                          .map(
                            (v) => Button(
                              style: ButtonStyle(
                                backgroundColor: WidgetStateProperty.all(
                                  const Color(0xFFEAF2FC),
                                ),
                              ),
                              onPressed: () {
                                _priceController.text = '$v';
                                a.price = v.toDouble();
                                appointments.set(a);
                                setState(() {});
                              },
                              child: Text('₹$v'),
                            ),
                          )
                          .toList(growable: false),
                    ),
                  ],
                );

                final secondColumn = Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    InfoLabel(
                      label: 'Post-operative notes:',
                      child: CupertinoTextField(
                        controller: _postOpController,
                        minLines: 4,
                        maxLines: 8,
                        onChanged: (value) {
                          a.postOpNotes = value;
                          appointments.set(a);
                        },
                        placeholder: 'Post-operative notes',
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: _postOpSuggestions.keys
                          .map(
                            (parent) => _quickChip(
                              label: parent,
                              selected: _selectedPostOpParent == parent,
                              selectedColor: const Color(0xFFDCEBFF),
                              selectedTextColor: const Color(0xFF134F9D),
                              normalColor: const Color(0xFFEFF5FF),
                              normalTextColor: const Color(0xFF355A84),
                              onTap: () {
                                setState(() => _selectedPostOpParent = parent);
                              },
                            ),
                          )
                          .toList(growable: false),
                    ),
                    if (_selectedPostOpParent != null &&
                        _postOpSuggestions[_selectedPostOpParent!] != null) ...[
                      const SizedBox(height: 14),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF6FAFF),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFDCE8F8)),
                        ),
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: _postOpSuggestions[_selectedPostOpParent!]!
                              .map(
                                (child) => _quickChip(
                                  label: child,
                                  selectedColor: const Color(0xFFFFEAD8),
                                  selectedTextColor: const Color(0xFF9A4A00),
                                  normalColor: const Color(0xFFFFF4E8),
                                  normalTextColor: const Color(0xFF8A5B2F),
                                  onTap: () {
                                    final parent = _selectedPostOpParent;
                                    if (parent == null) return;
                                    final parentLine = '- $parent';
                                    final childLine = '  - $child';
                                    final current =
                                        _postOpController.text.trim();
                                    if (current.contains(
                                            '$parentLine\n$childLine') ||
                                        current.contains('\n$childLine')) {
                                      return;
                                    }
                                    _postOpController.text = current
                                            .contains(parentLine)
                                        ? '$current\n$childLine'
                                        : (current.isEmpty
                                            ? '$parentLine\n$childLine'
                                            : '$current\n$parentLine\n$childLine');
                                    a.postOpNotes = _postOpController.text;
                                    appointments.set(a);
                                  },
                                ),
                              )
                              .toList(growable: false),
                        ),
                      ),
                    ],
                    if (widget.showInlineBottomActions) ...[
                      const SizedBox(height: 18),
                      Row(
                        children: [
                          Expanded(
                            child: FilledButton(
                              style: ButtonStyle(
                                backgroundColor: WidgetStateProperty.all(
                                  const Color(0xFF2BA58D),
                                ),
                                foregroundColor:
                                    WidgetStateProperty.all(Colors.white),
                              ),
                              onPressed: () {
                                showDialog<bool>(
                                  context: context,
                                  builder: (dialogContext) => ContentDialog(
                                    title: const Text('Move to Billing?'),
                                    content: const Text(
                                      'This appointment will be moved to Billing stage.',
                                    ),
                                    actions: [
                                      Button(
                                        onPressed: () =>
                                            Navigator.pop(dialogContext, false),
                                        child: const Text('Cancel'),
                                      ),
                                      FilledButton(
                                        onPressed: () =>
                                            Navigator.pop(dialogContext, true),
                                        child: const Text('Billing'),
                                      ),
                                    ],
                                  ),
                                ).then((confirmed) {
                                  if (confirmed != true) return;
                                  a.checkinStage = 'checkout';
                                  a.isDone = false;
                                  appointments.set(a);
                                  if (mounted) {
                                    Navigator.of(context).maybePop();
                                  }
                                });
                              },
                              child: const Text('Billing'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Button(
                              onPressed: _moveBackToWaiting,
                              child: const Text('Move Back to Waiting'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                );

                return Column(
                  children: [
                    firstColumn,
                    const SizedBox(height: 16),
                    secondColumn,
                  ],
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _quickChip({
    required String label,
    bool selected = false,
    Color selectedColor = const Color(0xFFDDEBFF),
    Color normalColor = const Color(0xFFEAF2FC),
    Color selectedTextColor = const Color(0xFF1459AD),
    Color normalTextColor = const Color(0xFF2F5B88),
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: selected ? selectedColor : normalColor,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected ? const Color(0xFF2D7BD8) : const Color(0xFFD5E5F7),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? selectedTextColor : normalTextColor,
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _CheckoutPaymentCard extends StatefulWidget {
  final Appointment appointment;
  final TextEditingController priceController;
  final TextEditingController paidController;
  final TextEditingController discountController;
  final bool discountEnabled;
  final ValueChanged<bool> onToggleDiscount;
  final VoidCallback onCollectFullBalance;

  const _CheckoutPaymentCard({
    required this.appointment,
    required this.priceController,
    required this.paidController,
    required this.discountController,
    required this.discountEnabled,
    required this.onToggleDiscount,
    required this.onCollectFullBalance,
  });

  @override
  State<_CheckoutPaymentCard> createState() => _CheckoutPaymentCardState();
}

class _CheckoutPaymentCardState extends State<_CheckoutPaymentCard> {
  static const Duration _receiptPdfBuildTimeout = Duration(seconds: 30);
  String _paymentMode = 'Cash';
  final TextEditingController _consultantChargeController =
      TextEditingController();
  DateTime _paymentDate = DateTime.now();
  int _receiptExportSequence = 0;
  String _discountMode = 'flat';
  double _basePrice = 0;
  String? _selectedConsultantDoctorId;

  @override
  void initState() {
    super.initState();
    final a = widget.appointment;
    _paymentMode = a.treatmentGpayPaid ? 'UPI' : 'Cash';
    _discountMode = a.discountType == 'percent' ? 'percent' : 'flat';
    _basePrice = a.price;
    _selectedConsultantDoctorId = a.consultantDoctorID;
    _consultantChargeController.text =
        a.priceToPayDoctor <= 0 ? '' : a.priceToPayDoctor.toStringAsFixed(0);
  }

  @override
  void dispose() {
    _consultantChargeController.dispose();
    super.dispose();
  }

  void _recalculatePrice() {
    final a = widget.appointment;
    final double discount = widget.discountEnabled
        ? (double.tryParse(widget.discountController.text.trim()) ?? 0)
        : 0;

    a.discount = discount;
    a.discountType = _discountMode;
    a.price = _basePrice;
    appointments.set(a);
    setState(() {});
  }

  ButtonStyle _pillStyle(
      {required bool selected, Color accent = const Color(0xFF2D7BD8)}) {
    return ButtonStyle(
      padding: WidgetStateProperty.all(
        const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      ),
      backgroundColor: WidgetStateProperty.all(
        selected ? accent.withValues(alpha: 0.12) : const Color(0xFFF8FBFF),
      ),
      shape: WidgetStateProperty.all(
        RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(
            color: selected ? accent : const Color(0xFFD8E3F1),
          ),
        ),
      ),
    );
  }

  String _safeName(String source) {
    final compact = source.trim().isEmpty ? 'patient' : source.trim();
    return compact.replaceAll(RegExp(r'[^a-zA-Z0-9]+'), '_');
  }

  String _nextReceiptLogTag() {
    _receiptExportSequence += 1;
    return 'receipt-${DateTime.now().millisecondsSinceEpoch}-$_receiptExportSequence';
  }

  void _logReceiptExport(String tag, String message,
      [Object? error, StackTrace? stackTrace]) {
    debugPrint('[Export][$tag] $message');
    if (error != null) {
      debugPrint('[Export][$tag] ERROR: $error');
    }
    if (stackTrace != null) {
      debugPrint('[Export][$tag] STACK: $stackTrace');
    }
  }

  void _showReceiptExportError(String message) {
    if (!mounted) return;
    displayInfoBar(
      context,
      builder: (ctx, close) => InfoBar(
        title: const Text('Receipt export failed'),
        content: Text(message),
        severity: InfoBarSeverity.error,
        action: IconButton(
          icon: const Icon(FluentIcons.clear),
          onPressed: close,
        ),
      ),
    );
  }

  Iterable<List<int>> _chunkBytes(List<int> bytes, int chunkSize) sync* {
    for (var offset = 0; offset < bytes.length; offset += chunkSize) {
      final end = (offset + chunkSize < bytes.length)
          ? offset + chunkSize
          : bytes.length;
      yield bytes.sublist(offset, end);
    }
  }

  Future<void> _writeReceiptPdfWithRetry({
    required String target,
    required List<int> bytes,
    required ExportProgressController progress,
    required String logTag,
  }) async {
    final tempFile = File('$target.tmp');
    const maxAttempts = 3;

    for (var attempt = 1; attempt <= maxAttempts; attempt++) {
      IOSink? sink;
      try {
        _logReceiptExport(logTag,
            'Receipt PDF write attempt $attempt started: $target (${bytes.length} bytes)');
        if (await tempFile.exists()) {
          await tempFile.delete();
        }

        sink = tempFile.openWrite();
        await sink.addStream(
            Stream<List<int>>.fromIterable(_chunkBytes(bytes, 128 * 1024)));
        await sink.flush();
        await sink.close();
        sink = null;
        await tempFile.openRead().drain<void>();

        if (!progress.isCancelled) {
          final targetFile = File(target);
          if (await targetFile.exists()) {
            await targetFile.delete();
          }
          await tempFile.rename(target);
          _logReceiptExport(
              logTag, 'Receipt PDF write finished successfully: $target');
        }
        return;
      } catch (error, stackTrace) {
        _logReceiptExport(logTag, 'Receipt PDF write attempt $attempt failed',
            error, stackTrace);
        await sink?.close();
        if (attempt == maxAttempts) rethrow;
        await Future<void>.delayed(Duration(milliseconds: 200 * attempt));
      } finally {
        await sink?.close();
        if (await tempFile.exists() && progress.isCancelled) {
          await tempFile.delete();
        }
      }
    }
  }

  pw.Document _buildReceiptPdf() {
    final a = widget.appointment;
    final patient = a.patient;
    final discount = a.discount;
    final discountedTotal = a.discountType == 'percent'
        ? (a.price - (a.price * discount / 100)).clamp(0, double.infinity)
        : (a.price - discount).clamp(0, double.infinity);
    final paid = double.tryParse(widget.paidController.text.trim()) ?? a.paid;
    final balance = (discountedTotal - paid).clamp(0, double.infinity);
    final treatmentLabel =
        a.selectedTreatments.where((t) => t.trim().isNotEmpty).join(', ');
    final doc = pw.Document();
    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(24),
        build: (context) => [
          pw.Text(
            'INVOICE / PAYMENT RECEIPT',
            style: pw.TextStyle(
              fontSize: 21,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.blue900,
            ),
          ),
          pw.SizedBox(height: 12),
          pw.Container(
            width: double.infinity,
            padding: const pw.EdgeInsets.all(12),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.grey300),
              borderRadius: pw.BorderRadius.circular(8),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'Dr Nowfar Dental Clinic',
                      style: pw.TextStyle(
                        fontSize: 16,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.blue900,
                      ),
                    ),
                    pw.SizedBox(height: 3),
                    pw.Text('Patient ID: ${a.patientID ?? '-'}'),
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text('Patient ID: ${a.patientID ?? '-'}'),
                    pw.Text(
                        'Invoice ID: VC-${DateTime.now().millisecondsSinceEpoch % 10000}'),
                  ],
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 12),
          pw.Container(
            width: double.infinity,
            padding: const pw.EdgeInsets.all(12),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.grey300),
              borderRadius: pw.BorderRadius.circular(8),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('Bill To:',
                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 6),
                pw.Text(a.title.trim().isEmpty ? 'Unnamed patient' : a.title),
                pw.Text(
                    'Phone: ${patient?.phone ?? '-'} | Age: ${patient?.age ?? 0}'),
                pw.Text('Doctor: Dr Nowfar'),
              ],
            ),
          ),
          pw.SizedBox(height: 12),
          pw.TableHelper.fromTextArray(
            headerDecoration:
                const pw.BoxDecoration(color: PdfColors.blueGrey50),
            cellAlignment: pw.Alignment.centerLeft,
            headers: const ['Details', 'Description', 'Cost', 'Amount'],
            data: [
              [
                DateFormat('dd MMM yyyy').format(_paymentDate),
                treatmentLabel.isEmpty ? '-' : treatmentLabel,
                'Rs ${a.price.toStringAsFixed(0)}',
                'Rs ${paid.toStringAsFixed(0)}',
              ],
            ],
          ),
          pw.SizedBox(height: 12),
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(
                child: pw.Container(
                  padding: const pw.EdgeInsets.all(10),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.green50,
                    borderRadius: pw.BorderRadius.circular(8),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'Payment Summary',
                        style: pw.TextStyle(
                          color: PdfColors.green800,
                          fontSize: 14,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.SizedBox(height: 6),
                      pw.Text('Amount Paid: Rs ${paid.toStringAsFixed(0)}'),
                      pw.Text('Outstanding: Rs ${balance.toStringAsFixed(0)}'),
                      pw.Text(
                          'Payment Status: ${balance <= 0 ? 'PAID' : 'DUE'}'),
                    ],
                  ),
                ),
              ),
              pw.SizedBox(width: 10),
              pw.Expanded(
                child: pw.Container(
                  padding: const pw.EdgeInsets.all(10),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.grey100,
                    borderRadius: pw.BorderRadius.circular(8),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                          'Treatment Cost: Rs ${a.price.toStringAsFixed(0)}'),
                      pw.Text(
                        'Discount: ${discount <= 0 ? '-' : (a.discountType == 'percent' ? '-${discount.toStringAsFixed(0)}%' : '-Rs ${discount.toStringAsFixed(0)}')}',
                      ),
                      pw.Text(
                          'Net Total: Rs ${discountedTotal.toStringAsFixed(0)}'),
                      pw.Text('Paid: Rs ${paid.toStringAsFixed(0)}'),
                      pw.Text(
                          'TOTAL: Rs ${discountedTotal.toStringAsFixed(0)}'),
                    ],
                  ),
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 12),
          pw.Text('Payment History',
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 6),
          pw.TableHelper.fromTextArray(
            headerDecoration:
                const pw.BoxDecoration(color: PdfColors.blueGrey50),
            headers: const ['Date', 'Reference', 'Mode', 'Amount'],
            data: [
              [
                DateFormat('dd MMM yyyy').format(_paymentDate),
                'TX-${DateTime.now().millisecondsSinceEpoch % 1000000}',
                _paymentMode,
                'Rs ${paid.toStringAsFixed(0)}',
              ],
            ],
          ),
          pw.SizedBox(height: 12),
          pw.Text(
              'Consultant Charge: Rs ${widget.appointment.priceToPayDoctor.toStringAsFixed(0)}'),
          pw.SizedBox(height: 24),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text('Device: Reception',
                  style: const pw.TextStyle(fontSize: 10)),
              pw.Text('Dentice Regemens',
                  style: const pw.TextStyle(fontSize: 10)),
              pw.Text('Dr Nowfar Dental Clinic',
                  style: const pw.TextStyle(fontSize: 10)),
            ],
          ),
        ],
      ),
    );
    return doc;
  }

  Future<void> _downloadReceiptPdf() async {
    final nowLabel =
        DateFormat('dd_MMM-yyyy').format(DateTime.now()).toLowerCase();
    final ageLabel = widget.appointment.patient?.age ?? 0;
    final patientName = _safeName(widget.appointment.title);
    final fileName = '${patientName}_${ageLabel}_$nowLabel.pdf';
    final logTag = _nextReceiptLogTag();
    try {
      await runWithExportProgressDialog<void>(
        context: context,
        title: 'Preparing receipt PDF',
        task: (progress) async {
          _logReceiptExport(logTag, 'Receipt export started');
          progress.setProgress(0.2);
          List<int> bytes;
          try {
            bytes = await _buildReceiptPdf()
                .save()
                .timeout(_receiptPdfBuildTimeout);
          } on TimeoutException {
            throw StateError('PDF generation timed out. Please try again.');
          }
          if (progress.isCancelled) return;
          progress.setProgress(0.6);
          final savePath = await FilePicker.platform.saveFile(
            dialogTitle: 'Save payment receipt',
            fileName: fileName,
          );
          if (savePath == null ||
              savePath.trim().isEmpty ||
              progress.isCancelled) {
            _logReceiptExport(logTag, 'Receipt export cancelled before write');
            return;
          }
          final target = savePath.toLowerCase().endsWith('.pdf')
              ? savePath
              : '$savePath.pdf';
          await _writeReceiptPdfWithRetry(
            target: target,
            bytes: bytes,
            progress: progress,
            logTag: logTag,
          );
          progress.setProgress(1.0);
          _logReceiptExport(logTag, 'Receipt export completed');
        },
      );
    } catch (error, stackTrace) {
      _logReceiptExport(
          logTag, 'Receipt export surfaced error to user', error, stackTrace);
      _showReceiptExportError('$error');
    }
  }

  Future<void> _printReceipt() async {
    final doc = _buildReceiptPdf();
    try {
      await Printing.layoutPdf(onLayout: (_) async => doc.save());
    } catch (_) {
      // Print cancelled or virtual printer error – ignore
    }
  }

  String _composeReceiptShareMessage() {
    final a = widget.appointment;
    final patientName =
        a.title.trim().isEmpty ? 'Patient' : _toTitleCase(a.title);
    final paid = double.tryParse(widget.paidController.text.trim()) ?? a.paid;
    final treatmentCost = a.price;
    final balance = (treatmentCost - paid).clamp(0, double.infinity);
    final status = balance <= 0 ? 'Paid' : 'Due';
    final treatmentCompleted = a.selectedTreatments
        .where((t) => t.trim().isNotEmpty)
        .join('-+-')
        .trim();

    return 'Hello $patientName,\n\n'
        'This is a message from Dr. Nowfar Dental Clinic. We are reaching out to provide a summary of your recent visit.\n\n'
        'Treatment History Summary\n\n'
        'Last Visit: ${DateFormat('dd MMM yyyy').format(a.date)}\n'
        'Treatment Completed: ${treatmentCompleted.isEmpty ? '-' : treatmentCompleted}\n'
        'Treatment Cost: Rs ${treatmentCost.toStringAsFixed(0)}\n'
        'Paid: Rs ${paid.toStringAsFixed(0)}\n'
        'Balance: Rs ${balance.toStringAsFixed(0)}\n'
        'Status: $status\n\n'
        'Dr. Nowfar Dental Clinic\n'
        'Address: 15, Kamaraj St, Senthamarai Nagar, Muthialpet, Puducherry, 605003, India\n'
        'Phone: +91 89035 61075\n'
        'Website: drnowfardental.in\n'
        'Google Maps: https://maps.app.goo.gl/KJNqKbk3U9VujcCKA';
  }

  Future<void> _openShareOptions() async {
    final message = _composeReceiptShareMessage();
    final patient = widget.appointment.patient;
    final email = patient?.email.trim() ?? '';
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => ContentDialog(
        title: const Text('Share Receipt'),
        content: Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            FilledButton(
              onPressed: () async {
                try {
                  await openWhatsApp(patient?.phone ?? '', message);
                } catch (_) {}
              },
              child: const Text('WhatsApp'),
            ),
            Button(
              onPressed: email.isEmpty
                  ? null
                  : () async {
                      try {
                        await sendEmail(
                          to: email,
                          subject: 'Payment Receipt',
                          body: message,
                        );
                      } catch (_) {}
                    },
              child: Text(email.isEmpty ? 'Email (No address)' : 'Email'),
            ),
          ],
        ),
        actions: [
          Button(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final a = widget.appointment;
    final discountedTotal = a.discountType == 'percent'
        ? (a.price - (a.price * a.discount / 100)).clamp(0, double.infinity)
        : (a.price - a.discount).clamp(0, double.infinity);
    final outstanding = (discountedTotal - a.paid).clamp(0, double.infinity);
    final status = outstanding <= 0 ? 'PAID' : 'DUE';
    final totalAfter =
        (double.tryParse(widget.paidController.text.trim()) ?? a.paid)
            .clamp(0, double.infinity);
    final visitDay = DateTime(a.date.year, a.date.month, a.date.day);
    final seenDoctorIds = appointments.present.values
        .where((row) {
          if (row.patientID != a.patientID) return false;
          final rowDay = DateTime(row.date.year, row.date.month, row.date.day);
          return rowDay == visitDay;
        })
        .expand((row) => row.operatorsIDs)
        .toSet();
    final consultantDoctors = doctors.present.values
        .where((doctor) => seenDoctorIds.contains(doctor.id))
        .toList(growable: false)
      ..sort((x, y) => x.title.toLowerCase().compareTo(y.title.toLowerCase()));

    return Padding(
      padding: const EdgeInsets.all(4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 4),
          LayoutBuilder(
            builder: (context, constraints) {
              final narrow = constraints.maxWidth < 860;

              final left = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Treatment Cost',
                    style: TextStyle(
                      color: Color(0xFF355279),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  CupertinoTextField(
                    controller: widget.priceController,
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                    ],
                    onChanged: (value) {
                      _basePrice = value.trim().isEmpty
                          ? 0
                          : (double.tryParse(value) ?? 0);
                      final discount = widget.discountEnabled
                          ? (double.tryParse(
                                  widget.discountController.text.trim()) ??
                              0.0)
                          : 0.0;
                      a.discount = discount;
                      a.discountType = _discountMode;
                      a.price = _basePrice;
                      appointments.set(a);
                      setState(() {});
                    },
                    prefix: const Padding(
                      padding: EdgeInsets.only(left: 10),
                      child:
                          Text('₹', style: TextStyle(color: Color(0xFF355279))),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [100, 200, 500, 1000, 2000, 2500]
                        .map(
                          (v) => Button(
                            style: _pillStyle(
                              selected: false,
                              accent: const Color(0xFF2D7BD8),
                            ),
                            onPressed: () {
                              _basePrice = v.toDouble();
                              widget.priceController.text = '$v';
                              _recalculatePrice();
                            },
                            child: Text('₹$v'),
                          ),
                        )
                        .toList(growable: false),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Text(
                        'Enable Discount',
                        style: TextStyle(
                          color: Color(0xFF355279),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(width: 8),
                      ToggleSwitch(
                        checked: widget.discountEnabled,
                        onChanged: (v) {
                          widget.onToggleDiscount(v);
                          if (!v) {
                            widget.discountController.clear();
                          }
                          _recalculatePrice();
                        },
                      ),
                    ],
                  ),
                  if (widget.discountEnabled) ...[
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        Button(
                          style: _pillStyle(
                            selected: _discountMode == 'flat',
                            accent: const Color(0xFF2D7BD8),
                          ),
                          onPressed: () {
                            setState(() => _discountMode = 'flat');
                            _recalculatePrice();
                          },
                          child:
                              Text(_discountMode == 'flat' ? '₹ Flat' : 'Flat'),
                        ),
                        Button(
                          style: _pillStyle(
                            selected: _discountMode == 'percent',
                            accent: const Color(0xFF2D7BD8),
                          ),
                          onPressed: () {
                            setState(() => _discountMode = 'percent');
                            _recalculatePrice();
                          },
                          child: Text(_discountMode == 'percent'
                              ? '% Percent'
                              : 'Percent'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    CupertinoTextField(
                      controller: widget.discountController,
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                      ],
                      onChanged: (_) => _recalculatePrice(),
                      placeholder: 'Discount',
                    ),
                    const SizedBox(height: 8),
                    if (_discountMode == 'percent')
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [5, 10, 20, 25, 50]
                            .map(
                              (v) => Button(
                                style: _pillStyle(
                                  selected: true,
                                  accent: const Color(0xFF2D7BD8),
                                ),
                                onPressed: () {
                                  widget.discountController.text = '$v';
                                  _recalculatePrice();
                                },
                                child: Text('$v%'),
                              ),
                            )
                            .toList(growable: false),
                      ),
                    if (_discountMode == 'flat')
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [100, 200, 500, 1000]
                            .map(
                              (v) => Button(
                                style: _pillStyle(
                                  selected: true,
                                  accent: const Color(0xFF2D7BD8),
                                ),
                                onPressed: () {
                                  widget.discountController.text = '$v';
                                  _recalculatePrice();
                                },
                                child: Text('₹$v'),
                              ),
                            )
                            .toList(growable: false),
                      ),
                  ],
                  const SizedBox(height: 14),
                  const Text(
                    'Amount Collected',
                    style: TextStyle(
                      color: Color(0xFF355279),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  CupertinoTextField(
                    controller: widget.paidController,
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                    ],
                    onChanged: (value) {
                      a.paid = double.tryParse(value) ?? 0;
                      appointments.set(a);
                    },
                    prefix: const Padding(
                      padding: EdgeInsets.only(left: 10),
                      child:
                          Text('₹', style: TextStyle(color: Color(0xFF355279))),
                    ),
                    suffix: Padding(
                      padding: const EdgeInsets.only(right: 10),
                      child: Text(
                        '₹${outstanding.toStringAsFixed(0)}',
                        style: const TextStyle(
                          color: Color(0xFF5A7397),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      ...[100, 200, 500, 1000, 2000, 2500].map(
                        (v) => Button(
                          style: _pillStyle(
                            selected: false,
                            accent: const Color(0xFF2D7BD8),
                          ),
                          onPressed: () {
                            widget.paidController.text = '$v';
                            a.paid = v.toDouble();
                            appointments.set(a);
                            setState(() {});
                          },
                          child: Text('₹$v'),
                        ),
                      ),
                      Button(
                        style: _pillStyle(
                          selected: false,
                          accent: const Color(0xFF16A34A),
                        ),
                        onPressed: widget.onCollectFullBalance,
                        child: const Text('Full'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Payment Mode',
                              style: TextStyle(
                                color: Color(0xFF355279),
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: ['Cash', 'UPI'].map((mode) {
                                final selected = _paymentMode == mode;
                                return Button(
                                  style: _pillStyle(selected: selected),
                                  onPressed: () {
                                    setState(() => _paymentMode = mode);
                                    final isDigital = mode == 'UPI';
                                    a.treatmentGpayPaid = isDigital;
                                    a.prescriptionGpayPaid = isDigital;
                                    appointments.set(a);
                                  },
                                  child: Text(
                                    mode,
                                    style: TextStyle(
                                      color: selected
                                          ? const Color(0xFF1459AD)
                                          : const Color(0xFF5A7397),
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                );
                              }).toList(growable: false),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Date',
                            style: TextStyle(
                              color: Color(0xFF355279),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Button(
                            onPressed: () async {
                              final picked = await material.showDatePicker(
                                context: context,
                                initialDate: _paymentDate,
                                firstDate: DateTime(2000, 1, 1),
                                lastDate: DateTime(2100, 12, 31),
                                builder: apexoDatePickerBuilder(context),
                              );
                              if (picked == null) return;
                              setState(() => _paymentDate = picked);
                            },
                            child: Text(
                                DateFormat('dd MMM yyyy').format(_paymentDate)),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Consultant Charge',
                    style: TextStyle(
                      color: Color(0xFF355279),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        flex: 5,
                        child: ComboBox<String>(
                          isExpanded: true,
                          placeholder: const Text('Select consultant'),
                          value: consultantDoctors.any(
                                  (d) => d.id == _selectedConsultantDoctorId)
                              ? _selectedConsultantDoctorId
                              : null,
                          items: [
                            const ComboBoxItem<String>(
                              value: '__none__',
                              child: Text('None'),
                            ),
                            ...consultantDoctors
                                .map(
                                  (doctor) => ComboBoxItem<String>(
                                    value: doctor.id,
                                    child: Text(
                                      doctor.title.trim().isEmpty
                                          ? 'Unnamed doctor'
                                          : doctor.title,
                                    ),
                                  ),
                                )
                                .toList(growable: false),
                          ],
                          onChanged: (value) {
                            setState(() {
                              if (value == '__none__' || value == null) {
                                _selectedConsultantDoctorId = null;
                                a.consultantDoctorID = null;
                              } else {
                                _selectedConsultantDoctorId = value;
                                a.consultantDoctorID = value;
                              }
                            });
                            appointments.set(a);
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        flex: 5,
                        child: CupertinoTextField(
                          controller: _consultantChargeController,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(
                                RegExp(r'[0-9.]')),
                          ],
                          prefix: const Padding(
                            padding: EdgeInsets.only(left: 10),
                            child: Text('₹',
                                style: TextStyle(color: Color(0xFF355279))),
                          ),
                          placeholder: 'Consultant charge',
                          onChanged: (value) {
                            a.priceToPayDoctor = double.tryParse(value) ?? 0;
                            appointments.set(a);
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              );

              final right = Padding(
                padding: const EdgeInsets.all(4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Patient',
                      style: const TextStyle(
                        color: Color(0xFF5A7397),
                        fontWeight: FontWeight.w700,
                        fontSize: 11,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            a.title.trim().isEmpty
                                ? 'Unnamed patient'
                                : a.title,
                            style: const TextStyle(
                              color: Color(0xFF2D476D),
                              fontWeight: FontWeight.w700,
                              fontSize: 18,
                            ),
                          ),
                        ),
                        Tooltip(
                          message: 'Download PDF',
                          child: IconButton(
                            icon: const Icon(
                              FluentIcons.download,
                              size: 18,
                              color: Color(0xFF1459AD),
                            ),
                            onPressed: _downloadReceiptPdf,
                          ),
                        ),
                        Tooltip(
                          message: 'Share',
                          child: IconButton(
                            icon: const Icon(
                              FluentIcons.share,
                              size: 18,
                              color: Color(0xFF7C3AED),
                            ),
                            onPressed: _openShareOptions,
                          ),
                        ),
                        Tooltip(
                          message: 'Print',
                          child: IconButton(
                            icon: const Icon(
                              FluentIcons.print,
                              size: 18,
                              color: Color(0xFF2BA58D),
                            ),
                            onPressed: _printReceipt,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Patient ID: ${a.patientID ?? '-'}',
                      style: const TextStyle(color: Color(0xFF5A7397)),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Age: ${a.patient?.age ?? 0}${(a.patient?.gender == 1 ? 'M' : a.patient?.gender == 0 ? 'F' : '')}  • ${a.patient?.phone ?? ''}',
                      style: const TextStyle(
                        color: Color(0xFF6D84A8),
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Divider(),
                    const SizedBox(height: 10),
                    const Text(
                      'Treatment',
                      style: TextStyle(
                        color: Color(0xFF2D476D),
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      a.selectedTreatments
                              .where((t) => t.trim().isNotEmpty)
                              .join(', ')
                              .trim()
                              .isEmpty
                          ? '-'
                          : a.selectedTreatments
                              .where((t) => t.trim().isNotEmpty)
                              .join(', '),
                      style: const TextStyle(
                        color: Color(0xFF5A7397),
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Divider(),
                    const SizedBox(height: 10),
                    const Text(
                      'Billing Summary',
                      style: TextStyle(
                        color: Color(0xFF2D476D),
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _summaryLine(
                        'Treatment Cost', '₹${a.price.toStringAsFixed(0)}'),
                    const SizedBox(height: 6),
                    if (widget.discountEnabled) ...[
                      _summaryLine(
                        'Discount Applied',
                        a.discount <= 0
                            ? '-'
                            : a.discountType == 'percent'
                                ? '-${a.discount.toStringAsFixed(0)}%'
                                : '-₹${a.discount.toStringAsFixed(0)}',
                        valueColor: const Color(0xFFD6455D),
                      ),
                      _summaryLine(
                        'Discounted Total',
                        '₹${discountedTotal.toStringAsFixed(0)}',
                        valueColor: const Color(0xFF1459AD),
                      ),
                      const SizedBox(height: 10),
                    ],
                    _summaryLine(
                        'Already Paid', '₹${a.paid.toStringAsFixed(0)}'),
                    _summaryLine(
                      'Remaining Balance',
                      '₹${outstanding.toStringAsFixed(0)}',
                      valueColor: const Color(0xFFD6455D),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'After Payment',
                      style: TextStyle(
                        color: Color(0xFF2D476D),
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _summaryLine(
                        'Total Paid', '₹${totalAfter.toStringAsFixed(0)}'),
                    _summaryLine(
                      'Balance',
                      '₹${(discountedTotal - totalAfter).clamp(0, double.infinity).toStringAsFixed(0)}',
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: status == 'PAID'
                            ? const Color(0xFFDCFCE7)
                            : const Color(0xFFFFF1F2),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        status,
                        style: TextStyle(
                          color: status == 'PAID'
                              ? const Color(0xFF16A34A)
                              : const Color(0xFFD6455D),
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
              );

              if (narrow) {
                return Column(
                  children: [
                    left,
                    const SizedBox(height: 12),
                    right,
                  ],
                );
              }

              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 64,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        left,
                      ],
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(flex: 36, child: right),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _summaryLine(String label, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFF5A7397),
              fontWeight: FontWeight.w600,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: valueColor ?? const Color(0xFF2D476D),
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class EnhancedTeethPickerCard extends StatelessWidget {
  final Set<String> selectedTeeth;
  final ValueChanged<Set<String>> onChanged;

  const EnhancedTeethPickerCard({
    super.key,
    required this.selectedTeeth,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFF5FAFF), Color(0xFFEDF6FF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFD4E6FA)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(FluentIcons.accounts, size: 13, color: Color(0xFF2D7BD8)),
              SizedBox(width: 6),
              Text(
                'Teeth Map (Enhanced)',
                style: TextStyle(
                  color: Color(0xFF2C4E76),
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          TeethPicker(
            selectedTeeth: selectedTeeth,
            isAdult: selectedTeeth.every((t) =>
                t.startsWith('1') ||
                t.startsWith('2') ||
                t.startsWith('3') ||
                t.startsWith('4')),
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

class _CheckinSearchableTagInput extends StatelessWidget {
  final List<String> initialValues;
  final List<String> suggestions;
  final String placeholder;
  final ValueChanged<List<String>> onChanged;

  const _CheckinSearchableTagInput({
    required this.initialValues,
    required this.suggestions,
    required this.placeholder,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return TagInputWidget(
      suggestions: suggestions
          .map((item) => TagInputItem(value: item, label: item))
          .toList(growable: false),
      initialValue: initialValues
          .where((item) => item.trim().isNotEmpty)
          .map((item) => TagInputItem(value: item.trim(), label: item.trim()))
          .toList(growable: true),
      strict: false,
      limit: 999,
      placeholder: placeholder,
      clearButton: true,
      onChanged: (items) {
        onChanged(
          items
              .where(
                  (item) => item.value != null && item.value!.trim().isNotEmpty)
              .map((item) => item.value!.trim())
              .toSet()
              .toList(growable: false),
        );
      },
    );
  }
}

class SvgOdontogramCard extends StatelessWidget {
  final Map<String, ToothState> teeth;
  final String selectedToothId;
  final String selectedToothNote;
  final ValueChanged<String> onSelectTooth;
  final ValueChanged<String> onToothNoteChanged;
  final void Function(String toothId, ToothSurface surface) onSurfaceTap;

  const SvgOdontogramCard({
    super.key,
    required this.teeth,
    required this.selectedToothId,
    required this.selectedToothNote,
    required this.onSelectTooth,
    required this.onToothNoteChanged,
    required this.onSurfaceTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFF5FAFF), Color(0xFFEDF6FF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFD4E6FA)),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isDesktop = constraints.maxWidth >= 980;

          final centerPanel = Expanded(
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFF4F8FF),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFD3E1F3)),
              ),
              child: Column(
                children: [
                  const Text(
                    'Odontogram',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF2C4E76),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: OdontogramPicker(
                        teeth: teeth,
                        onToothTap: onSelectTooth,
                        onSurfaceTap: onSurfaceTap,
                        toothSize: 48,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );

          final rightPanel = Container(
            width: 260,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFEFF4FC),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFD3E1F3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Tooth Details',
                  style: TextStyle(
                    color: Color(0xFF2C4E76),
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Tooth #$selectedToothId',
                  style: const TextStyle(
                    color: Color(0xFF2C4E76),
                    fontWeight: FontWeight.w700,
                    fontSize: 20,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Notes:',
                  style: TextStyle(
                    color: Color(0xFF2C4E76),
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 6),
                TextBox(
                  key: ValueKey(selectedToothId),
                  controller: TextEditingController(text: selectedToothNote),
                  placeholder: 'Add notes here...',
                  maxLines: 3,
                  onChanged: onToothNoteChanged,
                ),
                const SizedBox(height: 8),
                FilledButton(
                  onPressed: () {},
                  child: const SizedBox(
                    width: double.infinity,
                    child: Center(
                      child: Text('Save'),
                    ),
                  ),
                ),
              ],
            ),
          );

          if (!isDesktop) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(height: 280, child: centerPanel),
                const SizedBox(height: 8),
                rightPanel,
              ],
            );
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                height: 360,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    centerPanel,
                    const SizedBox(width: 8),
                    rightPanel,
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _PatientJourneyTimeline extends StatelessWidget {
  final List<Appointment> appointments;
  final DateTime? excludeDate;

  const _PatientJourneyTimeline({required this.appointments, this.excludeDate});

  static bool _sameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  @override
  Widget build(BuildContext context) {
    final scoped = excludeDate == null
        ? appointments
        : appointments
            .where((a) => !_sameDay(a.date, excludeDate!))
            .toList(growable: false);
    final points = scoped.take(8).toList(growable: false);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      decoration: BoxDecoration(
        color: const Color(0xFFF7FBFF),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE2ECF8)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Journey Timeline',
            style: TextStyle(
              color: Color(0xFF2C4E76),
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 8),
          if (points.isEmpty)
            const Text(
              'No timeline data available.',
              style: TextStyle(color: Color(0xFF6D84A8), fontSize: 12),
            )
          else
            ...points.asMap().entries.map((entry) {
              final item = entry.value;
              final treatments = item.selectedTreatments
                  .where((t) => t.trim().isNotEmpty)
                  .join(', ');
              final doctorNames = item.operators.isEmpty
                  ? 'Unassigned'
                  : item.operators.map((d) => d.title).join(', ');
              final teeth = item.selectedTeeth
                  .where((t) => t.trim().isNotEmpty)
                  .join(', ');
              final isLast = entry.key == points.length - 1;

              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Column(
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: const BoxDecoration(
                          color: Color(0xFF2D7BD8),
                          shape: BoxShape.circle,
                        ),
                      ),
                      if (!isLast)
                        Container(
                          width: 2,
                          height: 28,
                          color: const Color(0xFFCFE0F3),
                        ),
                    ],
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            DateFormat('dd MMM yyyy • h:mm a')
                                .format(item.date),
                            style: const TextStyle(
                              color: Color(0xFF1F446E),
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            treatments.isEmpty ? '-' : treatments,
                            style: const TextStyle(
                              color: Color(0xFF5F789B),
                              fontSize: 11,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Wrap(
                            spacing: 6,
                            runSpacing: 4,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 7,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFEAF2FC),
                                  borderRadius: BorderRadius.circular(999),
                                  border: Border.all(
                                    color: const Color(0xFFD5E5F7),
                                  ),
                                ),
                                child: Text(
                                  'Doctor: $doctorNames',
                                  style: const TextStyle(
                                    color: Color(0xFF355279),
                                    fontWeight: FontWeight.w700,
                                    fontSize: 10,
                                  ),
                                ),
                              ),
                              if (teeth.isNotEmpty)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 7,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF2F8E9),
                                    borderRadius: BorderRadius.circular(999),
                                    border: Border.all(
                                      color: const Color(0xFFD9EBC0),
                                    ),
                                  ),
                                  child: Text(
                                    'Teeth: $teeth',
                                    style: const TextStyle(
                                      color: Color(0xFF456824),
                                      fontWeight: FontWeight.w700,
                                      fontSize: 10,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            }),
        ],
      ),
    );
  }
}
