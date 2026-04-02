import 'package:apexo/features/appointments/appointment_model.dart';
import 'package:apexo/features/appointments/appointments_store.dart';
import 'package:apexo/features/appointments/open_appointment_panel.dart';
import 'package:apexo/common_widgets/patients_report_dialog.dart';
import 'package:apexo/features/doctors/doctors_store.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/material.dart' as material;
import 'package:intl/intl.dart';

class CheckinScreen extends StatefulWidget {
  const CheckinScreen({super.key});

  @override
  State<CheckinScreen> createState() => _CheckinScreenState();
}

class _CheckinScreenState extends State<CheckinScreen> {
  DateTime _selectedDate = _dateOnly(DateTime.now());
  String _selectedDoctor = '__all__';

  static DateTime _dateOnly(DateTime input) {
    return DateTime(input.year, input.month, input.day);
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
    );

    if (picked == null) return;
    setState(() {
      _selectedDate = _dateOnly(picked);
    });
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
      stream: appointments.observableMap.stream,
      builder: (context, _) {
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
          if (_selectedDoctor == '__unassigned__') return a.operatorsIDs.isEmpty;
          return a.operatorsIDs.contains(_selectedDoctor);
        }).toList(growable: false);

        final pending = filtered.where((a) => !a.isDone).toList(growable: false);
        final completed = filtered.where((a) => a.isDone).toList(growable: false);

        return Container(
          color: const Color(0xFFF3F7FC),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    const Text(
                      'Checkin Workflow',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF183A67),
                      ),
                    ),
                    const Spacer(),
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
                    FilledButton(
                      onPressed: () => setState(() {
                        _selectedDate = _dateOnly(DateTime.now());
                      }),
                      child: const Text('Today'),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
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
                      onTap: () => setState(() => _selectedDoctor = '__unassigned__'),
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
                _WorkflowColumn(
                  title: 'Pending',
                  color: const Color(0xFFE4A11B),
                  rows: pending,
                  showHistoryAction: true,
                ),
                const SizedBox(height: 10),
                _WorkflowColumn(
                  title: 'Completed',
                  color: const Color(0xFF3B9A42),
                  rows: completed,
                ),
              ],
            ),
          ),
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
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF2D7BD8) : Colors.white,
          borderRadius: BorderRadius.circular(10),
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

  const _WorkflowColumn({
    required this.title,
    required this.color,
    required this.rows,
    this.showHistoryAction = false,
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

  const _WorkflowRow({
    required this.appointment,
    this.showHistoryAction = false,
  });

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
    final doctor = appointment.operators.isEmpty
        ? 'Unassigned'
        : appointment.operators.map((d) => d.title).join(', ');
    final phone = appointment.patient?.phone ?? '-';
    final age = appointment.patient?.age ?? 0;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: Color(0xFFE2ECF8))),
      ),
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
                  '${DateFormat('h:mm a').format(appointment.date)} • $phone • ${age}y • $doctor',
                  style: const TextStyle(
                    color: Color(0xFF6D84A8),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          FilledButton(
            onPressed: () {
              appointment.isCheckedIn = !appointment.isCheckedIn;
              appointment.checkedInAt = appointment.isCheckedIn ? DateTime.now() : null;
              appointments.set(appointment);
            },
            style: ButtonStyle(
              backgroundColor: WidgetStateProperty.all(
                appointment.isCheckedIn ? const Color(0xFF1F8F4E) : const Color(0xFF2D7BD8),
              ),
            ),
            child: Text(appointment.isCheckedIn ? 'Undo Checkin' : 'Checkin'),
          ),
          const SizedBox(width: 8),
          Button(
            onPressed: () {
              appointment.isDone = !appointment.isDone;
              appointments.set(appointment);
            },
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
    );
  }
}
