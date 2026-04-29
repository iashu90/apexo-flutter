import 'package:apexo/features/patients/patient_model.dart';
import 'package:apexo/features/patients/patient_history_suggestions.dart';
import 'package:apexo/features/patients/patients_store.dart';
import 'package:apexo/common_widgets/selectable_chip_group.dart';
import 'package:apexo/core/theme/app_colors.dart';
import 'package:apexo/core/ui/components/app_button.dart';
import 'package:apexo/utils/uuid.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/material.dart' as material;
import 'package:flutter/services.dart';

String _normalizePhoneDigits(String input) {
  final digits = input.replaceAll(RegExp(r'[^0-9]'), '');
  if (digits.length <= 10) return digits;
  return digits.substring(0, 10);
}

String _toTitleCaseForPatientPopup(String input) {
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

Future<Patient?> openAddPatientPopup({
  required BuildContext context,
  String initialInput = '',
  Patient? existingPatient,
}) async {
  final isEditMode = existingPatient != null;
  final seed = isEditMode ? existingPatient.title.trim() : initialInput.trim();
  final looksLikePhone = RegExp(r'^[+0-9\s()-]+$').hasMatch(seed);

  final nameController = TextEditingController(
    text: isEditMode
        ? existingPatient.title
        : (looksLikePhone ? '' : _toTitleCaseForPatientPopup(seed)),
  );
  final ageController = TextEditingController(
    text: isEditMode && existingPatient.age > 0 ? '${existingPatient.age}' : '',
  );
  final phoneController = TextEditingController(
    text: isEditMode ? existingPatient.phone : (looksLikePhone ? seed : ''),
  );
  final addressController = TextEditingController(
    text: isEditMode ? existingPatient.address : '',
  );

  int gender = isEditMode ? existingPatient.gender : 0;
  String referral = (isEditMode && existingPatient.referralSource.isNotEmpty)
      ? existingPatient.referralSource
      : 'None';
  final selectedMedicalHistory =
      isEditMode ? existingPatient.tags.toSet() : <String>{};
  final selectedDrugHistory =
      isEditMode ? existingPatient.drugHistorySuggestions.toSet() : <String>{};
  final selectedMaternalHistory = isEditMode
      ? existingPatient.maternalHistorySuggestions.toSet()
      : <String>{};
  final selectedHabitsHistory =
      isEditMode ? existingPatient.habitsSuggestions.toSet() : <String>{};
  String? nameError;
  String? ageError;
  String? phoneError;
  List<Patient> possibleDuplicatePatients = <Patient>[];

  List<Patient> findPossibleDuplicates(String phoneDigits) {
    if (phoneDigits.length < 8) return const <Patient>[];
    final matches = patients.docs.values
        .where((p) {
          if (isEditMode && p.id == existingPatient.id) {
            return false;
          }
          final existingDigits = _normalizePhoneDigits(p.phone);
          if (existingDigits.isEmpty) return false;
          return existingDigits.contains(phoneDigits);
        })
        .toList(growable: false);
    return matches;
  }

  return showDialog<Patient>(
    context: context,
    builder: (dialogContext) {
      final screen = MediaQuery.of(dialogContext).size;
      final dialogWidth = (screen.width - 24).clamp(360.0, 1100.0);

      return StatefulBuilder(
        builder: (context, setStateDialog) => ContentDialog(
          constraints: BoxConstraints(maxWidth: dialogWidth),
          title: Row(
            children: [
              Expanded(
                child: Text(
                  isEditMode ? 'Edit Patient' : 'Add Patient',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              IconButton(
                icon: const Icon(FluentIcons.chrome_close, size: 12),
                onPressed: () => Navigator.pop(dialogContext),
              ),
            ],
          ),
          content: SizedBox(
            width: dialogWidth - 28,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _popupFieldLabel('Name:'),
                  TextBox(
                    controller: nameController,
                    placeholder: 'Patient name',
                    onChanged: (_) {
                      if (nameError != null) {
                        setStateDialog(() => nameError = null);
                      }
                    },
                  ),
                  if (nameError != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        nameError!,
                        style: const TextStyle(
                          color: Color(0xFFD6455D),
                          fontSize: 11,
                        ),
                      ),
                    ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _popupFieldLabel('Age:'),
                            TextBox(
                              controller: ageController,
                              placeholder: 'Age',
                              keyboardType: material.TextInputType.number,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                                LengthLimitingTextInputFormatter(3),
                              ],
                              onChanged: (_) {
                                if (ageError != null) {
                                  setStateDialog(() => ageError = null);
                                }
                              },
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _popupFieldLabel('Gender:'),
                            Row(
                              children: [
                                Expanded(
                                  child: AppButton(
                                    label: 'Male',
                                    variant: gender == 1
                                        ? AppButtonVariant.primary
                                        : AppButtonVariant.secondary,
                                    onPressed: () =>
                                        setStateDialog(() => gender = 1),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: AppButton(
                                    label: 'Female',
                                    variant: gender == 0
                                        ? AppButtonVariant.primary
                                        : AppButtonVariant.secondary,
                                    onPressed: () =>
                                        setStateDialog(() => gender = 0),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (ageError != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        ageError!,
                        style: const TextStyle(
                          color: Color(0xFFD6455D),
                          fontSize: 11,
                        ),
                      ),
                    ),
                  const SizedBox(height: 16),
                  _popupFieldLabel('Phone:'),
                  TextBox(
                    controller: phoneController,
                    placeholder: 'Phone',
                    keyboardType: material.TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(10),
                    ],
                    onChanged: (value) {
                      final digits = _normalizePhoneDigits(value);
                      final matches = findPossibleDuplicates(digits);
                      if (phoneError != null ||
                          possibleDuplicatePatients.isNotEmpty ||
                          matches.isNotEmpty) {
                        setStateDialog(() {
                          phoneError = null;
                          possibleDuplicatePatients = matches;
                        });
                      }
                    },
                  ),
                  if (phoneError != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        phoneError!,
                        style: const TextStyle(
                          color: Color(0xFFD6455D),
                          fontSize: 11,
                        ),
                      ),
                    ),
                  if (possibleDuplicatePatients.isNotEmpty)
                    Container(
                      margin: const EdgeInsets.only(top: 8),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1FBF4),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFB7E3C1)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Could be duplicate of ${possibleDuplicatePatients.length} existing patient(s). You can still create this patient.',
                            style: const TextStyle(
                              color: Color(0xFF116132),
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 6),
                          ...possibleDuplicatePatients.take(4).map(
                            (patient) => Padding(
                              padding: const EdgeInsets.only(bottom: 4),
                              child: Text(
                                '${patient.title.trim().isEmpty ? 'Unnamed patient' : patient.title} • ${patient.phone} • Age ${patient.age}',
                                style: const TextStyle(
                                  color: Color(0xFF1F446E),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                          if (possibleDuplicatePatients.length > 4)
                            Text(
                              '+${possibleDuplicatePatients.length - 4} more',
                              style: const TextStyle(
                                color: AppColors.textBlueMuted,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 12),
                  _popupFieldLabel('Address:'),
                  TextBox(
                    controller: addressController,
                    placeholder: 'Address',
                  ),
                  const SizedBox(height: 16),
                  _popupFieldLabel('Medical History:'),
                  SelectableChipGroup(
                    options: patientMedicalHistorySuggestions,
                    selected: selectedMedicalHistory,
                    onToggle: (item) {
                      setStateDialog(() {
                        if (selectedMedicalHistory.contains(item)) {
                          selectedMedicalHistory.remove(item);
                        } else {
                          selectedMedicalHistory.add(item);
                        }
                      });
                    },
                  ),
                  const SizedBox(height: 16),
                  _popupFieldLabel('Drug History:'),
                  SelectableChipGroup(
                    options: patientDrugHistorySuggestions,
                    selected: selectedDrugHistory,
                    onToggle: (item) {
                      setStateDialog(() {
                        if (selectedDrugHistory.contains(item)) {
                          selectedDrugHistory.remove(item);
                        } else {
                          selectedDrugHistory.add(item);
                        }
                      });
                    },
                  ),
                  const SizedBox(height: 16),
                  _popupFieldLabel('Maternal History:'),
                  SelectableChipGroup(
                    options: patientMaternalHistorySuggestions,
                    selected: selectedMaternalHistory,
                    onToggle: (item) {
                      setStateDialog(() {
                        if (selectedMaternalHistory.contains(item)) {
                          selectedMaternalHistory.remove(item);
                        } else {
                          selectedMaternalHistory.add(item);
                        }
                      });
                    },
                  ),
                  const SizedBox(height: 16),
                  _popupFieldLabel('Habits:'),
                  SelectableChipGroup(
                    options: patientHabitsSuggestions,
                    selected: selectedHabitsHistory,
                    onToggle: (item) {
                      setStateDialog(() {
                        if (selectedHabitsHistory.contains(item)) {
                          selectedHabitsHistory.remove(item);
                        } else {
                          selectedHabitsHistory.add(item);
                        }
                      });
                    },
                  ),
                  const SizedBox(height: 12),
                  _popupFieldLabel('Referral:'),
                  ComboBox<String>(
                    isExpanded: true,
                    value: referral,
                    items: const [
                      ComboBoxItem(value: 'None', child: Text('None')),
                      ComboBoxItem(value: 'Google', child: Text('Google')),
                      ComboBoxItem(
                          value: 'Social Media', child: Text('Social Media')),
                      ComboBoxItem(value: 'Friends', child: Text('Friends')),
                      ComboBoxItem(value: 'Camps', child: Text('Camps')),
                      ComboBoxItem(
                          value: 'Name Board', child: Text('Name Board')),
                    ],
                    onChanged: (v) =>
                        setStateDialog(() => referral = v ?? 'None'),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            AppButton(
              label: 'Close',
              variant: AppButtonVariant.secondary,
              onPressed: () => Navigator.pop(dialogContext),
            ),
            AppButton(
              label: isEditMode ? 'Save Changes' : 'Add Patient',
              onPressed: () {
                final rawName = nameController.text.trim();
                final parsedAge = int.tryParse(ageController.text.trim()) ?? 0;
                final rawPhone = _normalizePhoneDigits(phoneController.text);

                final computedNameError =
                    rawName.isEmpty ? 'Patient name is required.' : null;
                final computedAgeError =
                    parsedAge <= 0 ? 'Age is required.' : null;
                final computedPhoneError = rawPhone.isEmpty
                    ? 'Phone number is required.'
                    : rawPhone.length != 10
                        ? 'Invalid phone number.'
                        : null;

                setStateDialog(() {
                  nameError = computedNameError;
                  ageError = computedAgeError;
                  phoneError = computedPhoneError;
                });

                if (computedAgeError != null) return;
                if (computedNameError != null || computedPhoneError != null) {
                  return;
                }

                final patient =
                    existingPatient ?? Patient.fromJson({'id': uuid()});
                patient
                  ..title = _toTitleCaseForPatientPopup(rawName)
                  ..birth = parsedAge
                  ..gender = gender
                  ..phone = rawPhone
                  ..address = addressController.text.trim()
                  ..tags = selectedMedicalHistory.toList(growable: false)
                  ..drugHistorySuggestions =
                      selectedDrugHistory.toList(growable: false)
                  ..maternalHistorySuggestions =
                      selectedMaternalHistory.toList(growable: false)
                  ..habitsSuggestions =
                      selectedHabitsHistory.toList(growable: false)
                  ..referralSource = referral;
                patients.set(patient);
                Navigator.pop(dialogContext, patient);
              },
            ),
          ],
        ),
      );
    },
  );
}
