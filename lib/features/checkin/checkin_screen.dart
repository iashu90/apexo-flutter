import 'package:apexo/common_widgets/patients_report_dialog.dart';
import 'package:apexo/common_widgets/tag_input.dart';
import 'package:apexo/common_widgets/teeth_picker.dart';
import 'package:apexo/features/appointments/appointment_model.dart';
import 'package:apexo/features/appointments/appointments_store.dart';
import 'package:apexo/features/appointments/open_appointment_panel.dart';
import 'package:apexo/features/checkin/odontogram/odontogram_picker.dart';
import 'package:apexo/features/checkin/odontogram/tooth_model.dart';
import 'package:apexo/features/doctors/doctors_store.dart';
import 'package:apexo/features/patients/patient_model.dart';
import 'package:apexo/features/patients/patients_store.dart';
import 'package:apexo/features/settings/settings_stores.dart';
import 'package:apexo/utils/uuid.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' as material;
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

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

  final TextEditingController _quickPatientSearchController =
      TextEditingController();
  String _quickPatientSearchQuery = '';

  @override
  void initState() {
    super.initState();
    _quickPatientSearchController.addListener(() {
      setState(() {
        _quickPatientSearchQuery =
            _quickPatientSearchController.text.trim().toLowerCase();
      });
    });
  }

  @override
  void dispose() {
    _quickPatientSearchController.dispose();
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
    _quickPatientSearchController.clear();
    setState(() => _selectedAppointment = appointment);
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
              .where((a) => a.checkinStage == 'waiting' || a.checkinStage == 'pending')
              .toList(growable: false);
            final withDoctor = filtered
              .where((a) => a.checkinStage == 'with_doctor' || a.checkinStage == 'treatment')
              .toList(growable: false);
            final checkout = filtered
              .where((a) => a.checkinStage == 'checkout')
              .toList(growable: false);
            final completed = filtered
              .where((a) => a.checkinStage == 'completed' || a.isDone)
              .toList(growable: false);

            final allPatients = patients.present.values.toList(growable: false);
            final quickPatientSearchResults = _quickPatientSearchQuery.isEmpty
                ? const <Patient>[]
                : allPatients
                    .where((p) {
                      final name = p.title.toLowerCase();
                      final phone = p.phone.toLowerCase();
                      return name.contains(_quickPatientSearchQuery) ||
                          phone.contains(_quickPatientSearchQuery);
                    })
                    .take(8)
                    .toList(growable: false);

            final now = DateTime.now();
            final isToday = _selectedDate.year == now.year &&
                _selectedDate.month == now.month &&
                _selectedDate.day == now.day;

            return Container(
              color: const Color(0xFFF3F7FC),
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
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
                                  border: Border.all(color: const Color(0xFFD5E5F7)),
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
                          width: 360,
                          child: Stack(
                            clipBehavior: Clip.none,
                            children: [
                              TextBox(
                                controller: _quickPatientSearchController,
                                placeholder: 'Search patient for check-in',
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 10,
                                ),
                                decoration: WidgetStateProperty.all(
                                  BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(999),
                                    border: Border.all(color: const Color(0xFFCFE0F3)),
                                  ),
                                ),
                                prefix: const Padding(
                                  padding: EdgeInsets.only(left: 10),
                                  child: Icon(
                                    FluentIcons.search,
                                    size: 12,
                                    color: Color(0xFF6D84A8),
                                  ),
                                ),
                                suffix: _quickPatientSearchController.text.isNotEmpty
                                    ? IconButton(
                                        icon: const Icon(FluentIcons.clear),
                                        onPressed:
                                            () => _quickPatientSearchController.clear(),
                                      )
                                    : null,
                              ),
                              if (quickPatientSearchResults.isNotEmpty)
                                Positioned(
                                  top: 44,
                                  right: 0,
                                  child: Container(
                                    width: 360,
                                    padding: const EdgeInsets.symmetric(vertical: 4),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: const Color(0xFFD6E2F0)),
                                      boxShadow: const [
                                        BoxShadow(
                                          color: Color(0x160D2F5B),
                                          blurRadius: 10,
                                          offset: Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                    child: Column(
                                      children: quickPatientSearchResults.map((p) {
                                        final existing = filtered
                                            .where((a) => a.patientID == p.id)
                                            .toList(growable: false)
                                            .lastOrNull;
                                        return GestureDetector(
                                          behavior: HitTestBehavior.opaque,
                                          onTap: () {
                                            _quickPatientSearchController.clear();
                                            setState(() => _selectedAppointment = existing);
                                          },
                                          child: Padding(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 10,
                                              vertical: 8,
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
                                                IconButton(
                                                  icon: const Icon(
                                                    FluentIcons.check_mark,
                                                    size: 12,
                                                  ),
                                                  onPressed: () => _checkInPatient(p),
                                                ),
                                              ],
                                            ),
                                          ),
                                        );
                                      }).toList(growable: false),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Row(
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
                                  onPressed: () => _changeDate(-1),
                                  style: _dateButtonStyle,
                                  child: const Icon(FluentIcons.chevron_left, size: 12),
                                ),
                                Button(
                                  onPressed: () => _pickDate(context),
                                  style: _dateButtonStyle,
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        DateFormat('MMMM d, yyyy').format(_selectedDate),
                                        style: const TextStyle(
                                          color: Color(0xFF25466E),
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      const SizedBox(height: 1),
                                      Text(
                                        DateFormat('EEEE').format(_selectedDate),
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

                        final lists = SizedBox(
                          width: isWide ? 560 : double.infinity,
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
                                showHistoryAction: true,
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
                                title: 'Checkout',
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
                IconButton(
                  icon: Icon(
                    expanded
                        ? FluentIcons.chevron_down
                        : FluentIcons.chevron_right,
                    size: 11,
                  ),
                  onPressed: onToggleExpanded,
                ),
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
                Button(
                  onPressed: onToggleExpanded,
                  child: Text(expanded ? 'Collapse' : 'Expand'),
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

  Future<void> _moveStage(BuildContext context) async {
    if (stage == 'completed') {
      final shouldUndo = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => ContentDialog(
          title: const Text('Move back to Checkout?'),
          content: const Text('This appointment will be moved back to Checkout.'),
          actions: [
            Button(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              style: ButtonStyle(
                backgroundColor:
                    WidgetStateProperty.all(const Color(0xFFD6455D)),
              ),
              child: const Text('Move to Checkout'),
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
      final pickedDoctorId = await showDialog<String>(
        context: context,
        builder: (dialogContext) {
          final doctorRows = doctors.present.values.toList(growable: false)
            ..sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
          return ContentDialog(
            title: const Text('Assign Doctor'),
            content: SizedBox(
              width: 360,
              child: doctorRows.isEmpty
                  ? const Text('No doctors available to assign.')
                  : Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: doctorRows
                          .map(
                            (doctor) => Padding(
                              padding: const EdgeInsets.only(bottom: 6),
                              child: FilledButton(
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
      appointment.checkinStage = 'with_doctor';
      appointment.isDone = false;
      appointments.set(appointment);
      return;
    }

    if (stage == 'with_doctor') {
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

  static Color _doctorChipColor(String doctor) {
    const palette = [
      Color(0xFFFFE3E3),
      Color(0xFFE2F8E8),
      Color(0xFFFFF0D8),
      Color(0xFFE3ECFF),
      Color(0xFFFFE6F1),
      Color(0xFFE0F7FF),
      Color(0xFFF0F7DD),
    ];
    return palette[doctor.hashCode.abs() % palette.length];
  }

  static Color _doctorChipBorderColor(String doctor) {
    const palette = [
      Color(0xFFE05050),
      Color(0xFF3FAF64),
      Color(0xFFE2952B),
      Color(0xFF4C78D8),
      Color(0xFFD34F8D),
      Color(0xFF2E9BC1),
      Color(0xFF95B334),
    ];
    return palette[doctor.hashCode.abs() % palette.length];
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
    final genderRaw = (appointment.patient?.gender ?? '')
      .toString()
      .trim()
      .toLowerCase();
    final isMale = genderRaw.startsWith('m');
    final genderLabel = isMale ? 'M' : 'F';

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
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          patientName,
                          style: const TextStyle(
                            color: Color(0xFF1459AD),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      Container(
                        padding:
                            const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: isMale
                              ? const Color(0xFFE5F0FF)
                              : const Color(0xFFFFEAF1),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                            color: isMale
                                ? const Color(0xFF9EC0EE)
                                : const Color(0xFFE9A8C3),
                          ),
                        ),
                        child: Text(
                          '$genderLabel,$age',
                          style: TextStyle(
                            color: isMale
                                ? const Color(0xFF1459AD)
                                : const Color(0xFFC03A73),
                            fontWeight: FontWeight.w700,
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${DateFormat('h:mm a').format(appointment.date)} • $phone',
                    style: const TextStyle(
                      color: Color(0xFF6D84A8),
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: doctorsList
                        .map(
                          (doctor) => Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: _doctorChipColor(doctor),
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(
                                  color: _doctorChipBorderColor(doctor)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  FluentIcons.contact,
                                  size: 10,
                                  color: Color(0xFF0B4A96),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  doctor,
                                  style: const TextStyle(
                                    color: Color(0xFF0B4A96),
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
                ],
              ),
            ),
            FilledButton(
              onPressed: () => _moveStage(context),
              style: ButtonStyle(
                backgroundColor: WidgetStateProperty.all(
                  stage == 'completed'
                      ? const Color(0xFFD6455D)
                      : stage == 'waiting'
                          ? const Color(0xFF2D7BD8)
                          : stage == 'with_doctor'
                              ? const Color(0xFF2BA58D)
                              : const Color(0xFF3B9A42),
                ),
                foregroundColor: WidgetStateProperty.all(Colors.white),
              ),
              child: Text(
                stage == 'completed'
                    ? 'Back to Checkout'
                    : stage == 'waiting'
                    ? 'Checkin'
                        : stage == 'with_doctor'
                            ? 'Move to Checkout'
                      : 'Mark Appointment Complete',
              ),
            ),
            if (showHistoryAction) ...[
              const SizedBox(width: 8),
              Button(
                onPressed: () => _openPatientHistoryDialog(context),
                child: const Text('History'),
              ),
            ],
            if (stage == 'waiting' || stage == 'with_doctor') ...[
              const SizedBox(width: 8),
              Button(
                onPressed: () => openAppointment(appointment),
                child: const Text('Open'),
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
                    'Select a patient from Waiting, With Doctor, Checkout, or Completed to view history.',
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

  @override
  Widget build(BuildContext context) {
    final appointment = widget.appointment;
    final patient = appointment.patient;

    final age = patient?.age ?? 0;
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
        const SizedBox(height: 10),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _LastAppointmentInsightCard(lastAppointment: lastAppointment),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _PatientJourneyTimeline(appointments: all),
            ),
          ],
        ),
        const SizedBox(height: 10),
        if (appointment.checkinStage == 'with_doctor' ||
            appointment.checkinStage == 'checkout')
          _CheckinOperativeForm(
              appointment: appointment, allAppointmentsForPatient: all)
        else
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
            decoration: BoxDecoration(
              color: const Color(0xFFF7FBFF),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFE2ECF8)),
            ),
            child: const Text(
              'Operative payment and treatment details are available in With Doctor and Checkout stages.',
              style: TextStyle(color: Color(0xFF5F789B), fontSize: 12),
            ),
          ),
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
        if (otherRows.isEmpty)
          const SizedBox.shrink(),
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

  String _discountType = 'flat';
  String? _activeDiscountMode;
  bool _discountEnabled = false;
  double _basePriceBeforeDiscount = 0;
  TreatmentType _selectedOdontogramTreatment = TreatmentType.filling;
  String _selectedOdontogramToothId = '16';
  final Map<String, String> _odontogramNotes = <String, String>{};
  Set<String> _selectedTreatments = {};
  Set<String> _selectedTeeth = {};
  Map<String, ToothState> _teethStates = {};

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
    _discountType = a.discountType;
    _discountEnabled = a.discount > 0;
    _activeDiscountMode = a.discount > 0 ? a.discountType : null;
    _basePriceBeforeDiscount = a.price;
    _selectedTreatments = a.selectedTreatments.toSet();
    _selectedTeeth = a.selectedTeeth.toSet();
    _teethStates = {
      for (final id in _allToothIds) id: ToothState(toothId: id),
    };
    for (final id in _selectedTeeth) {
      if (!_teethStates.containsKey(id)) {
        _teethStates[id] = ToothState(toothId: id);
      }
      _teethStates[id]!.surfaces[ToothSurface.occlusal] =
          _selectedOdontogramTreatment;
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

  void _applyDiscount() {
    final a = widget.appointment;
    final discount = (_discountEnabled && _activeDiscountMode != null)
        ? (double.tryParse(_discountController.text.trim()) ?? 0.0)
        : 0.0;

    double finalPrice = _basePriceBeforeDiscount;
    if (discount > 0 && _activeDiscountMode != null) {
      if (_activeDiscountMode == 'percent') {
        finalPrice =
            _basePriceBeforeDiscount - (_basePriceBeforeDiscount * discount / 100);
      } else {
        finalPrice = _basePriceBeforeDiscount - discount;
      }
      if (finalPrice < 0) finalPrice = 0;
    }

    a.discount = discount;
    a.discountType = _discountType;
    a.price = finalPrice;

    _priceController.text = finalPrice == 0 ? '' : finalPrice.toStringAsFixed(0);
    appointments.set(a);
    setState(() {});
  }

  void _toggleDiscountMode(String mode) {
    final a = widget.appointment;
    if (!_discountEnabled) return;

    if (_activeDiscountMode == mode) {
      _activeDiscountMode = null;
      a.discount = 0;
      a.price = _basePriceBeforeDiscount;
      _priceController.text = a.price == 0 ? '' : a.price.toStringAsFixed(0);
      appointments.set(a);
      setState(() {});
      return;
    }

    _discountType = mode;
    _activeDiscountMode = mode;
    _applyDiscount();
  }

  void _applyPriceSuggestion(int value) {
    final a = widget.appointment;
    _priceController.text = '$value';
    _basePriceBeforeDiscount = value.toDouble();
    if (_discountEnabled && _activeDiscountMode != null) {
      _applyDiscount();
      return;
    }
    a.price = _basePriceBeforeDiscount;
    appointments.set(a);
    setState(() {});
  }

  void _applyPaidSuggestion(int value) {
    final a = widget.appointment;
    _paidController.text = '$value';
    a.paid = value.toDouble();
    appointments.set(a);
    setState(() {});
  }

  void _applyDiscountSuggestion(int value) {
    if (!_discountEnabled) {
      setState(() => _discountEnabled = true);
    }
    _discountController.text = '$value';
    _applyDiscount();
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

  void _onOdontogramSurfaceTap(String toothId, ToothSurface surface) {
    final a = widget.appointment;
    _selectedOdontogramToothId = toothId;
    final tooth = _teethStates[toothId] ?? ToothState(toothId: toothId);
    final current = tooth.surfaces[surface];
    tooth.surfaces[surface] =
        current == _selectedOdontogramTreatment ? null : _selectedOdontogramTreatment;
    _teethStates[toothId] = tooth;

    final hasAnySurface = tooth.surfaces.values.any((v) => v != null);
    if (hasAnySurface) {
      _selectedTeeth.add(toothId);
    } else {
      _selectedTeeth.remove(toothId);
    }

    a.selectedTeeth = _selectedTeeth.toList(growable: false);
    appointments.set(a);
    setState(() {});
  }

  Future<void> _confirmDoneToggle() async {
    final a = widget.appointment;
    if (a.isDone) {
      a.checkinStage = 'checkout';
      setState(() => a.isDone = false);
      appointments.set(a);
      return;
    }

    final shouldComplete = await showDialog<bool>(
      context: context,
      builder: (context) => ContentDialog(
        title: const Text('Mark appointment as done?'),
        content: const Text('This will move the appointment to completed list.'),
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
            child: const Text('Confirm'),
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
        content: const Text('This patient will be moved back to With Doctor stage.'),
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
    final topTreatments = _topTreatmentsForPatient();
    final globalTopTreatments = _topTreatmentsAcrossClinic();

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
          Text(
            isCheckout ? 'Checkout' : 'With Doctor',
            style: const TextStyle(
              color: Color(0xFF2C4E76),
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 8),
          if (isWithDoctor)
            LayoutBuilder(
            builder: (context, constraints) {
              final firstColumn = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
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
                  const SizedBox(height: 6),
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
                                if (a.diagnosis.contains(diagnosis)) {
                                  a.diagnosis.remove(diagnosis);
                                } else {
                                  a.diagnosis.add(diagnosis);
                                }
                                appointments.set(a);
                              });
                            },
                          ),
                        )
                        .toList(growable: false),
                  ),
                  const SizedBox(height: 10),
                  InfoLabel(
                    label: 'Treatment:',
                    child: _CheckinSearchableTagInput(
                      initialValues: _selectedTreatments.toList(growable: false),
                      suggestions: allTreatments.map((t) => t.name).toList(growable: false),
                      placeholder: 'Add treatment...',
                      onChanged: (values) {
                        _selectedTreatments = values.toSet();
                        a.selectedTreatments = values;
                        appointments.set(a);
                        setState(() {});
                      },
                    ),
                  ),
                  if (topTreatments.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    const Text(
                      'Patient previous treatments:',
                      style: TextStyle(
                        color: Color(0xFF5A7397),
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: topTreatments
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
                                  a.selectedTreatments =
                                      _selectedTreatments.toList(growable: false);
                                  appointments.set(a);
                                });
                              },
                            ),
                          )
                          .toList(growable: false),
                    ),
                  ],
                  if (globalTopTreatments.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    const Text(
                      'Top 10 provided treatments (all patients):',
                      style: TextStyle(
                        color: Color(0xFF5A7397),
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: globalTopTreatments
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
                                  a.selectedTreatments =
                                      _selectedTreatments.toList(growable: false);
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
                      onChanged: (value) {
                        a.postOpNotes = value;
                        appointments.set(a);
                      },
                      placeholder: 'Post-operative notes',
                    ),
                  ),
                  const SizedBox(height: 10),
                  FilledButton(
                    style: ButtonStyle(
                      backgroundColor:
                          WidgetStateProperty.all(const Color(0xFF2BA58D)),
                      foregroundColor: WidgetStateProperty.all(Colors.white),
                    ),
                    onPressed: () {
                      a.checkinStage = 'checkout';
                      a.isDone = false;
                      appointments.set(a);
                    },
                    child: const Text('Move to Checkout'),
                  ),
                  const SizedBox(height: 8),
                  Button(
                    onPressed: _moveBackToWaiting,
                    child: const Text('Move Back to Waiting'),
                  ),
                ],
              );

              return Column(
                children: [
                  firstColumn,
                  const SizedBox(height: 10),
                  secondColumn,
                ],
              );
            },
          ),
          if (isCheckout) ...[
            Row(
              children: [
                const Text(
                  'Enable Discount',
                  style: TextStyle(
                    color: Color(0xFF355279),
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(width: 8),
                ToggleSwitch(
                  checked: _discountEnabled,
                  onChanged: (value) {
                    final a = widget.appointment;
                    setState(() => _discountEnabled = value);
                    if (!value) {
                      _activeDiscountMode = null;
                      _discountController.clear();
                      a.discount = 0;
                      a.price = _basePriceBeforeDiscount;
                      _priceController.text =
                          a.price == 0 ? '' : a.price.toStringAsFixed(0);
                      appointments.set(a);
                      return;
                    }
                    _basePriceBeforeDiscount =
                        double.tryParse(_priceController.text.trim()) ??
                            _basePriceBeforeDiscount;
                  },
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (_discountEnabled) ...[
              InfoLabel(
                label: 'Discount',
                child: CupertinoTextField(
                  controller: _discountController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                  ],
                  onChanged: (_) => _applyDiscount(),
                  placeholder: 'Discount',
                ),
              ),
              const SizedBox(height: 8),
            ],
            InfoLabel(
              label: 'Price in ${globalSettings.get("currency_______").value}',
              child: CupertinoTextField(
                controller: _priceController,
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                ],
                onChanged: (value) {
                  _basePriceBeforeDiscount = double.tryParse(value) ?? 0;
                  if (_discountEnabled && _activeDiscountMode != null) {
                    _applyDiscount();
                    return;
                  }
                  a.price = _basePriceBeforeDiscount;
                  appointments.set(a);
                },
              ),
            ),
            const SizedBox(height: 8),
            InfoLabel(
              label: 'Paid in ${globalSettings.get("currency_______").value}',
              child: CupertinoTextField(
                controller: _paidController,
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                ],
                onChanged: (value) {
                  a.paid = double.tryParse(value) ?? 0;
                  appointments.set(a);
                },
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _paymentModeChip(
                  label: 'Cash',
                  selected: !a.treatmentGpayPaid,
                  color: const Color(0xFFE09C31),
                  onTap: () {
                    setState(() {
                      a.treatmentGpayPaid = false;
                      a.prescriptionGpayPaid = false;
                    });
                    appointments.set(a);
                  },
                ),
                _paymentModeChip(
                  label: 'Digital (GPay)',
                  selected: a.treatmentGpayPaid,
                  color: const Color(0xFF2D7BD8),
                  onTap: () {
                    setState(() {
                      a.treatmentGpayPaid = true;
                      a.prescriptionGpayPaid = true;
                    });
                    appointments.set(a);
                  },
                ),
              ],
            ),
            const SizedBox(height: 8),
            FilledButton(
              style: ButtonStyle(
                backgroundColor:
                    WidgetStateProperty.all(const Color(0xFF3B9A42)),
                foregroundColor: WidgetStateProperty.all(Colors.white),
              ),
              onPressed: _confirmDoneToggle,
              child: const Text('Mark Appointment Complete'),
            ),
            const SizedBox(height: 8),
            Button(
              onPressed: _moveBackToWithDoctor,
              child: const Text('Move Back to With Doctor'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _quickChip({
    required String label,
    bool selected = false,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFDDEBFF) : const Color(0xFFEAF2FC),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected ? const Color(0xFF2D7BD8) : const Color(0xFFD5E5F7),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? const Color(0xFF1459AD) : const Color(0xFF2F5B88),
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  Widget _paymentModeChip({
    required String label,
    required bool selected,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? color.withValues(alpha: 0.14) : const Color(0xFFF4F8FD),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected ? color : const Color(0xFFD6E2F0),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? color : const Color(0xFF355279),
            fontWeight: FontWeight.w700,
            fontSize: 12,
          ),
        ),
      ),
    );
  }
}

class _EnhancedTeethPickerCard extends StatelessWidget {
  final Set<String> selectedTeeth;
  final ValueChanged<Set<String>> onChanged;

  const _EnhancedTeethPickerCard({
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
          .toList(growable: false),
      strict: false,
      limit: 999,
      placeholder: placeholder,
      clearButton: true,
      onChanged: (items) {
        onChanged(
          items
              .where((item) => item.value != null && item.value!.trim().isNotEmpty)
              .map((item) => item.value!.trim())
              .toSet()
              .toList(growable: false),
        );
      },
    );
  }
}

class _SvgOdontogramCard extends StatelessWidget {
  final Map<String, ToothState> teeth;
  final String selectedToothId;
  final String selectedToothNote;
  final ValueChanged<String> onSelectTooth;
  final ValueChanged<String> onToothNoteChanged;
  final void Function(String toothId, ToothSurface surface) onSurfaceTap;

  const _SvgOdontogramCard({
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

  const _PatientJourneyTimeline({required this.appointments});

  @override
  Widget build(BuildContext context) {
    final points = appointments.take(8).toList(growable: false);

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
                            DateFormat('dd MMM yyyy • h:mm a').format(item.date),
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
