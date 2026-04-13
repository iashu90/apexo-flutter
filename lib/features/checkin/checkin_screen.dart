import 'dart:async';
import 'dart:io';

import 'package:apexo/common_widgets/patients_report_dialog.dart';
import 'package:apexo/common_widgets/export_progress_dialog.dart';
import 'package:apexo/common_widgets/tag_input.dart';
import 'package:apexo/common_widgets/teeth_picker.dart';
import 'package:apexo/features/appointments/appointment_model.dart';
import 'package:apexo/features/appointments/appointments_store.dart';
import 'package:apexo/features/checkin/odontogram/odontogram_picker.dart';
import 'package:apexo/features/checkin/odontogram/tooth_model.dart';
import 'package:apexo/features/doctors/doctors_store.dart';
import 'package:apexo/features/patients/patient_model.dart';
import 'package:apexo/features/patients/patients_store.dart';
import 'package:apexo/theme/material_date_picker_theme.dart';
import 'package:apexo/utils/uuid.dart';
import 'package:file_picker/file_picker.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' as material;
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

DateTime checkinPersistedDate = DateTime.now();

class CheckinScreen extends StatefulWidget {
  const CheckinScreen({super.key});

  @override
  State<CheckinScreen> createState() => _CheckinScreenState();
}

class _CheckinScreenState extends State<CheckinScreen> {
  DateTime _selectedDate = _dateOnly(checkinPersistedDate);
  String _selectedDoctor = '__all__';
  Appointment? _selectedAppointment;
  final Map<String, bool> _expandedStages = {
    'waiting': true,
    'with_doctor': true,
    'checkout': true,
    'completed': true,
  };

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
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

  Future<void> _openQuickPatientSearchDialog() async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        final queryController = TextEditingController(
          text: '',
        );
        String query = queryController.text.trim().toLowerCase();

        final allPatients = patients.present.values.toList(growable: false);
        final todaysAppointments = appointments.forDate(_selectedDate);

        return StatefulBuilder(
          builder: (context, setDialogState) {
            final matches = allPatients
                .where((p) {
                  if (query.isEmpty) return true;
                  final name = p.title.toLowerCase();
                  final phone = p.phone.toLowerCase();
                  return name.contains(query) || phone.contains(query);
                })
                .take(40)
                .toList(growable: false);

            return ContentDialog(
              title: const Text('Search Patient for Check-in'),
              content: SizedBox(
                width: 520,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextBox(
                      controller: queryController,
                      placeholder: 'Search by patient name or phone',
                      autofocus: true,
                      prefix: const Padding(
                        padding: EdgeInsets.only(left: 10),
                        child: Icon(
                          FluentIcons.search,
                          size: 12,
                          color: Color(0xFF6D84A8),
                        ),
                      ),
                      onChanged: (value) {
                        setDialogState(
                            () => query = value.trim().toLowerCase());
                      },
                    ),
                    const SizedBox(height: 10),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 420),
                      child: matches.isEmpty
                          ? const Center(
                              child: Padding(
                                padding: EdgeInsets.symmetric(vertical: 30),
                                child: Text(
                                  'No matching patients.',
                                  style: TextStyle(color: Color(0xFF6D84A8)),
                                ),
                              ),
                            )
                          : ListView.separated(
                              shrinkWrap: true,
                              itemCount: matches.length,
                              separatorBuilder: (_, __) =>
                                  const Divider(size: 1),
                              itemBuilder: (context, index) {
                                final p = matches[index];
                                final existing = todaysAppointments
                                    .where((a) => a.patientID == p.id)
                                    .toList(growable: false)
                                    .lastOrNull;

                                return Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 2,
                                    vertical: 6,
                                  ),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              p.title.trim().isEmpty
                                                  ? 'Unnamed patient'
                                                  : p.title,
                                              style: const TextStyle(
                                                color: Color(0xFF1F446E),
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              '${p.phone} • ${p.age}y',
                                              style: const TextStyle(
                                                color: Color(0xFF6D84A8),
                                                fontSize: 11,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      if (existing != null)
                                        Button(
                                          onPressed: () {
                                            setState(() =>
                                                _selectedAppointment =
                                                    existing);
                                            Navigator.pop(dialogContext);
                                          },
                                          child: const Text('Open'),
                                        )
                                      else
                                        FilledButton(
                                          onPressed: () {
                                            _checkInPatient(p);
                                            Navigator.pop(dialogContext);
                                          },
                                          child: const Text('Check-in'),
                                        ),
                                    ],
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
              actions: [
                Button(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Close'),
                ),
              ],
            );
          },
        );
      },
    );
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
            final checkout = filtered
                .where((a) => a.checkinStage == 'checkout')
                .toList(growable: false);
            final completed = filtered
                .where((a) => a.checkinStage == 'completed' || a.isDone)
                .toList(growable: false);

            final now = DateTime.now();
            final isToday = _selectedDate.year == now.year &&
                _selectedDate.month == now.month &&
                _selectedDate.day == now.day;
            final screenWidth = MediaQuery.of(context).size.width;
            final isMobile = screenWidth < 760;
            final isTablet = screenWidth >= 760 && screenWidth < 1160;

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
                                'Checkin',
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
                                  Text('Search Patient for Check-in'),
                                ],
                              ),
                            ),
                          ),
                        ],
                      )
                    else
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Row(
                              children: [
                                const Text(
                                  'Checkin',
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
                          ),
                          SizedBox(
                            width: isTablet ? 300 : 360,
                            child: FilledButton(
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
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(FluentIcons.search, size: 12),
                                  SizedBox(width: 8),
                                  Text('Search Patient for Check-in'),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
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
                          SizedBox(
                            width: 84,
                            child: Visibility(
                              visible: !isToday,
                              maintainSize: true,
                              maintainAnimation: true,
                              maintainState: true,
                              child: FilledButton(
                                onPressed: () => setState(() {
                                  _selectedDate = _dateOnly(DateTime.now());
                                  checkinPersistedDate = _selectedDate;
                                }),
                                child: const Text('Today'),
                              ),
                            ),
                          ),
                        ],
                      ),
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
                          return _DoctorFilterChip(
                            label: doctors.get(id)?.title ?? 'Unknown',
                            selected: _selectedDoctor == id,
                            onTap: () => setState(() => _selectedDoctor = id),
                          );
                        }),
                      ],
                    ),
                    const SizedBox(height: 12),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final isWide = constraints.maxWidth >= 1360;
                        final listWidth = constraints.maxWidth >= 1280
                            ? 560.0
                            : constraints.maxWidth >= 920
                                ? 500.0
                                : double.infinity;

                        final lists = SizedBox(
                          width: isWide ? listWidth : double.infinity,
                          child: Column(
                            children: [
                              _WorkflowColumn(
                                title: 'Waiting',
                                stage: 'waiting',
                                color: const Color(0xFFE4A11B),
                                rows: waiting,
                                showHistoryAction: false,
                                onSelect: (a) =>
                                    setState(() => _selectedAppointment = a),
                                selectedAppointmentId: _selectedAppointment?.id,
                                expanded: _expandedStages['waiting'] ?? true,
                                onToggleExpanded: () => setState(() {
                                  _expandedStages['waiting'] =
                                      !(_expandedStages['waiting'] ?? true);
                                }),
                              ),
                              const SizedBox(height: 10),
                              _WorkflowColumn(
                                title: 'With Doctor',
                                stage: 'with_doctor',
                                color: const Color(0xFF2D7BD8),
                                rows: withDoctor,
                                showHistoryAction: false,
                                onSelect: (a) =>
                                    setState(() => _selectedAppointment = a),
                                selectedAppointmentId: _selectedAppointment?.id,
                                expanded:
                                    _expandedStages['with_doctor'] ?? true,
                                onToggleExpanded: () => setState(() {
                                  _expandedStages['with_doctor'] =
                                      !(_expandedStages['with_doctor'] ?? true);
                                }),
                              ),
                              const SizedBox(height: 10),
                              _WorkflowColumn(
                                title: 'Billing',
                                stage: 'checkout',
                                color: const Color(0xFF2BA58D),
                                rows: checkout,
                                onSelect: (a) =>
                                    setState(() => _selectedAppointment = a),
                                selectedAppointmentId: _selectedAppointment?.id,
                                expanded: _expandedStages['checkout'] ?? true,
                                onToggleExpanded: () => setState(() {
                                  _expandedStages['checkout'] =
                                      !(_expandedStages['checkout'] ?? true);
                                }),
                              ),
                              const SizedBox(height: 10),
                              _WorkflowColumn(
                                title: 'Completed',
                                stage: 'completed',
                                color: const Color(0xFF3B9A42),
                                rows: completed,
                                onSelect: (a) =>
                                    setState(() => _selectedAppointment = a),
                                selectedAppointmentId: _selectedAppointment?.id,
                                expanded: _expandedStages['completed'] ?? true,
                                onToggleExpanded: () => setState(() {
                                  _expandedStages['completed'] =
                                      !(_expandedStages['completed'] ?? true);
                                }),
                              ),
                            ],
                          ),
                        );

                        final right = Expanded(
                          child: _CheckinHistoryPanel(
                            selectedAppointment: _selectedAppointment,
                            todaysAppointments: filtered,
                          ),
                        );

                        if (!isWide) {
                          return Column(
                            children: [
                              lists,
                              const SizedBox(height: 10),
                              SizedBox(width: double.infinity, child: right),
                            ],
                          );
                        }

                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            lists,
                            const SizedBox(width: 10),
                            right,
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
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
                const SizedBox(width: 8),
                Text(
                  '${rows.length}',
                  style: const TextStyle(
                    color: Color(0xFF355279),
                    fontWeight: FontWeight.w700,
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
                stage: stage,
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

  Future<String?> _pickDoctor(BuildContext context) async {
    return showDialog<String>(
      context: context,
      builder: (dialogContext) {
        final doctorRows = doctors.present.values.toList(growable: false)
          ..sort(
              (a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
        return ContentDialog(
          title: const Text('Assign Doctor'),
          content: SizedBox(
            width: 360,
            child: doctorRows.isEmpty
                ? const Text('No doctors available to assign.')
                : ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 320),
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: doctorRows
                            .map(
                              (doctor) => Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: FilledButton(
                                  style: ButtonStyle(
                                    padding: WidgetStateProperty.all(
                                      const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 12,
                                      ),
                                    ),
                                  ),
                                  onPressed: () =>
                                      Navigator.pop(dialogContext, doctor.id),
                                  child: Align(
                                    alignment: Alignment.centerLeft,
                                    child: Text(
                                      doctor.title.trim().isEmpty
                                          ? 'Unnamed doctor'
                                          : doctor.title,
                                    ),
                                  ),
                                ),
                              ),
                            )
                            .toList(growable: false),
                      ),
                    ),
                  ),
          ),
          actions: [
            Button(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _moveStage(BuildContext context) async {
    if (stage == 'completed') {
      final shouldUndo = await showDialog<bool>(
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
              style: ButtonStyle(
                backgroundColor:
                    WidgetStateProperty.all(const Color(0xFFE56E7D)),
              ),
              child: const Text('Billing'),
            ),
          ],
        ),
      );
      if (shouldUndo != true) return;
      appointment.checkinStage = 'checkout';
      appointment.isDone = false;
      appointments.set(appointment);
      return;
    }

    if (stage == 'waiting') {
      final pickedDoctorId = await _pickDoctor(context);
      if (pickedDoctorId == null || pickedDoctorId.trim().isEmpty) return;
      appointment.operatorsIDs = [pickedDoctorId];
      appointment.checkinStage = 'with_doctor';
      appointment.isDone = false;
      appointments.set(appointment);
      onSelect?.call(appointment);
      return;
    }

    if (stage == 'with_doctor') {
      final shouldMove = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => ContentDialog(
          title: const Text('Move to Billing?'),
          content: const Text('This appointment will be moved to Billing.'),
          actions: [
            Button(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Billing'),
            ),
          ],
        ),
      );
      if (shouldMove != true) return;
      appointment.checkinStage = 'checkout';
      appointment.isDone = false;
      appointments.set(appointment);
      return;
    }

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

    if (shouldComplete != true) return;
    appointment.checkinStage = 'completed';
    appointment.isDone = true;
    appointments.set(appointment);
  }

String _waitingLabel() {
  if (appointment.checkedInAt == null) return 'Waiting';
  
  final wait = DateTime.now().difference(appointment.checkedInAt!);
  final mins = wait.inMinutes;

  if (mins <= 0) return 'Waiting';

  if (mins >= 60) {
    final hours = mins ~/ 60;
    final remainingMins = mins % 60;
    
    // Returns "Waiting 1h 5m" or just "Waiting 1h" if mins is 0
    return remainingMins > 0 
        ? 'Waiting ${hours}h ${remainingMins}m' 
        : 'Waiting ${hours}h';
  }

  return 'Waiting ${mins}m';
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
        : appointment.title;
    final doctorsList = appointment.operators.isEmpty
        ? const <String>['Unassigned']
        : appointment.operators.map((d) => d.title).toList(growable: false);

    final phone = appointment.patient?.phone ?? '-';
    final age = appointment.patient?.age ?? 0;
    final rawGender = appointment.patient?.gender;
    final genderLabel = rawGender == 1 ? 'M' : 'F';
    final doctorLabel = doctorsList.first;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: selected ? const Color(0xFFEAF2FC) : Colors.transparent,
        border: const Border(top: BorderSide(color: Color(0xFFE2ECF8))),
      ),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onSelect == null ? null : () => onSelect!(appointment),
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
                    ],
                  ),
                  GestureDetector(
                    onTap: (stage == 'with_doctor' && selected)
                        ? () async {
                            final pickedDoctorId = await _pickDoctor(context);
                            if (pickedDoctorId == null ||
                                pickedDoctorId.trim().isEmpty) {
                              return;
                            }
                            appointment.operatorsIDs = [pickedDoctorId];
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
                            color: Color(0xFF3B82F6), // Standard link color
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            decoration:
                                TextDecoration.underline, // Adds the underline
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            if (stage != 'completed')
              FilledButton(
                onPressed: () => _moveStage(context),
                style: ButtonStyle(
                  backgroundColor: WidgetStateProperty.all(
                    stage == 'waiting'
                        ? const Color(0xFF2D7BD8)
                        : stage == 'with_doctor'
                            ? const Color(0xFF2BA58D)
                            : const Color(0xFF3B9A42),
                  ),
                  foregroundColor: WidgetStateProperty.all(Colors.white),
                ),
                child: Text(
                  stage == 'waiting'
                      ? 'Checkin'
                      : stage == 'with_doctor'
                          ? 'Billing'
                          : 'Complete',
                ),
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

class _CheckinHistoryPanel extends StatelessWidget {
  final Appointment? selectedAppointment;
  final List<Appointment> todaysAppointments;

  const _CheckinHistoryPanel({
    required this.selectedAppointment,
    required this.todaysAppointments,
  });

  @override
  Widget build(BuildContext context) {
    final selected = selectedAppointment;

    if (selected != null && selected.checkinStage == 'checkout') {
      return _CheckinHistoryDetails(appointment: selected);
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFD6E2F0)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: selected == null
            ? const SizedBox(
                height: 220,
                child: Center(
                  child: Text(
                    'Select a patient from Waiting, With Doctor, Billing, or Completed to view history.',
                    style: TextStyle(color: Color(0xFF6D84A8)),
                  ),
                ),
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _CheckinHistoryDetails(appointment: selected),
                ],
              ),
      ),
    );
  }
}

class _CheckinHistoryDetails extends StatefulWidget {
  final Appointment appointment;

  const _CheckinHistoryDetails({required this.appointment});

  @override
  State<_CheckinHistoryDetails> createState() => _CheckinHistoryDetailsState();
}

class _CheckinHistoryDetailsState extends State<_CheckinHistoryDetails> {
  static bool _sameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  Future<void> _changeDoctor(Appointment appointment) async {
    final pickedDoctorId = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        final doctorRows = doctors.present.values.toList(growable: false)
          ..sort(
              (a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
        return ContentDialog(
          title: const Text('Change Doctor'),
          content: SizedBox(
            width: 360,
            child: doctorRows.isEmpty
                ? const Text('No doctors available to assign.')
                : ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 320),
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: doctorRows
                            .map(
                              (doctor) => Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: FilledButton(
                                  style: ButtonStyle(
                                    padding: WidgetStateProperty.all(
                                      const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 12,
                                      ),
                                    ),
                                  ),
                                  onPressed: () =>
                                      Navigator.pop(dialogContext, doctor.id),
                                  child: Align(
                                    alignment: Alignment.centerLeft,
                                    child: Text(
                                      doctor.title.trim().isEmpty
                                          ? 'Unnamed doctor'
                                          : doctor.title,
                                    ),
                                  ),
                                ),
                              ),
                            )
                            .toList(growable: false),
                      ),
                    ),
                  ),
          ),
          actions: [
            Button(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
          ],
        );
      },
    );

    if (pickedDoctorId == null || pickedDoctorId.trim().isEmpty) return;
    appointment.operatorsIDs = [pickedDoctorId];
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
  }

  @override
  Widget build(BuildContext context) {
    final appointment = widget.appointment;
    final patient = appointment.patient;

    final age = patient?.age ?? 0;
    final doctorName = appointment.operators.isEmpty
        ? 'Unassigned'
        : appointment.operators.first.title;
    final patientNotes = patient?.notes.trim() ?? '';
    final pid = appointment.patientID;

    final all = appointments.present.values
        .where((a) => pid != null && pid.isNotEmpty && a.patientID == pid)
        .toList(growable: false)
      ..sort((a, b) => b.date.compareTo(a.date));

    final otherRows = all
        .where((a) => !_sameDay(a.date, appointment.date))
        .take(20)
        .toList(growable: false);

    if (appointment.checkinStage == 'checkout') {
      return _CheckinOperativeForm(
        appointment: appointment,
        allAppointmentsForPatient: all,
      );
    }

    final lastAppointment = otherRows.isNotEmpty ? otherRows.first : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          patient?.title.trim().isNotEmpty == true
              ? patient!.title
              : appointment.title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: Color(0xFF183A67),
          ),
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            Text(
              patient?.phone ?? '-',
              style: const TextStyle(fontSize: 12, color: Color(0xFF6D84A8)),
            ),
            const SizedBox(width: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFEAF2FC),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: const Color(0xFFD5E5F7)),
              ),
              child: Text(
                '${age}y',
                style: const TextStyle(
                  fontSize: 18,
                  color: Color(0xFF1459AD),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: () => _changeDoctor(appointment),
          behavior: HitTestBehavior.opaque,
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
                doctorName.trim().isEmpty ? 'Unnamed doctor' : doctorName,
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
        const SizedBox(height: 10),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child:
                  _LastAppointmentInsightCard(lastAppointment: lastAppointment),
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
        if (appointment.checkinStage == 'with_doctor')
          _CheckinOperativeForm(
              appointment: appointment, allAppointmentsForPatient: all)
        else
          const SizedBox.shrink(),
        if (appointment.checkinStage == 'completed') ...[
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton(
              style: ButtonStyle(
                backgroundColor:
                    WidgetStateProperty.all(const Color(0xFFE56E7D)),
              ),
              onPressed: () => _moveCompletedToBilling(appointment),
              child: const Text('Move Back to Billing'),
            ),
          ),
        ],
        const SizedBox(height: 10),
        if (patientNotes.isNotEmpty)
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
            decoration: BoxDecoration(
              color: const Color(0xFFF7FBFF),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFE2ECF8)),
            ),
            child: Text(
              'Patient Notes: $patientNotes',
              style: const TextStyle(color: Color(0xFF5F789B), fontSize: 12),
            ),
          ),
        if (otherRows.isEmpty) const SizedBox.shrink(),
      ],
    );
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

  const _CheckinOperativeForm({
    required this.appointment,
    required this.allAppointmentsForPatient,
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
        title: const Text('Move back to With Doctor?'),
        content:
            const Text('This patient will be moved back to With Doctor stage.'),
        actions: [
          Button(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Move to With Doctor'),
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
        onComplete: _confirmDoneToggle,
        onMoveBackToWithDoctor: _moveBackToWithDoctor,
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
              'With Doctor',
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
                                final current = _postOpController.text.trim();
                                if (current.contains(parent)) return;
                                _postOpController.text = current.isEmpty
                                    ? parent
                                    : '$current\n$parent';
                                a.postOpNotes = _postOpController.text;
                                appointments.set(a);
                              },
                            ),
                          )
                          .toList(growable: false),
                    ),
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
  final VoidCallback onComplete;
  final VoidCallback onMoveBackToWithDoctor;

  const _CheckoutPaymentCard({
    required this.appointment,
    required this.priceController,
    required this.paidController,
    required this.discountController,
    required this.discountEnabled,
    required this.onToggleDiscount,
    required this.onCollectFullBalance,
    required this.onComplete,
    required this.onMoveBackToWithDoctor,
  });

  @override
  State<_CheckoutPaymentCard> createState() => _CheckoutPaymentCardState();
}

class _CheckoutPaymentCardState extends State<_CheckoutPaymentCard> {
  static const Duration _receiptPdfBuildTimeout = Duration(seconds: 30);
  String _paymentMode = 'Cash';
  final TextEditingController _notesController = TextEditingController();
  DateTime _paymentDate = DateTime.now();
  int _receiptExportSequence = 0;
  bool _sendWhatsapp = true;
  bool _sendSms = false;
  String _discountMode = 'flat';
  double _basePrice = 0;

  @override
  void initState() {
    super.initState();
    final a = widget.appointment;
    _paymentMode = a.treatmentGpayPaid ? 'UPI' : 'Cash';
    _discountMode = a.discountType == 'percent' ? 'percent' : 'flat';
    _basePrice = a.price;
  }

  @override
  void dispose() {
    _notesController.dispose();
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
    widget.priceController.text =
        _basePrice == 0 ? '' : _basePrice.toStringAsFixed(0);
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
              'Notes: ${_notesController.text.trim().isEmpty ? '-' : _notesController.text.trim()}'),
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

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFDDE7F3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Collect Payment',
            style: TextStyle(
              color: Color(0xFF183A67),
              fontWeight: FontWeight.w700,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) {
              final narrow = constraints.maxWidth < 860;
              final left = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF2F2),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFF2D3D3)),
                    ),
                    child: Text(
                      'Outstanding Balance: ₹${outstanding.toStringAsFixed(0)}',
                      style: const TextStyle(
                        color: Color(0xFFD6455D),
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'Price',
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
                      _basePrice = double.tryParse(value) ?? 0;
                      _recalculatePrice();
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
                    children: [100, 200, 500, 1000, 2000]
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
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [5, 10, 20, 25, 50]
                          .map(
                            (v) => Button(
                              style: _pillStyle(
                                selected: _discountMode == 'percent',
                                accent: const Color(0xFF2D7BD8),
                              ),
                              onPressed: () {
                                setState(() => _discountMode = 'percent');
                                widget.discountController.text = '$v';
                                _recalculatePrice();
                              },
                              child: Text('$v%'),
                            ),
                          )
                          .toList(growable: false),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [100, 200, 500, 1000]
                          .map(
                            (v) => Button(
                              style: _pillStyle(
                                selected: _discountMode == 'flat',
                                accent: const Color(0xFF2D7BD8),
                              ),
                              onPressed: () {
                                setState(() => _discountMode = 'flat');
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
                    'Amount to Collect',
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
                      ...[100, 200, 500, 1000, 2000].map(
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
                  const SizedBox(height: 12),
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
                    child: Text(DateFormat('dd MMM yyyy').format(_paymentDate)),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Notes',
                    style: TextStyle(
                      color: Color(0xFF355279),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  CupertinoTextField(
                    controller: _notesController,
                    placeholder: 'Payment note',
                    onChanged: (value) {
                      a.preOpNotes = value;
                      appointments.set(a);
                    },
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Send Receipt Automatically',
                    style: TextStyle(
                      color: Color(0xFF355279),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Checkbox(
                        checked: _sendWhatsapp,
                        content: const Text('WhatsApp'),
                        onChanged: (v) =>
                            setState(() => _sendWhatsapp = v ?? true),
                      ),
                      const SizedBox(width: 10),
                      Checkbox(
                        checked: _sendSms,
                        content: const Text('SMS'),
                        onChanged: (v) => setState(() => _sendSms = v ?? false),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton(
                          style: ButtonStyle(
                            backgroundColor: WidgetStateProperty.all(
                                const Color(0xFF3B9A42)),
                          ),
                          onPressed: widget.onComplete,
                          child: const Text('Complete'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Button(
                          onPressed: widget.onMoveBackToWithDoctor,
                          child: const Text('Move Back to With Doctor'),
                        ),
                      ),
                    ],
                  ),
                ],
              );

              final right = Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF3F7FC),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFD6E2F0)),
                ),
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
                    Text(
                      a.title.trim().isEmpty ? 'Unnamed patient' : a.title,
                      style: const TextStyle(
                        color: Color(0xFF2D476D),
                        fontWeight: FontWeight.w700,
                        fontSize: 18,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Patient ID: ${a.patientID ?? '-'}',
                      style: const TextStyle(color: Color(0xFF5A7397)),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Age: ${a.patient?.age ?? 0}  •  Phone: ${a.patient?.phone ?? '-'}',
                      style: const TextStyle(
                        color: Color(0xFF6D84A8),
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
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
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        Button(
                          onPressed: _downloadReceiptPdf,
                          child: const Text('Download PDF'),
                        ),
                        Button(
                          onPressed: _printReceipt,
                          child: const Text('Print'),
                        ),
                      ],
                    ),
                  ],
                ),
              );

              if (narrow) {
                return Column(
                  children: [left, const SizedBox(height: 12), right],
                );
              }

              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 64, child: left),
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
