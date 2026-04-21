// ignore_for_file: unused_element, unused_field, unused_local_variable, unused_import, dead_code

import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:apexo/common_widgets/date_navigator_bar.dart';
import 'package:apexo/common_widgets/patient_checkin_lookup_dialog.dart';
import 'package:apexo/common_widgets/patients_report_dialog.dart';
import 'package:apexo/common_widgets/export_progress_dialog.dart';
import 'package:apexo/common_widgets/export_file_action_button.dart';
import 'package:apexo/common_widgets/tag_input.dart';
import 'package:apexo/common_widgets/teeth_picker.dart';
import 'package:apexo/features/appointments/appointment_model.dart';
import 'package:apexo/features/appointments/appointments_store.dart';
import 'package:apexo/features/checkin/odontogram/odontogram_picker.dart';
import 'package:apexo/features/checkin/appointment_journey_dialog.dart';
import 'package:apexo/features/checkin/checkin_stage_modals.dart';
import 'package:apexo/features/checkin/odontogram/tooth_model.dart';
import 'package:apexo/features/doctors/doctor_model.dart';
import 'package:apexo/features/doctors/doctors_store.dart';
import 'package:apexo/features/patients/open_add_patient_popup.dart';
import 'package:apexo/features/patients/patient_model.dart';
import 'package:apexo/features/patients/patients_store.dart';
import 'package:apexo/theme/material_date_picker_theme.dart';
import 'package:apexo/utils/uuid.dart';
import 'package:apexo/utils/share_actions.dart';
import 'package:apexo/utils/pdf_export_layout.dart';
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
          title: Text(
            'Schedule • ${_toTitleCase(patient.title)} • ${patient.age}y • ${patient.phone.trim().isEmpty ? '-' : patient.phone}',
          ),
          content: SizedBox(
            width: 560,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text('Date:',
                        style: TextStyle(fontWeight: FontWeight.w700)),
                    const SizedBox(width: 8),
                    Button(
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
                      child: Text(DateFormat('dd MMM yyyy').format(nextDate)),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Text('Time:',
                        style: TextStyle(fontWeight: FontWeight.w700)),
                    const SizedBox(width: 8),
                    Button(
                      onPressed: () async {
                        final picked = await material.showTimePicker(
                          context: context,
                          initialTime: nextTime,
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
                      child: Text(nextTime.format(context)),
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
                                ..clear()
                                ..add(doctor.id);
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
                                : doctor.title,
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
            Button(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Skip'),
            ),
            FilledButton(
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
              child: const Text('Schedule'),
            ),
          ],
        );
      },
    ),
  );
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
  final startStep = initialStep?.clamp(0, 3) ??
      _stepIndexFromStageValue(appointment.checkinStage);
  final patient = appointment.patient;
  final patientContext =
      '${patient?.age ?? 0}y • ${_patientGenderShort(appointment)} • ${(patient?.phone.trim().isEmpty ?? true) ? '-' : patient!.phone.trim()}';
  final allAppointmentsForPatient = appointments.present.values
      .where((row) => row.patientID == appointment.patientID)
      .toList(growable: false)
    ..sort((a, b) => b.date.compareTo(a.date));
  DateTime nextVisitDateTime = appointment.date.add(const Duration(days: 7));
  bool scheduledNextVisit = false;
  String? scheduledNextAppointmentId;
  String? nextDoctorId = appointment.operatorsIDs.isNotEmpty
      ? appointment.operatorsIDs.first
      : null;
  String scheduleError = '';
  final nextReasonController = TextEditingController(
    text: 'Follow-up visit',
  );

  void saveNextAppointment({
    required DateTime scheduledAt,
    String? doctorId,
    String reason = '',
  }) {
    nextVisitDateTime = scheduledAt;
    final nextAppointment = scheduledNextAppointmentId != null
        ? (appointments.get(scheduledNextAppointmentId!) ??
            Appointment.fromJson({'id': scheduledNextAppointmentId!}))
        : Appointment.fromJson({'id': uuid()});
    nextAppointment.patientID = appointment.patientID;
    nextAppointment.date = nextVisitDateTime;
    nextAppointment.checkinStage = 'scheduled';
    nextAppointment.isCheckedIn = false;
    nextAppointment.operatorsIDs =
        doctorId == null ? [...appointment.operatorsIDs] : [doctorId];
    if (reason.trim().isNotEmpty) {
      nextAppointment.preOpNotes = reason.trim();
    }
    appointments.set(nextAppointment);
    scheduledNextAppointmentId = nextAppointment.id;
    scheduledNextVisit = true;
  }

  Widget stageBody(BuildContext context, int currentStep, double panelHeight) {
    if (currentStep == 0 || currentStep == 2) {
      return _CheckinTreatmentStageScreen(
        appointment: appointment,
        allAppointmentsForPatient: allAppointmentsForPatient,
        forcedStage: currentStep == 2 ? 'checkout' : 'with_doctor',
        showInlineBottomActions: false,
        boxed: true,
        panelHeight: panelHeight,
      );
    }

    if (currentStep == 1) {
      final doctorRows = doctors.present.values.toList(growable: false)
        ..sort(
          (a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()),
        );

      return StatefulBuilder(
        builder: (context, setStepState) => _CheckinScheduledStageScreen(
          nextVisitDateTime: nextVisitDateTime,
          scheduledNextVisit: scheduledNextVisit,
          nextDoctorId: nextDoctorId,
          doctorRows: doctorRows,
          nextReasonController: nextReasonController,
          scheduleError: scheduleError,
          boxed: true,
          onDateChanged: (value) {
            setStepState(() {
              nextVisitDateTime = value;
              scheduleError = '';
            });
          },
          onTimeChanged: (picked) {
            setStepState(() {
              nextVisitDateTime = DateTime(
                nextVisitDateTime.year,
                nextVisitDateTime.month,
                nextVisitDateTime.day,
                picked.hour,
                picked.minute,
              );
              scheduleError = '';
            });
          },
          onDoctorChanged: (value) {
            setStepState(() {
              nextDoctorId = value;
            });
          },
          onReasonChanged: () {
            setStepState(() {
              scheduleError = '';
            });
          },
          onSchedule: () {
            if (nextVisitDateTime.isBefore(DateTime.now())) {
              setStepState(() {
                scheduleError =
                    'Next appointment must be now or in the future.';
              });
              return;
            }
            setStepState(() {
              scheduleError = '';
            });
            saveNextAppointment(
              scheduledAt: nextVisitDateTime,
              doctorId: nextDoctorId,
              reason: nextReasonController.text,
            );
            setStepState(() {});
          },
        ),
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
    stepBuilder: stageBody,
    onBeforeStepAdvance: (dialogContext, currentStep, nextStep) async {
      appointments.set(appointment);
    },
  );
}

Future<void> openNextCheckinStepperDialog(
  BuildContext context,
  Appointment appointment, {
  int? initialStep,
}) {
  return openAppointmentJourneyDialog(
    context,
    appointment,
    initialStep: initialStep,
  );
}

Future<void> openCheckinAppointmentModal(
  BuildContext context,
  Appointment appointment,
) async {
  final screenWidth = MediaQuery.of(context).size.width;
  final normalizedStage = appointment.checkinStage.trim().toLowerCase();
  final isWideStage = normalizedStage == 'checkout' ||
      normalizedStage == 'with_doctor' ||
      normalizedStage == 'treatment';
  final popupWidth = screenWidth < 760
      ? screenWidth - 20
      : isWideStage
          ? (screenWidth * 0.75).clamp(760.0, 1000.0)
          : 540.0;
  final stageLabel =
      normalizedStage == 'with_doctor' || normalizedStage == 'treatment'
          ? 'Treatment'
          : normalizedStage == 'checkout'
              ? 'Billing'
              : normalizedStage == 'completed'
                  ? 'Complete'
                  : 'Check-in';
  final patientName = appointment.title.trim().isEmpty
      ? 'Unnamed patient'
      : _toTitleCase(appointment.title);
  final patientAge = appointment.patient?.age ?? 0;
  final patientGender = appointment.patient?.gender == 1 ? 'M' : 'F';
  final patientPhone = (appointment.patient?.phone ?? '').trim();

  await showDialog<void>(
    context: context,
    barrierColor: const Color(0x660A1B33),
    builder: (dialogContext) => SafeArea(
      child: Align(
        alignment: Alignment.center,
        child: Container(
          width: popupWidth,
          height: screenWidth < 760
              ? null
              : MediaQuery.of(context).size.height * 0.9,
          margin: const EdgeInsets.fromLTRB(10, 12, 12, 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            boxShadow: const [
              BoxShadow(
                color: Color(0x2A0D2F5B),
                blurRadius: 24,
                offset: Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            children: [
              Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: appointment.checkinStage == 'completed'
                        ? const [Color(0xFF2BA58D), Color(0xFF1D8D77)]
                        : appointment.checkinStage == 'checkout'
                            ? const [Color(0xFF8B5CF6), Color(0xFF6D3FD2)]
                            : (appointment.checkinStage == 'with_doctor' ||
                                    appointment.checkinStage == 'treatment')
                                ? const [Color(0xFF5A84E6), Color(0xFF3F68CC)]
                                : const [Color(0xFFE4A11B), Color(0xFFD28C02)],
                  ),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(14),
                    topRight: Radius.circular(14),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            stageLabel,
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '$patientName • ${patientAge}y • $patientGender • ${patientPhone.isEmpty ? '-' : patientPhone}',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFFEAF2FF),
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(FluentIcons.cancel, size: 12),
                      style: ButtonStyle(
                        foregroundColor: WidgetStateProperty.all(Colors.white),
                      ),
                      onPressed: () => Navigator.pop(dialogContext),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: _CheckinHistoryDetails(
                  appointment: appointment,
                  rootContext: context,
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _CheckinTreatmentStageScreen extends StatelessWidget {
  final Appointment appointment;
  final List<Appointment> allAppointmentsForPatient;
  final String forcedStage;
  final bool showInlineBottomActions;
  final bool boxed;
  final double? panelHeight;

  const _CheckinTreatmentStageScreen({
    required this.appointment,
    required this.allAppointmentsForPatient,
    required this.forcedStage,
    this.showInlineBottomActions = false,
    this.boxed = false,
    this.panelHeight,
  });

  @override
  Widget build(BuildContext context) {
    final content = SingleChildScrollView(
      child: _CheckinOperativeForm(
        appointment: appointment,
        allAppointmentsForPatient: allAppointmentsForPatient,
        showInlineBottomActions: showInlineBottomActions,
        forcedStage: forcedStage,
      ),
    );

    if (!boxed) {
      return content;
    }

    return Container(
      width: double.infinity,
      height: panelHeight,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFD7E5F6)),
      ),
      padding: const EdgeInsets.all(10),
      child: content,
    );
  }
}

class _CheckinScheduledStageScreen extends StatelessWidget {
  final DateTime nextVisitDateTime;
  final bool scheduledNextVisit;
  final String? nextDoctorId;
  final List<Doctor?> doctorRows;
  final TextEditingController nextReasonController;
  final String scheduleError;
  final ValueChanged<DateTime> onDateChanged;
  final ValueChanged<material.TimeOfDay> onTimeChanged;
  final ValueChanged<String?> onDoctorChanged;
  final VoidCallback onReasonChanged;
  final VoidCallback onSchedule;
  final bool boxed;

  const _CheckinScheduledStageScreen({
    required this.nextVisitDateTime,
    required this.scheduledNextVisit,
    required this.nextDoctorId,
    required this.doctorRows,
    required this.nextReasonController,
    required this.scheduleError,
    required this.onDateChanged,
    required this.onTimeChanged,
    required this.onDoctorChanged,
    required this.onReasonChanged,
    required this.onSchedule,
    this.boxed = false,
  });

  @override
  Widget build(BuildContext context) {
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Schedule Next Appointment',
          style: TextStyle(
            color: Color(0xFF0F4B66),
            fontWeight: FontWeight.w700,
            fontSize: 20,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          scheduledNextVisit
              ? 'Next appointment scheduled at ${DateFormat('dd MMM yyyy • h:mm a').format(nextVisitDateTime)}'
              : 'Enter next appointment details below, then schedule. Or skip with Continue.',
          style: const TextStyle(
            color: Color(0xFF3E5F7D),
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: InfoLabel(
                label: 'Date',
                child: Button(
                  onPressed: () async {
                    final picked = await material.showDatePicker(
                      context: context,
                      initialDate: nextVisitDateTime,
                      firstDate: DateTime.now(),
                      lastDate: DateTime(2100, 12, 31),
                      builder: apexoDatePickerBuilder(context),
                    );
                    if (picked == null) return;
                    onDateChanged(
                      DateTime(
                        picked.year,
                        picked.month,
                        picked.day,
                        nextVisitDateTime.hour,
                        nextVisitDateTime.minute,
                      ),
                    );
                  },
                  child:
                      Text(DateFormat('dd MMM yyyy').format(nextVisitDateTime)),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: InfoLabel(
                label: 'Time',
                child: Button(
                  onPressed: () async {
                    final picked = await material.showTimePicker(
                      context: context,
                      initialTime: material.TimeOfDay(
                        hour: nextVisitDateTime.hour,
                        minute: nextVisitDateTime.minute,
                      ),
                    );
                    if (picked == null) return;
                    onTimeChanged(picked);
                  },
                  child: Text(DateFormat('h:mm a').format(nextVisitDateTime)),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ComboBox<String>(
          isExpanded: true,
          placeholder: const Text('Select doctor'),
          value: doctorRows.any((d) => d?.id == nextDoctorId)
              ? nextDoctorId
              : null,
          items: doctorRows
              .map(
                (doctor) => ComboBoxItem<String>(
                  value: doctor?.id,
                  child: Text(
                    (doctor?.title.trim().isEmpty ?? true)
                        ? 'Unnamed doctor'
                        : doctor!.title,
                  ),
                ),
              )
              .toList(growable: false),
          onChanged: onDoctorChanged,
        ),
        const SizedBox(height: 8),
        InfoLabel(
          label: 'Reason',
          child: TextBox(
            controller: nextReasonController,
            placeholder: 'Reason for next appointment',
            onChanged: (_) => onReasonChanged(),
          ),
        ),
        if (scheduleError.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            scheduleError,
            style: const TextStyle(
              color: Color(0xFFD4483B),
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
        const SizedBox(height: 10),
        Row(
          children: [
            FilledButton(
              onPressed: onSchedule,
              child: Text(
                scheduledNextVisit
                    ? 'Update Scheduled Appointment'
                    : 'Schedule Next Appointment',
              ),
            ),
          ],
        ),
      ],
    );

    if (!boxed) {
      return content;
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFD7E5F6)),
      ),
      child: content,
    );
  }
}

class _CheckinCompletedStageScreen extends StatelessWidget {
  final Appointment appointment;
  final Appointment? lastVisit;
  final bool boxed;

  const _CheckinCompletedStageScreen({
    required this.appointment,
    required this.lastVisit,
    this.boxed = false,
  });

  @override
  Widget build(BuildContext context) {
    final content = SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _patientDisplayName(appointment),
            style: const TextStyle(
              color: Color(0xFF163F70),
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            _patientFocusSummary(appointment),
            style: const TextStyle(
              color: Color(0xFF4F6C90),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          TodayAppointmentInsightCard(appointment: appointment),
          const SizedBox(height: 8),
          _LastAppointmentInsightCard(lastAppointment: lastVisit),
          const SizedBox(height: 12),
          _CheckoutBillingSummaryPanel(
            appointment: appointment,
            discountEnabled: appointment.discount > 0,
            totalPaidOverride: appointment.paid,
          ),
        ],
      ),
    );

    if (!boxed) {
      return content;
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFD7E5F6)),
      ),
      child: content,
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
    await openCheckinAppointmentModal(context, appointment);
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

  Future<void> _openQuickPatientSearchDialog() async {
    await showPatientCheckinLookupDialog(
      context: context,
      selectedDate: _selectedDate,
      title: 'Patient Check-in',
      onAddPatient: _openAddPatientPopup,
      onOpenExisting: (existing) async {
        if (!mounted) return;
        _selectAndOpenAppointment(existing);
      },
      onCheckInPatient: (patient) async {
        if (!mounted) return;
        _checkInPatient(patient);
      },
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
              color: const Color(0xFFF3F7FC),
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
                                child: Button(
                                  onPressed: _openNewPatientAndCheckin,
                                  child: const Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(FluentIcons.add_friend, size: 12),
                                      SizedBox(width: 8),
                                      Text('New Patient'),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: FilledButton(
                                  onPressed: _openQuickPatientSearchDialog,
                                  child: const Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(FluentIcons.search, size: 12),
                                      SizedBox(width: 8),
                                      Text('Check-in'),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          SizedBox(
                            width: double.infinity,
                            child: Button(
                              onPressed: filtered.isEmpty
                                  ? null
                                  : () {
                                      final target = _selectedAppointment ??
                                          filtered.first;
                                      _openNextCheckinStepper(target);
                                    },
                              child: const Text('New Checkin Flow'),
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
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                DateNavigatorBar(
                                  selectedDate: _selectedDate,
                                  onPrevious: () => _changeDate(-1),
                                  onNext: () => _changeDate(1),
                                  onPick: () => _pickDate(context),
                                  onToday: () => setState(() {
                                    _selectedDate = _dateOnly(DateTime.now());
                                    checkinPersistedDate = _selectedDate;
                                  }),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Button(
                            onPressed: _openNewPatientAndCheckin,
                            style: ButtonStyle(
                              padding: WidgetStateProperty.all(
                                const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 11,
                                ),
                              ),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(FluentIcons.add_friend, size: 12),
                                SizedBox(width: 8),
                                Text('New Patient'),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          FilledButton(
                            onPressed: _openQuickPatientSearchDialog,
                            style: ButtonStyle(
                              padding: WidgetStateProperty.all(
                                const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 11,
                                ),
                              ),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(FluentIcons.add, size: 12),
                                SizedBox(width: 8),
                                Text('Check-in'),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          FilledButton(
                            onPressed: filtered.isEmpty
                                ? null
                                : () {
                                    final target =
                                        _selectedAppointment ?? filtered.first;
                                    _openNextCheckinStepper(target);
                                  },
                            style: ButtonStyle(
                              backgroundColor: WidgetStateProperty.all(
                                const Color(0xFF1D8D77),
                              ),
                              foregroundColor:
                                  WidgetStateProperty.all(Colors.white),
                              padding: WidgetStateProperty.all(
                                const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 11,
                                ),
                              ),
                            ),
                            child: const Text('Next Checkin'),
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
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
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
  final String stage;
  final Color color;
  final List<Appointment> rows;
  final Set<String> duplicatePatientIds;
  final String Function(Appointment)? rowStageBuilder;
  final bool showHistoryAction;
  final bool expanded;
  final VoidCallback onToggleExpanded;
  final ValueChanged<Appointment>? onSelect;
  final String? selectedAppointmentId;
  final bool interactionsEnabled;

  const _WorkflowColumn({
    required this.title,
    required this.stage,
    required this.color,
    required this.rows,
    required this.duplicatePatientIds,
    this.rowStageBuilder,
    required this.expanded,
    required this.onToggleExpanded,
    this.showHistoryAction = false,
    this.onSelect,
    this.selectedAppointmentId,
    this.interactionsEnabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 120),
      opacity: interactionsEnabled ? 1 : 0.62,
      child: Container(
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
                const Spacer(),
                IconButton(
                  icon: Icon(
                    expanded
                        ? FluentIcons.chevron_down
                        : FluentIcons.chevron_right,
                    size: 11,
                  ),
                  onPressed: interactionsEnabled ? onToggleExpanded : null,
                ),
              ],
            ),
          ),
          if (!expanded)
            const Padding(
              padding: EdgeInsets.all(12),
              child: Text(
                'Collapsed',
                style: TextStyle(color: Color(0xFF6D84A8)),
              ),
            )
          else if (rows.isEmpty)
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
                stage: rowStageBuilder?.call(a) ?? stage,
                duplicateRecord: a.patientID != null &&
                    duplicatePatientIds.contains(a.patientID),
                showHistoryAction: showHistoryAction,
                selected: selectedAppointmentId == a.id,
                interactionsEnabled: interactionsEnabled,
                onSelect: onSelect,
              ),
            ),
        ],
      ),
    ));
  }
}

class _WorkflowRow extends StatelessWidget {
  final Appointment appointment;
  final String stage;
  final bool duplicateRecord;
  final bool showHistoryAction;
  final bool selected;
  final bool interactionsEnabled;
  final ValueChanged<Appointment>? onSelect;

  const _WorkflowRow({
    required this.appointment,
    required this.stage,
    this.duplicateRecord = false,
    this.showHistoryAction = false,
    this.selected = false,
    this.interactionsEnabled = true,
    this.onSelect,
  });

  Future<void> _openNextAppointmentPrompt(
    BuildContext context,
    Appointment appointment,
  ) async {
    await _showNextAppointmentPromptDialog(context, appointment);
  }

  Future<void> _deleteScheduledAppointment(
    BuildContext context,
    Appointment appointment,
  ) async {
    await appointments.hardDelete(appointment.id);
  }

  Future<void> _openScheduleActions(
    BuildContext context,
    Appointment appointment,
  ) async {
    final originalDate = appointment.date;
    DateTime selectedDate = DateTime(
      originalDate.year,
      originalDate.month,
      originalDate.day,
    );
    material.TimeOfDay selectedTime = material.TimeOfDay(
      hour: originalDate.hour,
      minute: originalDate.minute,
    );
    bool confirmDelete = false;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setStateDialog) {
          final updatedDateTime = DateTime(
            selectedDate.year,
            selectedDate.month,
            selectedDate.day,
            selectedTime.hour,
            selectedTime.minute,
          );
          final hasChanged = updatedDateTime != originalDate;

          return ContentDialog(
            title: const Text('Edit Appointment'),
            content: SizedBox(
              width: 520,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    appointment.title.trim().isEmpty
                        ? 'Unnamed patient'
                        : _toTitleCase(appointment.title),
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF183A67),
                      fontSize: 20,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      const Text(
                        'Date:',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(width: 8),
                      Button(
                        onPressed: () async {
                          final picked = await material.showDatePicker(
                            context: context,
                            initialDate: selectedDate,
                            firstDate: DateTime(2000, 1, 1),
                            lastDate: DateTime(2100, 12, 31),
                            builder: apexoDatePickerBuilder(context),
                          );
                          if (picked == null) return;
                          setStateDialog(() {
                            selectedDate = DateTime(
                              picked.year,
                              picked.month,
                              picked.day,
                            );
                          });
                        },
                        child: Text(
                          DateFormat('dd MMM yyyy').format(selectedDate),
                        ),
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
                          final picked = await material.showTimePicker(
                            context: context,
                            initialTime: selectedTime,
                          );
                          if (picked == null) return;
                          setStateDialog(() {
                            selectedTime = picked;
                          });
                        },
                        child: Text(selectedTime.format(context)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'Current: ${DateFormat('dd MMM yyyy, h:mm a').format(originalDate)}',
                    style: const TextStyle(
                      color: Color(0xFF5F789B),
                      fontSize: 16,
                    ),
                  ),
                  Text(
                    'Updated: ${DateFormat('dd MMM yyyy, h:mm a').format(updatedDateTime)}',
                    style: TextStyle(
                      color: hasChanged
                          ? const Color(0xFF1459AD)
                          : const Color(0xFF5F789B),
                      fontSize: 16,
                      fontWeight:
                          hasChanged ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                  if (confirmDelete) ...[
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF4F4),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFF3C3C8)),
                      ),
                      child: const Text(
                        'Delete confirmation: this action is permanent and cannot be undone.',
                        style: TextStyle(
                          color: Color(0xFFA11E34),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              Button(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Close'),
              ),
              FilledButton(
                style: ButtonStyle(
                  backgroundColor: WidgetStateProperty.resolveWith((states) {
                    if (states.contains(WidgetState.disabled)) {
                      return const Color(0xFFD0D5DD);
                    }
                    return const Color(0xFF2D7BD8);
                  }),
                  foregroundColor: WidgetStateProperty.resolveWith((states) {
                    if (states.contains(WidgetState.disabled)) {
                      return const Color(0xFF667085);
                    }
                    return Colors.white;
                  }),
                ),
                onPressed: hasChanged
                    ? () {
                        appointment.date = updatedDateTime;
                        appointments.set(appointment);
                        onSelect?.call(appointment);
                        Navigator.of(dialogContext, rootNavigator: true).pop();
                      }
                    : null,
                child: const Text('Update'),
              ),
              FilledButton(
                style: ButtonStyle(
                  backgroundColor:
                      WidgetStateProperty.all(const Color(0xFFD6455D)),
                ),
                onPressed: () async {
                  if (!confirmDelete) {
                    setStateDialog(() => confirmDelete = true);
                    return;
                  }
                  await _deleteScheduledAppointment(context, appointment);
                  if (dialogContext.mounted) {
                    Navigator.pop(dialogContext);
                  }
                },
                child: Text(confirmDelete ? 'Confirm Delete' : 'Delete'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _moveStage(BuildContext context) async {
    await CheckinStageModalRouter.openForStage(
      context: context,
      appointment: appointment,
      openTreatmentModal: openCheckinAppointmentModal,
      openBillingModal: openCheckinAppointmentModal,
      openCompleteModal: openCheckinAppointmentModal,
      onUpdated: () => onSelect?.call(appointment),
    );
  }

  Future<void> _undoStage(BuildContext context) async {
    final patientName = _patientDisplayName(appointment);

    if (stage == 'with_doctor') {
      final shouldMove = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => ContentDialog(
          title: Text('Move "$patientName" back to Waiting?'),
          content: Text(
            'Doctor assignment will be removed for $patientName.',
          ),
          actions: [
            Button(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Move to Waiting'),
            ),
          ],
        ),
      );
      if (shouldMove != true) return;
      appointment.operatorsIDs = [];
      appointment.checkinStage = 'waiting';
      appointment.isDone = false;
      appointments.set(appointment);
      return;
    }

    if (stage == 'checkout') {
      final shouldMove = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => ContentDialog(
          title: Text('Move "$patientName" back to Treatment?'),
          content: Text(
            'This appointment will be moved back to Treatment for $patientName.',
          ),
          actions: [
            Button(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Move to Treatment'),
            ),
          ],
        ),
      );
      if (shouldMove != true) return;
      appointment.checkinStage = 'with_doctor';
      appointment.isDone = false;
      appointments.set(appointment);
      return;
    }

    if (stage == 'completed') {
      final shouldMove = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => ContentDialog(
          title: Text('Move "$patientName" back to Billing?'),
          content: Text(
            'This appointment will be moved back to Billing for $patientName.',
          ),
          actions: [
            Button(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Move to Billing'),
            ),
          ],
        ),
      );
      if (shouldMove != true) return;
      appointment.checkinStage = 'checkout';
      appointment.isDone = false;
      appointments.set(appointment);
    }
  }

  String _waitingLabel() {
    final started = appointment.checkedInAt;
    if (started == null) return 'Waiting';
    final elapsed = DateTime.now().difference(started);
    if (elapsed.inMinutes < 1) return 'Waiting 0m';
    if (elapsed.inHours < 1) return 'Waiting ${elapsed.inMinutes}m';
    final hours = elapsed.inHours;
    final mins = elapsed.inMinutes.remainder(60);
    return 'Waiting ${hours}h ${mins}m';
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
        : _toTitleCase(appointment.title);
    final doctorsList = appointment.operators.isEmpty
        ? const <String>['Unassigned']
        : appointment.operators.map((d) => d.title).toList(growable: false);

    final phone = appointment.patient?.phone ?? '-';
    final age = appointment.patient?.age ?? 0;
    final rawGender = appointment.patient?.gender;
    final genderLabel = rawGender == 1 ? 'M' : 'F';
    final doctorLabel = doctorsList.join(', ');
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: stage == 'scheduled'
            ? const Color(0xFFFCF4E3) // Mild Orange (Orange 50)
            : stage == 'completed'
                ? const Color.fromARGB(
                    255, 235, 250, 230) // Mild Green (Green 50)
                : Colors.transparent,
        border: const Border(
          top: BorderSide(color: Color(0xFFE2ECF8)),
        ),
      ),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: !interactionsEnabled
          ? null
          : (stage == 'waiting' || stage == 'scheduled')
            ? () => _moveStage(context)
            : (onSelect == null ? null : () => onSelect!(appointment)),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    patientName,
                    style: const TextStyle(
                      color: Color(0xFF000000),
                      fontWeight: FontWeight.w600,
                      fontSize: 18,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Text(
                        '$age$genderLabel · $phone',
                        style: const TextStyle(
                          color: Color(0xFF6B7280),
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(width: 12),
                      if (stage == 'waiting') ...[
                        const SizedBox(width: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFE8A3),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            _waitingLabel(),
                            style: const TextStyle(
                              color: Color(0xFF7A5A00),
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                      if (stage == 'scheduled') ...[
                        const SizedBox(width: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE0EEFF),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            'Scheduled · ${DateFormat('h:mm a').format(appointment.date)}',
                            style: const TextStyle(
                              color: Color(0xFF1459AD),
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                      if (duplicateRecord) ...[
                        const SizedBox(width: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFEE2E2),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: const Text(
                            'Duplicate record',
                            style: TextStyle(
                              color: Color(0xFFB91C1C),
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: (stage == 'with_doctor' && selected)
                          ? () async {
                              final pickedDoctorIds = await pickDoctorDialog(
                                context,
                                initialSelected: appointment.operatorsIDs,
                                subtitle: _patientFocusSummary(appointment),
                              );
                              if (pickedDoctorIds == null ||
                                  pickedDoctorIds.isEmpty) {
                                return;
                              }
                              appointment.operatorsIDs = pickedDoctorIds;
                              appointments.set(appointment);
                            }
                          : null,
                      child: Row(
                        children: [
                          const Icon(
                            FluentIcons.contact,
                            size: 12,
                            color: Color(0xFF3B82F6),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            doctorLabel,
                            style: const TextStyle(
                              color: Color(0xFF3B82F6),
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (stage != 'waiting' && stage != 'scheduled')
                  Tooltip(
                    message: 'Undo',
                    child: IconButton(
                      icon: const Icon(material.Icons.undo_rounded, size: 18),
                      style: ButtonStyle(
                        padding: WidgetStateProperty.all(
                          const EdgeInsets.all(8),
                        ),
                        shape: WidgetStateProperty.all(
                          RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        backgroundColor:
                            WidgetStateProperty.all(const Color(0xFFFFF4E8)),
                        foregroundColor:
                            WidgetStateProperty.all(const Color(0xFFC97A11)),
                      ),
                      onPressed:
                          interactionsEnabled ? () => _undoStage(context) : null,
                    ),
                  ),
                if (stage != 'waiting' && stage != 'scheduled')
                  const SizedBox(width: 8),
                if (stage == 'scheduled' || stage == 'waiting')
                  Tooltip(
                    message: 'Edit or Delete Appointment',
                    child: IconButton(
                      icon: const Icon(material.Icons.edit, size: 18),
                      style: ButtonStyle(
                        padding: WidgetStateProperty.all(
                          const EdgeInsets.all(8),
                        ),
                        shape: WidgetStateProperty.all(
                          RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        foregroundColor:
                            WidgetStateProperty.all(const Color(0xFF6B7280)),
                      ),
                        onPressed: interactionsEnabled
                          ? () => _openScheduleActions(context, appointment)
                          : null,
                    ),
                  ),
                if (stage == 'scheduled' || stage == 'waiting')
                  const SizedBox(width: 8),
                if (stage == 'checkout')
                  Tooltip(
                    message: 'Complete',
                    child: IconButton(
                      icon: const Icon(
                        material.Icons.task_alt_rounded,
                        size: 18,
                      ),
                      style: ButtonStyle(
                        padding: WidgetStateProperty.all(
                          const EdgeInsets.all(8),
                        ),
                        shape: WidgetStateProperty.all(
                          RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        backgroundColor: WidgetStateProperty.all(
                          const Color(0xFFE8F8ED),
                        ),
                        foregroundColor: WidgetStateProperty.all(
                          const Color(0xFF2A8D3F),
                        ),
                      ),
                      onPressed:
                          interactionsEnabled ? () => _moveStage(context) : null,
                    ),
                  ),
                if (stage == 'completed')
                  Tooltip(
                    message: 'Schedule Appointment',
                    child: IconButton(
                      icon: const Icon(material.Icons.calendar_month, size: 18),
                      style: ButtonStyle(
                        padding: WidgetStateProperty.all(
                          const EdgeInsets.all(8),
                        ),
                        shape: WidgetStateProperty.all(
                          RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        backgroundColor:
                            WidgetStateProperty.all(const Color(0xFFEAF2FF)),
                        foregroundColor:
                            WidgetStateProperty.all(const Color(0xFF2D7BD8)),
                      ),
                        onPressed: interactionsEnabled
                          ? () => _openNextAppointmentPrompt(context, appointment)
                          : null,
                    ),
                  ),
              ],
            ),
            if (showHistoryAction) ...[
              const SizedBox(width: 8),
              Button(
                onPressed: () => _openPatientHistoryDialog(context),
                child: const Text('History'),
              ),
            ],
          ],
        ),
      ),
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
                Button(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(
                      dialogContext, selected.toList(growable: false)),
                  child: const Text('Save'),
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
          Button(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: ButtonStyle(
              backgroundColor: WidgetStateProperty.all(const Color(0xFFE56E7D)),
            ),
            child: const Text('Billing'),
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
                Text(
                  isCheckout
                      ? 'Today\'s Appointment Details'
                      : 'Current Appointment Details',
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF183A67),
                  ),
                ),
                const SizedBox(height: 4),
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
                        child: _PatientJourneyTimeline(
                          appointments: all,
                          excludeDate: appointment.date,
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
          child: FilledButton(
            style: ButtonStyle(
              backgroundColor: WidgetStateProperty.all(const Color(0xFF2D7BD8)),
            ),
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
            child: const Text('Check-in'),
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
              child: FilledButton(
                style: ButtonStyle(
                  backgroundColor:
                      WidgetStateProperty.all(const Color(0xFFD6455D)),
                  foregroundColor: WidgetStateProperty.all(Colors.white),
                ),
                onPressed: () async {
                  final shouldMove = await showDialog<bool>(
                    context: context,
                    builder: (dialogContext) => ContentDialog(
                      title: Text('Move "$patientName" back to Waiting?'),
                      content: Text(
                        '$patientName will be moved back to Waiting and doctor assignment will be removed.',
                      ),
                      actions: [
                        Button(
                          onPressed: () => Navigator.pop(dialogContext, false),
                          child: const Text('Cancel'),
                        ),
                        FilledButton(
                          onPressed: () => Navigator.pop(dialogContext, true),
                          child: const Text('Move'),
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
                child: const Text('Move Back to Waiting'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: FilledButton(
                style: ButtonStyle(
                  backgroundColor:
                      WidgetStateProperty.all(const Color(0xFF7C3AED)),
                  foregroundColor: WidgetStateProperty.all(Colors.white),
                ),
                onPressed: () {
                  appointment.checkinStage = 'checkout';
                  appointment.isDone = false;
                  appointments.set(appointment);
                  if (mounted) {
                    Navigator.of(context).pop();
                  }
                  if (mounted) setState(() {});
                },
                child: const Text('Proceed to Billing'),
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
              child: Button(
                onPressed: () async {
                  final shouldMove = await showDialog<bool>(
                    context: context,
                    builder: (dialogContext) => ContentDialog(
                      title: Text('Move "$patientName" back to Treatment?'),
                      content: Text(
                        'This appointment will be moved back to Treatment for $patientName.',
                      ),
                      actions: [
                        Button(
                          onPressed: () => Navigator.pop(dialogContext, false),
                          child: const Text('Cancel'),
                        ),
                        FilledButton(
                          onPressed: () => Navigator.pop(dialogContext, true),
                          child: const Text('Move to Treatment'),
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
                child: const Text('Move Back to Treatment'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: FilledButton(
                style: ButtonStyle(
                  backgroundColor:
                      WidgetStateProperty.all(const Color(0xFF3B9A42)),
                ),
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
                child: StreamBuilder(
                  stream: appointments.observableMap.stream,
                  builder: (context, _) {
                    final latest = appointments.present.values.firstWhere(
                        (a) => a.id == appointment.id,
                        orElse: () => appointment);
                    final paid = latest.paid;
                    return Text('Collect (₹${paid.toStringAsFixed(0)})');
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
              child: FilledButton(
                style: ButtonStyle(
                  backgroundColor:
                      WidgetStateProperty.all(const Color(0xFFE56E7D)),
                ),
                onPressed: () => _moveCompletedToBilling(appointment),
                child: const Text('Move Back to Billing'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: FilledButton(
                style: ButtonStyle(
                  backgroundColor:
                      WidgetStateProperty.all(const Color(0xFF2D7BD8)),
                ),
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
                child: const Text('New Appointment'),
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
          border: Border.all(color: const Color(0xFFD7E5F6)),
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

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FBFF),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFD7E5F6)),
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
            DateFormat('dd MMM yyyy • h:mm a').format(last.date),
            style: const TextStyle(
              color: Color(0xFF355279),
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Stage: ${last.checkinStage}',
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
    final treatments = appointment.selectedTreatments
        .where((row) => row.trim().isNotEmpty)
        .join(', ');

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FBFF),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFD7E5F6)),
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
            DateFormat('dd MMM yyyy • h:mm a').format(appointment.date),
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
            'Treatment: ${treatments.isEmpty ? '-' : treatments}',
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
  String _visitType = 'Follow-up Visit';
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

  static const List<String> _visitTypes = [
    'Follow-up Visit',
    'New Problem / New Treatment',
    'Consultation Only',
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
    _selectedConsultationTypes =
        a.subTreatments.where((e) => e.trim().isNotEmpty).toSet();
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
          Button(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Move to Waiting'),
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
          Button(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Move to Treatment'),
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
          if (isWithDoctor) 
            const SizedBox(height: 14),
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
                              selectedColor: const Color(0xFF2D7BD8),
                              selectedTextColor: Colors.white,
                              normalColor: const Color(0xFFF3F4F6),
                              normalTextColor: const Color(0xFF2D3F58),
                              radius: 7,
                              selectedBorderColor: const Color(0xFF2D7BD8),
                              normalBorderColor: const Color(0xFFDBE1EA),
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
                        if (!_hasConsultationSelected()) {
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
                                selectedColor: const Color(0xFF2D7BD8),
                                selectedTextColor: Colors.white,
                                normalColor: const Color(0xFFF3F4F6),
                                normalTextColor: const Color(0xFF2D3F58),
                                selectedBorderColor: const Color(0xFF2D7BD8),
                                normalBorderColor: const Color(0xFFDBE1EA),
                                radius: 7,
                                onTap: () {
                                  setState(() {
                                    if (_selectedTreatments.contains(t)) {
                                      _selectedTreatments.remove(t);
                                    } else {
                                      _selectedTreatments.add(t);
                                    }
                                    a.selectedTreatments = _selectedTreatments
                                        .toList(growable: false);
                                    if (!_hasConsultationSelected()) {
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
                              (type) => _quickChip(
                                label: type,
                                selected:
                                    _selectedConsultationTypes.contains(type),
                                selectedColor: const Color(0xFFFFDDBB),
                                selectedTextColor: const Color(0xFF8B4500),
                                normalColor: const Color(0xFFFFF3E6),
                                normalTextColor: const Color(0xFF8B5C2E),
                                selectedBorderColor: const Color(0xFFFFB36C),
                                normalBorderColor: const Color(0xFFF3D9BD),
                                radius: 7,
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
                            (v) => Button(
                              style: ButtonStyle(
                                backgroundColor: WidgetStateProperty.all(
                                  const Color(0xFFEAF2FC),
                                ),
                              ),
                              onPressed: () {
                                _priceController.text = '$v';
                                a.price = v.toDouble();
                                _scheduleAutosave();
                                setState(() {});
                              },
                              child: Text('₹$v'),
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
                            (parent) => _quickChip(
                              label: parent,
                              selected: _selectedPostOpParent == parent,
                              selectedColor: const Color(0xFF2D7BD8),
                              selectedTextColor: Colors.white,
                              normalColor: const Color(0xFFF3F4F6),
                              normalTextColor: const Color(0xFF2D3F58),
                              selectedBorderColor: const Color(0xFF2D7BD8),
                              normalBorderColor: const Color(0xFFDBE1EA),
                              radius: 7,
                              onTap: () {
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
                              (child) => _quickChip(
                                label: child,
                                selectedColor: const Color(0xFF2D7BD8),
                                selectedTextColor: Colors.white,
                                normalColor: const Color(0xFFF3F4F6),
                                normalTextColor: const Color(0xFF2D3F58),
                                selectedBorderColor: const Color(0xFF2D7BD8),
                                normalBorderColor: const Color(0xFFDBE1EA),
                                radius: 7,
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
                            child: FilledButton(
                              style: ButtonStyle(
                                backgroundColor: WidgetStateProperty.all(
                                  const Color(0xFF2BA58D),
                                ),
                                foregroundColor:
                                    WidgetStateProperty.all(Colors.white),
                              ),
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
                                      Button(
                                        onPressed: () =>
                                            Navigator.pop(dialogContext, false),
                                        child: const Text('Cancel'),
                                      ),
                                      FilledButton(
                                        onPressed: () =>
                                            Navigator.pop(dialogContext, true),
                                        child: const Text('Proceed'),
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
                              child: const Text('Proceed to Billing'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Button(
                              onPressed: _moveBackToWaiting,
                              child: const Text('Move Back to Waiting'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
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
                      SizedBox(width: 260, child: todaySummary),
                    ],
                  );
                }

                return Column(
                  children: [
                    firstColumn,
                    const SizedBox(height: 16),
                    secondColumn,
                    const SizedBox(height: 16),
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
    Color selectedColor = const Color(0xFFDDEBFF),
    Color normalColor = const Color(0xFFEAF2FC),
    Color selectedTextColor = const Color(0xFF1459AD),
    Color normalTextColor = const Color(0xFF2F5B88),
    Color selectedBorderColor = const Color(0xFF2D7BD8),
    Color normalBorderColor = const Color(0xFFD5E5F7),
    double radius = 999,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: selected ? selectedColor : normalColor,
          borderRadius: BorderRadius.circular(radius),
          border: Border.all(
            color: selected ? selectedBorderColor : normalBorderColor,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? selectedTextColor : normalTextColor,
            fontSize: 11,
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
                DateFormat('dd MMM yyyy').format(_paymentDate),
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
                      style: pw.TextStyle(
                          fontSize: 9, color: pdfSecondaryTextColor),
                    ),
                  if (a.postOpNotes.trim().isNotEmpty)
                    pw.Bullet(
                      text: a.postOpNotes.trim(),
                      style: pw.TextStyle(
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
        'Last Visit: ${DateFormat('dd MMM yyyy').format(a.date)}\n'
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
            FilledButton(
              onPressed: () async {
                try {
                  await openWhatsApp(patient?.phone ?? '', message);
                } catch (_) {}
              },
              child: const Text('WhatsApp'),
            ),
            Button(
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
              child: Text(email.isEmpty ? 'Email (No address)' : 'Email'),
            ),
          ],
        ),
        actions: [
          Button(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Close'),
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
                          (v) => Button(
                            style: _pillStyle(
                              selected: false,
                              accent: const Color(0xFF2D7BD8),
                            ),
                            onPressed: () {
                              _basePrice = v.toDouble();
                              widget.priceController.text = '$v';
                              _recalculatePrice();
                            },
                            child: Text('₹$v'),
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
                        Button(
                          style: _pillStyle(
                            selected: _discountMode == 'flat',
                            accent: const Color(0xFF2D7BD8),
                          ),
                          onPressed: () {
                            setState(() => _discountMode = 'flat');
                            _recalculatePrice();
                          },
                          child:
                              Text(_discountMode == 'flat' ? '₹ Flat' : 'Flat'),
                        ),
                        Button(
                          style: _pillStyle(
                            selected: _discountMode == 'percent',
                            accent: const Color(0xFF2D7BD8),
                          ),
                          onPressed: () {
                            setState(() => _discountMode = 'percent');
                            _recalculatePrice();
                          },
                          child: Text(_discountMode == 'percent'
                              ? '% Percent'
                              : 'Percent'),
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
                              (v) => Button(
                                style: _pillStyle(
                                  selected: false,
                                  accent: const Color(0xFF2D7BD8),
                                ),
                                onPressed: () {
                                  widget.discountController.text = '$v';
                                  _recalculatePrice();
                                },
                                child: Text('$v%'),
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
                              (v) => Button(
                                style: _pillStyle(
                                  selected: false,
                                  accent: const Color(0xFF2D7BD8),
                                ),
                                onPressed: () {
                                  widget.discountController.text = '$v';
                                  _recalculatePrice();
                                },
                                child: Text('₹$v'),
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
                        (v) => Button(
                          style: _pillStyle(
                            selected: false,
                            accent: const Color(0xFF2D7BD8),
                          ),
                          onPressed: () {
                            widget.paidController.text = '$v';
                            a.paid = v.toDouble();
                            _scheduleAutosave();
                            setState(() {});
                          },
                          child: Text('₹$v'),
                        ),
                      ),
                      Button(
                        style: _pillStyle(
                          selected: false,
                          accent: const Color(0xFF2D7BD8),
                        ),
                        onPressed: widget.onCollectFullBalance,
                        child: const Text('Full'),
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
                                return Button(
                                  style: _pillStyle(selected: selected),
                                  onPressed: () {
                                    setState(() => _paymentMode = mode);
                                    final isDigital = mode == 'UPI';
                                    a.treatmentGpayPaid = isDigital;
                                    a.prescriptionGpayPaid = isDigital;
                                    _scheduleAutosave();
                                  },
                                  child: Text(
                                    mode,
                                    style: TextStyle(
                                      color: selected
                                          ? const Color(0xFF1459AD)
                                          : const Color(0xFF5A7397),
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
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
                          Button(
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
                            child: Text(
                                DateFormat('dd MMM yyyy').format(_paymentDate)),
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
                        child: ComboBox<String>(
                          isExpanded: true,
                          placeholder: const Text('Select consultant'),
                          value: consultantDoctors.any(
                                  (d) => d.id == _selectedConsultantDoctorId)
                              ? _selectedConsultantDoctorId
                              : null,
                          items: [
                            const ComboBoxItem<String>(
                              value: '__none__',
                              child: Text('None'),
                            ),
                            ...consultantDoctors.map(
                              (doctor) => ComboBoxItem<String>(
                                value: doctor.id,
                                child: Text(
                                  doctor.title.trim().isEmpty
                                      ? 'Unnamed doctor'
                                      : doctor.title,
                                ),
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
                child: _CheckoutBillingSummaryPanel(
                  appointment: a,
                  discountEnabled: widget.discountEnabled,
                  totalPaidOverride: totalAfter,
                  onDownloadPdf: _downloadReceiptPdf,
                  onShare: _openShareOptions,
                  doctorNames: doctorNames,
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

class _CheckoutBillingSummaryPanel extends StatelessWidget {
  final Appointment appointment;
  final bool discountEnabled;
  final double? totalPaidOverride;
  final VoidCallback? onDownloadPdf;
  final VoidCallback? onShare;
  final List<String>? doctorNames;

  const _CheckoutBillingSummaryPanel({
    required this.appointment,
    required this.discountEnabled,
    this.totalPaidOverride,
    this.onDownloadPdf,
    this.onShare,
    this.doctorNames,
  });

  @override
  Widget build(BuildContext context) {
    final a = appointment;
    final discountedTotal = a.discountType == 'percent'
        ? (a.price - (a.price * a.discount / 100)).clamp(0, double.infinity)
        : (a.price - a.discount).clamp(0, double.infinity);
    final outstanding = (discountedTotal - a.paid).clamp(0, double.infinity);
    final totalAfter =
        (totalPaidOverride ?? a.paid).clamp(0, double.infinity).toDouble();
    final status = outstanding <= 0 ? 'PAID' : 'DUE';
    final resolvedDoctorNames = doctorNames ??
        a.operators
            .map((doctor) => doctor.title.trim())
            .where((name) => name.isNotEmpty)
            .toList(growable: false);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Patient',
          style: TextStyle(
            color: Color(0xFF5A7397),
            fontWeight: FontWeight.w700,
            fontSize: 11,
          ),
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            Expanded(
              child: Text(
                a.title.trim().isEmpty ? 'Unnamed patient' : a.title,
                style: const TextStyle(
                  color: Color(0xFF2D476D),
                  fontWeight: FontWeight.w700,
                  fontSize: 18,
                ),
              ),
            ),
            if (onDownloadPdf != null)
              ExportFileActionButton(
                type: ExportFileType.pdf,
                onPressed: onDownloadPdf,
              ),
            if (onShare != null)
              Tooltip(
                message: 'Share',
                child: IconButton(
                  icon: const Icon(
                    FluentIcons.share,
                    size: 18,
                    color: Color(0xFF7C3AED),
                  ),
                  onPressed: onShare,
                ),
              ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          'Patient ID: ${a.patientID ?? '-'}',
          style: const TextStyle(color: Color(0xFF5A7397)),
        ),
        const SizedBox(height: 4),
        Text(
          'Age: ${a.patient?.age ?? 0}${(a.patient?.gender == 1 ? 'M' : a.patient?.gender == 0 ? 'F' : '')}  • ${a.patient?.phone ?? ''}',
          style: const TextStyle(
            color: Color(0xFF6D84A8),
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Doctor: ${resolvedDoctorNames.isEmpty ? 'Unassigned' : resolvedDoctorNames.join(', ')}',
          style: const TextStyle(
            color: Color(0xFFD6455D),
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 10),
        const Divider(),
        const SizedBox(height: 10),
        const Text(
          'Treatment',
          style: TextStyle(
            color: Color(0xFF2D476D),
            fontWeight: FontWeight.w700,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          a.selectedTreatments
                  .where((t) => t.trim().isNotEmpty)
                  .join(', ')
                  .trim()
                  .isEmpty
              ? '-'
              : a.selectedTreatments
                  .where((t) => t.trim().isNotEmpty)
                  .join(', '),
          style: const TextStyle(
            color: Color(0xFF5A7397),
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 10),
        const Divider(),
        const SizedBox(height: 10),
        const Text(
          'Billing Summary',
          style: TextStyle(
            color: Color(0xFF2D476D),
            fontWeight: FontWeight.w700,
            fontSize: 16,
          ),
        ),
        const SizedBox(height: 8),
        _checkoutSummaryLine(
            'Treatment Cost', '₹${a.price.toStringAsFixed(0)}'),
        const SizedBox(height: 6),
        if (discountEnabled) ...[
          _checkoutSummaryLine(
            'Discount Applied',
            a.discount <= 0
                ? '-'
                : a.discountType == 'percent'
                    ? '-${a.discount.toStringAsFixed(0)}%'
                    : '-₹${a.discount.toStringAsFixed(0)}',
            valueColor: const Color(0xFFD6455D),
          ),
          _checkoutSummaryLine(
            'Discounted Total',
            '₹${discountedTotal.toStringAsFixed(0)}',
            valueColor: const Color(0xFF1459AD),
          ),
          const SizedBox(height: 10),
        ],
        _checkoutSummaryLine('Already Paid', '₹${a.paid.toStringAsFixed(0)}'),
        _checkoutSummaryLine(
          'Remaining Balance',
          '₹${outstanding.toStringAsFixed(0)}',
          valueColor: const Color(0xFFD6455D),
        ),
        const SizedBox(height: 12),
        const Text(
          'After Payment',
          style: TextStyle(
            color: Color(0xFF2D476D),
            fontWeight: FontWeight.w700,
            fontSize: 16,
          ),
        ),
        const SizedBox(height: 8),
        _checkoutSummaryLine('Total Paid', '₹${totalAfter.toStringAsFixed(0)}'),
        _checkoutSummaryLine(
          'Balance',
          '₹${(discountedTotal - totalAfter).clamp(0, double.infinity).toStringAsFixed(0)}',
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: status == 'PAID'
                ? const Color(0xFFDCFCE7)
                : const Color(0xFFFFF1F2),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            status,
            style: TextStyle(
              color: status == 'PAID'
                  ? const Color(0xFF16A34A)
                  : const Color(0xFFD6455D),
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    );
  }
}

Widget _checkoutSummaryLine(String label, String value, {Color? valueColor}) {
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

class SvgOdontogramCard extends StatelessWidget {
  final Map<String, ToothState> teeth;
  final String selectedToothId;
  final String selectedToothNote;
  final ValueChanged<String> onSelectTooth;
  final ValueChanged<String> onToothNoteChanged;
  final void Function(String toothId, ToothSurface surface) onSurfaceTap;

  const SvgOdontogramCard({
    super.key,
    required this.teeth,
    required this.selectedToothId,
    required this.selectedToothNote,
    required this.onSelectTooth,
    required this.onToothNoteChanged,
    required this.onSurfaceTap,
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
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isDesktop = constraints.maxWidth >= 980;

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
                SizedBox(height: 280, child: centerPanel),
                const SizedBox(height: 8),
                rightPanel,
              ],
            );
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                height: 360,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    centerPanel,
                    const SizedBox(width: 8),
                    rightPanel,
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _PatientJourneyTimeline extends StatelessWidget {
  final List<Appointment> appointments;
  final DateTime? excludeDate;

  const _PatientJourneyTimeline({required this.appointments, this.excludeDate});

  static bool _sameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  @override
  Widget build(BuildContext context) {
    final scoped = excludeDate == null
        ? appointments
        : appointments
            .where((a) => !_sameDay(a.date, excludeDate!))
            .toList(growable: false);
    final points = scoped.take(8).toList(growable: false);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Journey Timeline',
            style: TextStyle(
              color: Color(0xFF2C4E76),
              fontWeight: FontWeight.w800,
              fontSize: 15,
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
              final doctorNames = item.operators.isEmpty
                  ? 'Unassigned'
                  : item.operators.map((d) => d.title).join(', ');
              final teeth = item.selectedTeeth
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
                          const SizedBox(height: 3),
                          Wrap(
                            spacing: 6,
                            runSpacing: 4,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 7,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFEAF2FC),
                                  borderRadius: BorderRadius.circular(999),
                                  border: Border.all(
                                    color: const Color(0xFFD5E5F7),
                                  ),
                                ),
                                child: Text(
                                  'Doctor: $doctorNames',
                                  style: const TextStyle(
                                    color: Color(0xFF355279),
                                    fontWeight: FontWeight.w700,
                                    fontSize: 10,
                                  ),
                                ),
                              ),
                              if (teeth.isNotEmpty)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 7,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF2F8E9),
                                    borderRadius: BorderRadius.circular(999),
                                    border: Border.all(
                                      color: const Color(0xFFD9EBC0),
                                    ),
                                  ),
                                  child: Text(
                                    'Teeth: $teeth',
                                    style: const TextStyle(
                                      color: Color(0xFF456824),
                                      fontWeight: FontWeight.w700,
                                      fontSize: 10,
                                    ),
                                  ),
                                ),
                            ],
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
