import 'package:apexo/common_widgets/pick_doctor_dialog.dart';
import 'package:apexo/core/ui/components/app_button.dart';
import 'package:apexo/features/appointments/appointment_model.dart';
import 'package:apexo/features/appointments/appointments_store.dart';
import 'package:fluent_ui/fluent_ui.dart';

const List<String> _scheduledCheckinFocusNotes = [
  'Suture removal',
  'PCS',
  'Pain',
  'Scaling',
  'Filling',
  'Extraction',
  'Ortho',
  'RCT',
];

class _ScheduledCheckinDraft {
  final Set<String> focusNotes;

  const _ScheduledCheckinDraft({required this.focusNotes});
}

typedef CheckinStageModalOpener = Future<void> Function(
  BuildContext context,
  Appointment appointment,
);

String normalizeCheckinStage(String rawStage) {
  final normalized = rawStage.trim().toLowerCase();
  switch (normalized) {
    case 'pending':
    case 'scheduled':
      return 'scheduled';
    case 'waiting':
      return 'waiting';
    case 'with_doctor':
    case 'treatment':
      return 'treatment';
    case 'checkout':
    case 'billing':
      return 'billing';
    case 'completed':
    case 'complete':
      return 'complete';
    default:
      return normalized;
  }
}

String _stagePatientSummary(Appointment appointment) {
  final name = appointment.title.trim().isEmpty
      ? 'Unnamed patient'
      : appointment.title.trim();
  final age = appointment.patient?.age ?? 0;
  final gender = appointment.patient?.gender == 1
      ? 'M'
      : appointment.patient?.gender == 0
          ? 'F'
          : '-';
  final phone = appointment.patient?.phone.trim() ?? '';
  return '$name • ${age}y • $gender • ${phone.isEmpty ? '-' : phone}';
}

class AssignDoctorModal {
  static Future<bool> show(
    BuildContext context,
    Appointment appointment, {
    VoidCallback? onUpdated,
  }) async {
    final pickedDoctorIds = await pickDoctorDialog(
      context,
      initialSelected: appointment.operatorsIDs,
      subtitle: _stagePatientSummary(appointment),
    );
    if (pickedDoctorIds == null || pickedDoctorIds.isEmpty) return false;

    appointment.operatorsIDs = pickedDoctorIds;
    appointment.checkinStage = 'with_doctor';
    appointment.completedTime = null;
    appointment.isDone = false;
    appointment.checkedInAt ??= DateTime.now();
    appointments.set(appointment);
    onUpdated?.call();
    return true;
  }
}

class TreatmentModal {
  static Future<void> show(
    BuildContext context,
    Appointment appointment, {
    required CheckinStageModalOpener openModal,
  }) {
    return openModal(context, appointment);
  }
}

class BillingModal {
  static Future<void> show(
    BuildContext context,
    Appointment appointment, {
    required CheckinStageModalOpener openModal,
  }) {
    return openModal(context, appointment);
  }
}

class CompleteModal {
  static Future<void> show(
    BuildContext context,
    Appointment appointment, {
    required CheckinStageModalOpener openModal,
  }) {
    return openModal(context, appointment);
  }
}

class CheckinStageModalRouter {
  static Future<void> openForStage({
    required BuildContext context,
    required Appointment appointment,
    required CheckinStageModalOpener openTreatmentModal,
    required CheckinStageModalOpener openBillingModal,
    required CheckinStageModalOpener openCompleteModal,
    VoidCallback? onUpdated,
  }) async {
    final stage = normalizeCheckinStage(appointment.checkinStage);

    if (stage == 'scheduled') {
      final draft = await _showScheduledCheckinDialog(
        context,
        appointment,
      );
      if (draft == null) return;
      appointment.checkinStage = 'waiting';
      appointment.checkedInAt = DateTime.now();
      appointment.completedTime = null;
      appointment.isDone = false;
      appointment.chiefComplaints = draft.focusNotes.toList(growable: false);
      if (draft.focusNotes.isNotEmpty) {
        appointment.preOpNotes = draft.focusNotes.join(', ');
      }
      appointments.set(appointment);
      onUpdated?.call();

      if (!context.mounted) return;
      final assigned = await AssignDoctorModal.show(
        context,
        appointment,
        onUpdated: onUpdated,
      );
      if (assigned) return;
      return;
    }

    if (stage == 'waiting') {
      await AssignDoctorModal.show(
        context,
        appointment,
        onUpdated: onUpdated,
      );
      return;
    }

    if (stage == 'treatment') {
      await TreatmentModal.show(
        context,
        appointment,
        openModal: openTreatmentModal,
      );
      return;
    }

    if (stage == 'billing') {
      await BillingModal.show(
        context,
        appointment,
        openModal: openBillingModal,
      );
      return;
    }

    if (stage == 'complete') {
      await CompleteModal.show(
        context,
        appointment,
        openModal: openCompleteModal,
      );
      return;
    }

    await openTreatmentModal(context, appointment);
  }

  static Future<_ScheduledCheckinDraft?> _showScheduledCheckinDialog(
    BuildContext context,
    Appointment appointment,
  ) async {
    final patientName = appointment.title.trim().isEmpty
        ? 'Patient'
        : appointment.title.trim();
    final selectedFocusNotes = {
      ...appointment.chiefComplaints.where((row) => row.trim().isNotEmpty),
    };
    final customNoteController = TextEditingController();
    _ScheduledCheckinDraft? result;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setStateDialog) => ContentDialog(
          title: Text('Checkin $patientName'),
          content: SizedBox(
            width: 500,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_stagePatientSummary(appointment)),
                const SizedBox(height: 8),
                if (selectedFocusNotes.isNotEmpty)
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: selectedFocusNotes.map((note) {
                      return Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEAF2FF),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(color: const Color(0xFFCFE0F7)),
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
                  children: _scheduledCheckinFocusNotes.map((note) {
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
              label: 'Check In',
              onPressed: () {
                result = _ScheduledCheckinDraft(
                  focusNotes: Set<String>.from(selectedFocusNotes),
                );
                Navigator.pop(dialogContext);
              },
            ),
          ],
        ),
      ),
    );

    customNoteController.dispose();
    return result;
  }
}
