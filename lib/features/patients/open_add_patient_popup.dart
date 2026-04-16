import 'package:apexo/features/patients/patient_model.dart';
import 'package:apexo/features/patients/patient_history_suggestions.dart';
import 'package:apexo/features/patients/patients_store.dart';
import 'package:apexo/utils/uuid.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/material.dart' as material;

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

Future<Patient?> openAddPatientPopup({
  required BuildContext context,
  String initialInput = '',
}) async {
  final seed = initialInput.trim();
  final looksLikePhone = RegExp(r'^[+0-9\s()-]+$').hasMatch(seed);

  final nameController = TextEditingController(
    text: looksLikePhone ? '' : _toTitleCaseForPatientPopup(seed),
  );
  final ageController = TextEditingController();
  final phoneController =
      TextEditingController(text: looksLikePhone ? seed : '');
  final addressController = TextEditingController();
  final notesController = TextEditingController();

  int gender = 0;
  String referral = 'None';
  final selectedMedicalHistory = <String>{};
  final selectedDrugHistory = <String>{};
  final selectedMaternalHistory = <String>{};
  final selectedHabitsHistory = <String>{};
  String? nameError;
  String? ageError;
  String? phoneError;

  return showDialog<Patient>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (context, setStateDialog) => ContentDialog(
        title: Row(
          children: [
            const Expanded(
              child: Text(
                'Add Patient',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            IconButton(
              icon: const Icon(FluentIcons.chrome_close, size: 12),
              onPressed: () => Navigator.pop(dialogContext),
            ),
          ],
        ),
        content: SizedBox(
          width: 700,
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
                            onChanged: (_) {
                              if (ageError != null) {
                                setStateDialog(() => ageError = null);
                              }
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _popupFieldLabel('Gender:'),
                          ComboBox<int>(
                            value: gender,
                            isExpanded: true,
                            items: const [
                              ComboBoxItem(value: 1, child: Text('Male')),
                              ComboBoxItem(value: 0, child: Text('Female')),
                            ],
                            onChanged: (v) =>
                                setStateDialog(() => gender = v ?? 0),
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
                const SizedBox(height: 8),
                _popupFieldLabel('Phone:'),
                TextBox(
                  controller: phoneController,
                  placeholder: 'Phone',
                  keyboardType: material.TextInputType.number,
                  onChanged: (_) {
                    if (phoneError != null) {
                      setStateDialog(() => phoneError = null);
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
                const SizedBox(height: 8),
                _popupFieldLabel('Address:'),
                TextBox(
                  controller: addressController,
                  placeholder: 'Address',
                ),
                const SizedBox(height: 8),
                _popupFieldLabel('Notes:'),
                TextBox(
                  controller: notesController,
                  placeholder: 'Notes',
                  maxLines: 3,
                ),
                const SizedBox(height: 8),
                _popupFieldLabel('Medical History:'),
                _buildSelectableHistoryChips(
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
                const SizedBox(height: 8),
                _popupFieldLabel('Drug History:'),
                _buildSelectableHistoryChips(
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
                const SizedBox(height: 8),
                _popupFieldLabel('Maternal History:'),
                _buildSelectableHistoryChips(
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
                const SizedBox(height: 8),
                _popupFieldLabel('Habits:'),
                _buildSelectableHistoryChips(
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
                const SizedBox(height: 8),
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
          Button(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Close'),
          ),
          FilledButton(
            onPressed: () {
              final rawName = nameController.text.trim();
              final parsedAge = int.tryParse(ageController.text.trim()) ?? 0;
              final rawPhone = phoneController.text.trim();

              final computedNameError =
                  rawName.isEmpty ? 'Patient name is required.' : null;
              final computedAgeError =
                  parsedAge <= 0 ? 'Age is required.' : null;
              final computedPhoneError =
                  rawPhone.isEmpty ? 'Phone number is required.' : null;

              setStateDialog(() {
                nameError = computedNameError;
                ageError = computedAgeError;
                phoneError = computedPhoneError;
              });

              if (computedAgeError != null) return;
              if (computedNameError != null || computedPhoneError != null) {
                return;
              }

              final patient = Patient.fromJson({
                'id': uuid(),
                'title': _toTitleCaseForPatientPopup(rawName),
                'birth': parsedAge,
                'gender': gender,
                'phone': rawPhone,
                'address': addressController.text.trim(),
                'notes': notesController.text.trim(),
                'tags': selectedMedicalHistory.toList(growable: false),
                'drugHistorySuggestions':
                  selectedDrugHistory.toList(growable: false),
                'maternalHistorySuggestions':
                  selectedMaternalHistory.toList(growable: false),
                'habitsSuggestions':
                  selectedHabitsHistory.toList(growable: false),
                'referralSource': referral,
              });
              patients.set(patient);
              Navigator.pop(dialogContext, patient);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    ),
  );
}
