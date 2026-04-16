import 'package:apexo/common_widgets/pick_doctor_dialog.dart';
import 'package:apexo/features/appointments/appointment_model.dart';
import 'package:apexo/features/appointments/appointments_store.dart';
import 'package:fluent_ui/fluent_ui.dart';

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

class AssignDoctorModal {
  static Future<bool> show(
    BuildContext context,
    Appointment appointment, {
    VoidCallback? onUpdated,
  }) async {
    final pickedDoctorIds = await pickDoctorDialog(
      context,
      initialSelected: appointment.operatorsIDs,
    );
    if (pickedDoctorIds == null || pickedDoctorIds.isEmpty) return false;

    appointment.operatorsIDs = pickedDoctorIds;
    appointment.checkinStage = 'with_doctor';
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
      final patientName = appointment.title.trim().isEmpty
          ? 'Patient'
          : appointment.title.trim();
      final shouldCheckin = await _showScheduledCheckinDialog(
        context,
        patientName,
      );
      if (shouldCheckin != true) return;
      appointment.checkinStage = 'waiting';
      appointment.checkedInAt = DateTime.now();
      appointment.isDone = false;
      appointments.set(appointment);
      onUpdated?.call();
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

  static Future<bool?> _showScheduledCheckinDialog(
    BuildContext context,
    String patientName,
  ) {
    return showDialog<bool>(
      context: context,
      builder: (dialogContext) => ContentDialog(
        title: Text('Checkin $patientName'),
        actions: [
          Button(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Check In'),
          ),
        ],
      ),
    );
  }
}
