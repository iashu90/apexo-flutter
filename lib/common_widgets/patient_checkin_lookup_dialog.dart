import 'package:apexo/common_widgets/patient_history_modal.dart';
import 'package:apexo/common_widgets/schedule_appointment_dialog.dart';
import 'package:apexo/core/perf/perf_markers.dart';
import 'package:apexo/core/theme/app_colors.dart';
import 'package:apexo/core/ui/critical_write_ui_guard.dart';
import 'package:apexo/features/appointments/appointment_model.dart';
import 'package:apexo/features/appointments/appointments_store.dart';
import 'package:apexo/features/doctors/doctors_store.dart';
import 'package:apexo/features/patients/patient_model.dart';
import 'package:apexo/features/patients/patients_store.dart';
import 'package:apexo/core/ui/components/app_button.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:intl/intl.dart';

typedef PatientLookupAddPatient = Future<Patient?> Function(String query);
typedef PatientLookupOpenExisting = Future<void> Function(
  Appointment appointment,
);
typedef PatientLookupCheckInPatient = Future<void> Function(Patient patient);

const List<String> kPatientLookupFocusNotes = [
  'Suture removal',
  'PCS',
  'Pain',
  'Scaling',
  'Filling',
  'Extraction',
  'Ortho',
  'RCT',
];

Future<ScheduleAppointmentDraft?> _scheduleAppointmentForPatient(
  BuildContext context,
  Patient patient,
  DateTime selectedDate,
) async {
  final initialDateTime = selectedDate.isBefore(DateTime.now())
      ? DateTime.now().add(const Duration(days: 1))
      : DateTime(selectedDate.year, selectedDate.month, selectedDate.day, 10);
  final draft = await showScheduleAppointmentDialog(
    context: context,
    patientSummary:
        '${patient.title.trim().isEmpty ? 'Unnamed patient' : _toTitleCase(patient.title)} • ${patient.age}y • ${patient.phone.trim().isEmpty ? '-' : patient.phone}',
    initialDateTime: initialDateTime,
    suggestedFocusNotes: kPatientLookupFocusNotes,
    title: 'Schedule Appointment',
    confirmLabel: 'Schedule',
  );
  if (draft == null) return null;
  if (!runCriticalWriteUiGuard(context,
      actionLabel: 'scheduling appointment')) {
    return null;
  }

  final appointment = Appointment.fromJson({});
  appointment.patientID = patient.id;
  appointment.date = draft.scheduledAt;
  appointment.checkinStage = 'scheduled';
  appointment.operatorsIDs = draft.doctorIds.toList(growable: false);
  appointment.chiefComplaints = draft.focusNotes.toList(growable: false);
  if (draft.focusNotes.isNotEmpty) {
    appointment.preOpNotes = draft.focusNotes.join(', ');
  }
  appointments.set(appointment);

  return draft;
}

Future<ScheduleAppointmentDraft?> _confirmCheckInForPatient(
  BuildContext context,
  Patient patient,
  DateTime selectedDate,
) async {
  final selectedDoctors = <String>{};
  final selectedFocusNotes = <String>{};
  final customNoteController = TextEditingController();
  ScheduleAppointmentDraft? result;

  await showDialog<void>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (context, setStateDialog) {
        final checkinAt = DateTime.now();
        final doctorRows = doctors.present.values.toList(growable: false)
          ..sort(
              (a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));

        return ContentDialog(
          title: const Text('Confirm Check-in'),
          content: SizedBox(
            width: 460,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${patient.title.trim().isEmpty ? 'Unnamed patient' : _toTitleCase(patient.title)} • ${patient.age}y • ${patient.phone.trim().isEmpty ? '-' : patient.phone}',
                  style: const TextStyle(
                    color: Color(0xFF355279),
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Check-in: ${DateFormat('dd MMM yyyy, h:mm a').format(checkinAt)}',
                  style: const TextStyle(
                    color: Color(0xFF1459AD),
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'Visit Notes',
                  style: TextStyle(
                    color: Color(0xFF355279),
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: kPatientLookupFocusNotes.map((note) {
                    final selected = selectedFocusNotes.contains(note);
                    return AppButton(
                      label: note,
                      compact: true,
                      variant: selected
                          ? AppButtonVariant.primary
                          : AppButtonVariant.secondary,
                      onPressed: () {
                        setStateDialog(() {
                          if (selected) {
                            selectedFocusNotes.remove(note);
                          } else {
                            selectedFocusNotes.add(note);
                          }
                        });
                      },
                    );
                  }).toList(growable: false),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextBox(
                        controller: customNoteController,
                        placeholder: 'Add custom note and press Enter',
                        onSubmitted: (value) {
                          final cleaned = value.trim();
                          if (cleaned.isEmpty) return;
                          setStateDialog(() {
                            selectedFocusNotes.add(cleaned);
                            customNoteController.clear();
                          });
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    AppButton(
                      label: 'Add',
                      compact: true,
                      variant: AppButtonVariant.secondary,
                      onPressed: () {
                        final cleaned = customNoteController.text.trim();
                        if (cleaned.isEmpty) return;
                        setStateDialog(() {
                          selectedFocusNotes.add(cleaned);
                          customNoteController.clear();
                        });
                      },
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
                              selectedDoctors.add(doctor.id);
                            }
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: selected
                                ? AppColors.brandBlue
                                : AppColors.slate1004,
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(
                              color: selected
                                  ? AppColors.brandBlue
                                  : AppColors.violet1503,
                            ),
                          ),
                          child: Text(
                            doctor.title.trim().isEmpty
                                ? 'Unnamed doctor'
                                : _toTitleCase(doctor.title),
                            style: TextStyle(
                              color: selected
                                  ? Colors.white
                                  : AppColors.textBlueStrong,
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
            AppButton(
              label: 'Cancel',
              variant: AppButtonVariant.secondary,
              onPressed: () => Navigator.pop(dialogContext),
            ),
            AppButton(
              label: 'Check-in',
              onPressed: () {
                result = ScheduleAppointmentDraft(
                  scheduledAt: DateTime(
                    selectedDate.year,
                    selectedDate.month,
                    selectedDate.day,
                    checkinAt.hour,
                    checkinAt.minute,
                  ),
                  doctorIds: selectedDoctors,
                  focusNotes: selectedFocusNotes,
                );
                Navigator.pop(dialogContext);
              },
            ),
          ],
        );
      },
    ),
  );

  customNoteController.dispose();
  return result;
}

Future<void> showPatientCheckinLookupDialog({
  required BuildContext context,
  required DateTime selectedDate,
  required PatientLookupAddPatient onAddPatient,
  required PatientLookupOpenExisting onOpenExisting,
  required PatientLookupCheckInPatient onCheckInPatient,
  String title = 'Patient Check-in',
  String initialQuery = '',
}) async {
  await showDialog<void>(
    context: context,
    builder: (dialogContext) {
      final screen = MediaQuery.of(dialogContext).size;
      final dialogWidth = (screen.width - 24).clamp(340.0, 1040.0);
      final maxBodyHeight = (screen.height - 250).clamp(320.0, 680.0);

      final queryController = TextEditingController(text: initialQuery);
      String query = queryController.text.trim().toLowerCase();
      String activeTab = 'search';

      final allPatients = patients.present.values.toList(growable: false);
      final allAppointments =
          appointments.present.values.toList(growable: false);
      final todaysAppointments = appointments.forDate(selectedDate);
      final appointmentsByPatient = <String, List<Appointment>>{};
      for (final appointment in allAppointments) {
        final pid = appointment.patientID;
        if (pid == null || pid.isEmpty) continue;
        (appointmentsByPatient[pid] ??= <Appointment>[]).add(appointment);
      }
      for (final rows in appointmentsByPatient.values) {
        rows.sort((a, b) => a.date.compareTo(b.date));
      }

      final todaysAppointmentByPatient = <String, Appointment>{};
      for (final appointment in todaysAppointments) {
        final pid = appointment.patientID;
        if (pid == null || pid.isEmpty) continue;
        final existing = todaysAppointmentByPatient[pid];
        if (existing == null || appointment.date.isAfter(existing.date)) {
          todaysAppointmentByPatient[pid] = appointment;
        }
      }

      final waitingCount = todaysAppointments
          .where((a) =>
              a.checkinStage == 'waiting' ||
              a.checkinStage == 'pending' ||
              a.checkinStage == 'scheduled')
          .length;

      final recentToday = allPatients
          .where((p) => todaysAppointmentByPatient.containsKey(p.id))
          .toList(growable: false);

      final searchIndex = allPatients
          .map(
            (patient) => _PatientLookupSearchIndexEntry(
              patient: patient,
              normalizedName: patient.title.toLowerCase(),
              normalizedPhone: patient.phone.toLowerCase(),
            ),
          )
          .toList(growable: false);

      return StatefulBuilder(
        builder: (context, setDialogState) {
          final matches = PerfMarkers.track(
            'checkin.search.lookupFilter',
            () => searchIndex
                .where((entry) {
                  if (query.isEmpty) return true;
                  return entry.normalizedName.contains(query) ||
                      entry.normalizedPhone.contains(query);
                })
                .take(40)
                .map((entry) => entry.patient)
                .toList(growable: false),
            data: {
              'queryLen': query.length,
            },
          );

          final hasExactMatch = query.isNotEmpty &&
              searchIndex.any((entry) {
                final name = entry.normalizedName.trim();
                final phone = entry.normalizedPhone.trim();
                return name == query || phone == query;
              });

          Appointment? todayAppointment(Patient patient) {
            return todaysAppointmentByPatient[patient.id];
          }

          String statusLabel(Appointment? existing) {
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

          Widget statusChip(Appointment? existing) {
            final stage = existing?.checkinStage.trim().toLowerCase() ?? '';
            final isCompleted =
                stage == 'completed' || existing?.isDone == true;
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
                statusLabel(existing),
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

          Widget patientCard(Patient patient) {
            final existing = todayAppointment(patient);
            final allVisits =
                appointmentsByPatient[patient.id] ?? const <Appointment>[];
            final visitsCount = allVisits.length;
            final lastVisitText = visitsCount == 0
                ? 'No visits'
                : DateFormat('dd MMM yyyy').format(allVisits.last.date);
            final displayName = patient.title.trim().isEmpty
                ? 'Unnamed patient'
                : _toTitleCase(patient.title);
            final phone = patient.phone.trim().isEmpty ? '-' : patient.phone;
            final focusNotes = (existing?.chiefComplaints ?? const <String>[])
                .where((row) => row.trim().isNotEmpty)
                .toList(growable: false);

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
                            Row(
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
                                const SizedBox(width: 4),
                                Tooltip(
                                  message: 'Last treatments',
                                  child: IconButton(
                                    icon: const Icon(
                                      FluentIcons.report_document,
                                      size: 14,
                                      color: Color(0xFF2D7BD8),
                                    ),
                                    onPressed: () {
                                      showPatientHistoryDialog(
                                        context: context,
                                        patient: patient,
                                        rows: patient.patientDetails,
                                      );
                                    },
                                  ),
                                ),
                                const Spacer(),
                              ],
                            ),
                            Row(children: [
                              Text(
                                '$phone • ${patient.age}y',
                                style: const TextStyle(
                                  color: Color(0xFF637A99),
                                  fontWeight: FontWeight.w600,
                                  fontSize: 11,
                                ),
                              ),
                              const SizedBox(width: 4),
                              if (focusNotes.isNotEmpty)
                                Wrap(
                                  spacing: 6,
                                  runSpacing: 6,
                                  children: focusNotes.take(4).map((note) {
                                    return Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 3,
                                      ),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFEAF2FF),
                                        borderRadius:
                                            BorderRadius.circular(999),
                                        border: Border.all(
                                          color: const Color(0xFFCFE0F7),
                                        ),
                                      ),
                                      child: Text(
                                        note,
                                        style: const TextStyle(
                                          color: Color(0xFF355279),
                                          fontWeight: FontWeight.w700,
                                          fontSize: 10,
                                        ),
                                      ),
                                    );
                                  }).toList(growable: false),
                                )
                            ]),
                            const SizedBox(height: 4),
                            Text(
                              'Last: $lastVisitText • Visits: $visitsCount',
                              style: const TextStyle(
                                color: Color(0xFF637A99),
                                fontWeight: FontWeight.w600,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                      statusChip(existing),
                    ],
                  ),
                  const SizedBox(height: 6),
                  const Divider(size: 1),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      if (existing != null)
                        AppButton(
                          label: 'Open',
                          variant: AppButtonVariant.secondary,
                          onPressed: () async {
                            final navigator = Navigator.of(dialogContext);
                            if (navigator.mounted) {
                              navigator.pop();
                            }
                            await onOpenExisting(existing);
                          },
                        ),
                      if (existing != null) const SizedBox(width: 6),
                      AppButton(
                        label: 'Check-in',
                        onPressed: () async {
                          final checkinDraft = await _confirmCheckInForPatient(
                            context,
                            patient,
                            selectedDate,
                          );
                          if (checkinDraft == null) return;
                          if (!runCriticalWriteUiGuard(
                            context,
                            actionLabel: 'checking in patient',
                          )) {
                            return;
                          }

                          final titledName = patient.title.trim().isEmpty
                              ? patient.title
                              : _toTitleCase(patient.title);
                          if (titledName != patient.title) {
                            patient.title = titledName;
                            patients.set(patient);
                          }
                          final navigator = Navigator.of(dialogContext);
                          await onCheckInPatient(patient);

                          final appointmentRows = appointments.present.values
                              .where((row) => row.patientID == patient.id)
                              .where((row) {
                            final rowDate = DateTime(
                                row.date.year, row.date.month, row.date.day);
                            final targetDate = DateTime(selectedDate.year,
                                selectedDate.month, selectedDate.day);
                            return rowDate == targetDate &&
                                row.checkinStage == 'waiting';
                          }).toList(growable: false)
                            ..sort((a, b) {
                              final aStamp = a.checkedInAt ?? a.date;
                              final bStamp = b.checkedInAt ?? b.date;
                              return bStamp.compareTo(aStamp);
                            });

                          if (appointmentRows.isNotEmpty) {
                            final target = appointmentRows.first;
                            target.operatorsIDs =
                                checkinDraft.doctorIds.toList(growable: false);
                            target.chiefComplaints =
                                checkinDraft.focusNotes.toList(growable: false);
                            if (checkinDraft.focusNotes.isNotEmpty) {
                              target.preOpNotes =
                                  checkinDraft.focusNotes.join(', ');
                            }
                            appointments.set(target);
                          }

                          if (navigator.mounted) {
                            navigator.pop();
                          }
                        },
                      ),
                      const SizedBox(width: 6),
                      AppButton(
                        label: 'Schedule',
                        variant: AppButtonVariant.secondary,
                        onPressed: () async {
                          final scheduledDraft =
                              await _scheduleAppointmentForPatient(
                            context,
                            patient,
                            selectedDate,
                          );
                          if (scheduledDraft == null || !context.mounted) {
                            return;
                          }
                          displayInfoBar(
                            context,
                            builder: (context, close) => InfoBar(
                              title: const Text('Appointment scheduled'),
                              content: Text(
                                'Scheduled for ${DateFormat('dd MMM yyyy, hh:mm a').format(scheduledDraft.scheduledAt)}',
                              ),
                              severity: InfoBarSeverity.success,
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ],
              ),
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
                const SizedBox(width: 8),
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
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      _tabChip(
                        label: "Today's",
                        selected: activeTab == 'today',
                        onTap: () => setDialogState(() => activeTab = 'today'),
                      ),
                      const SizedBox(width: 8),
                      _tabChip(
                        label: 'Search',
                        selected: activeTab == 'search',
                        onTap: () => setDialogState(() => activeTab = 'search'),
                      ),
                    ],
                  ),
                  if (activeTab == 'search') ...[
                    const SizedBox(height: 10),
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
                        setDialogState(
                            () => query = value.trim().toLowerCase());
                      },
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Type name or phone • Press Enter to check-in instantly',
                      style: TextStyle(
                        color: Color(0xFF5A6E89),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  SizedBox(
                    height: maxBodyHeight,
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (activeTab == 'today') ...[
                            if (recentToday.isEmpty)
                              const Padding(
                                padding: EdgeInsets.only(bottom: 8),
                                child: Text(
                                  'No patients found for today.',
                                  style: TextStyle(color: Color(0xFF6D84A8)),
                                ),
                              )
                            else
                              ...recentToday.map(patientCard),
                          ] else ...[
                            if (matches.isEmpty)
                              const Padding(
                                padding: EdgeInsets.symmetric(vertical: 18),
                                child: Text(
                                  'No matching patients.',
                                  style: TextStyle(color: Color(0xFF6D84A8)),
                                ),
                              )
                            else
                              ...matches.map(patientCard),
                            if (query.isNotEmpty && !hasExactMatch)
                              AppButton(
                                label:
                                    'Add "${queryController.text.trim()}" as new patient',
                                onPressed: () async {
                                  final navigator = Navigator.of(dialogContext);
                                  final created =
                                      await onAddPatient(queryController.text);
                                  if (created == null) return;
                                  await onCheckInPatient(created);
                                  if (navigator.mounted) {
                                    navigator.pop();
                                  }
                                },
                              ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              AppButton(
                label: 'Close',
                variant: AppButtonVariant.secondary,
                onPressed: () => Navigator.pop(dialogContext),
              ),
            ],
          );
        },
      );
    },
  );
}

Widget _tabChip({
  required String label,
  required bool selected,
  required VoidCallback onTap,
}) {
  return GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      decoration: BoxDecoration(
        color: selected ? const Color(0xFF2D7BD8) : const Color(0xFFEFF4FB),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: selected ? const Color(0xFF2D7BD8) : const Color(0xFFD5E5F7),
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: selected ? Colors.white : const Color(0xFF355279),
          fontWeight: FontWeight.w700,
          fontSize: 13,
        ),
      ),
    ),
  );
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

class _PatientLookupSearchIndexEntry {
  final Patient patient;
  final String normalizedName;
  final String normalizedPhone;

  const _PatientLookupSearchIndexEntry({
    required this.patient,
    required this.normalizedName,
    required this.normalizedPhone,
  });
}
