import 'package:apexo/common_widgets/patients_report_dialog.dart';
import 'package:apexo/common_widgets/tag_input.dart';
import 'package:apexo/common_widgets/teeth_picker.dart';
import 'package:apexo/features/appointments/appointment_model.dart';
import 'package:apexo/features/appointments/appointments_store.dart';
import 'package:apexo/features/appointments/open_appointment_panel.dart';
import 'package:apexo/features/checkin/odontogram/odontogram_picker.dart';
import 'package:apexo/features/checkin/odontogram/tooth_model.dart';
import 'package:apexo/features/checkin/odontogram/treatment_colors.dart';
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
        _CheckinOperativeForm(
            appointment: appointment, allAppointmentsForPatient: all),
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
  bool _discountEnabled = false;
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
    final rawPrice = double.tryParse(_priceController.text.trim()) ?? 0;
    final discount = _discountEnabled
      ? (double.tryParse(_discountController.text.trim()) ?? 0.0)
      : 0.0;

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

    _priceController.text =
        finalPrice == 0 ? '' : finalPrice.toStringAsFixed(0);
    appointments.set(a);
    setState(() {});
  }

  void _applyPriceSuggestion(int value) {
    final a = widget.appointment;
    _priceController.text = '$value';
    a.price = value.toDouble();
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

  List<String> _topTreatments() {
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
    setState(() => a.isDone = true);
    appointments.set(a);
  }

  @override
  Widget build(BuildContext context) {
    final a = widget.appointment;
    final topTreatments = _topTreatments();

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
          LayoutBuilder(
            builder: (context, constraints) {
              final twoColumns = constraints.maxWidth >= 860;
              final firstColumn = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
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
                  if (topTreatments.isNotEmpty) ...[
                    const SizedBox(height: 6),
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
                  const SizedBox(height: 8),
                  _EnhancedTeethPickerCard(
                    selectedTeeth: _selectedTeeth,
                    onChanged: (teeth) {
                      _selectedTeeth = teeth;
                      a.selectedTeeth = teeth.toList(growable: false);
                      appointments.set(a);
                      setState(() {});
                    },
                  ),
                  const SizedBox(height: 8),
                  _SvgOdontogramCard(
                    teeth: _teethStates,
                    selectedTreatment: _selectedOdontogramTreatment,
                    selectedToothId: _selectedOdontogramToothId,
                    selectedToothNote: _odontogramNotes[_selectedOdontogramToothId] ?? '',
                    onToothNoteChanged: (value) {
                      _odontogramNotes[_selectedOdontogramToothId] = value;
                    },
                    onSelectTooth: (toothId) =>
                        setState(() => _selectedOdontogramToothId = toothId),
                    onTreatmentChanged: (value) =>
                        setState(() => _selectedOdontogramTreatment = value),
                    onSurfaceTap: _onOdontogramSurfaceTap,
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
                      onChanged: (value) {
                        a.postOpNotes = value;
                        appointments.set(a);
                      },
                      placeholder: 'Post-operative notes',
                    ),
                  ),
                  const SizedBox(height: 8),
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
                          setState(() => _discountEnabled = value);
                          if (!value) {
                            _discountController.clear();
                          }
                          _applyDiscount();
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  if (_discountEnabled) ...[
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
                      ),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        _quickChip(
                          label: '₹ Flat',
                          selected: _discountType == 'flat',
                          onTap: () {
                            setState(() => _discountType = 'flat');
                            _applyDiscount();
                          },
                        ),
                        _quickChip(
                          label: '% Percent',
                          selected: _discountType == 'percent',
                          onTap: () {
                            setState(() => _discountType = 'percent');
                            _applyDiscount();
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [5, 10, 15, 20, 25]
                          .map(
                            (v) => _quickChip(
                              label: _discountType == 'percent' ? '$v%' : '₹$v',
                              onTap: () => _applyDiscountSuggestion(v),
                            ),
                          )
                          .toList(growable: false),
                    ),
                    const SizedBox(height: 8),
                  ],
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
                              appointments.set(a);
                              _applyDiscount();
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
                              appointments.set(a);
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [100, 200, 500, 1000, 2000]
                        .map(
                          (v) => GestureDetector(
                            onTap: () => _applyPriceSuggestion(v),
                            child: Container(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: const Color(0xFFEAF2FC),
                                borderRadius: BorderRadius.circular(999),
                                border: Border.all(color: const Color(0xFFD5E5F7)),
                              ),
                              child: Text(
                                '₹$v',
                                style: const TextStyle(
                                  color: Color(0xFF2F5B88),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                        )
                        .toList(growable: false),
                  ),
                ],
              );

              if (!twoColumns) {
                return Column(
                  children: [
                    firstColumn,
                    const SizedBox(height: 8),
                    secondColumn,
                  ],
                );
              }

              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: firstColumn),
                  const SizedBox(width: 10),
                  Expanded(child: secondColumn),
                ],
              );
            },
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
              backgroundColor: WidgetStateProperty.all(
                a.isDone ? const Color(0xFFD6455D) : const Color(0xFF2BA58D),
              ),
              foregroundColor: WidgetStateProperty.all(Colors.white),
            ),
            onPressed: _confirmDoneToggle,
            child: Text(a.isDone ? 'Undo Done' : 'Mark Appointment Done'),
          ),
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

class _SvgOdontogramCard extends StatelessWidget {
  final Map<String, ToothState> teeth;
  final TreatmentType selectedTreatment;
  final String selectedToothId;
  final String selectedToothNote;
  final ValueChanged<String> onSelectTooth;
  final ValueChanged<String> onToothNoteChanged;
  final ValueChanged<TreatmentType> onTreatmentChanged;
  final void Function(String toothId, ToothSurface surface) onSurfaceTap;

  const _SvgOdontogramCard({
    required this.teeth,
    required this.selectedTreatment,
    required this.selectedToothId,
    required this.selectedToothNote,
    required this.onSelectTooth,
    required this.onToothNoteChanged,
    required this.onTreatmentChanged,
    required this.onSurfaceTap,
  });

  @override
  Widget build(BuildContext context) {
    Widget treatmentChip(TreatmentType treatment, String label) {
      final selected = selectedTreatment == treatment;
      return GestureDetector(
        onTap: () => onTreatmentChanged(treatment),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: selected
                ? getTreatmentColor(treatment).withValues(alpha: 0.18)
                : const Color(0xFFF4F8FD),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: selected
                  ? getTreatmentColor(treatment)
                  : const Color(0xFFD6E2F0),
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: selected
                  ? getTreatmentColor(treatment)
                  : const Color(0xFF355279),
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
        ),
      );
    }

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
          final selectedTooth =
              teeth[selectedToothId] ?? ToothState(toothId: selectedToothId);
          final activeTreatments = selectedTooth.surfaces.entries
              .where((entry) => entry.value != null)
              .toList(growable: false);

          Widget surfaceButton(String label, ToothSurface surface) {
            final value = selectedTooth.surfaces[surface];
            final active = value != null;
            final color = getTreatmentColor(value);
            return GestureDetector(
              onTap: () => onSurfaceTap(selectedToothId, surface),
              child: Container(
                width: 36,
                height: 30,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: active ? color.withValues(alpha: 0.18) : const Color(0xFFF4F8FD),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: active ? color : const Color(0xFFD6E2F0),
                  ),
                ),
                child: Text(
                  label,
                  style: TextStyle(
                    color: active ? color : const Color(0xFF355279),
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              ),
            );
          }

          final leftPanel = Container(
            width: 210,
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
                  'Treatment Selection',
                  style: TextStyle(
                    color: Color(0xFF2C4E76),
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    treatmentChip(TreatmentType.filling, 'Filling'),
                    const SizedBox(height: 6),
                    treatmentChip(TreatmentType.rootCanal, 'Root Canal'),
                    const SizedBox(height: 6),
                    treatmentChip(TreatmentType.crown, 'Crown'),
                    const SizedBox(height: 6),
                    treatmentChip(TreatmentType.extraction, 'Extraction'),
                    const SizedBox(height: 6),
                    treatmentChip(TreatmentType.implant, 'Implant'),
                  ],
                ),
              ],
            ),
          );

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
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    surfaceButton('M', ToothSurface.mesial),
                    surfaceButton('D', ToothSurface.distal),
                    surfaceButton('O', ToothSurface.occlusal),
                    surfaceButton('B', ToothSurface.buccal),
                    surfaceButton('L', ToothSurface.lingual),
                  ],
                ),
                const SizedBox(height: 10),
                const Text(
                  'Current Treatments:',
                  style: TextStyle(
                    color: Color(0xFF2C4E76),
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 6),
                if (activeTreatments.isEmpty)
                  const Text(
                    'No treatment assigned.',
                    style: TextStyle(
                      color: Color(0xFF6D84A8),
                      fontSize: 12,
                    ),
                  )
                else
                  ...activeTreatments.map((entry) {
                    final label = switch (entry.key) {
                      ToothSurface.mesial => 'M',
                      ToothSurface.distal => 'D',
                      ToothSurface.occlusal => 'O',
                      ToothSurface.buccal => 'B',
                      ToothSurface.lingual => 'L',
                    };
                    final treatmentLabel = switch (entry.value!) {
                      TreatmentType.filling => 'Filling',
                      TreatmentType.rootCanal => 'Root Canal',
                      TreatmentType.crown => 'Crown',
                      TreatmentType.extraction => 'Extraction',
                      TreatmentType.implant => 'Implant',
                    };
                    return Container(
                      width: double.infinity,
                      margin: const EdgeInsets.only(bottom: 5),
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF5FAFF),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFD5E5F7)),
                      ),
                      child: Text(
                        '$label - $treatmentLabel',
                        style: const TextStyle(
                          color: Color(0xFF355279),
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                      ),
                    );
                  }),
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
                leftPanel,
                const SizedBox(height: 8),
                SizedBox(height: 280, child: centerPanel),
                const SizedBox(height: 8),
                rightPanel,
              ],
            );
          }

          return SizedBox(
            height: 360,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                leftPanel,
                const SizedBox(width: 8),
                centerPanel,
                const SizedBox(width: 8),
                rightPanel,
              ],
            ),
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
