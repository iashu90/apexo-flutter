import 'package:apexo/features/appointments/appointment_model.dart';
import 'package:apexo/features/appointments/appointments_store.dart';
import 'package:apexo/features/appointments/open_appointment_panel.dart';
import 'package:apexo/common_widgets/patients_report_dialog.dart';
import 'package:apexo/features/doctors/doctors_store.dart';
import 'package:apexo/features/patients/patients_store.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/material.dart' as material;
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
              if (_selectedDoctor == '__unassigned__') {
                return a.operatorsIDs.isEmpty;
              }
              return a.operatorsIDs.contains(_selectedDoctor);
            }).toList(growable: false);

            final pending =
                filtered.where((a) => !a.isDone).toList(growable: false);
            final completed =
                filtered.where((a) => a.isDone).toList(growable: false);
            final today = DateTime.now();
            final isToday = _selectedDate.year == today.year &&
                _selectedDate.month == today.month &&
                _selectedDate.day == today.day;

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
                            child: Container(
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
                                    child: const Icon(
                                      FluentIcons.chevron_left,
                                      size: 12,
                                    ),
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
                                    child: const Icon(
                                      FluentIcons.chevron_right,
                                      size: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          Align(
                            alignment: Alignment.centerRight,
                            child: SizedBox(
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
                          onTap: () => setState(() => _selectedDoctor = '__all__'),
                        ),
                        _DoctorFilterChip(
                          label: 'Unassigned',
                          selected: _selectedDoctor == '__unassigned__',
                          onTap: () =>
                              setState(() => _selectedDoctor = '__unassigned__'),
                        ),
                        ...doctorOptions
                            .where((id) => id != '__unassigned__')
                            .map((id) {
                          final doctorName = doctors.get(id)?.title ?? 'Unknown';
                          return _DoctorFilterChip(
                            label: doctorName,
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

                        final history = Expanded(
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
                              SizedBox(
                                width: double.infinity,
                                child: _CheckinHistoryPanel(
                                  selectedAppointment: _selectedAppointment,
                                  todaysAppointments: filtered,
                                ),
                              ),
                            ],
                          );
                        }

                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            lists,
                            const SizedBox(width: 10),
                            history,
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
              borderRadius: const BorderRadius.vertical(top: Radius.circular(11)),
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
          content: const Text(
            'This appointment will be moved back to Pending.',
          ),
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
    final patientName = appointment.title.trim().isEmpty ? 'Unnamed patient' : appointment.title;
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
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: _doctorChipColor(doctor),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: _doctorChipBorderColor(doctor),
                            ),
                          ),
                          child: Text(
                            doctor,
                            style: const TextStyle(
                              color: Color(0xFF0B4A96),
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                            ),
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
                appointment.isDone ? const Color(0xFFD6455D) : const Color(0xFF3B9A42),
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
          final value = treatment.trim();
          if (value.isNotEmpty) {
            todaysPatientTreatments.add(value);
          }
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
                        style: TextStyle(
                          color: Color(0xFF6D84A8),
                          fontSize: 12,
                        ),
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
                                  horizontal: 8,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFEAF2FC),
                                  borderRadius: BorderRadius.circular(999),
                                  border: Border.all(color: const Color(0xFFD5E5F7)),
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
    final currentChiefComplaint = appointment.preOpNotes.trim();
    final currentDiagnosis = appointment.diagnosis
      .map((d) => d.trim())
      .where((d) => d.isNotEmpty)
      .join(', ');
    final currentTeeth = appointment.selectedTeeth
      .map((t) => t.trim())
      .where((t) => t.isNotEmpty)
      .join(', ');
    final currentNotes = [appointment.preOpNotes.trim(), appointment.postOpNotes.trim()]
        .where((n) => n.isNotEmpty)
        .join(' | ');
    final pid = appointment.patientID;
    final all = appointments.present.values
        .where((a) => pid != null && pid.isNotEmpty && a.patientID == pid)
        .toList(growable: false)
      ..sort((a, b) => b.date.compareTo(a.date));

    final todayRows = all.where((a) => _sameDay(a.date, appointment.date)).toList(growable: false);
    final otherRows = all.where((a) => !_sameDay(a.date, appointment.date)).take(20).toList(growable: false);
    final assignableDoctorIds = <String>[
      '__unassigned__',
      ...doctors.present.values.map((d) => d.id),
    ];

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
                    color:
                        a.isDone ? const Color(0xFF3B9A42) : const Color(0xFFE4A11B),
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
            const SizedBox(height: 4),
            Text(
              a.preOpNotes.trim().isEmpty
                  ? 'Chief complaint: -'
                  : 'Chief complaint: ${a.preOpNotes.trim()}',
              style: const TextStyle(
                color: Color(0xFF5F789B),
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              a.diagnosis.where((d) => d.trim().isNotEmpty).isEmpty
                  ? 'Diagnosis: -'
                  : 'Diagnosis: ${a.diagnosis.where((d) => d.trim().isNotEmpty).join(', ')}',
              style: const TextStyle(
                color: Color(0xFF5F789B),
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              a.selectedTeeth.where((t) => t.trim().isNotEmpty).isEmpty
                  ? 'Teeth: -'
                  : 'Teeth: ${a.selectedTeeth.where((t) => t.trim().isNotEmpty).join(', ')}',
              style: const TextStyle(
                color: Color(0xFF5F789B),
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 5),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: a.selectedTreatments.isEmpty
                  ? const [
                      Text(
                        'No treatments recorded',
                        style: TextStyle(
                          color: Color(0xFF8AA0BC),
                          fontSize: 11,
                        ),
                      ),
                    ]
                  : a.selectedTreatments
                      .map(
                        (t) => Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEAF2FC),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(
                              color: const Color(0xFFD5E5F7),
                            ),
                          ),
                          child: Text(
                            t,
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
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFF6D84A8),
              ),
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
          children: [
            const Text(
              'Assign Doctor',
              style: TextStyle(
                color: Color(0xFF2C4E76),
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              constraints: const BoxConstraints(minWidth: 220, maxWidth: 320),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFFEAF2FC),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFCFE0F3)),
              ),
              child: ComboBox<String>(
                value: appointment.operatorsIDs.isEmpty
                    ? '__unassigned__'
                    : appointment.operatorsIDs.first,
                items: assignableDoctorIds
                    .map(
                      (id) => ComboBoxItem<String>(
                        value: id,
                        child: Text(
                          id == '__unassigned__'
                              ? 'Unassigned'
                              : (doctors.get(id)?.title ?? 'Unknown'),
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
            const SizedBox(width: 8),
            FilledButton(
              onPressed: () => openAppointment(appointment, 1),
              style: ButtonStyle(
                backgroundColor:
                    WidgetStateProperty.all(const Color(0xFF2D7BD8)),
              ),
              child: const Text('Operative Details'),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Container(
          width: double.infinity,
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
                'Current Visit Overview',
                style: TextStyle(
                  color: Color(0xFF2C4E76),
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                currentChiefComplaint.isEmpty
                    ? 'Chief complaint: -'
                    : 'Chief complaint: $currentChiefComplaint',
                style: const TextStyle(
                  color: Color(0xFF5F789B),
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                currentDiagnosis.isEmpty
                    ? 'Diagnosis: -'
                    : 'Diagnosis: $currentDiagnosis',
                style: const TextStyle(
                  color: Color(0xFF5F789B),
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                currentTeeth.isEmpty ? 'Teeth: -' : 'Teeth: $currentTeeth',
                style: const TextStyle(
                  color: Color(0xFF5F789B),
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
        Container(
          width: double.infinity,
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
                'Medical Notes',
                style: TextStyle(
                  color: Color(0xFF2C4E76),
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                currentNotes.isEmpty ? 'Visit: -' : 'Visit: $currentNotes',
                style: const TextStyle(
                  color: Color(0xFF5F789B),
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                patientNotes.isEmpty ? 'Patient: -' : 'Patient: $patientNotes',
                style: const TextStyle(
                  color: Color(0xFF5F789B),
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        _PatientJourneyTimeline(appointments: all),
        const SizedBox(height: 8),
        _PatientJourneyTimelineHorizontal(appointments: all),
        const SizedBox(height: 10),
        const Text(
          "Today's Appointments",
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: Color(0xFF2C4E76),
          ),
        ),
        const SizedBox(height: 8),
        if (todayRows.isEmpty)
          const Text(
            'No appointments today for this patient.',
            style: TextStyle(color: Color(0xFF6D84A8)),
          )
        else
          ...todayRows.map(historyCard),
        const SizedBox(height: 10),
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

class _PatientJourneyTimeline extends StatelessWidget {
  final List<Appointment> appointments;

  const _PatientJourneyTimeline({required this.appointments});

  @override
  Widget build(BuildContext context) {
    final points = appointments.take(8).toList(growable: false).reversed.toList(growable: false);

    return Container(
      width: double.infinity,
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
            ...points.asMap().entries.map(
              (entry) {
                final item = entry.value;
                final treatments = item.selectedTreatments.where((t) => t.trim().isNotEmpty).join(', ');
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
              },
            ),
        ],
      ),
    );
  }
}

class _PatientJourneyTimelineHorizontal extends StatelessWidget {
  final List<Appointment> appointments;

  const _PatientJourneyTimelineHorizontal({required this.appointments});

  @override
  Widget build(BuildContext context) {
    final points = appointments
        .take(8)
        .toList(growable: false)
        .reversed
        .toList(growable: false);

    return Container(
      width: double.infinity,
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
            'Journey Timeline (Horizontal)',
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
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: points.asMap().entries.map((entry) {
                  final item = entry.value;
                  final treatments = item.selectedTreatments
                      .where((t) => t.trim().isNotEmpty)
                      .join(', ');
                  final isLast = entry.key == points.length - 1;

                  return Row(
                    children: [
                      SizedBox(
                        width: 170,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              DateFormat('dd MMM').format(item.date),
                              style: const TextStyle(
                                color: Color(0xFF1F446E),
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              treatments.isEmpty ? '-' : treatments,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Color(0xFF5F789B),
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (!isLast)
                        Row(
                          children: const [
                            SizedBox(width: 4),
                            Icon(
                              FluentIcons.chevron_right,
                              size: 11,
                              color: Color(0xFF8AA0BC),
                            ),
                            SizedBox(width: 8),
                          ],
                        ),
                    ],
                  );
                }).toList(growable: false),
              ),
            ),
        ],
      ),
    );
  }
}
