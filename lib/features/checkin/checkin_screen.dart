// ignore_for_file: unused_element, unused_field, unused_local_variable, unused_import, dead_code

import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:apexo/common_widgets/date_navigator_bar.dart';
import 'package:apexo/common_widgets/last_treatments_modal.dart';
import 'package:apexo/common_widgets/patient_checkin_search_button.dart';
import 'package:apexo/common_widgets/patient_history_modal.dart';
import 'package:apexo/common_widgets/app_screen_title.dart';
import 'package:apexo/common_widgets/export_progress_dialog.dart';
import 'package:apexo/common_widgets/export_buttons.dart';
import 'package:apexo/common_widgets/tag_input.dart';
import 'package:apexo/common_widgets/teeth_picker.dart';
import 'package:apexo/common_widgets/selectable_chip_group.dart';
import 'package:apexo/common_widgets/patient_timeline_card.dart';
import 'package:apexo/common_widgets/schedule_appointment_dialog.dart';
import 'package:apexo/core/theme/app_theme.dart';
import 'package:apexo/core/sync_write_health.dart';
import 'package:apexo/core/ui/critical_write_ui_guard.dart';
import 'package:apexo/core/ui/components/app_button.dart';
import 'package:apexo/core/ui/components/app_badge.dart';
import 'package:apexo/core/ui/components/app_dropdown_menu.dart';
import 'package:apexo/core/ui/components/app_table.dart';
import 'package:apexo/core/ui/components/status_pill.dart';
import 'package:apexo/core/theme/app_colors.dart';
import 'package:apexo/features/appointments/appointment_model.dart';
import 'package:apexo/features/appointments/appointments_store.dart';
import 'package:apexo/features/checkin/odontogram/odontogram_picker.dart';
import 'package:apexo/features/checkin/appointment_journey_dialog.dart';
import 'package:apexo/features/checkin/checkin_stage_modals.dart';
import 'package:apexo/features/checkin/checkin_timeline_mapper.dart';
import 'package:apexo/features/checkin/odontogram/tooth_model.dart';
import 'package:apexo/features/doctors/doctor_model.dart';
import 'package:apexo/features/doctors/doctors_store.dart';
import 'package:apexo/features/expenses/expense_model.dart';
import 'package:apexo/features/expenses/expenses_store.dart';
import 'package:apexo/features/labwork/labworks_store.dart';
import 'package:apexo/features/patients/open_add_patient_popup.dart';
import 'package:apexo/features/patients/patient_history_suggestions.dart';
import 'package:apexo/features/patients/patient_model.dart';
import 'package:apexo/features/patients/patients_store.dart';
import 'package:apexo/features/treatment_packages/treatment_package_screen.dart';
import 'package:apexo/theme/material_date_picker_theme.dart';
import 'package:apexo/utils/uuid.dart';
import 'package:apexo/utils/share_actions.dart';
import 'package:apexo/utils/pdf_export_layout.dart';
import 'package:apexo/utils/clinic_time.dart';
import 'package:apexo/services/login.dart';
import 'package:apexo/services/permissions.dart';
import 'package:file_picker/file_picker.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' as material;
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:apexo/common_widgets/pick_doctor_dialog.dart';

part 'checkin_stage_panels.dart';
part 'checkin_workflow_widgets.dart';
part 'checkin_schedule_widgets.dart';
part 'checkin_checkout_summary.dart';
part 'checkin_operative_form.dart';

DateTime checkinPersistedDate = DateTime.now();

String _toTitleCase(String input) {
  final cleaned = input.trim();
  if (cleaned.isEmpty) return cleaned;
  final parts = cleaned.split(RegExp(r'\s+'));
  return parts.map((word) {
    if (word.isEmpty) return word;
    final first = word.substring(0, 1).toUpperCase();
    final rest = word.length > 1 ? word.substring(1).toLowerCase() : '';
    return '$first$rest';
  }).join(' ');
}

String _patientDisplayName(Appointment appointment) {
  final name = appointment.title.trim();
  return name.isEmpty ? 'Unnamed patient' : _toTitleCase(name);
}

String _patientGenderShort(Appointment appointment) {
  final gender = appointment.patient?.gender;
  if (gender == 1) return 'M';
  if (gender == 0) return 'F';
  return '-';
}

String _patientFocusSummary(Appointment appointment) {
  final age = appointment.patient?.age ?? 0;
  final gender = _patientGenderShort(appointment);
  final phone = appointment.patient?.phone.trim() ?? '';
  final safePhone = phone.isEmpty ? '-' : phone;
  return '${_patientDisplayName(appointment)} • ${age}y • $gender • $safePhone';
}

String _medicalHistorySummaryText(Patient? patient) {
  final medicalHistoryEntries = <String>{
    ...?patient?.tags,
    ...?patient?.drugHistorySuggestions,
    ...?patient?.maternalHistorySuggestions,
    ...?patient?.habitsSuggestions,
  }.where((entry) => entry.trim().isNotEmpty).toList(growable: false);

  return medicalHistoryEntries.isEmpty
      ? 'Medical History: No history recorded'
      : 'Medical History: ${medicalHistoryEntries.join(', ')}';
}

const List<String> kCheckinFocusNotes = [
  'Suture removal',
  'PCS',
  'Pain',
  'Scaling',
  'Filling',
  'Extraction',
  'Ortho',
  'RCT',
];

Set<String> _normalizeFocusNotes(Iterable<String> values) {
  final normalized = <String>{};
  for (final value in values) {
    final cleaned = value.trim();
    if (cleaned.isEmpty) continue;
    normalized.add(cleaned);
  }
  return normalized;
}

Future<void> _showNextAppointmentPromptDialog(
  BuildContext context,
  Appointment appointment,
) async {
  final patient = appointment.patient;
  if (patient == null) return;

  final draft = await showScheduleAppointmentDialog(
    context: context,
    title: 'Schedule Appointment',
    confirmLabel: 'Schedule',
    patientSummary:
        '${_patientDisplayName(appointment)} • ${patient.age}y • ${patient.phone.trim().isEmpty ? '-' : patient.phone}',
    initialDateTime: DateTime.now().add(const Duration(days: 7)),
    initialDoctorIds: appointment.operatorsIDs,
    initialFocusNotes: appointment.chiefComplaints,
    suggestedFocusNotes: kCheckinFocusNotes,
  );
  if (draft == null) return;
  if (!runCriticalWriteUiGuard(context, actionLabel: 'scheduling appointment')) {
    return;
  }

  final nextAppointment = Appointment.fromJson({
    'patientID': patient.id,
    'operatorsIDs': draft.doctorIds.toList(growable: false),
    'date': draft.scheduledAt.millisecondsSinceEpoch,
    'checkinStage': 'pending',
    'chiefComplaints': draft.focusNotes.toList(growable: false),
  });
  if (draft.focusNotes.isNotEmpty) {
    nextAppointment.preOpNotes = draft.focusNotes.join(', ');
  }
  appointments.set(nextAppointment);
}

Future<void> _upsertScheduledFollowUpAppointment(
  BuildContext context,
  Appointment baseAppointment, {
  Appointment? existingScheduled,
}) async {
  if ((baseAppointment.patientID ?? '').trim().isEmpty) return;

  final patient = baseAppointment.patient;
  if (patient == null) return;

  final draft = await showScheduleAppointmentDialog(
    context: context,
    patientSummary:
        '${_patientDisplayName(baseAppointment)} • ${patient.age}y • ${patient.phone.trim().isEmpty ? '-' : patient.phone}',
    initialDateTime:
        existingScheduled?.date ?? DateTime.now().add(const Duration(days: 7)),
    initialDoctorIds: (existingScheduled?.operatorsIDs.isNotEmpty ?? false)
        ? existingScheduled!.operatorsIDs
        : baseAppointment.operatorsIDs,
    initialFocusNotes: (existingScheduled?.chiefComplaints.isNotEmpty ?? false)
        ? existingScheduled!.chiefComplaints
        : baseAppointment.chiefComplaints,
    suggestedFocusNotes: kCheckinFocusNotes,
    title: existingScheduled == null
        ? 'Schedule Appointment'
        : 'Edit Scheduled Appointment',
    confirmLabel: existingScheduled == null ? 'Schedule' : 'Update',
  );
  if (draft == null) return;
  if (!runCriticalWriteUiGuard(context, actionLabel: 'saving scheduled follow-up')) {
    return;
  }

  final scheduledAt = draft.scheduledAt;
  if (scheduledAt.isBefore(DateTime.now())) {
    displayInfoBar(
      context,
      builder: (ctx, close) => InfoBar(
        title: const Text('Invalid schedule time'),
        content: const Text('Please pick a future date and time.'),
        severity: InfoBarSeverity.warning,
        action: IconButton(
          icon: const Icon(FluentIcons.clear),
          onPressed: close,
        ),
      ),
    );
    return;
  }

  final targetAppointment =
      existingScheduled ?? Appointment.fromJson({'id': uuid()});
  targetAppointment.patientID = baseAppointment.patientID;
  targetAppointment.date = scheduledAt;
  targetAppointment.checkinStage = 'scheduled';
  targetAppointment.isCheckedIn = false;
  targetAppointment.operatorsIDs = draft.doctorIds.toList(growable: false);
  targetAppointment.chiefComplaints = draft.focusNotes.toList(growable: false);
  if (draft.focusNotes.isNotEmpty) {
    targetAppointment.preOpNotes = draft.focusNotes.join(', ');
  }
  if (targetAppointment.preOpNotes.trim().isEmpty) {
    targetAppointment.preOpNotes = 'Follow-up visit';
  }
  appointments.set(targetAppointment);
}

Future<void> _confirmDeleteScheduledFollowUpAppointment(
  BuildContext context,
  Appointment scheduledAppointment,
) async {
  final shouldDelete = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => ContentDialog(
      title: const Text('Delete Scheduled Appointment'),
      content: Text(
        'Delete appointment on ${formatClinicDateTime(scheduledAppointment.date, pattern: 'dd MMM yyyy • h:mm a')}?',
      ),
      actions: [
        AppButton(
          label: 'Cancel',
          variant: AppButtonVariant.secondary,
          onPressed: () => Navigator.pop(dialogContext, false),
        ),
        AppButton(
          label: 'Delete',
          variant: AppButtonVariant.danger,
          onPressed: () => Navigator.pop(dialogContext, true),
        ),
      ],
    ),
  );

  if (shouldDelete != true) return;
  await appointments.hardDelete(scheduledAppointment.id);
}

Future<void> _confirmCancelScheduledFollowUpAppointment(
  BuildContext context,
  Appointment scheduledAppointment,
) async {
  final shouldCancel = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => ContentDialog(
      title: const Text('Cancel Scheduled Appointment'),
      content: Text(
        'Mark appointment on ${formatClinicDateTime(scheduledAppointment.date, pattern: 'dd MMM yyyy • h:mm a')} as cancelled?',
      ),
      actions: [
        AppButton(
          label: 'Keep Appointment',
          variant: AppButtonVariant.secondary,
          onPressed: () => Navigator.pop(dialogContext, false),
        ),
        AppButton(
          label: 'Cancel Appointment',
          variant: AppButtonVariant.danger,
          onPressed: () => Navigator.pop(dialogContext, true),
        ),
      ],
    ),
  );

  if (shouldCancel != true) return;
  scheduledAppointment.checkinStage = 'cancelled';
  scheduledAppointment.isCheckedIn = false;
  appointments.set(scheduledAppointment);
}

List<Widget> _buildBillingSummaryLines(
  Appointment appointment, {
  double? paidOverride,
}) {
  final treatmentCost = appointment.price.clamp(0, double.infinity).toDouble();
  final prescriptionCost =
      appointment.prescriptionPrice.clamp(0, double.infinity).toDouble();
  final hasPrescriptionCharge = prescriptionCost > 0;
  final subtotal = treatmentCost + prescriptionCost;
  final discount = appointment.discount;
  final discountedTotal = appointment.discountType == 'percent'
      ? (appointment.price - (appointment.price * discount / 100))
          .clamp(0, double.infinity)
      : (appointment.price - discount).clamp(0, double.infinity);
  final netTotal =
      (discountedTotal + prescriptionCost).clamp(0, double.infinity);
  final paid =
      ((paidOverride ?? appointment.paid) + appointment.prescriptionPaid)
          .clamp(0, double.infinity);
  final balance = (netTotal - paid).clamp(0, double.infinity);
  final status = balance <= 0 ? 'PAID' : 'DUE';

  return [
    Text('Treatment Cost: Rs ${treatmentCost.toStringAsFixed(0)}'),
    if (hasPrescriptionCharge)
      Text('Prescription Cost: Rs ${prescriptionCost.toStringAsFixed(0)}'),
    Text('Subtotal: Rs ${subtotal.toStringAsFixed(0)}'),
    Text(
      'Discount: ${discount <= 0 ? '-' : (appointment.discountType == 'percent' ? '-${discount.toStringAsFixed(0)}%' : '-Rs ${discount.toStringAsFixed(0)}')}',
    ),
    Text('Net Total: Rs ${netTotal.toStringAsFixed(0)}'),
    Text('Paid: Rs ${paid.toStringAsFixed(0)}'),
    Text('Balance: Rs ${balance.toStringAsFixed(0)}'),
    Text('Status: $status'),
  ];
}

Future<bool> _confirmMoveToCompleted(
  BuildContext context,
  Appointment appointment, {
  double? paidOverride,
}) async {
  final patientSummary = _patientFocusSummary(appointment);
  final shouldComplete = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => ContentDialog(
      title: const Text('Move to Completed?'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(patientSummary),
          const SizedBox(height: 8),
          const Text(
            'Billing Summary',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          ..._buildBillingSummaryLines(appointment, paidOverride: paidOverride),
          const SizedBox(height: 10),
          const Text('This appointment will be moved to Completed.'),
        ],
      ),
      actions: [
        AppButton(
          label: 'Cancel',
          variant: AppButtonVariant.secondary,
          onPressed: () => Navigator.pop(dialogContext, false),
        ),
        AppButton(
          label: 'Complete',
          onPressed: () => Navigator.pop(dialogContext, true),
        ),
      ],
    ),
  );
  return shouldComplete == true;
}

int _stepIndexFromStageValue(String stage) {
  final normalized = stage.trim().toLowerCase();
  if (normalized == 'with_doctor' || normalized == 'treatment') {
    return 0;
  }
  if (normalized == 'checkout' || normalized == 'billing') {
    return 2;
  }
  if (normalized == 'completed') {
    return 3;
  }
  return 0;
}

class _PatientHistoryDraftController {
  Set<String>? _medicalHistory;
  Set<String>? _drugHistory;
  Set<String>? _maternalHistory;
  Set<String>? _habits;

  void update({
    required Set<String> medicalHistory,
    required Set<String> drugHistory,
    required Set<String> maternalHistory,
    required Set<String> habits,
  }) {
    _medicalHistory = Set<String>.from(medicalHistory);
    _drugHistory = Set<String>.from(drugHistory);
    _maternalHistory = Set<String>.from(maternalHistory);
    _habits = Set<String>.from(habits);
  }

  void commitToPatient(Patient? patient) {
    if (patient == null) return;
    if (_medicalHistory == null ||
        _drugHistory == null ||
        _maternalHistory == null ||
        _habits == null) {
      return;
    }

    patient.tags = _medicalHistory!.toList(growable: false);
    patient.drugHistorySuggestions = _drugHistory!.toList(growable: false);
    patient.maternalHistorySuggestions =
        _maternalHistory!.toList(growable: false);
    patient.habitsSuggestions = _habits!.toList(growable: false);
    patients.set(patient);
  }
}

void _restoreAppointmentFromSnapshot(Appointment target, Appointment snapshot) {
  final restored = Appointment.fromJson({
    ...snapshot.toJson(),
    'id': target.id,
  });

  target.operatorsIDs = restored.operatorsIDs.toList(growable: false);
  target.patientID = restored.patientID;
  target.consultantDoctorID = restored.consultantDoctorID;
  target.preOpNotes = restored.preOpNotes;
  target.postOpNotes = restored.postOpNotes;
  target.prescriptions = restored.prescriptions.toList(growable: false);
  target.price = restored.price;
  target.discountedPrice = restored.discountedPrice;
  target.paid = restored.paid;
  target.priceToPayDoctor = restored.priceToPayDoctor;
  target.paidToDoctor = restored.paidToDoctor;
  target.prescriptionPrice = restored.prescriptionPrice;
  target.prescriptionPaid = restored.prescriptionPaid;
  target.imgs = restored.imgs.toList(growable: false);
  target.date = restored.date;
  target.isDone = restored.isDone;
  target.discount = restored.discount;
  target.discountType = restored.discountType;
  target.diagnosis = restored.diagnosis.toList(growable: false);
  target.chiefComplaints = restored.chiefComplaints.toList(growable: false);
  target.selectedTreatments =
      restored.selectedTreatments.toList(growable: false);
  target.subTreatments = restored.subTreatments.toList(growable: false);
  target.selectedTeeth = restored.selectedTeeth.toList(growable: false);
  target.treatmentGpayPaid = restored.treatmentGpayPaid;
  target.prescriptionGpayPaid = restored.prescriptionGpayPaid;
  target.isCheckedIn = restored.isCheckedIn;
  target.checkinStage = restored.checkinStage;
  target.visitType = restored.visitType;
  target.sourceTimeZone = restored.sourceTimeZone;
  target.checkedInAt = restored.checkedInAt;
  target.completedTime = restored.completedTime;
}

Future<void> openAppointmentJourneyDialog(
  BuildContext context,
  Appointment appointment, {
  int? initialStep,
}) async {
  final originalSnapshot = Appointment.fromJson({
    ...appointment.toJson(),
    'id': appointment.id,
  });
  bool hasUnsavedDraft = false;

  void markDraftChanged() {
    hasUnsavedDraft = true;
  }

  final patientHistoryDraft = _PatientHistoryDraftController();
  final isDoctorLogin = permissions.currentRole == UserRole.doctor;
  final rawStartStep = initialStep?.clamp(0, 3) ??
      _stepIndexFromStageValue(appointment.checkinStage);
  final startStep = isDoctorLogin
      ? (rawStartStep == 3
          ? 1
          : rawStartStep == 2
              ? 1
              : rawStartStep)
      : rawStartStep;
  final patient = appointment.patient;
  final patientContext =
      '${patient?.age ?? 0}y • ${_patientGenderShort(appointment)} • ${(patient?.phone.trim().isEmpty ?? true) ? '-' : patient!.phone.trim()}';
  final allAppointmentsForPatient = appointments.present.values
      .where((row) => row.patientID == appointment.patientID)
      .toList(growable: false)
    ..sort((a, b) => b.date.compareTo(a.date));
  Widget stageBody(BuildContext context, int currentStep, double panelHeight) {
    if (isDoctorLogin) {
      if (currentStep == 0) {
        return _PatientHistoryStepScreen(
          appointment: appointment,
          allAppointmentsForPatient: allAppointmentsForPatient,
          draftController: patientHistoryDraft,
        );
      }

      if (currentStep == 1) {
        return _CheckinTreatmentStageScreen(
          appointment: appointment,
          allAppointmentsForPatient: allAppointmentsForPatient,
          forcedStage: 'with_doctor',
          showInlineBottomActions: false,
          boxed: true,
          panelHeight: panelHeight,
          onDraftChanged: markDraftChanged,
        );
      }

      return const SizedBox.shrink();
    }

    if (currentStep == 0) {
      return _PatientHistoryStepScreen(
        appointment: appointment,
        allAppointmentsForPatient: allAppointmentsForPatient,
        draftController: patientHistoryDraft,
      );
    }

    if (currentStep == 1 || currentStep == 2) {
      return _CheckinTreatmentStageScreen(
        appointment: appointment,
        allAppointmentsForPatient: allAppointmentsForPatient,
        forcedStage: currentStep == 2 ? 'checkout' : 'with_doctor',
        showInlineBottomActions: false,
        boxed: true,
        panelHeight: panelHeight,
        onDraftChanged: markDraftChanged,
      );
    }

    final previousVisits = allAppointmentsForPatient
        .where((row) => row.id != appointment.id)
        .toList(growable: false);
    final Appointment? lastVisit =
        previousVisits.isEmpty ? null : previousVisits.first;

    return _CheckinCompletedStageScreen(
      appointment: appointment,
      lastVisit: lastVisit,
      boxed: true,
    );
  }

  await showAppointmentJourneyDialog(
    context: context,
    title: 'Appointment Journey',
    patientName: _patientDisplayName(appointment),
    patientContext: patientContext,
    initialStep: startStep,
    stepSubtitles: isDoctorLogin
        ? const [
            'Checked In',
            'Patient History',
            'Treatment',
          ]
        : const [
            'Checked In',
            'Patient History',
            'Treatment',
            'Billing',
            'Completed',
          ],
    primaryActionLabelBuilder: (currentStep) {
      if (isDoctorLogin) {
        if (currentStep == 0) return 'Continue to Treatment';
        if (currentStep == 1) return 'Treatment Complete';
        return null;
      }
      if (currentStep == 0) return 'Continue to Treatment';
      if (currentStep == 1) return 'Treatment Complete';
      if (currentStep == 2) return 'Billing Complete';
      return null;
    },
    stepBuilder: stageBody,
    onBeforeStepAdvance: (dialogContext, currentStep, nextStep) async {
      if (currentStep == 0 && nextStep > currentStep) {
        patientHistoryDraft.commitToPatient(appointment.patient);
      }
      if (isDoctorLogin) {
        if (nextStep >= 2) {
          appointment.checkinStage = 'completed';
          appointment.completedTime = DateTime.now();
          appointment.isDone = true;
        }
        appointments.set(appointment);
        return;
      }

      if (nextStep == 2) {
        appointment.checkinStage = 'checkout';
        appointment.completedTime = null;
        appointment.isDone = false;
      } else if (nextStep == 3) {
        appointment.checkinStage = 'completed';
        appointment.completedTime = DateTime.now();
        appointment.isDone = true;
      }
      appointments.set(appointment);
      hasUnsavedDraft = false;
    },
    onAttemptClose: (dialogContext) async {
      if (!hasUnsavedDraft) return true;

      final decision = await showDialog<String>(
        context: dialogContext,
        builder: (ctx) => ContentDialog(
          title: const Text('Unsaved Changes'),
          content: const Text(
            'You have unsaved journey changes. Save before closing?',
          ),
          actions: [
            AppButton(
              label: 'Cancel',
              variant: AppButtonVariant.secondary,
              onPressed: () => Navigator.pop(ctx, 'cancel'),
            ),
            AppButton(
              label: 'Dismiss',
              variant: AppButtonVariant.danger,
              onPressed: () => Navigator.pop(ctx, 'dismiss'),
            ),
            AppButton(
              label: 'Save',
              onPressed: () => Navigator.pop(ctx, 'save'),
            ),
          ],
        ),
      );

      if (decision == 'save') {
        appointments.set(appointment);
        hasUnsavedDraft = false;
        return true;
      }

      if (decision == 'dismiss') {
        _restoreAppointmentFromSnapshot(appointment, originalSnapshot);
        appointments.set(appointment);
        hasUnsavedDraft = false;
        return true;
      }

      return false;
    },
  );
}

class _PatientHistoryStepScreen extends StatefulWidget {
  final Appointment appointment;
  final List<Appointment> allAppointmentsForPatient;
  final _PatientHistoryDraftController? draftController;

  const _PatientHistoryStepScreen({
    required this.appointment,
    required this.allAppointmentsForPatient,
    this.draftController,
  });

  @override
  State<_PatientHistoryStepScreen> createState() =>
      _PatientHistoryStepScreenState();
}

class _PatientHistoryStepScreenState extends State<_PatientHistoryStepScreen> {
  late Set<String> _selectedMedicalHistory;
  late Set<String> _selectedDrugHistory;
  late Set<String> _selectedMaternalHistory;
  late Set<String> _selectedHabits;
  bool _showMore = false;

  @override
  void initState() {
    super.initState();
    final patient = widget.appointment.patient;
    _selectedMedicalHistory = {...?patient?.tags};
    _selectedDrugHistory = {...?patient?.drugHistorySuggestions};
    _selectedMaternalHistory = {...?patient?.maternalHistorySuggestions};
    _selectedHabits = {...?patient?.habitsSuggestions};
    _syncDraftController();
  }

  void _syncDraftController() {
    widget.draftController?.update(
      medicalHistory: _selectedMedicalHistory,
      drugHistory: _selectedDrugHistory,
      maternalHistory: _selectedMaternalHistory,
      habits: _selectedHabits,
    );
  }

  void _toggleItem(Set<String> selected, String value) {
    setState(() {
      if (selected.contains(value)) {
        selected.remove(value);
      } else {
        selected.add(value);
      }
    });
    _syncDraftController();
  }

  Widget _popupFieldLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: AppColors.blue7505,
        ),
      ),
    );
  }

  Widget _historyCell(
    String value, {
    int flex = 1,
    TextAlign textAlign = TextAlign.left,
    bool header = false,
  }) {
    return Expanded(
      flex: flex,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        child: Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: textAlign,
          style: TextStyle(
            color: header ? AppColors.blue6007 : AppColors.blue7002,
            fontWeight: header ? FontWeight.w700 : FontWeight.w600,
            fontSize: header ? 11 : 12,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final rows = widget.allAppointmentsForPatient
        .where((row) => row.id != widget.appointment.id)
        .toList(growable: false)
      ..sort((a, b) => b.date.compareTo(a.date));

    final visibleCount = _showMore ? rows.length : rows.length.clamp(0, 5);
    final visibleRows = rows.take(visibleCount).toList(growable: false);

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.slate504,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.borderBlueSoft),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _popupFieldLabel('Medical History:'),
                SelectableChipGroup(
                  options: patientMedicalHistorySuggestions,
                  selected: _selectedMedicalHistory,
                  onToggle: (value) => _toggleItem(
                    _selectedMedicalHistory,
                    value,
                  ),
                ),
                const SizedBox(height: 10),
                _popupFieldLabel('Drug History:'),
                SelectableChipGroup(
                  options: patientDrugHistorySuggestions,
                  selected: _selectedDrugHistory,
                  onToggle: (value) => _toggleItem(
                    _selectedDrugHistory,
                    value,
                  ),
                ),
                const SizedBox(height: 10),
                _popupFieldLabel('Maternal History:'),
                SelectableChipGroup(
                  options: patientMaternalHistorySuggestions,
                  selected: _selectedMaternalHistory,
                  onToggle: (value) => _toggleItem(
                    _selectedMaternalHistory,
                    value,
                  ),
                ),
                const SizedBox(height: 10),
                _popupFieldLabel('Habits:'),
                SelectableChipGroup(
                  options: patientHabitsSuggestions,
                  selected: _selectedHabits,
                  onToggle: (value) => _toggleItem(
                    _selectedHabits,
                    value,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.slate504,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.borderBlueSoft),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Last Treatments',
                  style: TextStyle(
                    color: AppColors.blue7006,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 8),
                if (visibleRows.isEmpty)
                  const Text(
                    'No previous treatments found.',
                    style: TextStyle(
                      color: AppColors.textBlueMuted,
                      fontWeight: FontWeight.w600,
                    ),
                  )
                else
                  Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceBlueSoft,
                          border: Border.all(color: AppColors.violet1508),
                        ),
                        child: Row(
                          children: [
                            _historyCell('Date', flex: 2, header: true),
                            _historyCell('Treatment', flex: 3, header: true),
                            _historyCell('Teeth', flex: 2, header: true),
                            _historyCell('Diagnosis', flex: 3, header: true),
                            _historyCell('Chief Complaint',
                                flex: 3, header: true),
                            _historyCell('Doctor', flex: 2, header: true),
                          ],
                        ),
                      ),
                      ...visibleRows.map((row) {
                        final treatmentText = row.selectedTreatments
                            .where((e) => e.trim().isNotEmpty)
                            .join(', ')
                            .trim();
                        final doctorText = row.operators
                            .map((d) => d.title.trim())
                            .where((d) => d.isNotEmpty)
                            .join(', ')
                            .trim();
                        final teethText = row.selectedTeeth
                            .where((e) => e.trim().isNotEmpty)
                            .join(', ')
                            .trim();
                        final diagnosisText = row.diagnosis
                            .where((e) => e.trim().isNotEmpty)
                            .join(', ')
                            .trim();
                        final complaintText = row.chiefComplaints
                            .where((e) => e.trim().isNotEmpty)
                            .join(', ')
                            .trim();

                        return Container(
                          padding: const EdgeInsets.symmetric(vertical: 1),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            border: Border.all(color: AppColors.borderBlueSoft),
                          ),
                          child: Row(
                            children: [
                              _historyCell(
                                formatClinicDate(row.date,
                                    pattern: 'dd MMM yyyy'),
                                flex: 2,
                              ),
                              _historyCell(
                                  treatmentText.isEmpty ? '-' : treatmentText,
                                  flex: 3),
                              _historyCell(teethText.isEmpty ? '-' : teethText,
                                  flex: 2),
                              _historyCell(
                                  diagnosisText.isEmpty ? '-' : diagnosisText,
                                  flex: 3),
                              _historyCell(
                                  complaintText.isEmpty ? '-' : complaintText,
                                  flex: 3),
                              _historyCell(
                                  doctorText.isEmpty
                                      ? 'Unassigned'
                                      : doctorText,
                                  flex: 2),
                            ],
                          ),
                        );
                      }),
                    ],
                  ),
                if (rows.length > 5) ...[
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerRight,
                    child: AppButton(
                      label: _showMore ? 'Show Less' : 'Show More',
                      variant: AppButtonVariant.secondary,
                      compact: true,
                      onPressed: () => setState(() => _showMore = !_showMore),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CheckinScreenSkeleton extends StatelessWidget {
  const _CheckinScreenSkeleton();

  Widget _skeletonCard({double height = 260}) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.violet1506),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 120,
            height: 14,
            decoration: BoxDecoration(
              color: AppColors.slate100,
              borderRadius: BorderRadius.circular(6),
            ),
          ),
          const SizedBox(height: 12),
          ...List.generate(
            5,
            (_) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Container(
                width: double.infinity,
                height: 10,
                decoration: BoxDecoration(
                  color: AppColors.slate1004,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            growable: false,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppTheme.light.scaffoldBackgroundColor,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              height: 38,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.violet1506),
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                SizedBox(width: 340, child: _skeletonCard()),
                SizedBox(width: 340, child: _skeletonCard()),
                SizedBox(width: 340, child: _skeletonCard()),
                SizedBox(width: 340, child: _skeletonCard()),
                SizedBox(width: 340, child: _skeletonCard()),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class CheckinScreen extends StatefulWidget {
  const CheckinScreen({super.key});

  @override
  State<CheckinScreen> createState() => _CheckinScreenState();
}

class _CheckinScreenState extends State<CheckinScreen> {
  DateTime _selectedDate = _dateOnly(checkinPersistedDate);
  String _selectedDoctor = '__all__';
  Appointment? _selectedAppointment;
  Timer? _waitingTimer;
  late final Future<void> _bootstrapFuture;
  final Map<String, bool> _expandedStages = {
    'waiting': true,
    'with_doctor': true,
    'billing_completed': true,
  };

  @override
  void initState() {
    super.initState();
    _bootstrapFuture = _initializeStores();
    _waitingTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (!mounted) return;
      setState(() {});
    });
  }

  Future<void> _initializeStores() async {
    await Future.wait([
      appointments.loaded,
      patients.loaded,
      doctors.loaded,
      labworks.loaded,
    ]);
  }

  @override
  void dispose() {
    _waitingTimer?.cancel();
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

  Appointment? _checkInPatient(Patient patient) {
    if (!runCriticalWriteUiGuard(context, actionLabel: 'checking in patient')) {
      return null;
    }
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
    return appointment;
  }

  String _billingCombinedRowStage(Appointment appointment) {
    if (appointment.checkinStage == 'completed' || appointment.isDone) {
      return 'completed';
    }
    return 'checkout';
  }

  Future<void> _openAppointmentPopup(Appointment appointment) async {
    await openAppointmentJourneyDialog(context, appointment);
  }

  void _selectAndOpenAppointment(Appointment appointment) {
    setState(() => _selectedAppointment = appointment);
    _openAppointmentPopup(appointment);
  }

  Future<Patient?> _openAddPatientPopup(String query) {
    return openAddPatientPopup(
      context: context,
      initialInput: query,
    );
  }

  Future<void> _openNewPatientAndCheckin() async {
    final created = await _openAddPatientPopup('');
    if (!mounted || created == null) return;
    final appointment = _checkInPatient(created);
    if (appointment == null) return;
    if (!mounted) return;
    await _openAppointmentPopup(appointment);
  }

  Future<void> _openTreatmentPackageManager() async {
    await showTreatmentPackageManagerDialog(context: context);
  }

  Future<void> _openNextCheckinStepper(Appointment appointment) async {
    await openAppointmentJourneyDialog(context, appointment);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _bootstrapFuture,
      builder: (context, bootSnapshot) {
        if (bootSnapshot.connectionState != ConnectionState.done) {
          return const _CheckinScreenSkeleton();
        }

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

                final isDoctorLogin =
                    permissions.currentRole == UserRole.doctor;

                final patientVisitCounts = <String, int>{};
                for (final row in filtered) {
                  final patientId = row.patientID;
                  if (patientId == null || patientId.trim().isEmpty) continue;
                  patientVisitCounts[patientId] =
                      (patientVisitCounts[patientId] ?? 0) + 1;
                }
                final duplicatePatientIds = patientVisitCounts.entries
                    .where((entry) => entry.value > 1)
                    .map((entry) => entry.key)
                    .toSet();

                final waiting = filtered
                    .where((a) => a.checkinStage == 'waiting')
                    .toList(growable: true)
                  ..sort((a, b) => a.date.compareTo(b.date));

                final scheduled = filtered
                    .where((a) =>
                        a.checkinStage == 'pending' ||
                        a.checkinStage == 'scheduled')
                    .toList(growable: true)
                  ..sort((a, b) => a.date.compareTo(b.date));
                final cancelled = filtered
                    .where((a) => a.checkinStage == 'cancelled')
                    .toList(growable: true)
                  ..sort((a, b) => b.date.compareTo(a.date));
                final withDoctor = filtered
                    .where((a) =>
                        a.checkinStage == 'with_doctor' ||
                        a.checkinStage == 'treatment')
                    .toList(growable: true)
                  ..sort((a, b) => a.date.compareTo(b.date));
                final billingList = filtered
                    .where(
                      (a) =>
                          (a.checkinStage == 'checkout' ||
                              a.checkinStage == 'billing') &&
                          !a.isDone &&
                          a.checkinStage != 'completed',
                    )
                    .toList(growable: true)
                  ..sort((a, b) => a.date.compareTo(b.date));

                final completedList = filtered
                    .where(
                      (a) => a.checkinStage == 'completed' || a.isDone,
                    )
                    .toList(growable: true)
                  ..sort((a, b) {
                    final aTs = a.completedTime?.millisecondsSinceEpoch ??
                        a.checkedInAt?.millisecondsSinceEpoch ??
                        a.date.millisecondsSinceEpoch;
                    final bTs = b.completedTime?.millisecondsSinceEpoch ??
                        b.checkedInAt?.millisecondsSinceEpoch ??
                        b.date.millisecondsSinceEpoch;
                    return bTs.compareTo(aTs);
                  });

                final now = DateTime.now();
                final isToday = _selectedDate.year == now.year &&
                    _selectedDate.month == now.month &&
                    _selectedDate.day == now.day;
                final screenWidth = MediaQuery.of(context).size.width;
                final isMobile = screenWidth < 760;

                return Container(
                  color: AppTheme.light.scaffoldBackgroundColor,
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
                                  Text(
                                    'Check-in (${todaysAppointments.length})',
                                    style: const TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.blue750,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  Expanded(
                                    child: AppButton(
                                      variant: AppButtonVariant.secondary,
                                      onPressed: _openNewPatientAndCheckin,
                                      label: 'New Patient',
                                      leading: const Icon(
                                          FluentIcons.add_friend,
                                          size: 12),
                                      expanded: true,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: PatientCheckinSearchButton(
                                      selectedDate: _selectedDate,
                                      title: 'Search Patient',
                                      compact: true,
                                      showInput: false,
                                      onAddPatient: _openAddPatientPopup,
                                      onOpenExisting: (existing) async {
                                        if (!mounted) return;
                                        _selectAndOpenAppointment(existing);
                                      },
                                      onCheckInPatient: (patient) async {
                                        if (!mounted) return;
                                        _checkInPatient(patient);
                                      },
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              SizedBox(
                                width: double.infinity,
                                child: AppButton(
                                  onPressed: _openTreatmentPackageManager,
                                  variant: AppButtonVariant.secondary,
                                  label: 'Treatment Packages',
                                  leading:
                                      const Icon(FluentIcons.medical, size: 12),
                                  expanded: true,
                                ),
                              ),
                              const SizedBox(height: 8),
                              SizedBox(
                                width: double.infinity,
                                child: AppButton(
                                  onPressed: () {
                                    final target =
                                        _selectedAppointment ?? filtered.first;
                                    _openNextCheckinStepper(target);
                                  },
                                  label: 'New Checkin Flow',
                                  expanded: true,
                                ),
                              ),
                            ],
                          )
                        else
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  AppScreenTitle(
                                    title:
                                        'Check-in (${todaysAppointments.length})',
                                  ),
                                ],
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Center(
                                  child: DateNavigatorBar(
                                    selectedDate: _selectedDate,
                                    onPrevious: () => _changeDate(-1),
                                    onNext: () => _changeDate(1),
                                    onPick: () => _pickDate(context),
                                    onToday: () => setState(() {
                                      _selectedDate = _dateOnly(DateTime.now());
                                      checkinPersistedDate = _selectedDate;
                                    }),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              AppButton(
                                onPressed: _openNewPatientAndCheckin,
                                variant: AppButtonVariant.secondary,
                                label: 'New Patient',
                                leading: const Icon(FluentIcons.add_friend,
                                    size: 12),
                              ),
                              const SizedBox(width: 8),
                              AppButton(
                                onPressed: _openTreatmentPackageManager,
                                variant: AppButtonVariant.secondary,
                                label: 'Treatment Packages',
                                leading:
                                    const Icon(FluentIcons.medical, size: 12),
                              ),
                              const SizedBox(width: 8),
                              SizedBox(
                                width: 180,
                                child: PatientCheckinSearchButton(
                                  selectedDate: _selectedDate,
                                  title: 'Search Patient',
                                  compact: false,
                                  showInput: false,
                                  onAddPatient: _openAddPatientPopup,
                                  onOpenExisting: (existing) async {
                                    if (!mounted) return;
                                    _selectAndOpenAppointment(existing);
                                  },
                                  onCheckInPatient: (patient) async {
                                    if (!mounted) return;
                                    _checkInPatient(patient);
                                  },
                                ),
                              ),
                            ],
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
                              final isSelected = _selectedDoctor == id;
                              return _DoctorFilterChip(
                                label: doctors.get(id)?.title ?? 'Unknown',
                                selected: isSelected,
                                onTap: () => setState(
                                  () => _selectedDoctor =
                                      isSelected ? '__all__' : id,
                                ),
                              );
                            }),
                          ],
                        ),
                        const SizedBox(height: 12),
                        LayoutBuilder(
                          builder: (context, constraints) {
                            final stacked = constraints.maxWidth <
                                (isDoctorLogin ? 1120 : 1400);

                            final waitingColumn = _WorkflowColumn(
                              title: 'Waiting (${waiting.length})',
                              stage: 'waiting',
                              color: AppColors.amber350,
                              rows: waiting,
                              duplicatePatientIds: duplicatePatientIds,
                              showHistoryAction: false,
                              onSelect: _selectAndOpenAppointment,
                              selectedAppointmentId: _selectedAppointment?.id,
                              expanded: _expandedStages['waiting'] ?? true,
                              onToggleExpanded: () => setState(() {
                                _expandedStages['waiting'] =
                                    !(_expandedStages['waiting'] ?? true);
                              }),
                            );

                            final scheduledColumn = _WorkflowColumn(
                              title: 'Scheduled (${scheduled.length})',
                              stage: 'scheduled',
                              color: AppColors.scheduledChipFg,
                              rows: scheduled,
                              duplicatePatientIds: duplicatePatientIds,
                              showHistoryAction: false,
                              onSelect: _selectAndOpenAppointment,
                              selectedAppointmentId: _selectedAppointment?.id,
                              expanded: _expandedStages['scheduled'] ?? true,
                              onToggleExpanded: () => setState(() {
                                _expandedStages['scheduled'] =
                                    !(_expandedStages['scheduled'] ?? true);
                              }),
                            );

                            final cancelledColumn = _WorkflowColumn(
                              title: 'Cancelled (${cancelled.length})',
                              stage: 'cancelled',
                              color: AppColors.rose6003,
                              rows: cancelled,
                              duplicatePatientIds: duplicatePatientIds,
                              showHistoryAction: false,
                              onSelect: _selectAndOpenAppointment,
                              selectedAppointmentId: _selectedAppointment?.id,
                              expanded: _expandedStages['cancelled'] ?? true,
                              onToggleExpanded: () => setState(() {
                                _expandedStages['cancelled'] =
                                    !(_expandedStages['cancelled'] ?? true);
                              }),
                            );

                            final withDoctorColumn = _WorkflowColumn(
                              title: 'Treatment (${withDoctor.length})',
                              stage: 'with_doctor',
                              color: AppColors.brandBlue,
                              rows: withDoctor,
                              duplicatePatientIds: duplicatePatientIds,
                              showHistoryAction: false,
                              onSelect: _selectAndOpenAppointment,
                              selectedAppointmentId: _selectedAppointment?.id,
                              expanded: _expandedStages['with_doctor'] ?? true,
                              onToggleExpanded: () => setState(() {
                                _expandedStages['with_doctor'] =
                                    !(_expandedStages['with_doctor'] ?? true);
                              }),
                            );

                            final billingColumn = _WorkflowColumn(
                              title: 'Billing (${billingList.length})',
                              stage: 'billing',
                              color: AppColors.blue6008,
                              rows: billingList,
                              duplicatePatientIds: duplicatePatientIds,
                              onSelect: _selectAndOpenAppointment,
                              selectedAppointmentId: _selectedAppointment?.id,
                              interactionsEnabled: !isDoctorLogin,
                              expanded: _expandedStages['billing'] ?? true,
                              onToggleExpanded: () => setState(() {
                                _expandedStages['billing'] =
                                    !(_expandedStages['billing'] ?? true);
                              }),
                            );

                            final completedColumn = _WorkflowColumn(
                              title: 'Completed (${completedList.length})',
                              stage: 'completed',
                              color: AppColors.green500,
                              rows: completedList,
                              duplicatePatientIds: duplicatePatientIds,
                              onSelect: _selectAndOpenAppointment,
                              selectedAppointmentId: _selectedAppointment?.id,
                              interactionsEnabled: !isDoctorLogin,
                              expanded: _expandedStages['completed'] ?? true,
                              onToggleExpanded: () => setState(() {
                                _expandedStages['completed'] =
                                    !(_expandedStages['completed'] ?? true);
                              }),
                            );

                            if (stacked) {
                              return Column(
                                children: [
                                  waitingColumn,
                                  if (!isDoctorLogin) ...[
                                    const SizedBox(height: 10),
                                    scheduledColumn,
                                    if (cancelled.isNotEmpty) ...[
                                      const SizedBox(height: 10),
                                      cancelledColumn,
                                    ],
                                  ],
                                  const SizedBox(height: 10),
                                  withDoctorColumn,
                                  const SizedBox(height: 10),
                                  billingColumn,
                                  const SizedBox(height: 10),
                                  completedColumn,
                                ],
                              );
                            }

                            return Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Column(
                                    children: [
                                      waitingColumn,
                                      if (!isDoctorLogin) ...[
                                        const SizedBox(height: 10),
                                        scheduledColumn,
                                        if (cancelled.isNotEmpty) ...[
                                          const SizedBox(height: 10),
                                          cancelledColumn,
                                        ],
                                      ],
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(child: withDoctorColumn),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    children: [
                                      billingColumn,
                                      const SizedBox(height: 10),
                                      completedColumn,
                                    ],
                                  ),
                                ),
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
      },
    );
  }
}

class _CheckinHistoryDetails extends StatefulWidget {
  final Appointment appointment;
  final BuildContext rootContext;

  const _CheckinHistoryDetails({
    required this.appointment,
    required this.rootContext,
  });

  @override
  State<_CheckinHistoryDetails> createState() => _CheckinHistoryDetailsState();
}

class _CheckinHistoryDetailsState extends State<_CheckinHistoryDetails> {
  static bool _sameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  Future<void> _changeDoctor(Appointment appointment) async {
    final pickedDoctorIds = await showDialog<List<String>>(
      context: context,
      builder: (dialogContext) {
        final doctorRows = doctors.present.values.toList(growable: false)
          ..sort(
              (a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
        final selected = appointment.operatorsIDs.toSet();
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            final selectedRows = doctorRows
                .where((d) => selected.contains(d.id))
                .toList(growable: false);
            final otherRows = doctorRows
                .where((d) => !selected.contains(d.id))
                .toList(growable: false);
            return ContentDialog(
              title: Row(
                children: [
                  const Expanded(child: Text('Change Doctors')),
                  IconButton(
                    icon: const Icon(FluentIcons.chrome_close, size: 12),
                    onPressed: () => Navigator.pop(dialogContext),
                  ),
                ],
              ),
              content: SizedBox(
                width: 420,
                child: doctorRows.isEmpty
                    ? const Text('No doctors available to assign.')
                    : ConstrainedBox(
                        constraints: const BoxConstraints(maxHeight: 360),
                        child: SingleChildScrollView(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _patientFocusSummary(appointment),
                                style: const TextStyle(
                                  color: AppColors.textBlueStrong,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 10),
                              if (selectedRows.isNotEmpty) ...[
                                const Text(
                                  'Selected Doctors',
                                  style: TextStyle(
                                    color: AppColors.green600,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: selectedRows.map((doctor) {
                                    final doctorName =
                                        doctor.title.trim().isEmpty
                                            ? 'Unnamed doctor'
                                            : doctor.title;
                                    return GestureDetector(
                                      onTap: () {
                                        setStateDialog(() {
                                          selected.remove(doctor.id);
                                        });
                                      },
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 10, vertical: 6),
                                        decoration: BoxDecoration(
                                          color: AppColors.green1002,
                                          borderRadius:
                                              BorderRadius.circular(999),
                                          border: Border.all(
                                            color: AppColors.green400,
                                          ),
                                        ),
                                        child: Text(
                                          doctorName,
                                          style: const TextStyle(
                                            color: AppColors.green650,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                    );
                                  }).toList(growable: false),
                                ),
                                const SizedBox(height: 10),
                                const Divider(size: 1),
                                const SizedBox(height: 10),
                              ],
                              const Text(
                                'Other Doctors',
                                style: TextStyle(
                                  color: AppColors.textBlueStrong,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: otherRows.map((doctor) {
                                  final doctorName = doctor.title.trim().isEmpty
                                      ? 'Unnamed doctor'
                                      : doctor.title;
                                  return GestureDetector(
                                    onTap: () {
                                      setStateDialog(() {
                                        selected.add(doctor.id);
                                      });
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 10, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: AppColors.slate1004,
                                        borderRadius:
                                            BorderRadius.circular(999),
                                        border: Border.all(
                                          color: AppColors.violet1502,
                                        ),
                                      ),
                                      child: Text(
                                        doctorName,
                                        style: const TextStyle(
                                          color: AppColors.textBlueStrong,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                  );
                                }).toList(growable: false),
                              ),
                            ],
                          ),
                        ),
                      ),
              ),
              actions: [
                AppButton(
                  label: 'Cancel',
                  variant: AppButtonVariant.secondary,
                  onPressed: () => Navigator.pop(dialogContext),
                ),
                AppButton(
                  label: 'Save',
                  onPressed: () => Navigator.pop(
                      dialogContext, selected.toList(growable: false)),
                ),
              ],
            );
          },
        );
      },
    );

    if (pickedDoctorIds == null || pickedDoctorIds.isEmpty) return;
    appointment.operatorsIDs = pickedDoctorIds;
    appointments.set(appointment);
  }

  Future<void> _moveCompletedToBilling(Appointment appointment) async {
    final patientName = _patientDisplayName(appointment);
    final shouldMove = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => ContentDialog(
        title: Text('Move "$patientName" back to Billing?'),
        content: Text(
          'This appointment will be moved back to Billing stage for $patientName.',
        ),
        actions: [
          AppButton(
            label: 'Cancel',
            variant: AppButtonVariant.secondary,
            onPressed: () => Navigator.pop(dialogContext, false),
          ),
          AppButton(
            label: 'Billing',
            variant: AppButtonVariant.danger,
            onPressed: () => Navigator.pop(dialogContext, true),
          ),
        ],
      ),
    );
    if (shouldMove != true) return;
    appointment.checkinStage = 'checkout';
    appointment.completedTime = null;
    appointment.isDone = false;
    appointments.set(appointment);
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  Future<void> _openNextAppointmentPrompt(Appointment appointment) async {
    await _showNextAppointmentPromptDialog(context, appointment);
  }

  @override
  Widget build(BuildContext context) {
    final appointment = widget.appointment;
    final patient = appointment.patient;

    final doctorName = appointment.operators.isEmpty
        ? 'Unassigned'
        : appointment.operators.map((d) => d.title).join(', ');
    final medicalHistorySummary = _medicalHistorySummaryText(patient);
    final isCheckout = appointment.checkinStage == 'checkout';
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
    final timelineRows =
        otherRows.length <= 1 ? <Appointment>[] : otherRows.sublist(1);

    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    medicalHistorySummary,
                    style: const TextStyle(
                      color: AppColors.rose650,
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                ),
                const Divider(size: 1),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        isCheckout
                            ? 'Today\'s Appointment Details'
                            : 'Current Appointment Details',
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: AppColors.blue750,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                if (!isCheckout)
                  GestureDetector(
                    onTap: () => _changeDoctor(appointment),
                    behavior: HitTestBehavior.opaque,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 6),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text(
                            'Doctor:',
                            style: TextStyle(
                              color: AppColors.blue5004,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            doctorName.trim().isEmpty
                                ? 'Unnamed doctor'
                                : doctorName,
                            style: const TextStyle(
                              color: AppColors.brandBlueDark,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Icon(FluentIcons.chevron_down, size: 10),
                        ],
                      ),
                    ),
                  ),
                const SizedBox(height: 10),
                if (isCheckout)
                  TodayAppointmentInsightCard(appointment: appointment)
                else
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: _LastAppointmentInsightCard(
                          lastAppointment: lastAppointment,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _CompactTimelineTable(
                          rows: timelineRows,
                        ),
                      ),
                    ],
                  ),
                const SizedBox(height: 10),
                if (appointment.checkinStage == 'with_doctor' ||
                    appointment.checkinStage == 'checkout')
                  _CheckinTreatmentStageScreen(
                    appointment: appointment,
                    allAppointmentsForPatient: all,
                    forcedStage: appointment.checkinStage == 'checkout'
                        ? 'checkout'
                        : 'with_doctor',
                    showInlineBottomActions: false,
                  )
                else
                  const SizedBox.shrink(),
                if (appointment.checkinStage == 'completed') ...[
                  const SizedBox(height: 8),
                  _CheckinCompletedStageScreen(
                    appointment: appointment,
                    lastVisit: lastAppointment,
                  ),
                ],
                const SizedBox(height: 10),
                if (otherRows.isEmpty) const SizedBox.shrink(),
              ],
            ),
          ),
        ),
        _buildFixedFooterActions(appointment),
      ],
    );
  }

  Widget _buildFixedFooterActions(Appointment appointment) {
    final stage = appointment.checkinStage.trim().toLowerCase();
    final patientName = _patientDisplayName(appointment);
    if (stage == 'waiting' || stage == 'pending') {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: AppColors.violet1002)),
        ),
        child: SizedBox(
          width: double.infinity,
          child: AppButton(
            label: 'Check-in',
            onPressed: () async {
              Navigator.of(context).pop();
              final pickedDoctorIds = await pickDoctorDialog(
                widget.rootContext,
                initialSelected: appointment.operatorsIDs,
                subtitle: _patientFocusSummary(appointment),
              );
              if (pickedDoctorIds == null || pickedDoctorIds.isEmpty) return;
              appointment.operatorsIDs = pickedDoctorIds;
              appointment.checkinStage = 'with_doctor';
              appointment.completedTime = null;
              appointment.isDone = false;
              appointment.checkedInAt = DateTime.now();
              appointments.set(appointment);
              if (mounted) setState(() {});
            },
          ),
        ),
      );
    }

    if (stage == 'with_doctor') {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: AppColors.violet1002)),
        ),
        child: Row(
          children: [
            Expanded(
              child: AppButton(
                label: 'Move Back to Waiting',
                variant: AppButtonVariant.danger,
                onPressed: () async {
                  final shouldMove = await showDialog<bool>(
                    context: context,
                    builder: (dialogContext) => ContentDialog(
                      title: Text('Move "$patientName" back to Waiting?'),
                      content: Text(
                        '$patientName will be moved back to Waiting and doctor assignment will be removed.',
                      ),
                      actions: [
                        AppButton(
                          label: 'Cancel',
                          variant: AppButtonVariant.secondary,
                          onPressed: () => Navigator.pop(dialogContext, false),
                        ),
                        AppButton(
                          label: 'Move',
                          variant: AppButtonVariant.danger,
                          onPressed: () => Navigator.pop(dialogContext, true),
                        ),
                      ],
                    ),
                  );
                  if (shouldMove != true) return;
                  appointment.checkinStage = 'waiting';
                  appointment.operatorsIDs = [];
                  appointment.completedTime = null;
                  appointment.isDone = false;
                  appointments.set(appointment);
                  if (mounted) {
                    Navigator.of(context).pop();
                  }
                  if (mounted) setState(() {});
                },
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: AppButton(
                label: 'Proceed to Billing',
                onPressed: () {
                  appointment.checkinStage = 'checkout';
                  appointment.completedTime = null;
                  appointment.isDone = false;
                  appointments.set(appointment);
                  if (mounted) {
                    Navigator.of(context).pop();
                  }
                  if (mounted) setState(() {});
                },
              ),
            ),
          ],
        ),
      );
    }

    if (stage == 'checkout') {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: AppColors.violet1002)),
        ),
        child: Row(
          children: [
            Expanded(
              child: AppButton(
                label: 'Move Back to Treatment',
                variant: AppButtonVariant.secondary,
                onPressed: () async {
                  final shouldMove = await showDialog<bool>(
                    context: context,
                    builder: (dialogContext) => ContentDialog(
                      title: Text('Move "$patientName" back to Treatment?'),
                      content: Text(
                        'This appointment will be moved back to Treatment for $patientName.',
                      ),
                      actions: [
                        AppButton(
                          label: 'Cancel',
                          variant: AppButtonVariant.secondary,
                          onPressed: () => Navigator.pop(dialogContext, false),
                        ),
                        AppButton(
                          label: 'Move to Treatment',
                          variant: AppButtonVariant.danger,
                          onPressed: () => Navigator.pop(dialogContext, true),
                        ),
                      ],
                    ),
                  );
                  if (shouldMove != true) return;
                  appointment.checkinStage = 'with_doctor';
                  appointment.completedTime = null;
                  appointment.isDone = false;
                  appointments.set(appointment);
                  if (mounted) {
                    Navigator.of(context).pop();
                  }
                  if (mounted) setState(() {});
                },
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: AppButton(
                label: 'Collect',
                onPressed: () async {
                  final shouldComplete = await _confirmMoveToCompleted(
                    context,
                    appointment,
                  );
                  if (!shouldComplete) return;
                  appointment.checkinStage = 'completed';
                  appointment.completedTime = DateTime.now();
                  appointment.isDone = true;
                  appointments.set(appointment);
                  if (mounted) {
                    Navigator.of(context).pop();
                  }
                  await _openNextAppointmentPrompt(appointment);
                  if (mounted) setState(() {});
                },
                leading: StreamBuilder(
                  stream: appointments.observableMap.stream,
                  builder: (context, _) {
                    final latest = appointments.present.values.firstWhere(
                        (a) => a.id == appointment.id,
                        orElse: () => appointment);
                    final paid = latest.paid;
                    return Text('\u20B9${paid.toStringAsFixed(0)}');
                  },
                ),
              ),
            ),
          ],
        ),
      );
    }

    if (stage == 'completed') {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: AppColors.violet1002)),
        ),
        child: Row(
          children: [
            Expanded(
              child: AppButton(
                label: 'Move Back to Billing',
                variant: AppButtonVariant.danger,
                onPressed: () => _moveCompletedToBilling(appointment),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: AppButton(
                label: 'New Appointment',
                onPressed: () {
                  final patient = appointment.patient;
                  if (patient == null) return;
                  final nextAppointment = Appointment.fromJson({
                    'patientID': patient.id,
                    'operatorsIDs': appointment.operatorsIDs,
                    'date': DateTime.now()
                        .add(const Duration(days: 7))
                        .millisecondsSinceEpoch,
                  });
                  _openNextAppointmentPrompt(appointment);
                },
              ),
            ),
          ],
        ),
      );
    }

    return const SizedBox.shrink();
  }
}

class _LastAppointmentInsightCard extends StatelessWidget {
  final Appointment? lastAppointment;
  const _LastAppointmentInsightCard({required this.lastAppointment});

  @override
  Widget build(BuildContext context) {
    if (lastAppointment == null) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.slate504,
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Text(
          'No previous appointment history available.',
          style: TextStyle(
            color: AppColors.textBlueMuted,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
    }

    final last = lastAppointment!;
    final treatmentSummary = last.selectedTreatments
        .where((row) => row.trim().isNotEmpty)
        .join(', ');
    final diagnosis =
        last.diagnosis.where((row) => row.trim().isNotEmpty).join(', ');
    final chiefComplaints =
        last.chiefComplaints.where((row) => row.trim().isNotEmpty).join(', ');
    final doctorSummary = last.operators.isEmpty
        ? 'Unassigned'
        : last.operators
            .map((d) => d.title.trim().isEmpty ? 'Unnamed doctor' : d.title)
            .join(', ');
    final teethSummary =
        last.selectedTeeth.where((row) => row.trim().isNotEmpty).join(', ');

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.slate504,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Last Appointment',
            style: TextStyle(
              color: AppColors.blue7508,
              fontWeight: FontWeight.w800,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            formatClinicDateTime(last.date, pattern: 'dd MMM yyyy • h:mm a'),
            style: const TextStyle(
              color: AppColors.textBlueStrong,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Diagnosis: ${diagnosis.isEmpty ? '-' : diagnosis}',
            style: const TextStyle(
              color: AppColors.textBlueMuted,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Chief Complaints: ${chiefComplaints.isEmpty ? '-' : chiefComplaints}',
            style: const TextStyle(
              color: AppColors.textBlueMuted,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Treatment: ${treatmentSummary.isEmpty ? '-' : treatmentSummary}',
            style: const TextStyle(
              color: AppColors.textBlueMuted,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Doctor: $doctorSummary',
            style: const TextStyle(
              color: AppColors.textBlueMuted,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Teeth: ${teethSummary.isEmpty ? '-' : teethSummary}',
            style: const TextStyle(
              color: AppColors.textBlueMuted,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class TodayAppointmentInsightCard extends StatelessWidget {
  final Appointment appointment;

  const TodayAppointmentInsightCard({
    super.key,
    required this.appointment,
  });

  @override
  Widget build(BuildContext context) {
    final diagnosis =
        appointment.diagnosis.where((row) => row.trim().isNotEmpty).join(', ');
    final chiefComplaints = appointment.chiefComplaints
        .where((row) => row.trim().isNotEmpty)
        .join(', ');
    final treatments = appointment.selectedTreatments
        .where((row) => row.trim().isNotEmpty)
        .join(', ');
    final teethSummary =
        appointment.selectedTeeth.map((id) => id.toString()).join(', ');
    final doctorSummary = appointment.operators.isEmpty
        ? 'Unassigned'
        : appointment.operators
            .map((d) => d.title.trim().isEmpty ? 'Unnamed doctor' : d.title)
            .join(', ');

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.slate504,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Today Appointment',
            style: TextStyle(
              color: AppColors.blue7508,
              fontWeight: FontWeight.w800,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            formatClinicDateTime(appointment.date,
                pattern: 'dd MMM yyyy • h:mm a'),
            style: const TextStyle(
              color: AppColors.textBlueStrong,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Diagnosis: ${diagnosis.isEmpty ? '-' : diagnosis}',
            style: const TextStyle(
              color: AppColors.textBlueMuted,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Chief Complaints: ${chiefComplaints.isEmpty ? '-' : chiefComplaints}',
            style: const TextStyle(
              color: AppColors.textBlueMuted,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Treatment: ${treatments.isEmpty ? '-' : treatments}',
            style: const TextStyle(
              color: AppColors.textBlueMuted,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Doctor: $doctorSummary',
            style: const TextStyle(
              color: AppColors.textBlueMuted,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Teeth: ${teethSummary.isEmpty ? '-' : teethSummary}',
            style: const TextStyle(
              color: AppColors.textBlueMuted,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _CompactTimelineTable extends StatelessWidget {
  final List<Appointment> rows;

  const _CompactTimelineTable({
    required this.rows,
  });

  @override
  Widget build(BuildContext context) {
    final visibleRows = rows.take(5).toList(growable: false);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.slate504,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Patient Timeline',
            style: TextStyle(
              color: AppColors.blue7508,
              fontWeight: FontWeight.w800,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 8),
          if (visibleRows.isEmpty)
            const Text(
              'No timeline entries available.',
              style: TextStyle(
                color: AppColors.textBlueMuted,
                fontWeight: FontWeight.w600,
              ),
            )
          else
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SizedBox(
                width: 720,
                child: AppTable(
                  columns: const [
                    material.DataColumn(label: Text('Date')),
                    material.DataColumn(label: Text('Treatment')),
                    material.DataColumn(label: Text('Doctor')),
                    material.DataColumn(label: Text('Teeth')),
                  ],
                  rows: visibleRows
                      .map(
                        (row) => material.DataRow(
                          cells: [
                            material.DataCell(
                              Text(formatClinicDate(row.date,
                                  pattern: 'dd MMM yyyy')),
                            ),
                            material.DataCell(
                              Text(
                                row.selectedTreatments
                                        .where((e) => e.trim().isNotEmpty)
                                        .join(', ')
                                        .trim()
                                        .isEmpty
                                    ? '-'
                                    : row.selectedTreatments
                                        .where((e) => e.trim().isNotEmpty)
                                        .join(', '),
                              ),
                            ),
                            material.DataCell(
                              Text(
                                row.operators.isEmpty
                                    ? 'Unassigned'
                                    : row.operators
                                        .map((doctor) => doctor.title.trim())
                                        .where((name) => name.isNotEmpty)
                                        .join(', '),
                              ),
                            ),
                            material.DataCell(
                              Text(
                                row.selectedTeeth
                                        .where((e) => e.trim().isNotEmpty)
                                        .join(', ')
                                        .trim()
                                        .isEmpty
                                    ? '-'
                                    : row.selectedTeeth
                                        .where((e) => e.trim().isNotEmpty)
                                        .join(', '),
                              ),
                            ),
                          ],
                        ),
                      )
                      .toList(growable: false),
                ),
              ),
            ),
        ],
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

  const _CheckoutPaymentCard({
    required this.appointment,
    required this.priceController,
    required this.paidController,
    required this.discountController,
    required this.discountEnabled,
    required this.onToggleDiscount,
    required this.onCollectFullBalance,
  });

  @override
  State<_CheckoutPaymentCard> createState() => _CheckoutPaymentCardState();
}

class _CheckoutPaymentCardState extends State<_CheckoutPaymentCard> {
  static const Duration _receiptPdfBuildTimeout = Duration(seconds: 30);
  static const String _rupeeSymbol = '\u20B9';
  String _paymentMode = 'Cash';
  final TextEditingController _consultantChargeController =
      TextEditingController();
  final TextEditingController _prescriptionChargeController =
      TextEditingController();
  static const List<String> _prescriptionChargeItems = [
    'None',
    'Tooth Paste',
    'Dental Floss',
    'Mouth Wash',
    'Gel',
    'Brush',
  ];
  Timer? _autosaveDebounce;
  bool _hasPendingAutosave = false;
  int _receiptExportSequence = 0;
  String _discountMode = 'flat';
  double _basePrice = 0;
  String? _selectedConsultantDoctorId;
  String _selectedPrescriptionChargeItem = 'None';
  String? _initialConsultantDoctorId;
  DateTime? _initialConsultantMonthAnchor;

  @override
  void initState() {
    super.initState();
    final a = widget.appointment;
    _paymentMode = a.treatmentGpayPaid ? 'UPI' : 'Cash';
    _discountMode = a.discountType == 'percent' ? 'percent' : 'flat';
    _basePrice = a.price;
    _selectedConsultantDoctorId = a.consultantDoctorID;
    _initialConsultantDoctorId = a.consultantDoctorID;
    _initialConsultantMonthAnchor = DateTime(a.date.year, a.date.month, 1);
    _consultantChargeController.text =
        a.priceToPayDoctor <= 0 ? '' : a.priceToPayDoctor.toStringAsFixed(0);
    final presetItem = a.prescriptions.map((item) => item.trim()).firstWhere(
          (item) => _prescriptionChargeItems.contains(item),
          orElse: () => _selectedPrescriptionChargeItem,
        );
    _selectedPrescriptionChargeItem =
        (presetItem == 'None' && a.prescriptionPaid > 0)
            ? 'Medicines'
            : presetItem;
    _prescriptionChargeController.text =
        a.prescriptionPaid <= 0 ? '' : a.prescriptionPaid.toStringAsFixed(0);
  }

  @override
  void dispose() {
    _autosaveDebounce?.cancel();
    if (_hasPendingAutosave) {
      appointments.set(widget.appointment);
    }
    _consultantChargeController.dispose();
    _prescriptionChargeController.dispose();
    super.dispose();
  }

  void _scheduleAutosave({bool immediate = false}) {
    final appointment = widget.appointment;
    if (immediate) {
      _autosaveDebounce?.cancel();
      _autosaveDebounce = null;
      _hasPendingAutosave = false;
      appointments.set(appointment);
      unawaited(_syncConsultantMonthlyExpenseEntries());
      return;
    }

    _hasPendingAutosave = true;
    _autosaveDebounce?.cancel();
    _autosaveDebounce = Timer(const Duration(milliseconds: 900), () {
      _hasPendingAutosave = false;
      appointments.set(appointment);
      unawaited(_syncConsultantMonthlyExpenseEntries());
    });
  }

  Future<void> _syncConsultantMonthlyExpenseEntries() async {
    final targets = <MapEntry<String, DateTime>>[];

    void addTarget(String? doctorId, DateTime? monthAnchor) {
      final id = (doctorId ?? '').trim();
      if (id.isEmpty || monthAnchor == null) return;
      final normalized = DateTime(monthAnchor.year, monthAnchor.month, 1);
      final alreadyTracked = targets.any((entry) =>
          entry.key == id &&
          entry.value.year == normalized.year &&
          entry.value.month == normalized.month);
      if (!alreadyTracked) {
        targets.add(MapEntry<String, DateTime>(id, normalized));
      }
    }

    final a = widget.appointment;
    addTarget(_initialConsultantDoctorId, _initialConsultantMonthAnchor);
    addTarget(a.consultantDoctorID, DateTime(a.date.year, a.date.month, 1));

    for (final target in targets) {
      _syncConsultantExpenseForDoctorMonth(
        doctorId: target.key,
        monthAnchor: target.value,
      );
    }
  }

  void _syncConsultantExpenseForDoctorMonth({
    required String doctorId,
    required DateTime monthAnchor,
  }) {
    final monthlyTotal = appointments.present.values.where((row) {
      if ((row.consultantDoctorID ?? '').trim() != doctorId) return false;
      if (row.date.year != monthAnchor.year ||
          row.date.month != monthAnchor.month) {
        return false;
      }
      return row.priceToPayDoctor > 0;
    }).fold<double>(0, (sum, row) => sum + row.priceToPayDoctor);

    final existingRows = expenses.present.values.where((expense) {
      if (expense.items.isEmpty) return false;
      if (expense.items.first.trim().toLowerCase() != 'consultant') {
        return false;
      }
      if (expense.operatorsIDs.length != 1) return false;
      if (expense.operatorsIDs.first != doctorId) return false;
      return expense.date.year == monthAnchor.year &&
          expense.date.month == monthAnchor.month;
    }).toList(growable: true);

    if (existingRows.isNotEmpty) {
      final primary = existingRows.first;
      primary.amount = monthlyTotal;
      primary.date = monthAnchor;
      primary.items = const ['Consultant'];
      primary.operatorsIDs = [doctorId];
      primary.tags = [
        ...primary.tags
            .where(
                (tag) => tag.trim().toLowerCase() != 'auto:consultant-monthly')
            .toList(growable: false),
        'auto:consultant-monthly',
      ];
      expenses.set(primary);

      for (final duplicate in existingRows.skip(1)) {
        duplicate.amount = 0;
        duplicate.tags = [
          ...duplicate.tags
              .where((tag) =>
                  tag.trim().toLowerCase() != 'auto:consultant-duplicate')
              .toList(growable: false),
          'auto:consultant-duplicate',
        ];
        expenses.set(duplicate);
      }
      return;
    }

    if (monthlyTotal <= 0) return;

    final doctorTitle = doctors.get(doctorId)?.title.trim();
    final row = Expense.fromJson({});
    row.date = monthAnchor;
    row.amount = monthlyTotal;
    row.items = const ['Consultant'];
    row.operatorsIDs = [doctorId];
    row.issuer = (doctorTitle == null || doctorTitle.isEmpty)
        ? 'Consultant'
        : doctorTitle;
    row.note = 'Auto consultant monthly total';
    row.tags = const ['auto:consultant-monthly'];
    expenses.set(row);
  }

  void _recalculatePrice() {
    final a = widget.appointment;
    final double discount = widget.discountEnabled
        ? (double.tryParse(widget.discountController.text.trim()) ?? 0)
        : 0;

    a.discount = discount;
    a.discountType = _discountMode;
    a.price = _basePrice;
    _scheduleAutosave();
    setState(() {});
  }

  Future<void> _scheduleAppointmentFromBilling({
    Appointment? existingScheduled,
  }) async {
    final a = widget.appointment;
    if ((a.patientID ?? '').trim().isEmpty) {
      return;
    }

    final resolvedExisting = existingScheduled ??
        (() {
          final upcomingAppointments = appointments.present.values.where((row) {
            if (row.id == a.id) return false;
            if (row.patientID != a.patientID) return false;
            final stage = row.checkinStage.trim().toLowerCase();
            if (stage != 'scheduled' && stage != 'pending') return false;
            return row.date.isAfter(DateTime.now());
          }).toList(growable: false)
            ..sort((x, y) => x.date.compareTo(y.date));
          return upcomingAppointments.isEmpty
              ? null
              : upcomingAppointments.first;
        })();

    final patient = a.patient;
    if (patient == null) {
      return;
    }

    final draft = await showScheduleAppointmentDialog(
      context: context,
      patientSummary:
          '${_patientDisplayName(a)} • ${patient.age}y • ${patient.phone.trim().isEmpty ? '-' : patient.phone}',
      initialDateTime:
          resolvedExisting?.date ?? DateTime.now().add(const Duration(days: 7)),
      initialDoctorIds: (resolvedExisting?.operatorsIDs.isNotEmpty ?? false)
          ? resolvedExisting!.operatorsIDs
          : a.operatorsIDs,
      initialFocusNotes: (resolvedExisting?.chiefComplaints.isNotEmpty ?? false)
          ? resolvedExisting!.chiefComplaints
          : a.chiefComplaints,
      suggestedFocusNotes: kCheckinFocusNotes,
      title: resolvedExisting == null
          ? 'Schedule Appointment'
          : 'Edit Scheduled Appointment',
      confirmLabel: resolvedExisting == null ? 'Schedule' : 'Update',
    );
    if (draft == null) return;
    if (!mounted) return;

    final scheduledAt = draft.scheduledAt;
    if (scheduledAt.isBefore(DateTime.now())) {
      displayInfoBar(
        context,
        builder: (ctx, close) => InfoBar(
          title: const Text('Invalid schedule time'),
          content: const Text('Please pick a future date and time.'),
          severity: InfoBarSeverity.warning,
          action: IconButton(
            icon: const Icon(FluentIcons.clear),
            onPressed: close,
          ),
        ),
      );
      return;
    }

    final targetAppointment =
        resolvedExisting ?? Appointment.fromJson({'id': uuid()});
    targetAppointment.patientID = a.patientID;
    targetAppointment.date = scheduledAt;
    targetAppointment.checkinStage = 'scheduled';
    targetAppointment.isCheckedIn = false;
    targetAppointment.operatorsIDs = draft.doctorIds.toList(growable: false);
    targetAppointment.chiefComplaints = draft.focusNotes.toList(growable: false);
    if (draft.focusNotes.isNotEmpty) {
      targetAppointment.preOpNotes = draft.focusNotes.join(', ');
    }
    if (targetAppointment.preOpNotes.trim().isEmpty) {
      targetAppointment.preOpNotes = 'Follow-up visit';
    }
    appointments.set(targetAppointment);

    if (!mounted) return;
    setState(() {});
  }

  ButtonStyle _pillStyle(
      {required bool selected, Color accent = AppColors.brandBlue}) {
    return ButtonStyle(
      padding: WidgetStateProperty.all(
        const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      ),
      backgroundColor: WidgetStateProperty.all(
        selected ? accent.withValues(alpha: 0.12) : AppColors.slate504,
      ),
      shape: WidgetStateProperty.all(
        RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(
            color: selected ? accent : AppColors.violet1509,
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

  static pw.Widget _pdfSummaryLine(String label, String value,
      {bool bold = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 1),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label,
              style: pw.TextStyle(
                  fontSize: 9,
                  color: pdfSecondaryTextColor,
                  fontWeight:
                      bold ? pw.FontWeight.bold : pw.FontWeight.normal)),
          pw.Text(value,
              style: pw.TextStyle(
                  fontSize: bold ? 12 : 10,
                  color: pdfGreenColor,
                  fontWeight:
                      bold ? pw.FontWeight.bold : pw.FontWeight.normal)),
        ],
      ),
    );
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
        pageTheme: exportPdfPageTheme(),
        header: (context) => exportPdfHeader(
          context,
          title: 'Patient ID: ${a.patientID ?? "-"}',
          subtitle:
              'Invoice ID: VC-${DateTime.now().millisecondsSinceEpoch % 10000}',
        ),
        footer: exportPdfFooter,
        build: (context) => exportPdfBodyWithMargins([
          pw.SizedBox(height: 8),
          exportPdfBillToSection(
            patientName: a.title.trim().isEmpty ? 'Unnamed patient' : a.title,
            patientId: a.patientID ?? '-',
            phone: patient?.phone.trim().isEmpty ?? true
                ? '-'
                : patient!.phone.trim(),
            doctor: 'Dr Nowfar',
            age: '${patient?.age ?? '-'}',
            gender: patient?.gender == 1 ? 'Male' : 'Female',
          ),
          pw.SizedBox(height: 8),
          pw.TableHelper.fromTextArray(
            headerDecoration: exportPdfTableHeaderDecoration,
            headerStyle: exportPdfTableHeaderTextStyle,
            cellStyle: exportPdfTableCellTextStyle,
            headerPadding: headerPadding,
            cellPadding: cellPadding,
            cellAlignment: exportPdfTableCellAlignment,
            border: exportPdfTableBorder(),
            rowDecoration: exportPdfTableRowDecoration,
            headers: const ['Details', 'Description', 'Cost', 'Amount'],
            data: [
              [
                formatClinicDate(a.date, pattern: 'dd MMM yyyy'),
                treatmentLabel.isEmpty ? '-' : treatmentLabel,
                'Rs ${a.price.toStringAsFixed(0)}',
                'Rs ${paid.toStringAsFixed(0)}',
              ],
            ],
          ),
          pw.SizedBox(height: 10),
          if (a.preOpNotes.trim().isNotEmpty ||
              a.postOpNotes.trim().isNotEmpty) ...[
            pw.SizedBox(height: 10),
            pw.Container(
              width: double.infinity,
              padding: const pw.EdgeInsets.all(10),
              decoration: exportPdfCardDecoration(color: pdfCardGrey),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('Notes:',
                      style: pw.TextStyle(
                        fontSize: 11,
                        fontWeight: pw.FontWeight.bold,
                        color: pdfPrimaryTextColor,
                      )),
                  pw.SizedBox(height: 4),
                  if (a.preOpNotes.trim().isNotEmpty)
                    pw.Bullet(
                      text: a.preOpNotes.trim(),
                      style: const pw.TextStyle(
                          fontSize: 9, color: pdfSecondaryTextColor),
                    ),
                  if (a.postOpNotes.trim().isNotEmpty)
                    pw.Bullet(
                      text: a.postOpNotes.trim(),
                      style: const pw.TextStyle(
                          fontSize: 9, color: pdfSecondaryTextColor),
                    ),
                ],
              ),
            ),
          ],
          pw.SizedBox(height: 12),
          exportPdfDoctorSignatureSection(),
        ]),
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
          await ensureExportPdfAssetsLoaded();
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

  String _composeReceiptShareMessage() {
    final a = widget.appointment;
    final patientName =
        a.title.trim().isEmpty ? 'Patient' : _toTitleCase(a.title);
    final treatmentPaid =
        double.tryParse(widget.paidController.text.trim()) ?? a.paid;
    final paid = treatmentPaid + a.prescriptionPaid;
    final treatmentCost = a.price;
    final prescriptionCost = a.prescriptionPrice;
    final hasPrescriptionCharge = prescriptionCost > 0;
    final totalCost = treatmentCost + prescriptionCost;
    final balance = (totalCost - paid).clamp(0, double.infinity);
    final status = balance <= 0 ? 'Paid' : 'Due';
    final treatmentCompleted = a.selectedTreatments
        .where((t) => t.trim().isNotEmpty)
        .join('-+-')
        .trim();

    return 'Hello $patientName,\n\n'
        'This is a message from Dr. Nowfar Dental Clinic. We are reaching out to provide a summary of your recent visit.\n\n'
        'Treatment History Summary\n\n'
        'Last Visit: ${formatClinicDate(a.date, pattern: 'dd MMM yyyy')}\n'
        'Treatment Completed: ${treatmentCompleted.isEmpty ? '-' : treatmentCompleted}\n'
        'Treatment Cost: Rs ${treatmentCost.toStringAsFixed(0)}\n'
        '${hasPrescriptionCharge ? 'Prescription Cost: Rs ${prescriptionCost.toStringAsFixed(0)}\\n' : ''}'
        'Total Cost: Rs ${totalCost.toStringAsFixed(0)}\n'
        'Paid: Rs ${paid.toStringAsFixed(0)}\n'
        'Balance: Rs ${balance.toStringAsFixed(0)}\n'
        'Status: $status\n\n'
        'Dr. Nowfar Dental Clinic\n'
        'Address: 15, Kamaraj St, Senthamarai Nagar, Muthialpet, Puducherry, 605003, India\n'
        'Phone: +91 89035 61075\n'
        'Website: drnowfardental.in\n'
        'Google Maps: https://maps.app.goo.gl/KJNqKbk3U9VujcCKA';
  }

  Future<void> _openShareOptions() async {
    final message = _composeReceiptShareMessage();
    final patient = widget.appointment.patient;
    final email = patient?.email.trim() ?? '';
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => ContentDialog(
        title: const Text('Share Receipt'),
        content: Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            AppButton(
              label: 'WhatsApp',
              onPressed: () async {
                try {
                  await openWhatsApp(patient?.phone ?? '', message);
                } catch (_) {}
              },
            ),
            AppButton(
              label: email.isEmpty ? 'Email (No address)' : 'Email',
              variant: AppButtonVariant.secondary,
              onPressed: email.isEmpty
                  ? null
                  : () async {
                      try {
                        await sendEmail(
                          to: email,
                          subject: 'Payment Receipt',
                          body: message,
                        );
                      } catch (_) {}
                    },
            ),
          ],
        ),
        actions: [
          AppButton(
            label: 'Close',
            variant: AppButtonVariant.secondary,
            onPressed: () => Navigator.pop(dialogContext),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final a = widget.appointment;
    final discountedTotal = a.discountType == 'percent'
        ? (a.price - (a.price * a.discount / 100)).clamp(0, double.infinity)
        : (a.price - a.discount).clamp(0, double.infinity);
    final netTotal =
        (discountedTotal + a.prescriptionPrice).clamp(0, double.infinity);
    final outstanding =
        (netTotal - (a.paid + a.prescriptionPaid)).clamp(0, double.infinity);
    final status = outstanding <= 0 ? 'PAID' : 'DUE';
    final totalAfter =
        (double.tryParse(widget.paidController.text.trim()) ?? a.paid)
            .clamp(0, double.infinity)
            .toDouble();
    final visitDay = DateTime(a.date.year, a.date.month, a.date.day);
    final seenDoctorIds = appointments.present.values
        .where((row) {
          if (row.patientID != a.patientID) return false;
          final rowDay = DateTime(row.date.year, row.date.month, row.date.day);
          return rowDay == visitDay;
        })
        .expand((row) => row.operatorsIDs)
        .toSet();
    final consultantDoctors = doctors.present.values
        .where((doctor) => seenDoctorIds.contains(doctor.id))
        .toList(growable: false)
      ..sort((x, y) => x.title.toLowerCase().compareTo(y.title.toLowerCase()));
    final upcomingAppointments = appointments.present.values.where((row) {
      if (row.id == a.id) return false;
      if (row.patientID != a.patientID) return false;
      final stage = row.checkinStage.trim().toLowerCase();
      if (stage != 'scheduled' && stage != 'pending') return false;
      return row.date.isAfter(DateTime.now());
    }).toList(growable: false)
      ..sort((x, y) => x.date.compareTo(y.date));
    final nextScheduled =
        upcomingAppointments.isEmpty ? null : upcomingAppointments.first;
    final nextScheduledText = nextScheduled == null
        ? null
        : formatClinicDateTime(nextScheduled.date,
            pattern: 'dd MMM yyyy • h:mm a');

    return Padding(
      padding: const EdgeInsets.all(4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 4),
          LayoutBuilder(
            builder: (context, constraints) {
              final narrow = constraints.maxWidth < 860;

              final left = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Treatment Cost',
                    style: TextStyle(
                      color: AppColors.textBlueStrong,
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
                      _basePrice = value.trim().isEmpty
                          ? 0
                          : (double.tryParse(value) ?? 0);
                      final discount = widget.discountEnabled
                          ? (double.tryParse(
                                  widget.discountController.text.trim()) ??
                              0.0)
                          : 0.0;
                      a.discount = discount;
                      a.discountType = _discountMode;
                      a.price = _basePrice;
                      _scheduleAutosave();
                      setState(() {});
                    },
                    prefix: const Padding(
                      padding: EdgeInsets.only(left: 10),
                      child: Text(_rupeeSymbol,
                          style:
                              const TextStyle(color: AppColors.textBlueStrong)),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [100, 200, 500, 1000, 2000, 2500]
                        .map(
                          (v) => AppButton(
                            label: '₹$v',
                            compact: false,
                            variant: AppButtonVariant.secondary,
                            onPressed: () {
                              _basePrice = v.toDouble();
                              widget.priceController.text = '$v';
                              _recalculatePrice();
                            },
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
                          color: AppColors.textBlueStrong,
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
                        AppButton(
                          label: _discountMode == 'flat' ? '₹ Flat' : 'Flat',
                          compact: true,
                          variant: _discountMode == 'flat'
                              ? AppButtonVariant.primary
                              : AppButtonVariant.secondary,
                          onPressed: () {
                            setState(() => _discountMode = 'flat');
                            _recalculatePrice();
                          },
                        ),
                        AppButton(
                          label: _discountMode == 'percent'
                              ? '% Percent'
                              : 'Percent',
                          compact: true,
                          variant: _discountMode == 'percent'
                              ? AppButtonVariant.primary
                              : AppButtonVariant.secondary,
                          onPressed: () {
                            setState(() => _discountMode = 'percent');
                            _recalculatePrice();
                          },
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
                    if (_discountMode == 'percent')
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [5, 10, 20, 25, 50]
                            .map(
                              (v) => AppButton(
                                label: '$v%',
                                compact: false,
                                variant: AppButtonVariant.secondary,
                                onPressed: () {
                                  widget.discountController.text = '$v';
                                  _recalculatePrice();
                                },
                              ),
                            )
                            .toList(growable: false),
                      ),
                    if (_discountMode == 'flat')
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [100, 200, 500, 1000]
                            .map(
                              (v) => AppButton(
                                label: '₹$v',
                                compact: false,
                                variant: AppButtonVariant.secondary,
                                onPressed: () {
                                  widget.discountController.text = '$v';
                                  _recalculatePrice();
                                },
                              ),
                            )
                            .toList(growable: false),
                      ),
                  ],
                  const SizedBox(height: 14),
                  const Text(
                    'Amount Collected',
                    style: TextStyle(
                      color: AppColors.textBlueStrong,
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
                      _scheduleAutosave();
                      setState(() {});
                    },
                    prefix: const Padding(
                      padding: EdgeInsets.only(left: 10),
                      child: Text(_rupeeSymbol,
                          style:
                              const TextStyle(color: AppColors.textBlueStrong)),
                    ),
                    suffix: Padding(
                      padding: const EdgeInsets.only(right: 10),
                      child: Text(
                        '₹${outstanding.toStringAsFixed(0)}',
                        style: const TextStyle(
                          color: AppColors.textBlueMuted,
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
                      ...[100, 200, 500, 1000, 2000, 2500].map(
                        (v) => AppButton(
                          label: '₹$v',
                          compact: false,
                          variant: AppButtonVariant.secondary,
                          onPressed: () {
                            widget.paidController.text = '$v';
                            a.paid = v.toDouble();
                            _scheduleAutosave();
                            setState(() {});
                          },
                        ),
                      ),
                      AppButton(
                        label: 'Full',
                        compact: false,
                        variant: AppButtonVariant.primary,
                        onPressed: widget.onCollectFullBalance,
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'Payment Mode',
                    style: TextStyle(
                      color: AppColors.textBlueStrong,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: ['Cash', 'UPI'].map((mode) {
                      final selected = _paymentMode == mode;
                      return AppButton(
                        label: mode,
                        compact: false,
                        variant: selected
                            ? AppButtonVariant.primary
                            : AppButtonVariant.secondary,
                        onPressed: () {
                          setState(() => _paymentMode = mode);
                          final isDigital = mode == 'UPI';
                          a.treatmentGpayPaid = isDigital;
                          a.prescriptionGpayPaid = isDigital;
                          _scheduleAutosave();
                        },
                      );
                    }).toList(growable: false),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Prescription Charge',
                    style: TextStyle(
                      color: AppColors.textBlueStrong,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        flex: 5,
                        child: AppDropdownMenu<String>(
                          width: double.infinity,
                          value: _selectedPrescriptionChargeItem,
                          items: _prescriptionChargeItems
                              .map(
                                (item) => AppDropdownItem<String>(
                                  value: item,
                                  label: item,
                                ),
                              )
                              .toList(growable: false),
                          onChanged: (value) {
                            if (value.trim().isEmpty) return;
                            setState(() {
                              _selectedPrescriptionChargeItem = value;
                              final preserved = a.prescriptions
                                  .where((item) => !_prescriptionChargeItems
                                      .contains(item.trim()))
                                  .toList(growable: true);
                              if (value == 'None') {
                                _prescriptionChargeController.clear();
                                a.prescriptionPaid = 0;
                                a.prescriptionPrice = 0;
                              } else {
                                preserved.add(value);
                              }
                              a.prescriptions = preserved;
                            });
                            _scheduleAutosave();
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        flex: 5,
                        child: CupertinoTextField(
                          enabled: _selectedPrescriptionChargeItem != 'None',
                          controller: _prescriptionChargeController,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(
                                RegExp(r'[0-9.]')),
                          ],
                          prefix: const Padding(
                            padding: EdgeInsets.only(left: 10),
                            child: Text(_rupeeSymbol,
                                style: const TextStyle(
                                    color: AppColors.textBlueStrong)),
                          ),
                          placeholder: _selectedPrescriptionChargeItem == 'None'
                              ? 'Select prescription item first'
                              : 'Prescription charge',
                          onChanged: (value) {
                            final parsed = double.tryParse(value) ?? 0;
                            a.prescriptionPaid = parsed;
                            a.prescriptionPrice = parsed;
                            _scheduleAutosave();
                            setState(() {});
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Consultant Charge',
                    style: TextStyle(
                      color: AppColors.textBlueStrong,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        flex: 5,
                        child: AppDropdownMenu<String?>(
                          width: double.infinity,
                          value: consultantDoctors.any(
                                  (d) => d.id == _selectedConsultantDoctorId)
                              ? _selectedConsultantDoctorId
                              : '__none__',
                          items: [
                            const AppDropdownItem<String?>(
                              value: '__none__',
                              label: 'None',
                            ),
                            ...consultantDoctors.map(
                              (doctor) => AppDropdownItem<String?>(
                                value: doctor.id,
                                label: doctor.title.trim().isEmpty
                                    ? 'Unnamed doctor'
                                    : doctor.title,
                              ),
                            ),
                          ],
                          onChanged: (value) {
                            setState(() {
                              if (value == '__none__' || value == null) {
                                _selectedConsultantDoctorId = null;
                                a.consultantDoctorID = null;
                              } else {
                                _selectedConsultantDoctorId = value;
                                a.consultantDoctorID = value;
                              }
                            });
                            _scheduleAutosave();
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        flex: 5,
                        child: CupertinoTextField(
                          controller: _consultantChargeController,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(
                                RegExp(r'[0-9.]')),
                          ],
                          prefix: const Padding(
                            padding: EdgeInsets.only(left: 10),
                            child: Text(_rupeeSymbol,
                                style: const TextStyle(
                                    color: AppColors.textBlueStrong)),
                          ),
                          placeholder: 'Consultant charge',
                          onChanged: (value) {
                            a.priceToPayDoctor = double.tryParse(value) ?? 0;
                            _scheduleAutosave();
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              );

              final doctorNames = a.operators
                  .map((doctor) => doctor.title.trim())
                  .where((name) => name.isNotEmpty)
                  .toList(growable: false);

              final right = Padding(
                padding: const EdgeInsets.all(4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.max,
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        ExportPdfButton(
                          onPressed: _downloadReceiptPdf,
                        ),
                        Tooltip(
                          message: 'Share',
                          child: IconButton(
                            icon: const Icon(
                              FluentIcons.share,
                              size: 18,
                              color: AppColors.accentViolet,
                            ),
                            onPressed: _openShareOptions,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    _InlineNextAppointmentCard(
                      appointment: a,
                      includeCancelledSection: true,
                    ),
                    const SizedBox(height: 10),
                    _CheckoutBillingSummaryPanel(
                      appointment: a,
                      discountEnabled: widget.discountEnabled,
                      totalPaidOverride: totalAfter,
                      includeTodayInOutstanding: false,
                      doctorNames: doctorNames,
                      onDoctorEdit: () async {
                        final picked = await pickDoctorDialog(
                          context,
                          initialSelected: a.operatorsIDs,
                          title: 'Assign Doctor(s)',
                        );
                        if (picked == null || !context.mounted) return;
                        a.operatorsIDs = picked;
                        appointments.set(a);
                        setState(() {});
                      },
                      scheduledAppointments: upcomingAppointments,
                      scheduledAppointmentText: nextScheduledText,
                      scheduledAppointmentTexts: upcomingAppointments
                          .map((row) => formatClinicDateTime(row.date,
                              pattern: 'dd MMM yyyy • h:mm a'))
                          .toList(growable: false),
                      onScheduleAppointment: (a.patientID ?? '').trim().isEmpty
                          ? null
                          : _scheduleAppointmentFromBilling,
                      onEditScheduledAppointment: (row) =>
                          _scheduleAppointmentFromBilling(
                              existingScheduled: row),
                      onDeleteScheduledAppointmentForRow: (row) =>
                          _confirmDeleteScheduledFollowUpAppointment(
                        context,
                        row,
                      ),
                      onDeleteScheduledAppointment: nextScheduled == null
                          ? null
                          : () => _confirmDeleteScheduledFollowUpAppointment(
                                context,
                                nextScheduled,
                              ),
                    ),
                  ],
                ),
              );

              if (narrow) {
                return Column(
                  children: [
                    left,
                    const SizedBox(height: 12),
                    right,
                  ],
                );
              }

              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 64,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        left,
                      ],
                    ),
                  ),
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
              color: AppColors.textBlueMuted,
              fontWeight: FontWeight.w600,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: valueColor ?? AppColors.blue7006,
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
          colors: [AppColors.slate502, AppColors.violet1008],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.violet1504),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(FluentIcons.accounts, size: 13, color: AppColors.brandBlue),
              SizedBox(width: 6),
              Text(
                'Teeth Map (Enhanced)',
                style: TextStyle(
                  color: AppColors.blue7005,
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
