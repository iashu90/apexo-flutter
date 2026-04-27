// ignore_for_file: unused_element, unused_field, unused_local_variable, unused_import, dead_code

import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:apexo/common_widgets/date_navigator_bar.dart';
import 'package:apexo/common_widgets/patient_checkin_search_button.dart';
import 'package:apexo/common_widgets/patient_history_modal.dart';
import 'package:apexo/common_widgets/export_progress_dialog.dart';
import 'package:apexo/common_widgets/export_file_action_button.dart';
import 'package:apexo/common_widgets/tag_input.dart';
import 'package:apexo/common_widgets/teeth_picker.dart';
import 'package:apexo/common_widgets/patient_timeline_card.dart';
import 'package:apexo/core/theme/app_theme.dart';
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
import 'package:apexo/features/patients/open_add_patient_popup.dart';
import 'package:apexo/features/patients/patient_history_suggestions.dart';
import 'package:apexo/features/patients/patient_model.dart';
import 'package:apexo/features/patients/patients_store.dart';
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

Future<void> _showNextAppointmentPromptDialog(
  BuildContext context,
  Appointment appointment,
) async {
  final patient = appointment.patient;
  if (patient == null) return;

  DateTime nextDate = DateTime.now().add(const Duration(days: 7));
  material.TimeOfDay nextTime = material.TimeOfDay(
    hour: nextDate.hour,
    minute: nextDate.minute,
  );
  final selectedDoctors = appointment.operatorsIDs.toSet();

  await showDialog<void>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (context, setStateDialog) {
        final doctorRows = doctors.present.values.toList(growable: false)
          ..sort(
              (a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));

        return ContentDialog(
          title: const Text('Schedule Appointment'),
          content: SizedBox(
            width: 560,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Patient context moved here
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Text(
                    '${_patientDisplayName(appointment)} • ${patient.age}y • ${patient.phone.trim().isEmpty ? '-' : patient.phone}',
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 15),
                  ),
                ),
                Row(
                  children: [
                    const Text('Date:',
                        style: TextStyle(fontWeight: FontWeight.w700)),
                    const SizedBox(width: 8),
                    AppButton(
                      label: formatClinicDate(nextDate, pattern: 'dd MMM yyyy'),
                      variant: AppButtonVariant.secondary,
                      onPressed: () async {
                        final picked = await material.showDatePicker(
                          context: context,
                          initialDate: nextDate,
                          firstDate: DateTime.now(),
                          lastDate: DateTime(2100, 12, 31),
                          builder: apexoDatePickerBuilder(context),
                        );
                        if (picked == null) return;
                        setStateDialog(() {
                          nextDate = DateTime(
                            picked.year,
                            picked.month,
                            picked.day,
                            nextTime.hour,
                            nextTime.minute,
                          );
                        });
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Text('Time:',
                        style: TextStyle(fontWeight: FontWeight.w700)),
                    const SizedBox(width: 8),
                    AppButton(
                      label: nextTime.format(context),
                      variant: AppButtonVariant.secondary,
                      onPressed: () async {
                        final picked = await material.showTimePicker(
                          context: context,
                          initialTime: nextTime,
                          builder: apexoDatePickerBuilder(context),
                        );
                        if (picked == null) return;
                        setStateDialog(() {
                          nextTime = picked;
                          nextDate = DateTime(
                            nextDate.year,
                            nextDate.month,
                            nextDate.day,
                            picked.hour,
                            picked.minute,
                          );
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
                              selectedDoctors
                                  .add(doctor.id); // allow multi-select
                            }
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: selected
                                ? const Color(0xFF2D7BD8)
                                : const Color(0xFFEFF4FB),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(
                              color: selected
                                  ? const Color(0xFF2D7BD8)
                                  : const Color(0xFFD4E2F3),
                            ),
                          ),
                          child: Text(
                            doctor.title.trim().isEmpty
                                ? 'Unnamed doctor'
                                : _toTitleCase(doctor.title),
                            style: TextStyle(
                              color: selected
                                  ? Colors.white
                                  : const Color(0xFF355A84),
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
              label: 'Skip',
              variant: AppButtonVariant.secondary,
              onPressed: () => Navigator.pop(dialogContext),
            ),
            AppButton(
              label: 'Schedule',
              onPressed: () {
                final scheduledDate = DateTime(
                  nextDate.year,
                  nextDate.month,
                  nextDate.day,
                  nextTime.hour,
                  nextTime.minute,
                );
                Navigator.pop(dialogContext);
                final nextAppointment = Appointment.fromJson({
                  'patientID': patient.id,
                  'operatorsIDs': selectedDoctors.toList(growable: false),
                  'date': scheduledDate.millisecondsSinceEpoch,
                  'checkinStage': 'pending',
                });
                appointments.set(nextAppointment);
              },
            ),
          ],
        );
      },
    ),
  );
}

Future<void> _upsertScheduledFollowUpAppointment(
  BuildContext context,
  Appointment baseAppointment, {
  Appointment? existingScheduled,
}) async {
  if ((baseAppointment.patientID ?? '').trim().isEmpty) return;

  final initialDate =
      existingScheduled?.date ?? DateTime.now().add(const Duration(days: 7));
  final pickedDate = await material.showDatePicker(
    context: context,
    initialDate: initialDate,
    firstDate: DateTime.now(),
    lastDate: DateTime(2100, 12, 31),
    builder: apexoDatePickerBuilder(context),
  );
  if (pickedDate == null || !context.mounted) return;

  final pickedTime = await material.showTimePicker(
    context: context,
    initialTime: material.TimeOfDay(
      hour: existingScheduled?.date.hour ?? 10,
      minute: existingScheduled?.date.minute ?? 0,
    ),
    builder: apexoDatePickerBuilder(context),
  );
  if (pickedTime == null || !context.mounted) return;

  final scheduledAt = DateTime(
    pickedDate.year,
    pickedDate.month,
    pickedDate.day,
    pickedTime.hour,
    pickedTime.minute,
  );
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
  if (targetAppointment.operatorsIDs.isEmpty) {
    targetAppointment.operatorsIDs = [...baseAppointment.operatorsIDs];
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
  final discount = appointment.discount;
  final discountedTotal = appointment.discountType == 'percent'
      ? (appointment.price - (appointment.price * discount / 100))
          .clamp(0, double.infinity)
      : (appointment.price - discount).clamp(0, double.infinity);
  final paid = (paidOverride ?? appointment.paid).clamp(0, double.infinity);
  final balance = (discountedTotal - paid).clamp(0, double.infinity);
  final status = balance <= 0 ? 'PAID' : 'DUE';

  return [
    Text('Treatment Cost: Rs ${appointment.price.toStringAsFixed(0)}'),
    Text(
      'Discount: ${discount <= 0 ? '-' : (appointment.discountType == 'percent' ? '-${discount.toStringAsFixed(0)}%' : '-Rs ${discount.toStringAsFixed(0)}')}',
    ),
    Text('Net Total: Rs ${discountedTotal.toStringAsFixed(0)}'),
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

Future<void> openAppointmentJourneyDialog(
  BuildContext context,
  Appointment appointment, {
  int? initialStep,
}) async {
  final isDoctorLogin = permissions.currentRole == UserRole.doctor;
  final rawStartStep = initialStep?.clamp(0, 3) ??
      _stepIndexFromStageValue(appointment.checkinStage);
  final startStep = isDoctorLogin
      ? (rawStartStep == 3
          ? 2
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
        );
      }

      final previousVisits = allAppointmentsForPatient
          .where((row) => row.id != appointment.id)
          .toList(growable: false)
        ..sort((a, b) => b.date.compareTo(a.date));
      final Appointment? lastVisit =
          previousVisits.isEmpty ? null : previousVisits.first;

      return _CheckinCompletedStageScreen(
        appointment: appointment,
        lastVisit: lastVisit,
        boxed: true,
      );
    }

    if (currentStep == 0) {
      return _PatientHistoryStepScreen(
        appointment: appointment,
        allAppointmentsForPatient: allAppointmentsForPatient,
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
            'Completed',
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
      if (isDoctorLogin) {
        if (nextStep == 2) {
          appointment.checkinStage = 'completed';
          appointment.isDone = true;
        }
        appointments.set(appointment);
        return;
      }

      if (nextStep == 2) {
        appointment.checkinStage = 'checkout';
        appointment.isDone = false;
      } else if (nextStep == 3) {
        appointment.checkinStage = 'completed';
        appointment.isDone = true;
      }
      appointments.set(appointment);
    },
  );
}

class _PatientHistoryStepScreen extends StatefulWidget {
  final Appointment appointment;
  final List<Appointment> allAppointmentsForPatient;

  const _PatientHistoryStepScreen({
    required this.appointment,
    required this.allAppointmentsForPatient,
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
  }

  void _updatePatient(void Function(Patient patient) updater) {
    final patient = widget.appointment.patient;
    if (patient == null) return;
    updater(patient);
    patients.set(patient);
  }

  void _toggleItem(Set<String> selected, String value, void Function() onSave) {
    setState(() {
      if (selected.contains(value)) {
        selected.remove(value);
      } else {
        selected.add(value);
      }
    });
    onSave();
  }

  Widget _popupFieldLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: Color(0xFF1F446E),
        ),
      ),
    );
  }

  Widget _buildSelectableHistoryChips({
    required List<String> options,
    required Set<String> selected,
    required void Function(String value) onToggle,
  }) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: options.map((item) {
        final isSelected = selected.contains(item);
        return GestureDetector(
          onTap: () => onToggle(item),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: isSelected
                  ? const Color(0xFF2D7BD8)
                  : const Color(0xFFEFF4FB),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: isSelected
                    ? const Color(0xFF2D7BD8)
                    : const Color(0xFFD4E2F3),
              ),
            ),
            child: Text(
              item,
              style: TextStyle(
                color: isSelected ? Colors.white : const Color(0xFF345982),
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        );
      }).toList(growable: false),
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
            color: header ? const Color(0xFF4E6789) : const Color(0xFF25466F),
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
              color: const Color(0xFFF8FBFF),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFDCE8F8)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _popupFieldLabel('Medical History:'),
                _buildSelectableHistoryChips(
                  options: patientMedicalHistorySuggestions,
                  selected: _selectedMedicalHistory,
                  onToggle: (value) => _toggleItem(
                    _selectedMedicalHistory,
                    value,
                    () => _updatePatient(
                      (patient) => patient.tags =
                          _selectedMedicalHistory.toList(growable: false),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                _popupFieldLabel('Drug History:'),
                _buildSelectableHistoryChips(
                  options: patientDrugHistorySuggestions,
                  selected: _selectedDrugHistory,
                  onToggle: (value) => _toggleItem(
                    _selectedDrugHistory,
                    value,
                    () => _updatePatient(
                      (patient) => patient.drugHistorySuggestions =
                          _selectedDrugHistory.toList(growable: false),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                _popupFieldLabel('Maternal History:'),
                _buildSelectableHistoryChips(
                  options: patientMaternalHistorySuggestions,
                  selected: _selectedMaternalHistory,
                  onToggle: (value) => _toggleItem(
                    _selectedMaternalHistory,
                    value,
                    () => _updatePatient(
                      (patient) => patient.maternalHistorySuggestions =
                          _selectedMaternalHistory.toList(growable: false),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                _popupFieldLabel('Habits:'),
                _buildSelectableHistoryChips(
                  options: patientHabitsSuggestions,
                  selected: _selectedHabits,
                  onToggle: (value) => _toggleItem(
                    _selectedHabits,
                    value,
                    () => _updatePatient(
                      (patient) => patient.habitsSuggestions =
                          _selectedHabits.toList(growable: false),
                    ),
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
              color: const Color(0xFFF8FBFF),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFDCE8F8)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Last Treatments',
                  style: TextStyle(
                    color: Color(0xFF2D476D),
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 8),
                if (visibleRows.isEmpty)
                  const Text(
                    'No previous treatments found.',
                    style: TextStyle(
                      color: Color(0xFF5A7397),
                      fontWeight: FontWeight.w600,
                    ),
                  )
                else
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: SizedBox(
                      width: 900,
                      child: Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEFF5FF),
                              border:
                                  Border.all(color: const Color(0xFFD7E5F7)),
                            ),
                            child: Row(
                              children: [
                                _historyCell('Date', flex: 2, header: true),
                                _historyCell('Treatment',
                                    flex: 3, header: true),
                                _historyCell('Teeth', flex: 2, header: true),
                                _historyCell('Diagnosis',
                                    flex: 3, header: true),
                                _historyCell('Chief Complaint',
                                    flex: 3, header: true),
                                _historyCell('Doctor', flex: 2, header: true),
                              ],
                            ),
                          ),
                          const SizedBox(height: 6),
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
                              margin: const EdgeInsets.only(bottom: 6),
                              padding: const EdgeInsets.symmetric(vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                border:
                                    Border.all(color: const Color(0xFFDCE8F8)),
                              ),
                              child: Row(
                                children: [
                                  _historyCell(
                                    formatClinicDate(row.date,
                                        pattern: 'dd MMM yyyy'),
                                    flex: 2,
                                  ),
                                  _historyCell(
                                      treatmentText.isEmpty
                                          ? '-'
                                          : treatmentText,
                                      flex: 3),
                                  _historyCell(
                                      teethText.isEmpty ? '-' : teethText,
                                      flex: 2),
                                  _historyCell(
                                      diagnosisText.isEmpty
                                          ? '-'
                                          : diagnosisText,
                                      flex: 3),
                                  _historyCell(
                                      complaintText.isEmpty
                                          ? '-'
                                          : complaintText,
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
                    ),
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
  final Map<String, bool> _expandedStages = {
    'waiting': true,
    'with_doctor': true,
    'billing_completed': true,
  };

  @override
  void initState() {
    super.initState();
    _waitingTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (!mounted) return;
      setState(() {});
    });
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

  Appointment _checkInPatient(Patient patient) {
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
    if (!mounted) return;
    await _openAppointmentPopup(appointment);
  }

  Future<void> _openNextCheckinStepper(Appointment appointment) async {
    await openAppointmentJourneyDialog(context, appointment);
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

            final isDoctorLogin = permissions.currentRole == UserRole.doctor;

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
            final billingAndCompleted = filtered
                .where(
                  (a) =>
                      a.checkinStage == 'checkout' ||
                      a.checkinStage == 'billing' ||
                      a.checkinStage == 'completed' ||
                      a.isDone,
                )
                .toList(growable: true)
              ..sort((a, b) {
                final aCompleted =
                    a.checkinStage == 'completed' || a.isDone ? 1 : 0;
                final bCompleted =
                    b.checkinStage == 'completed' || b.isDone ? 1 : 0;
                if (aCompleted != bCompleted) return aCompleted - bCompleted;
                return a.date.compareTo(b.date);
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
                              const Text(
                                'Check-in',
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF183A67),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 5,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFEAF2FC),
                                  borderRadius: BorderRadius.circular(999),
                                  border: Border.all(
                                      color: const Color(0xFFD5E5F7)),
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
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(
                                child: AppButton(
                                  variant: AppButtonVariant.secondary,
                                  onPressed: _openNewPatientAndCheckin,
                                  label: 'New Patient',
                                  leading: const Icon(FluentIcons.add_friend,
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
                              const Text(
                                'Check-in',
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
                                  border: Border.all(
                                      color: const Color(0xFFD5E5F7)),
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
                            label: 'New Patient',
                            leading:
                                const Icon(FluentIcons.add_friend, size: 12),
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
                              () =>
                                  _selectedDoctor = isSelected ? '__all__' : id,
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
                          color: const Color(0xFFE4A11B),
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
                          color: const Color(0xFF4E79AF),
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
                          color: const Color(0xFFC2415B),
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
                          color: const Color(0xFF2D7BD8),
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
                          title:
                              'Billing & Completed (${billingAndCompleted.length})',
                          stage: 'billing_completed',
                          color: const Color(0xFF6C4CCF),
                          rows: billingAndCompleted,
                          duplicatePatientIds: duplicatePatientIds,
                          rowStageBuilder: _billingCombinedRowStage,
                          onSelect: _selectAndOpenAppointment,
                          selectedAppointmentId: _selectedAppointment?.id,
                          interactionsEnabled: !isDoctorLogin,
                          expanded:
                              _expandedStages['billing_completed'] ?? true,
                          onToggleExpanded: () => setState(() {
                            _expandedStages['billing_completed'] =
                                !(_expandedStages['billing_completed'] ?? true);
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
                            Expanded(child: billingColumn),
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
                                  color: Color(0xFF355279),
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 10),
                              if (selectedRows.isNotEmpty) ...[
                                const Text(
                                  'Selected Doctors',
                                  style: TextStyle(
                                    color: Color(0xFF15803D),
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
                                          color: const Color(0xFFDFF7E8),
                                          borderRadius:
                                              BorderRadius.circular(999),
                                          border: Border.all(
                                            color: const Color(0xFF22C55E),
                                          ),
                                        ),
                                        child: Text(
                                          doctorName,
                                          style: const TextStyle(
                                            color: Color(0xFF166534),
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
                                  color: Color(0xFF355A84),
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
                                        color: const Color(0xFFEFF4FB),
                                        borderRadius:
                                            BorderRadius.circular(999),
                                        border: Border.all(
                                          color: const Color(0xFFD2E1F2),
                                        ),
                                      ),
                                      child: Text(
                                        doctorName,
                                        style: const TextStyle(
                                          color: Color(0xFF355A84),
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
                      color: Color(0xFFC63A4D),
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
                          color: Color(0xFF183A67),
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
                              color: Color(0xFF6D84A8),
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
                              color: Color(0xFF1459AD),
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
          border: Border(top: BorderSide(color: Color(0xFFE2ECF8))),
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
          border: Border(top: BorderSide(color: Color(0xFFE2ECF8))),
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
          border: Border(top: BorderSide(color: Color(0xFFE2ECF8))),
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
                    return Text('₹${paid.toStringAsFixed(0)}');
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
          border: Border(top: BorderSide(color: Color(0xFFE2ECF8))),
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
          color: const Color(0xFFF8FBFF),
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Text(
          'No previous appointment history available.',
          style: TextStyle(
            color: Color(0xFF5B7394),
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
        color: const Color(0xFFF8FBFF),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Last Appointment',
            style: TextStyle(
              color: Color(0xFF223B5E),
              fontWeight: FontWeight.w800,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            formatClinicDateTime(last.date, pattern: 'dd MMM yyyy • h:mm a'),
            style: const TextStyle(
              color: Color(0xFF355279),
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Diagnosis: ${diagnosis.isEmpty ? '-' : diagnosis}',
            style: const TextStyle(
              color: Color(0xFF5B7394),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Chief Complaints: ${chiefComplaints.isEmpty ? '-' : chiefComplaints}',
            style: const TextStyle(
              color: Color(0xFF5B7394),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Treatment: ${treatmentSummary.isEmpty ? '-' : treatmentSummary}',
            style: const TextStyle(
              color: Color(0xFF5B7394),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Doctor: $doctorSummary',
            style: const TextStyle(
              color: Color(0xFF5B7394),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Teeth: ${teethSummary.isEmpty ? '-' : teethSummary}',
            style: const TextStyle(
              color: Color(0xFF5B7394),
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
        color: const Color(0xFFF8FBFF),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Today Appointment',
            style: TextStyle(
              color: Color(0xFF223B5E),
              fontWeight: FontWeight.w800,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            formatClinicDateTime(appointment.date,
                pattern: 'dd MMM yyyy • h:mm a'),
            style: const TextStyle(
              color: Color(0xFF355279),
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Diagnosis: ${diagnosis.isEmpty ? '-' : diagnosis}',
            style: const TextStyle(
              color: Color(0xFF5B7394),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Chief Complaints: ${chiefComplaints.isEmpty ? '-' : chiefComplaints}',
            style: const TextStyle(
              color: Color(0xFF5B7394),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Treatment: ${treatments.isEmpty ? '-' : treatments}',
            style: const TextStyle(
              color: Color(0xFF5B7394),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Doctor: $doctorSummary',
            style: const TextStyle(
              color: Color(0xFF5B7394),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Teeth: ${teethSummary.isEmpty ? '-' : teethSummary}',
            style: const TextStyle(
              color: Color(0xFF5B7394),
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
        color: const Color(0xFFF8FBFF),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Patient Timeline',
            style: TextStyle(
              color: Color(0xFF223B5E),
              fontWeight: FontWeight.w800,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 8),
          if (visibleRows.isEmpty)
            const Text(
              'No timeline entries available.',
              style: TextStyle(
                color: Color(0xFF5B7394),
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

class _CheckinOperativeForm extends StatefulWidget {
  final Appointment appointment;
  final List<Appointment> allAppointmentsForPatient;
  final bool showInlineBottomActions;
  final String? forcedStage;

  const _CheckinOperativeForm({
    required this.appointment,
    required this.allAppointmentsForPatient,
    this.showInlineBottomActions = false,
    this.forcedStage,
  });

  @override
  State<_CheckinOperativeForm> createState() => _CheckinOperativeFormState();
}

class _CheckinOperativeFormState extends State<_CheckinOperativeForm> {
  Timer? _autosaveDebounce;
  late final TextEditingController _postOpController;
  late final TextEditingController _priceController;
  late final TextEditingController _paidController;
  late final TextEditingController _discountController;
  bool _hasPendingAutosave = false;
  bool _discountEnabled = false;
  Set<String> _selectedTreatments = {};
  Set<String> _selectedConsultationTypes = {};
  Set<String> _selectedChiefComplaints = {};
  String _visitType = 'Consultation Only';
  String? _selectedPostOpParent;
  Set<String> _selectedTeeth = {};
  Map<String, ToothState> _teethStates = {};

  static const List<String> _consultationSubTypes = [
    'General',
    'RCT',
    'Extraction',
    'Ortho',
    'Pulpectomy',
    'Food Lodgment',
    'Sinusits',
    'Gum Disease',
    'Implant',
    'TMJ',
    'Crown & Bridge',
    'Clear Aligner',
    'Denture Evaluation',
    'Others',
  ];

  static const List<String> _rctSubTypes = [
    'AO & BMP',
    'Obturation',
    'PCS',
  ];

  static const List<String> _visitTypes = [
    'Consultation Only',
    'New Problem / New Treatment',
    'Follow-up Visit',
  ];

  static const List<String> _chiefComplaintSuggestions = [
    'Toothache',
    'Sensitivity',
    'Swelling',
    'Bleeding',
    'Cavity',
    'Abscess',
    'Gingivitis',
    'Halitosis',
    'Malocclusion',
    'Impacted',
    'Discoloration',
    'Xerostomia',
    'Bruxism',
    'Orthodontics',
    'Prophylaxis',
    'Extraction',
    'Restoration',
    'Trauma',
    'Periodontitis',
    'Pulpitis',
  ];

  static const Map<String, List<String>> _postOpSuggestions = {
    'Post Tooth Extraction': [
      'Bite on the gauze for 30-45 minutes.',
      'Do not spit, rinse, or use a straw for 24 hours.',
      'Eat soft foods and drink cool liquids.',
      'Avoid hot food, smoking, and alcohol.',
      'Take medicines as prescribed.',
      'Apply ice pack outside cheek for swelling (10 minutes on, 10 minutes off).',
      'Rest today and avoid heavy work.',
      'Brush gently, avoid extraction area.',
    ],
    'Bleeding Control': [
      'Bite on gauze for 30-45 mins',
      'Minor oozing is normal for 24h',
      'Do not spit',
      'Apply tea bag if bleeding persists',
    ],
    'Pain Management': [
      'Take first dose before numbness wears off',
      'Ibuprofen 400-600mg every 6h',
      'Alternate Tylenol/Advil',
      'Avoid Aspirin',
    ],
    'Swelling & Inflammation': [
      'Ice pack: 20 mins on / 20 mins off',
      'Keep head elevated while sleeping',
      'Swelling peaks at 48-72 hours',
      'Warm compress after 48 hours',
    ],
    'Activity Restrictions': [
      'Rest for the remainder of the day',
      'No heavy lifting/exercise for 48h',
      'Avoid bending over',
    ],
    'Diet & Nutrition': [
      'Soft foods only (Yogurt, Soup, Mashed Potatoes)',
      'Cold/Room temp foods only for 24h',
      'Chew on the opposite side',
      'High protein/Hydrate well',
    ],
    'Oral Hygiene': [
      'No rinsing for the first 24h',
      'Gentle warm salt water rinse (Day 2)',
      'Brush other teeth carefully',
      'Do not disturb the surgical site',
    ],
    'Habits to Avoid': [
      'No Straws',
      'No Smoking for 72h',
      'No Alcohol',
      'No Vaping',
    ],
    'Suture (Stitch) Care': [
      'Dissolvable: will fall out in 5-10 days',
      'Non-dissolvable: return in 1 week for removal',
      'Do not pull on loose ends',
    ],
    'Medicated Rinses/Antibiotics': [
      'Chlorhexidine rinse 2x daily',
      'Finish the full course of antibiotics',
      'Apply prescribed topical gel with Q-tip',
    ],
    'Warning Signs': [
      'Uncontrolled bleeding',
      'Severe pain not relieved by meds',
      'Fever or chills',
      'Persistent numbness after 6 hours',
    ],
  };

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
    _discountEnabled = a.discount > 0;
    _selectedTreatments = a.selectedTreatments.toSet();
    _selectedChiefComplaints = a.chiefComplaints.toSet();
    _selectedConsultationTypes =
        a.subTreatments.where((e) => e.trim().isNotEmpty).toSet();
    if (_selectedConsultationTypes.contains('Access opening') ||
        _selectedConsultationTypes.contains('BMP')) {
      _selectedConsultationTypes
        ..remove('Access opening')
        ..remove('BMP')
        ..add('AO & BMP');
      a.subTreatments = _selectedConsultationTypes.toList(growable: false);
    }
    _visitType =
        _visitTypes.contains(a.visitType) ? a.visitType : 'Follow-up Visit';
    _selectedTeeth = a.selectedTeeth.toSet();
    _teethStates = {
      for (final id in _allToothIds) id: ToothState(toothId: id),
    };
    for (final id in _selectedTeeth) {
      if (!_teethStates.containsKey(id)) {
        _teethStates[id] = ToothState(toothId: id);
      }
      _teethStates[id]!.surfaces[ToothSurface.occlusal] = TreatmentType.filling;
    }
  }

  bool _hasConsultationSelected() {
    return _selectedTreatments
        .any((t) => t.trim().toLowerCase() == 'consultation');
  }

  bool _hasRctSelected() {
    return _selectedTreatments.any((t) => t.trim().toLowerCase() == 'rct');
  }

  void _scheduleAutosave({bool immediate = false}) {
    final appointment = widget.appointment;
    if (immediate) {
      _autosaveDebounce?.cancel();
      _autosaveDebounce = null;
      _hasPendingAutosave = false;
      appointments.set(appointment);
      return;
    }

    _hasPendingAutosave = true;
    _autosaveDebounce?.cancel();
    _autosaveDebounce = Timer(const Duration(milliseconds: 900), () {
      _hasPendingAutosave = false;
      appointments.set(appointment);
    });
  }

  @override
  void dispose() {
    _autosaveDebounce?.cancel();
    if (_hasPendingAutosave) {
      appointments.set(widget.appointment);
    }
    _postOpController.dispose();
    _priceController.dispose();
    _paidController.dispose();
    _discountController.dispose();
    super.dispose();
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

  Future<void> _confirmDoneToggle() async {
    final a = widget.appointment;
    if (a.isDone) {
      a.checkinStage = 'checkout';
      setState(() => a.isDone = false);
      _scheduleAutosave(immediate: true);
      return;
    }

    final shouldComplete = await _confirmMoveToCompleted(
      context,
      a,
      paidOverride: a.paid,
    );

    if (!shouldComplete) return;
    a.checkinStage = 'completed';
    setState(() => a.isDone = true);
    _scheduleAutosave(immediate: true);
    await _openNextAppointmentPrompt(a);
  }

  Future<void> _openNextAppointmentPrompt(Appointment appointment) async {
    await _showNextAppointmentPromptDialog(context, appointment);
  }

  Future<void> _moveBackToWaiting() async {
    final patientName = _patientDisplayName(widget.appointment);
    final shouldMove = await showDialog<bool>(
      context: context,
      builder: (context) => ContentDialog(
        title: Text('Move "$patientName" back to Waiting?'),
        content: Text(
          '$patientName will be moved back to Waiting and doctor assignment will be removed.',
        ),
        actions: [
          AppButton(
            label: 'Cancel',
            variant: AppButtonVariant.secondary,
            onPressed: () => Navigator.pop(context, false),
          ),
          AppButton(
            label: 'Move to Waiting',
            variant: AppButtonVariant.danger,
            onPressed: () => Navigator.pop(context, true),
          ),
        ],
      ),
    );
    if (shouldMove != true) return;
    final a = widget.appointment;
    a.operatorsIDs = [];
    a.checkinStage = 'waiting';
    a.isDone = false;
    _scheduleAutosave(immediate: true);
  }

  Future<void> _moveBackToWithDoctor() async {
    final patientName = _patientDisplayName(widget.appointment);
    final shouldMove = await showDialog<bool>(
      context: context,
      builder: (context) => ContentDialog(
        title: Text('Move "$patientName" back to Treatment?'),
        content: Text(
            'This patient will be moved back to Treatment stage for $patientName.'),
        actions: [
          AppButton(
            label: 'Cancel',
            variant: AppButtonVariant.secondary,
            onPressed: () => Navigator.pop(context, false),
          ),
          AppButton(
            label: 'Move to Treatment',
            variant: AppButtonVariant.danger,
            onPressed: () => Navigator.pop(context, true),
          ),
        ],
      ),
    );
    if (shouldMove != true) return;
    final a = widget.appointment;
    a.checkinStage = 'with_doctor';
    a.isDone = false;
    _scheduleAutosave(immediate: true);
  }

  @override
  Widget build(BuildContext context) {
    final a = widget.appointment;
    final effectiveStage = widget.forcedStage ?? a.checkinStage;
    final isWithDoctor = effectiveStage == 'with_doctor';
    final isCheckout = effectiveStage == 'checkout';

    if (isCheckout) {
      return _CheckoutPaymentCard(
        appointment: a,
        priceController: _priceController,
        paidController: _paidController,
        discountController: _discountController,
        discountEnabled: _discountEnabled,
        onToggleDiscount: (value) => setState(() => _discountEnabled = value),
        onCollectFullBalance: () {
          final discount = a.discount;
          final discountedTotal = (a.discountType == 'percent'
                  ? (a.price - (a.price * discount / 100))
                      .clamp(0, double.infinity)
                  : (a.price - discount).clamp(0, double.infinity))
              .toDouble();
          _paidController.text = discountedTotal.toStringAsFixed(0);
          a.paid = discountedTotal;
          appointments.set(a);
          setState(() {});
        },
      );
    }

    final topTreatments = _topTreatmentsForPatient();
    final globalTopTreatments = _topTreatmentsAcrossClinic();
    final mergedTopTreatments = <String>{
      ...topTreatments,
      ...globalTopTreatments,
    }.take(10).toList(growable: false);

    const sectionTitleStyle = TextStyle(
      color: Color(0xFF2C4E76),
      fontWeight: FontWeight.w800,
      fontSize: 15,
    );

    return SizedBox(
      width: double.infinity,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isWithDoctor)
            const Text(
              'Treatment',
              style: TextStyle(
                color: Color(0xFF2C4E76),
                fontWeight: FontWeight.w800,
                fontSize: 18,
              ),
            ),
          if (isWithDoctor) const SizedBox(height: 14),
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              _medicalHistorySummaryText(a.patient),
              style: const TextStyle(
                color: Color(0xFFC63A4D),
                fontWeight: FontWeight.w700,
                fontSize: 14,
              ),
            ),
          ),
          if (isWithDoctor)
            LayoutBuilder(
              builder: (context, constraints) {
                final firstColumn = Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Visit Type', style: sectionTitleStyle),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: _visitTypes.map((type) {
                        final selected = _visitType == type;
                        final icon = type == 'Follow-up Visit'
                            ? FluentIcons.calendar
                            : type == 'New Problem / New Treatment'
                                ? FluentIcons.health
                                : FluentIcons.chat;
                        final note = type == 'Follow-up Visit'
                            ? 'Patient is returning for a review'
                            : type == 'New Problem / New Treatment'
                                ? 'New concern or additional treatment'
                                : 'Advice or opinion only';

                        return GestureDetector(
                          onTap: () {
                            setState(() {
                              _visitType = type;
                              a.visitType = type;
                              _scheduleAutosave();
                            });
                          },
                          child: Container(
                            width: 250,
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: selected
                                  ? const Color(0xFFEAF6FF)
                                  : const Color(0xFFF4F6FA),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: selected
                                    ? const Color(0xFF4DB6C6)
                                    : const Color(0xFFDDE5F0),
                              ),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  width: 28,
                                  height: 28,
                                  decoration: BoxDecoration(
                                    color: selected
                                        ? const Color(0xFFBEE9EF)
                                        : const Color(0xFFE9EDF5),
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  alignment: Alignment.center,
                                  child: Icon(icon,
                                      size: 12, color: const Color(0xFF2E5C85)),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        type,
                                        style: const TextStyle(
                                          color: Color(0xFF254870),
                                          fontWeight: FontWeight.w700,
                                          fontSize: 12,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        note,
                                        style: const TextStyle(
                                          color: Color(0xFF5B7394),
                                          fontWeight: FontWeight.w600,
                                          fontSize: 11,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }).toList(growable: false),
                    ),
                    const SizedBox(height: 12),
                    const Text('Chief Complaint', style: sectionTitleStyle),
                    const SizedBox(height: 6),
                    _CheckinSearchableTagInput(
                      initialValues:
                          _selectedChiefComplaints.toList(growable: false),
                      suggestions: _chiefComplaintSuggestions,
                      placeholder: 'Add chief complaint...',
                      onChanged: (values) {
                        setState(() {
                          _selectedChiefComplaints = values.toSet();
                          a.chiefComplaints = values;
                          _scheduleAutosave();
                        });
                      },
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: _chiefComplaintSuggestions
                          .map(
                            (complaint) => _quickChip(
                              label: complaint,
                              selected:
                                  _selectedChiefComplaints.contains(complaint),
                              onTap: () {
                                setState(() {
                                  if (_selectedChiefComplaints
                                      .contains(complaint)) {
                                    _selectedChiefComplaints.remove(complaint);
                                  } else {
                                    _selectedChiefComplaints.add(complaint);
                                  }
                                  a.chiefComplaints = _selectedChiefComplaints
                                      .toList(growable: false);
                                  _scheduleAutosave();
                                });
                              },
                            ),
                          )
                          .toList(growable: false),
                    ),
                    const SizedBox(height: 12),
                    InfoLabel(
                      label: 'Teeth:',
                      child: TeethPicker(
                        selectedTeeth: _selectedTeeth,
                        isAdult: (a.patient?.age ?? 0) >= 13,
                        onChanged: (teeth) {
                          setState(() {
                            _selectedTeeth = teeth;
                            for (final id in teeth) {
                              _teethStates.putIfAbsent(
                                id,
                                () => ToothState(toothId: id),
                              );
                            }
                            a.selectedTeeth = teeth.toList(growable: false);
                            _scheduleAutosave();
                          });
                        },
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Text('Diagnosis', style: sectionTitleStyle),
                    const SizedBox(height: 6),
                    _CheckinSearchableTagInput(
                      initialValues: a.diagnosis,
                      suggestions: allDiagnosis,
                      placeholder: 'Add diagnosis...',
                      onChanged: (values) {
                        setState(() {
                          a.diagnosis = values;
                          _scheduleAutosave();
                        });
                      },
                    ),
                    const SizedBox(height: 10),
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
                                  final updated =
                                      a.diagnosis.toList(growable: true);
                                  if (updated.contains(diagnosis)) {
                                    updated.remove(diagnosis);
                                  } else {
                                    updated.add(diagnosis);
                                  }
                                  a.diagnosis = updated;
                                  _scheduleAutosave();
                                });
                              },
                            ),
                          )
                          .toList(growable: false),
                    ),
                    const SizedBox(height: 16),
                    const Text('Treatment', style: sectionTitleStyle),
                    const SizedBox(height: 6),
                    _CheckinSearchableTagInput(
                      initialValues:
                          _selectedTreatments.toList(growable: false),
                      suggestions: allTreatments
                          .map((t) => t.name)
                          .toList(growable: false),
                      placeholder: 'Add treatment...',
                      onChanged: (values) {
                        _selectedTreatments = values.toSet();
                        a.selectedTreatments = values;
                        if (!_hasConsultationSelected() && !_hasRctSelected()) {
                          _selectedConsultationTypes.clear();
                          a.subTreatments = [];
                        } else {
                          a.subTreatments = _selectedConsultationTypes.toList(
                              growable: false);
                        }
                        _scheduleAutosave();
                        setState(() {});
                      },
                    ),
                    if (mergedTopTreatments.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Text(
                        topTreatments.isNotEmpty
                            ? 'Top 10 treatments (includes patient history):'
                            : 'Top 10 provided treatments:',
                        style: const TextStyle(
                          color: Color(0xFF5A7397),
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: mergedTopTreatments
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
                                    a.selectedTreatments = _selectedTreatments
                                        .toList(growable: false);
                                    if (!_hasConsultationSelected() &&
                                        !_hasRctSelected()) {
                                      _selectedConsultationTypes.clear();
                                      a.subTreatments = [];
                                    } else {
                                      a.subTreatments =
                                          _selectedConsultationTypes.toList(
                                        growable: false,
                                      );
                                    }
                                    _scheduleAutosave();
                                  });
                                },
                              ),
                            )
                            .toList(growable: false),
                      ),
                    ],
                    if (_hasConsultationSelected()) ...[
                      const SizedBox(height: 10),
                      const Text(
                        'Consultation Type Suggestions:',
                        style: TextStyle(
                          color: Color(0xFF5A7397),
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: _consultationSubTypes
                            .map(
                              (type) => _hierarchyChip(
                                label: type,
                                selected:
                                    _selectedConsultationTypes.contains(type),
                                onTap: () {
                                  setState(() {
                                    if (_selectedConsultationTypes
                                        .contains(type)) {
                                      _selectedConsultationTypes.remove(type);
                                    } else {
                                      _selectedConsultationTypes.add(type);
                                    }
                                    a.subTreatments =
                                        _selectedConsultationTypes.toList(
                                      growable: false,
                                    );
                                    _scheduleAutosave();
                                  });
                                },
                              ),
                            )
                            .toList(growable: false),
                      ),
                    ],
                    if (_hasRctSelected()) ...[
                      const SizedBox(height: 10),
                      const Text(
                        'RCT Stage Selection:',
                        style: TextStyle(
                          color: Color(0xFF5A7397),
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: _rctSubTypes
                            .map(
                              (type) => _hierarchyChip(
                                label: type,
                                selected:
                                    _selectedConsultationTypes.contains(type),
                                onTap: () {
                                  setState(() {
                                    if (_selectedConsultationTypes
                                        .contains(type)) {
                                      _selectedConsultationTypes.remove(type);
                                    } else {
                                      _selectedConsultationTypes.add(type);
                                    }
                                    a.subTreatments =
                                        _selectedConsultationTypes.toList(
                                      growable: false,
                                    );
                                    _scheduleAutosave();
                                  });
                                },
                              ),
                            )
                            .toList(growable: false),
                      ),
                    ],
                    const SizedBox(height: 10),
                    const Text('Treatment Price', style: sectionTitleStyle),
                    const SizedBox(height: 6),
                    CupertinoTextField(
                      controller: _priceController,
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                      ],
                      prefix: const Padding(
                        padding: EdgeInsets.only(left: 10),
                        child: Text('₹',
                            style: TextStyle(color: Color(0xFF355279))),
                      ),
                      placeholder: 'Treatment price',
                      onChanged: (value) {
                        a.price = double.tryParse(value) ?? 0;
                        _scheduleAutosave();
                      },
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
                                _priceController.text = '$v';
                                a.price = v.toDouble();
                                _scheduleAutosave();
                                setState(() {});
                              },
                            ),
                          )
                          .toList(growable: false),
                    ),
                  ],
                );

                final secondColumn = Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Post-operative Notes',
                        style: sectionTitleStyle),
                    const SizedBox(height: 6),
                    CupertinoTextField(
                      controller: _postOpController,
                      minLines: 4,
                      maxLines: 8,
                      onChanged: (value) {
                        a.postOpNotes = value;
                        _scheduleAutosave();
                      },
                      placeholder: 'Post-operative notes',
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: _postOpSuggestions.keys
                          .map(
                            (parent) => AppButton(
                              label: parent,
                              compact: false,
                              variant: _selectedPostOpParent == parent
                                  ? AppButtonVariant.primary
                                  : AppButtonVariant.secondary,
                              onPressed: () {
                                setState(() => _selectedPostOpParent = parent);
                              },
                            ),
                          )
                          .toList(growable: false),
                    ),
                    if (_selectedPostOpParent != null &&
                        _postOpSuggestions[_selectedPostOpParent!] != null) ...[
                      const SizedBox(height: 14),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _postOpSuggestions[_selectedPostOpParent!]!
                            .map(
                              (child) => _hierarchyChip(
                                label: child,
                                selected: false,
                                onTap: () {
                                  final parent = _selectedPostOpParent;
                                  if (parent == null) return;
                                  final parentLine = '- $parent';
                                  final childLine = '  - $child';
                                  final current = _postOpController.text.trim();
                                  if (current.contains(
                                          '$parentLine\n$childLine') ||
                                      current.contains('\n$childLine')) {
                                    return;
                                  }
                                  _postOpController.text = current
                                          .contains(parentLine)
                                      ? '$current\n$childLine'
                                      : (current.isEmpty
                                          ? '$parentLine\n$childLine'
                                          : '$current\n$parentLine\n$childLine');
                                  setState(() {});
                                  a.postOpNotes = _postOpController.text;
                                  _scheduleAutosave();
                                },
                              ),
                            )
                            .toList(growable: false),
                      ),
                    ],
                    if (widget.showInlineBottomActions) ...[
                      const SizedBox(height: 18),
                      Row(
                        children: [
                          Expanded(
                            child: AppButton(
                              label: 'Proceed to Billing',
                              onPressed: () async {
                                final navigator = Navigator.of(context);
                                final patientName = _patientDisplayName(a);
                                final confirmed = await showDialog<bool>(
                                  context: context,
                                  builder: (dialogContext) => ContentDialog(
                                    title: Text(
                                      'Move "$patientName" to Billing?',
                                    ),
                                    content: Text(
                                      'This appointment will be moved to Billing stage for $patientName.',
                                    ),
                                    actions: [
                                      AppButton(
                                        label: 'Cancel',
                                        variant: AppButtonVariant.secondary,
                                        onPressed: () =>
                                            Navigator.pop(dialogContext, false),
                                      ),
                                      AppButton(
                                        label: 'Proceed',
                                        onPressed: () =>
                                            Navigator.pop(dialogContext, true),
                                      ),
                                    ],
                                  ),
                                );
                                if (confirmed != true) return;
                                a.checkinStage = 'checkout';
                                a.isDone = false;
                                _scheduleAutosave(immediate: true);
                                if (!mounted) return;
                                navigator.maybePop();
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: AppButton(
                              label: 'Move Back to Waiting',
                              variant: AppButtonVariant.danger,
                              onPressed: _moveBackToWaiting,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                );

                final scheduler = _InlineNextAppointmentCard(
                  appointment: a,
                  includeCancelledSection: true,
                );
                final todaySummary = _buildTodaySummaryCard(a);

                if (constraints.maxWidth >= 1180) {
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(flex: 42, child: firstColumn),
                      const SizedBox(width: 12),
                      Expanded(flex: 42, child: secondColumn),
                      const SizedBox(width: 12),
                      SizedBox(
                        width: 260,
                        child: Column(
                          children: [
                            scheduler,
                            const SizedBox(height: 10),
                            todaySummary,
                          ],
                        ),
                      ),
                    ],
                  );
                }

                return Column(
                  children: [
                    firstColumn,
                    const SizedBox(height: 16),
                    secondColumn,
                    const SizedBox(height: 16),
                    scheduler,
                    const SizedBox(height: 10),
                    todaySummary,
                  ],
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _quickChip({
    required String label,
    bool selected = false,
    AppButtonVariant selectedVariant = AppButtonVariant.primary,
    AppButtonVariant normalVariant = AppButtonVariant.secondary,
    required VoidCallback onTap,
  }) {
    return AppButton(
      label: label,
      compact: false,
      variant: selected ? selectedVariant : normalVariant,
      onPressed: onTap,
    );
  }

  Widget _hierarchyChip({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFE6F7EC) : const Color(0xFFF4FBF6),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected ? const Color(0xFF9FD9B1) : const Color(0xFFCDEBD7),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? const Color(0xFF1E8B66) : const Color(0xFF2F7A57),
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  Widget _buildTodaySummaryCard(Appointment a) {
    final treatedTeeth = _selectedTeeth.toList(growable: false)
      ..sort((x, y) => x.compareTo(y));
    final diagnosisLabel =
        a.diagnosis.where((d) => d.trim().isNotEmpty).join(', ').trim().isEmpty
            ? '-'
            : a.diagnosis.where((d) => d.trim().isNotEmpty).join(', ');
    final chiefComplaintLabel = a.chiefComplaints
            .where((d) => d.trim().isNotEmpty)
            .join(', ')
            .trim()
            .isEmpty
        ? '-'
        : a.chiefComplaints.where((d) => d.trim().isNotEmpty).join(', ');
    final selectedTreatments =
        a.selectedTreatments.where((t) => t.trim().isNotEmpty).toList();
    final selectedSubTreatments =
        a.subTreatments.where((t) => t.trim().isNotEmpty).toList();
    final treatmentLabel = selectedTreatments.isEmpty
        ? 'Consultation'
        : selectedSubTreatments.isEmpty
            ? selectedTreatments.join(', ')
            : '${selectedTreatments.join(', ')} - ${selectedSubTreatments.join(', ')}';

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF4F7FC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFD7E0EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Today Summary',
            style: TextStyle(
              color: Color(0xFF223B5E),
              fontWeight: FontWeight.w800,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 12),
          _summaryLine('Teeth treated',
              treatedTeeth.isEmpty ? '-' : treatedTeeth.join(', ')),
          _summaryLine('Diagnosis', diagnosisLabel),
          _summaryLine('Chief complaint', chiefComplaintLabel),
          _summaryLine('Treatment', treatmentLabel),
          _summaryLine('Cost', '₹${a.price.toStringAsFixed(0)}',
              valueColor: const Color(0xFF203A61)),
          const SizedBox(height: 10),
          const Divider(size: 1),
        ],
      ),
    );
  }

  Widget _summaryLine(String label, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Expanded(
            child: Text(
              '$label:',
              style: const TextStyle(
                color: Color(0xFF5A6B7F),
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(
                color: valueColor ?? const Color(0xFF2A3F5E),
                fontWeight: FontWeight.w700,
                fontSize: 13,
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
  String _paymentMode = 'Cash';
  final TextEditingController _consultantChargeController =
      TextEditingController();
  Timer? _autosaveDebounce;
  bool _hasPendingAutosave = false;
  DateTime _paymentDate = DateTime.now();
  int _receiptExportSequence = 0;
  String _discountMode = 'flat';
  double _basePrice = 0;
  String? _selectedConsultantDoctorId;

  @override
  void initState() {
    super.initState();
    final a = widget.appointment;
    _paymentMode = a.treatmentGpayPaid ? 'UPI' : 'Cash';
    _discountMode = a.discountType == 'percent' ? 'percent' : 'flat';
    _basePrice = a.price;
    _selectedConsultantDoctorId = a.consultantDoctorID;
    _consultantChargeController.text =
        a.priceToPayDoctor <= 0 ? '' : a.priceToPayDoctor.toStringAsFixed(0);
  }

  @override
  void dispose() {
    _autosaveDebounce?.cancel();
    if (_hasPendingAutosave) {
      appointments.set(widget.appointment);
    }
    _consultantChargeController.dispose();
    super.dispose();
  }

  void _scheduleAutosave({bool immediate = false}) {
    final appointment = widget.appointment;
    if (immediate) {
      _autosaveDebounce?.cancel();
      _autosaveDebounce = null;
      _hasPendingAutosave = false;
      appointments.set(appointment);
      return;
    }

    _hasPendingAutosave = true;
    _autosaveDebounce?.cancel();
    _autosaveDebounce = Timer(const Duration(milliseconds: 900), () {
      _hasPendingAutosave = false;
      appointments.set(appointment);
    });
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

    final initialDate =
        resolvedExisting?.date ?? DateTime.now().add(const Duration(days: 7));
    final pickedDate = await material.showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime.now(),
      lastDate: DateTime(2100, 12, 31),
      builder: apexoDatePickerBuilder(context),
    );
    if (pickedDate == null) return;
    if (!mounted) return;

    final pickedTime = await material.showTimePicker(
      context: context,
      initialTime: material.TimeOfDay(
        hour: resolvedExisting?.date.hour ?? 10,
        minute: resolvedExisting?.date.minute ?? 0,
      ),
      builder: apexoDatePickerBuilder(context),
    );
    if (pickedTime == null) return;
    if (!mounted) return;

    final scheduledAt = DateTime(
      pickedDate.year,
      pickedDate.month,
      pickedDate.day,
      pickedTime.hour,
      pickedTime.minute,
    );
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
    if (targetAppointment.operatorsIDs.isEmpty) {
      targetAppointment.operatorsIDs = [...a.operatorsIDs];
    }
    if (targetAppointment.preOpNotes.trim().isEmpty) {
      targetAppointment.preOpNotes = 'Follow-up visit';
    }
    appointments.set(targetAppointment);

    if (!mounted) return;
    setState(() {});
  }

  ButtonStyle _pillStyle(
      {required bool selected, Color accent = const Color(0xFF2D7BD8)}) {
    return ButtonStyle(
      padding: WidgetStateProperty.all(
        const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      ),
      backgroundColor: WidgetStateProperty.all(
        selected ? accent.withValues(alpha: 0.12) : const Color(0xFFF8FBFF),
      ),
      shape: WidgetStateProperty.all(
        RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(
            color: selected ? accent : const Color(0xFFD8E3F1),
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
                formatClinicDate(_paymentDate, pattern: 'dd MMM yyyy'),
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
    final paid = double.tryParse(widget.paidController.text.trim()) ?? a.paid;
    final treatmentCost = a.price;
    final balance = (treatmentCost - paid).clamp(0, double.infinity);
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
    final outstanding = (discountedTotal - a.paid).clamp(0, double.infinity);
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
                      color: Color(0xFF355279),
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
                      child:
                          Text('₹', style: TextStyle(color: Color(0xFF355279))),
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
                          color: Color(0xFF355279),
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
                                compact: true,
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
                                compact: true,
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
                      color: Color(0xFF355279),
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
                    },
                    prefix: const Padding(
                      padding: EdgeInsets.only(left: 10),
                      child:
                          Text('₹', style: TextStyle(color: Color(0xFF355279))),
                    ),
                    suffix: Padding(
                      padding: const EdgeInsets.only(right: 10),
                      child: Text(
                        '₹${outstanding.toStringAsFixed(0)}',
                        style: const TextStyle(
                          color: Color(0xFF5A7397),
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
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Payment Mode',
                              style: TextStyle(
                                color: Color(0xFF355279),
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
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Date',
                            style: TextStyle(
                              color: Color(0xFF355279),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 8),
                          AppButton(
                            label: formatClinicDate(_paymentDate,
                                pattern: 'dd MMM yyyy'),
                            variant: AppButtonVariant.secondary,
                            onPressed: () async {
                              final picked = await material.showDatePicker(
                                context: context,
                                initialDate: _paymentDate,
                                firstDate: DateTime(2000, 1, 1),
                                lastDate: DateTime(2100, 12, 31),
                                builder: apexoDatePickerBuilder(context),
                              );
                              if (picked == null) return;
                              setState(() => _paymentDate = picked);
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Consultant Charge',
                    style: TextStyle(
                      color: Color(0xFF355279),
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
                            child: Text('₹',
                                style: TextStyle(color: Color(0xFF355279))),
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
                        ExportFileActionButton(
                          type: ExportFileType.pdf,
                          onPressed: _downloadReceiptPdf,
                        ),
                        Tooltip(
                          message: 'Share',
                          child: IconButton(
                            icon: const Icon(
                              FluentIcons.share,
                              size: 18,
                              color: Color(0xFF7C3AED),
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
              color: Color(0xFF5A7397),
              fontWeight: FontWeight.w600,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: valueColor ?? const Color(0xFF2D476D),
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
