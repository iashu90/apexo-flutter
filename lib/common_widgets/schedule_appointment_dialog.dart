import 'package:apexo/core/theme/app_colors.dart';
import 'package:apexo/core/ui/components/app_button.dart';
import 'package:apexo/features/doctors/doctors_store.dart';
import 'package:apexo/theme/material_date_picker_theme.dart';
import 'package:apexo/utils/clinic_time.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/material.dart' as material;

class ScheduleAppointmentDraft {
  final DateTime scheduledAt;
  final Set<String> doctorIds;
  final Set<String> focusNotes;

  const ScheduleAppointmentDraft({
    required this.scheduledAt,
    required this.doctorIds,
    required this.focusNotes,
  });
}

Set<String> _normalizeNotes(Iterable<String> values) {
  final normalized = <String>{};
  for (final value in values) {
    final cleaned = value.trim();
    if (cleaned.isEmpty) continue;
    normalized.add(cleaned);
  }
  return normalized;
}

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

Future<ScheduleAppointmentDraft?> showScheduleAppointmentDialog({
  required BuildContext context,
  required String patientSummary,
  required DateTime initialDateTime,
  Iterable<String> initialDoctorIds = const <String>[],
  Iterable<String> initialFocusNotes = const <String>[],
  Iterable<String> suggestedFocusNotes = const <String>[],
  String title = 'Schedule Appointment',
  String confirmLabel = 'Schedule',
  DateTime? firstDate,
  DateTime? lastDate,
  bool requireFutureDateTime = true,
}) async {
  DateTime selectedDate = DateTime(
    initialDateTime.year,
    initialDateTime.month,
    initialDateTime.day,
  );
  material.TimeOfDay selectedTime = material.TimeOfDay(
    hour: initialDateTime.hour,
    minute: initialDateTime.minute,
  );

  final selectedDoctors = initialDoctorIds.toSet();
  final selectedFocusNotes = _normalizeNotes(initialFocusNotes);
  final customNoteController = TextEditingController();
  final now = DateTime.now();
  final minDate = firstDate ?? DateTime(now.year, now.month, now.day);
  final maxDate = lastDate ?? DateTime(now.year + 5, 12, 31);

  ScheduleAppointmentDraft? result;

  await showDialog<void>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (context, setStateDialog) {
        final doctorRows = doctors.present.values.toList(growable: false)
          ..sort(
            (a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()),
          );

        final scheduledAt = DateTime(
          selectedDate.year,
          selectedDate.month,
          selectedDate.day,
          selectedTime.hour,
          selectedTime.minute,
        );

        return ContentDialog(
          title: Row(
            children: [
              Expanded(child: Text(title)),
              IconButton(
                icon: const Icon(FluentIcons.chrome_close, size: 11),
                onPressed: () => Navigator.pop(dialogContext),
              ),
            ],
          ),
          content: SizedBox(
            width: 560,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Text(
                    patientSummary,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                ),
                Row(
                  children: [
                    const Text('Date:',
                        style: TextStyle(fontWeight: FontWeight.w700)),
                    const SizedBox(width: 8),
                    AppButton(
                      label: formatClinicDate(selectedDate, pattern: 'dd MMM yyyy'),
                      variant: AppButtonVariant.secondary,
                      onPressed: () async {
                        final picked = await material.showDatePicker(
                          context: context,
                          initialDate: selectedDate,
                          firstDate: minDate,
                          lastDate: maxDate,
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
                      label: selectedTime.format(context),
                      variant: AppButtonVariant.secondary,
                      onPressed: () async {
                        final picked = await material.showTimePicker(
                          context: context,
                          initialTime: selectedTime,
                          builder: apexoDatePickerBuilder(context),
                        );
                        if (picked == null) return;
                        setStateDialog(() => selectedTime = picked);
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Scheduled: ${formatClinicDateTime(scheduledAt, pattern: 'dd MMM yyyy • h:mm a')}',
                  style: const TextStyle(
                    color: AppColors.brandBlueDark,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Visit Notes',
                  style: TextStyle(
                    color: AppColors.textBlueStrong,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: suggestedFocusNotes.map((note) {
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
                      variant: AppButtonVariant.secondary,
                      compact: true,
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
                if (selectedFocusNotes.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: selectedFocusNotes.map((note) {
                      return GestureDetector(
                        onTap: () {
                          setStateDialog(() {
                            selectedFocusNotes.remove(note);
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.slate1006,
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(color: AppColors.violet150),
                          ),
                          child: Text(
                            note,
                            style: const TextStyle(
                              color: AppColors.textBlueStrong,
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      );
                    }).toList(growable: false),
                  ),
                ],
                const SizedBox(height: 24),
                const Text(
                  'Consultant/Doctor',
                  style: TextStyle(
                    color: AppColors.textBlueStrong,
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
              label: confirmLabel,
              onPressed: () {
                if (requireFutureDateTime && scheduledAt.isBefore(DateTime.now())) {
                  return;
                }
                result = ScheduleAppointmentDraft(
                  scheduledAt: scheduledAt,
                  doctorIds: Set<String>.from(selectedDoctors),
                  focusNotes: Set<String>.from(selectedFocusNotes),
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
