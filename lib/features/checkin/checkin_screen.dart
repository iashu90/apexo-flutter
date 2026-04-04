import 'package:apexo/common_widgets/patients_report_dialog.dart';
import 'package:apexo/common_widgets/tag_input.dart';
import 'package:apexo/common_widgets/teeth_picker.dart';
import 'package:apexo/features/appointments/appointment_model.dart';
import 'package:apexo/features/appointments/appointments_store.dart';
import 'package:apexo/features/appointments/open_appointment_panel.dart';
import 'package:apexo/features/appointments/treatment_model.dart';
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

            final pending =
                filtered.where((a) => !a.isDone).toList(growable: false);
            final completed =
                filtered.where((a) => a.isDone).toList(growable: false);

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

            if (_selectedAppointment != null) {
              final stillVisible =
                  filtered.any((a) => a.id == _selectedAppointment!.id);
              if (!stillVisible) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (!mounted) return;
                  setState(() => _selectedAppointment = null);
                });
              }
            }

            return Container(
              color: const Color(0xFFF3F7FC),
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 20),
                child: Column(
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
                              'Checkin',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF183A67),
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
                                    border: Border.all(
                                        color: const Color(0xFFD6E2F0)),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Button(
                                        onPressed: () => _changeDate(-1),
                                        style: _dateButtonStyle,
                                        child: const Icon(
                                            FluentIcons.chevron_left,
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
                                        child: const Icon(
                                            FluentIcons.chevron_right,
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
                                      onPressed: () => setState(() {
                                        _selectedDate =
                                            _dateOnly(DateTime.now());
                                        checkinPersistedDate = _selectedDate;
                                      }),
                                      child: const Text('Today'),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Align(
                            alignment: Alignment.centerRight,
                            child: SizedBox(
                              width: 360,
                              child: Stack(
                                clipBehavior: Clip.none,
                                children: [
                                  TextBox(
                                    controller: _quickPatientSearchController,
                                    placeholder: 'Search patient for check-in',
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 12, vertical: 10),
                                    decoration: WidgetStateProperty.all(
                                      BoxDecoration(
                                        color: Colors.white,
                                        borderRadius:
                                            BorderRadius.circular(999),
                                        border: Border.all(
                                            color: const Color(0xFFCFE0F3)),
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
                                    suffix: _quickPatientSearchController
                                            .text.isNotEmpty
                                        ? IconButton(
                                            icon: const Icon(FluentIcons.clear),
                                            onPressed: () =>
                                                _quickPatientSearchController
                                                    .clear(),
                                          )
                                        : null,
                                  ),
                                  if (quickPatientSearchResults.isNotEmpty)
                                    Positioned(
                                      top: 44,
                                      right: 0,
                                      child: Container(
                                        width: 360,
                                        padding: const EdgeInsets.symmetric(
                                            vertical: 4),
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius:
                                              BorderRadius.circular(12),
                                          border: Border.all(
                                              color: const Color(0xFFD6E2F0)),
                                          boxShadow: const [
                                            BoxShadow(
                                              color: Color(0x160D2F5B),
                                              blurRadius: 10,
                                              offset: Offset(0, 2),
                                            ),
                                          ],
                                        ),
                                        child: Column(
                                          children: quickPatientSearchResults
                                              .map((p) {
                                            final existing = filtered
                                                .where(
                                                    (a) => a.patientID == p.id)
                                                .toList(growable: false)
                                                .lastOrNull;
                                            return GestureDetector(
                                              behavior: HitTestBehavior.opaque,
                                              onTap: () {
                                                _quickPatientSearchController
                                                    .clear();
                                                setState(() =>
                                                    _selectedAppointment =
                                                        existing);
                                              },
                                              child: Padding(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                        horizontal: 10,
                                                        vertical: 8),
                                                child: Row(
                                                  children: [
                                                    Expanded(
                                                      child: Column(
                                                        crossAxisAlignment:
                                                            CrossAxisAlignment
                                                                .start,
                                                        children: [
                                                          Text(
                                                            p.title
                                                                    .trim()
                                                                    .isEmpty
                                                                ? 'Unnamed patient'
                                                                : p.title,
                                                            style:
                                                                const TextStyle(
                                                              color: Color(
                                                                  0xFF1F446E),
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w700,
                                                            ),
                                                          ),
                                                          const SizedBox(
                                                              height: 2),
                                                          Text(
                                                            '${p.phone} • ${p.age}y',
                                                            style:
                                                                const TextStyle(
                                                              color: Color(
                                                                  0xFF6D84A8),
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
                                                      onPressed: () =>
                                                          _checkInPatient(p),
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
                                title: 'Pending',
                                color: const Color(0xFFE4A11B),
                                rows: pending,
                                showHistoryAction: true,
                                onSelect: (a) =>
                                    setState(() => _selectedAppointment = a),
                                selectedAppointmentId: _selectedAppointment?.id,
                              ),
                              const SizedBox(height: 10),
                              _WorkflowColumn(
                                title: 'Completed',
                                color: const Color(0xFF3B9A42),
                                rows: completed,
                                onSelect: (a) =>
                                    setState(() => _selectedAppointment = a),
                                selectedAppointmentId: _selectedAppointment?.id,
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
  final Color color;
  final List<Appointment> rows;
  final bool showHistoryAction;
  final ValueChanged<Appointment>? onSelect;
  final String? selectedAppointmentId;

  const _WorkflowColumn({
    required this.title,
    required this.color,
    required this.rows,
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
              ],
            ),
          ),
          if (rows.isEmpty)
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
  final bool showHistoryAction;
  final bool selected;
  final ValueChanged<Appointment>? onSelect;

  const _WorkflowRow({
    required this.appointment,
    this.showHistoryAction = false,
    this.selected = false,
    this.onSelect,
  });

  Future<void> _toggleDone(BuildContext context) async {
    if (appointment.isDone) {
      final shouldUndo = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => ContentDialog(
          title: const Text('Undo completion?'),
          content:
              const Text('This appointment will be moved back to Pending.'),
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
              child: const Text('Undo Complete'),
            ),
          ],
        ),
      );
      if (shouldUndo != true) return;
      appointment.isDone = false;
      appointments.set(appointment);
      return;
    }

    final shouldComplete = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => ContentDialog(
        title: const Text('Mark as complete?'),
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
    appointment.isDone = true;
    appointments.set(appointment);
  }

  static Color _doctorChipColor(String doctor) {
    const palette = [
      Color(0xFFEAF2FC),
      Color(0xFFE8F8F3),
      Color(0xFFFFF2E5),
      Color(0xFFF2EDFF),
      Color(0xFFFFEEF2),
      Color(0xFFE9F7FF),
      Color(0xFFF3F7EA),
    ];
    return palette[doctor.hashCode.abs() % palette.length];
  }

  static Color _doctorChipBorderColor(String doctor) {
    const palette = [
      Color(0xFF9FC4F1),
      Color(0xFF8FD4BD),
      Color(0xFFE7C08D),
      Color(0xFFC2B3EF),
      Color(0xFFE5B2C0),
      Color(0xFFA9D4EB),
      Color(0xFFBDD2A0),
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
                      color: Color(0xFF1459AD),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${DateFormat('h:mm a').format(appointment.date)} • $phone • ${age}y',
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
              onPressed: () => _toggleDone(context),
              style: ButtonStyle(
                backgroundColor: WidgetStateProperty.all(
                  appointment.isDone
                      ? const Color(0xFFD6455D)
                      : const Color(0xFF3B9A42),
                ),
                foregroundColor: WidgetStateProperty.all(Colors.white),
              ),
              child: Text(appointment.isDone ? 'Undo Complete' : 'Complete'),
            ),
            if (showHistoryAction) ...[
              const SizedBox(width: 8),
              Button(
                onPressed: () => _openPatientHistoryDialog(context),
                child: const Text('History'),
              ),
            ],
            const SizedBox(width: 8),
            Button(
              onPressed: () => openAppointment(appointment),
              child: const Text('Open'),
            ),
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
    final todaysPatientTreatments = <String>{};

    if (selected != null) {
      for (final appointment in todaysAppointments) {
        if (appointment.patientID != selected.patientID) continue;
        for (final treatment in appointment.selectedTreatments) {
          final v = treatment.trim();
          if (v.isNotEmpty) todaysPatientTreatments.add(v);
        }
      }
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
                    'Select a patient from Pending or Completed to view history.',
                    style: TextStyle(color: Color(0xFF6D84A8)),
                  ),
                ),
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Today Treatment Snapshot',
                    style: TextStyle(
                      color: Color(0xFF2C4E76),
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 6),
                  if (todaysPatientTreatments.isEmpty)
                    const Padding(
                      padding: EdgeInsets.only(bottom: 10),
                      child: Text(
                        'No treatments added for today.',
                        style:
                            TextStyle(color: Color(0xFF6D84A8), fontSize: 12),
                      ),
                    )
                  else
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: todaysPatientTreatments
                            .map(
                              (treatment) => Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFEAF2FC),
                                  borderRadius: BorderRadius.circular(999),
                                  border: Border.all(
                                      color: const Color(0xFFD5E5F7)),
                                ),
                                child: Text(
                                  treatment,
                                  style: const TextStyle(
                                    color: Color(0xFF2F5B88),
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            )
                            .toList(growable: false),
                      ),
                    ),
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

    Widget historyCard(Appointment a) {
      return Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
        decoration: BoxDecoration(
          color: const Color(0xFFF6FAFF),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFE2ECF8)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  DateFormat('dd MMM yyyy • h:mm a').format(a.date),
                  style: const TextStyle(
                    color: Color(0xFF2F4F76),
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
                const Spacer(),
                Text(
                  a.isDone ? 'Completed' : 'Pending',
                  style: TextStyle(
                    color: a.isDone
                        ? const Color(0xFF3B9A42)
                        : const Color(0xFFE4A11B),
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 5),
            Text(
              a.operators.isEmpty
                  ? 'Doctor: Unassigned'
                  : 'Doctor: ${a.operators.map((d) => d.title).join(', ')}',
              style: const TextStyle(
                color: Color(0xFF1357A8),
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      );
    }

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
        _AssignDoctorDrop(appointment: appointment),
        const SizedBox(height: 10),
        _LastAppointmentInsightCard(lastAppointment: lastAppointment),
        const SizedBox(height: 10),
        _CheckinOperativeForm(
            appointment: appointment, allAppointmentsForPatient: all),
        const SizedBox(height: 10),
        _PatientJourneyTimeline(appointments: all),
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
        const Text(
          'Other Appointments',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: Color(0xFF2C4E76),
          ),
        ),
        const SizedBox(height: 8),
        if (otherRows.isEmpty)
          const Text(
            'No older history found for this patient.',
            style: TextStyle(color: Color(0xFF6D84A8)),
          )
        else
          ...otherRows.map(historyCard),
      ],
    );
  }
}

class _AssignDoctorDrop extends StatefulWidget {
  final Appointment appointment;

  const _AssignDoctorDrop({required this.appointment});

  @override
  State<_AssignDoctorDrop> createState() => _AssignDoctorDropState();
}

class _AssignDoctorDropState extends State<_AssignDoctorDrop> {
  @override
  Widget build(BuildContext context) {
    final appointment = widget.appointment;
    final assignableDoctorIds = <String>[
      '__unassigned__',
      ...doctors.present.values.map((d) => d.id),
    ];

    final selectedId = appointment.operatorsIDs.isEmpty
        ? '__unassigned__'
        : appointment.operatorsIDs.first;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Assign Doctor',
          style: TextStyle(
            color: Color(0xFF2C4E76),
            fontWeight: FontWeight.w700,
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 6),
        SizedBox(
          width: 340,
          child: material.DropdownButtonFormField<String>(
            value: assignableDoctorIds.contains(selectedId)
                ? selectedId
                : '__unassigned__',
            isExpanded: true,
            icon: const Icon(FluentIcons.chevron_down, size: 11),
            decoration: material.InputDecoration(
              isDense: true,
              filled: true,
              fillColor: const Color(0xFFF8FBFF),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              border: material.OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const material.BorderSide(color: Color(0xFFCFE0F3)),
              ),
              enabledBorder: material.OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const material.BorderSide(color: Color(0xFFCFE0F3)),
              ),
              focusedBorder: material.OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const material.BorderSide(color: Color(0xFF2D7BD8)),
              ),
            ),
            items: assignableDoctorIds
                .map(
                  (id) => material.DropdownMenuItem<String>(
                    value: id,
                    child: Text(
                      id == '__unassigned__'
                          ? 'Unassigned'
                          : (doctors.get(id)?.title ?? 'Unknown'),
                      style: const TextStyle(fontSize: 13),
                    ),
                  ),
                )
                .toList(growable: false),
            onChanged: (value) {
              if (value == null) return;
              setState(() {
                appointment.operatorsIDs =
                    value == '__unassigned__' ? <String>[] : <String>[value];
              });
              appointments.set(appointment);
            },
          ),
        ),
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
  Set<String> _selectedTreatments = {};
  Set<String> _selectedTeeth = {};

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
    _selectedTreatments = a.selectedTreatments.toSet();
    _selectedTeeth = a.selectedTeeth.toSet();
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
    final rawPrice = double.tryParse(_priceController.text.trim()) ?? 0;
    final discount = double.tryParse(_discountController.text.trim()) ?? 0;

    double finalPrice = rawPrice;
    if (discount > 0) {
      if (_discountType == 'percent') {
        finalPrice = rawPrice - (rawPrice * discount / 100);
      } else {
        finalPrice = rawPrice - discount;
      }
      if (finalPrice < 0) finalPrice = 0;
    }

    a.discount = discount;
    a.discountType = _discountType;
    a.price = finalPrice;
    a.isDone = true;

    _priceController.text =
        finalPrice == 0 ? '' : finalPrice.toStringAsFixed(0);
    appointments.set(a);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final a = widget.appointment;

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
          const Text(
            'Operative Inputs',
            style: TextStyle(
              color: Color(0xFF2C4E76),
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 8),
          InfoLabel(
            label: 'Diagnosis:',
            child: TagInputWidget(
              suggestions: allDiagnosis
                  .map((d) => TagInputItem(value: d, label: d))
                  .toList(),
              onChanged: (values) {
                a.diagnosis = values
                    .where((e) => e.value != null)
                    .map((e) => e.value!)
                    .toList(growable: false);
                a.isDone = true;
                appointments.set(a);
              },
              initialValue: a.diagnosis
                  .map((v) => TagInputItem(value: v, label: v))
                  .toList(),
              strict: false,
              limit: 999,
              placeholder: 'Diagnosis...',
            ),
          ),
          const SizedBox(height: 8),
          InfoLabel(
            label: 'Treatment:',
            child: TagInputWidget(
              suggestions: allTreatments
                  .map((t) => TagInputItem(
                      value: t.name, label: '${t.name} - ₹${t.price}'))
                  .toList(),
              onChanged: (values) {
                _selectedTreatments = values
                    .where((e) => e.value != null)
                    .map((e) => e.value!)
                    .toSet();
                a.selectedTreatments =
                    _selectedTreatments.toList(growable: false);
                a.isDone = true;
                appointments.set(a);
                setState(() {});
              },
              initialValue: _selectedTreatments
                  .map((v) => TagInputItem(value: v, label: v))
                  .toList(growable: false),
              strict: false,
              limit: 999,
              placeholder: 'Treatments...',
            ),
          ),
          const SizedBox(height: 8),
          TeethPicker(
            selectedTeeth: _selectedTeeth,
            isAdult: _selectedTeeth.every((t) =>
                t.startsWith('1') ||
                t.startsWith('2') ||
                t.startsWith('3') ||
                t.startsWith('4')),
            onChanged: (teeth) {
              _selectedTeeth = teeth;
              a.selectedTeeth = teeth.toList(growable: false);
              a.isDone = true;
              appointments.set(a);
              setState(() {});
            },
          ),
          const SizedBox(height: 8),
          InfoLabel(
            label: 'Post-operative notes:',
            child: CupertinoTextField(
              controller: _postOpController,
              onChanged: (value) {
                a.postOpNotes = value;
                a.isDone = true;
                appointments.set(a);
              },
              placeholder: 'Post-operative notes',
            ),
          ),
          const SizedBox(height: 8),
          InfoLabel(
            label: 'Discount',
            child: CupertinoTextField(
              controller: _discountController,
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))
              ],
              onChanged: (_) => _applyDiscount(),
              placeholder: 'Discount',
              suffix: GestureDetector(
                onTap: () {
                  setState(() {
                    _discountType =
                        _discountType == 'percent' ? 'flat' : 'percent';
                    _applyDiscount();
                  });
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Text(_discountType == 'percent' ? '%' : '₹'),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: InfoLabel(
                  label:
                      'Price in ${globalSettings.get("currency_______").value}',
                  child: CupertinoTextField(
                    controller: _priceController,
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))
                    ],
                    onChanged: (value) {
                      a.price = double.tryParse(value) ?? 0;
                      a.isDone = true;
                      appointments.set(a);
                    },
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: InfoLabel(
                  label:
                      'Paid in ${globalSettings.get("currency_______").value}',
                  child: CupertinoTextField(
                    controller: _paidController,
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))
                    ],
                    onChanged: (value) {
                      a.paid = double.tryParse(value) ?? 0;
                      a.isDone = true;
                      appointments.set(a);
                    },
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Checkbox(
            checked: a.treatmentGpayPaid,
            onChanged: (checked) {
              setState(() {
                a.treatmentGpayPaid = checked ?? false;
                a.isDone = true;
              });
              appointments.set(a);
            },
            content: const Text('Paid via GPay'),
          ),
          Checkbox(
            checked: a.isDone,
            onChanged: (checked) {
              setState(() {
                a.isDone = checked == true;
              });
              appointments.set(a);
            },
            content: const Text('Appointment is done'),
          ),
        ],
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

    return Align(
      alignment: Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: Container(
          margin: const EdgeInsets.only(bottom: 10),
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
                            ],
                          ),
                        ),
                      ),
                    ],
                  );
                }),
            ],
          ),
        ),
      ),
    );
  }
}
