import 'package:apexo/features/appointments/appointment_model.dart';
import 'package:apexo/features/appointments/appointments_store.dart';
import 'package:apexo/features/patients/patient_model.dart';
import 'package:apexo/features/patients/patients_store.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/material.dart' as material;
import 'package:intl/intl.dart';

typedef PatientLookupAddPatient = Future<Patient?> Function(String query);
typedef PatientLookupOpenExisting = Future<void> Function(
  Appointment appointment,
);
typedef PatientLookupCheckInPatient = Future<void> Function(Patient patient);

Future<DateTime?> _pickScheduleDateTime(
  BuildContext context,
  DateTime selectedDate,
  Patient? patient,
) async {
  final now = DateTime.now();
  DateTime pickedDate = selectedDate.isBefore(now)
      ? DateTime(now.year, now.month, now.day)
      : DateTime(selectedDate.year, selectedDate.month, selectedDate.day);
  material.TimeOfDay pickedTime = const material.TimeOfDay(
    hour: 10,
    minute: 0,
  );

  DateTime? result;

  await showDialog<void>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (context, setStateDialog) {
        final updatedDateTime = DateTime(
          pickedDate.year,
          pickedDate.month,
          pickedDate.day,
          pickedTime.hour,
          pickedTime.minute,
        );

        return ContentDialog(
          title: const Text('Schedule Appointment'),
          content: SizedBox(
            width: 460,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (patient != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Text(
                      '${patient.title.trim().isEmpty ? 'Unnamed patient' : _toTitleCase(patient.title)} • ${patient.age}y • ${patient.phone.trim().isEmpty ? '-' : patient.phone}',
                      style: const TextStyle(
                        color: Color(0xFF355279),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                Row(
                  children: [
                    const Text(
                      'Date:',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(width: 8),
                    Button(
                      onPressed: () async {
                        final next = await material.showDatePicker(
                          context: context,
                          initialDate: pickedDate,
                          firstDate: DateTime(now.year - 1, 1, 1),
                          lastDate: DateTime(now.year + 5, 12, 31),
                          helpText: 'Select appointment date',
                        );
                        if (next == null) return;
                        setStateDialog(() {
                          pickedDate = DateTime(next.year, next.month, next.day);
                        });
                      },
                      child: Text(DateFormat('dd MMM yyyy').format(pickedDate)),
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
                        final next = await material.showTimePicker(
                          context: context,
                          initialTime: pickedTime,
                          helpText: 'Select appointment time',
                        );
                        if (next == null) return;
                        setStateDialog(() => pickedTime = next);
                      },
                      child: Text(pickedTime.format(context)),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  'Scheduled: ${DateFormat('dd MMM yyyy, h:mm a').format(updatedDateTime)}',
                  style: const TextStyle(
                    color: Color(0xFF1459AD),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          actions: [
            Button(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                result = updatedDateTime;
                Navigator.pop(dialogContext);
              },
              child: const Text('Schedule'),
            ),
          ],
        );
      },
    ),
  );

  return result;
}

Future<DateTime?> _scheduleAppointmentForPatient(
  BuildContext context,
  Patient patient,
  DateTime selectedDate,
) async {
  final scheduledAt =
      await _pickScheduleDateTime(context, selectedDate, patient);
  if (scheduledAt == null) return null;

  final appointment = Appointment.fromJson({});
  appointment.patientID = patient.id;
  appointment.date = scheduledAt;
  appointment.checkinStage = 'scheduled';
  appointments.set(appointment);

  return scheduledAt;
}

Future<void> showPatientCheckinLookupDialog({
  required BuildContext context,
  required DateTime selectedDate,
  required PatientLookupAddPatient onAddPatient,
  required PatientLookupOpenExisting onOpenExisting,
  required PatientLookupCheckInPatient onCheckInPatient,
  String title = 'Patient Check-in',
}) async {
  await showDialog<void>(
    context: context,
    builder: (dialogContext) {
      final screen = MediaQuery.of(dialogContext).size;
      final dialogWidth = (screen.width - 24).clamp(340.0, 1320.0);
      final twoColumn = dialogWidth >= 1000;
      final maxBodyHeight = (screen.height - 250).clamp(320.0, 680.0);

      final queryController = TextEditingController(text: '');
      String query = queryController.text.trim().toLowerCase();

      final allPatients = patients.present.values.toList(growable: false);
      final todaysAppointments = appointments.forDate(selectedDate);

      return StatefulBuilder(
        builder: (context, setDialogState) {
          final waitingCount = todaysAppointments
              .where((a) =>
                  a.checkinStage == 'waiting' ||
                  a.checkinStage == 'pending' ||
                  a.checkinStage == 'scheduled')
              .length;

          final matches = allPatients
              .where((p) {
                if (query.isEmpty) return true;
                final name = p.title.toLowerCase();
                final phone = p.phone.toLowerCase();
                return name.contains(query) || phone.contains(query);
              })
              .take(40)
              .toList(growable: false);

          final hasExactMatch = query.isNotEmpty &&
              allPatients.any((p) {
                final name = p.title.trim().toLowerCase();
                final phone = p.phone.trim().toLowerCase();
                return name == query || phone == query;
              });

            final recentToday = allPatients
              .where((p) => todaysAppointments.any((a) => a.patientID == p.id))
              .toList(growable: false);

          Appointment? _todayAppointment(Patient patient) {
            final rows = todaysAppointments
                .where((a) => a.patientID == patient.id)
                .toList(growable: false);
            if (rows.isEmpty) return null;
            return rows.last;
          }

          String _statusLabel(Appointment? existing) {
            if (existing == null) return 'No Appointment';
            final stage = existing.checkinStage.trim().toLowerCase();
            if (stage == 'waiting') return 'Waiting';
            if (stage == 'scheduled' || stage == 'pending') {
              return 'Appointment ${DateFormat('h:mm a').format(existing.date)}';
            }
            if (stage == 'with_doctor' || stage == 'treatment') {
              return 'With Doctor';
            }
            if (stage == 'checkout') return 'Billing';
            if (stage == 'completed' || existing.isDone) return 'Completed';
            return _toTitleCase(stage);
          }

          Widget _statusChip(Appointment? existing) {
            final stage = existing?.checkinStage.trim().toLowerCase() ?? '';
            final isCompleted = stage == 'completed' || existing?.isDone == true;
            final isWaiting = stage == 'waiting';
            final isScheduled = stage == 'scheduled' || stage == 'pending';
            final isTreatment = stage == 'with_doctor' || stage == 'treatment';
            final isBilling = stage == 'checkout' || stage == 'billing';

            final background = isCompleted
                ? const Color(0xFFE8F7EE)
                : isWaiting
                    ? const Color(0xFFFFF4D9)
                    : isScheduled
                        ? const Color(0xFFEAF2FF)
                        : isTreatment
                            ? const Color(0xFFEAF0FF)
                            : isBilling
                                ? const Color(0xFFF1EBFF)
                                : const Color(0xFFEEF2F7);

            final foreground = isCompleted
                ? const Color(0xFF166534)
                : isWaiting
                    ? const Color(0xFF8A5A00)
                    : isScheduled
                        ? const Color(0xFF1459AD)
                        : isTreatment
                            ? const Color(0xFF1E40AF)
                            : isBilling
                                ? const Color(0xFF5B2FA8)
                                : const Color(0xFF1F3B57);

            return Container(
              constraints: const BoxConstraints(maxWidth: 138),
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
              decoration: BoxDecoration(
                color: background,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                _statusLabel(existing),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
                style: TextStyle(
                  color: foreground,
                  fontWeight: FontWeight.w700,
                  fontSize: 11,
                ),
              ),
            );
          }

          Widget _patientCard(Patient patient) {
            final existing = _todayAppointment(patient);
            final displayName = patient.title.trim().isEmpty
                ? 'Unnamed patient'
                : patient.title;
            final phone = patient.phone.trim().isEmpty ? '-' : patient.phone;

            return Container(
              margin: const EdgeInsets.only(bottom: 0),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFD8E3EF)),
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
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          color: const Color(0xFF8EA7C1),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          _initials(displayName),
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              displayName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Color(0xFF1F2B40),
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                              ),
                            ),
                            Text(
                              '$phone • ${patient.age}y',
                              style: const TextStyle(
                                color: Color(0xFF637A99),
                                fontWeight: FontWeight.w600,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                      _statusChip(existing),
                    ],
                  ),
                  const SizedBox(height: 6),
                  const Divider(size: 1),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      if (existing != null)
                        Button(
                          onPressed: () async {
                            final navigator = Navigator.of(dialogContext);
                            if (navigator.mounted) {
                              navigator.pop();
                            }
                            await onOpenExisting(existing);
                          },
                          child: const Text('Open'),
                        ),
                      if (existing != null) const SizedBox(width: 6),
                      FilledButton(
                        onPressed: () async {
                          final navigator = Navigator.of(dialogContext);
                          await onCheckInPatient(patient);
                          if (navigator.mounted) {
                            navigator.pop();
                          }
                        },
                        child: const Text('Check-in'),
                      ),
                      const SizedBox(width: 6),
                      Button(
                        onPressed: () async {
                          final scheduledAt = await _scheduleAppointmentForPatient(
                            context,
                            patient,
                            selectedDate,
                          );
                          if (scheduledAt == null || !context.mounted) return;
                          displayInfoBar(
                            context,
                            builder: (context, close) => InfoBar(
                              title: const Text('Appointment scheduled'),
                              content: Text(
                                'Scheduled for ${DateFormat('dd MMM yyyy, hh:mm a').format(scheduledAt)}',
                              ),
                              severity: InfoBarSeverity.success,
                            ),
                          );
                        },
                        child: const Text('Schedule'),
                      ),
                    ],
                  ),
                ],
              ),
            );
          }

          Widget _patientGrid(List<Patient> patientsList, {required int columns}) {
            return GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: patientsList.length,
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: columns,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
                childAspectRatio: 2.25,
              ),
              itemBuilder: (_, index) => _patientCard(patientsList[index]),
            );
          }

          return ContentDialog(
            constraints: BoxConstraints(maxWidth: dialogWidth),
            title: Row(
              children: [
                Expanded(
                  child: Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 10,
                    runSpacing: 6,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1F2B40),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEDEFF2),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          '$waitingCount waiting',
                          style: const TextStyle(
                            color: Color(0xFF1F2B40),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(FluentIcons.chrome_close, size: 12),
                  onPressed: () => Navigator.pop(dialogContext),
                ),
              ],
            ),
            content: SizedBox(
              width: dialogWidth - 22,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextBox(
                    controller: queryController,
                    placeholder: 'Search name or phone...',
                    autofocus: true,
                    prefix: const Padding(
                      padding: EdgeInsets.only(left: 10),
                      child: Icon(
                        FluentIcons.search,
                        size: 12,
                        color: Color(0xFF6D84A8),
                      ),
                    ),
                    onSubmitted: (_) async {
                      if (matches.isEmpty) return;
                      final navigator = Navigator.of(dialogContext);
                      await onCheckInPatient(matches.first);
                      if (navigator.mounted) {
                        navigator.pop();
                      }
                    },
                    onChanged: (value) {
                      setDialogState(() => query = value.trim().toLowerCase());
                    },
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Type name or phone • Press Enter to check-in instantly',
                    style: TextStyle(
                      color: Color(0xFF5A6E89),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton(
                          onPressed: () async {
                            final navigator = Navigator.of(dialogContext);
                            final created = await onAddPatient(queryController.text);
                            if (created == null) return;
                            await onCheckInPatient(created);
                            if (navigator.mounted) {
                              navigator.pop();
                            }
                          },
                          child: const Text('New Patient'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Button(
                          onPressed: matches.isEmpty
                              ? null
                              : () async {
                                  final scheduledAt = await _scheduleAppointmentForPatient(
                                    context,
                                    matches.first,
                                    selectedDate,
                                  );
                                  if (scheduledAt == null || !context.mounted) {
                                    return;
                                  }
                                  displayInfoBar(
                                    context,
                                    builder: (context, close) => InfoBar(
                                      title: const Text('Appointment scheduled'),
                                      content: Text(
                                        'Scheduled for ${DateFormat('dd MMM yyyy, hh:mm a').format(scheduledAt)}',
                                      ),
                                      severity: InfoBarSeverity.success,
                                    ),
                                  );
                                },
                          child: const Text('Schedule'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: maxBodyHeight,
                    child: twoColumn
                        ? Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: _LookupColumn(
                                  title: 'Recent Today',
                                  children: recentToday.isEmpty
                                      ? const [
                                          Padding(
                                            padding: EdgeInsets.only(bottom: 8),
                                            child: Text(
                                              'No recent patients today.',
                                              style: TextStyle(
                                                color: Color(0xFF6D84A8),
                                              ),
                                            ),
                                          ),
                                        ]
                                      : [
                                          _patientGrid(
                                            recentToday,
                                            columns: 2,
                                          ),
                                        ],
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _LookupColumn(
                                  title: 'Search Results',
                                  children: [
                                    if (matches.isEmpty)
                                      const Padding(
                                        padding: EdgeInsets.symmetric(vertical: 18),
                                        child: Text(
                                          'No matching patients.',
                                          style: TextStyle(color: Color(0xFF6D84A8)),
                                        ),
                                      )
                                    else
                                      ...matches.map(_patientCard),
                                    if (query.isNotEmpty && !hasExactMatch)
                                      FilledButton(
                                        onPressed: () async {
                                          final navigator = Navigator.of(dialogContext);
                                          final created = await onAddPatient(queryController.text);
                                          if (created == null) return;
                                          await onCheckInPatient(created);
                                          if (navigator.mounted) {
                                            navigator.pop();
                                          }
                                        },
                                        child: Text(
                                          'Add "${queryController.text.trim()}" as new patient',
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ],
                          )
                        : _LookupColumn(
                            title: 'Recent Today',
                            children: [
                              if (recentToday.isEmpty)
                                const Padding(
                                  padding: EdgeInsets.only(bottom: 8),
                                  child: Text(
                                    'No recent patients today.',
                                    style: TextStyle(color: Color(0xFF6D84A8)),
                                  ),
                                )
                              else
                                _patientGrid(
                                  recentToday,
                                  columns: dialogWidth >= 760 ? 2 : 1,
                                ),
                              const SizedBox(height: 6),
                              const Text(
                                'Search Results',
                                style: TextStyle(
                                  color: Color(0xFF4D5C77),
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 8),
                              if (matches.isEmpty)
                                const Padding(
                                  padding: EdgeInsets.symmetric(vertical: 18),
                                  child: Text(
                                    'No matching patients.',
                                    style: TextStyle(color: Color(0xFF6D84A8)),
                                  ),
                                )
                              else
                                ...matches.map(_patientCard),
                              if (query.isNotEmpty && !hasExactMatch)
                                FilledButton(
                                  onPressed: () async {
                                    final navigator = Navigator.of(dialogContext);
                                    final created = await onAddPatient(queryController.text);
                                    if (created == null) return;
                                    await onCheckInPatient(created);
                                    if (navigator.mounted) {
                                      navigator.pop();
                                    }
                                  },
                                  child: Text(
                                    'Add "${queryController.text.trim()}" as new patient',
                                  ),
                                ),
                            ],
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

class _LookupColumn extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _LookupColumn({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(4, 2, 4, 2),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                color: Color(0xFF4D5C77),
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            ...children,
          ],
        ),
      ),
    );
  }
}

String _initials(String name) {
  final cleaned = name.trim();
  if (cleaned.isEmpty) return 'U';
  final parts = cleaned
      .split(RegExp(r'\s+'))
      .where((part) => part.isNotEmpty)
      .toList(growable: false);
  if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
  return (parts[0].substring(0, 1) + parts[1].substring(0, 1)).toUpperCase();
}

String _toTitleCase(String input) {
  final cleaned = input.trim();
  if (cleaned.isEmpty) return cleaned;
  final words = cleaned.split(RegExp(r'\s+'));
  return words
      .map((word) => word.isEmpty
          ? word
          : word.substring(0, 1).toUpperCase() +
              (word.length > 1 ? word.substring(1).toLowerCase() : ''))
      .join(' ');
}
