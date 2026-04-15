import 'package:apexo/features/patients/patient_model.dart';
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

Future<Patient?> openAddPatientPopup({
  required BuildContext context,
  String initialInput = '',
  List<String> medicalHistorySuggestions = const <String>[
    'Antibiotics (Penicillin)',
    'Latex Allergy',
    'Local Anesthetics',
    'Hypertension (High BP)',
    'Heart Attack / Stroke',
    'Artificial Heart Valves',
    'Blood Thinners (Anticoagulants)',
    'Diabetes (HbA1c levels)',
    'GLP-1 Agonists (Ozempic/Wegovy)',
    'Osteoporosis (Bisphosphonates)',
    'Joint Replacement',
    'Asthma',
    'Sleep Apnea / Snoring',
    'Hepatitis (B or C)',
    'HIV / AIDS',
    'Epilepsy / Seizures',
    'Anxiety / Dental Phobia',
    'Tobacco / Vaping',
    'Alcohol Consumption',
    'Pregnancy',
  ],
}) async {
  final seed = initialInput.trim();
  final looksLikePhone = RegExp(r'^[+0-9\s()-]+$').hasMatch(seed);

  final nameController = TextEditingController(
    text: looksLikePhone ? '' : _toTitleCaseForPatientPopup(seed),
  );
  final ageController = TextEditingController();
  final phoneController = TextEditingController(text: looksLikePhone ? seed : '');
  final addressController = TextEditingController();
  final notesController = TextEditingController();
  final customHistoryController = TextEditingController();

  int gender = 0;
  String referral = 'None';
  final selectedMedicalHistory = <String>{};
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
          width: 520,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                InfoLabel(
                  label: 'Name:',
                  child: TextBox(
                    controller: nameController,
                    placeholder: 'Patient name',
                    onChanged: (_) {
                      if (nameError != null) {
                        setStateDialog(() => nameError = null);
                      }
                    },
                  ),
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
                      child: InfoLabel(
                        label: 'Age:',
                        child: TextBox(
                          controller: ageController,
                          placeholder: 'Age',
                          keyboardType: material.TextInputType.number,
                          onChanged: (_) {
                            if (ageError != null) {
                              setStateDialog(() => ageError = null);
                            }
                          },
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: InfoLabel(
                        label: 'Gender:',
                        child: ComboBox<int>(
                          value: gender,
                          isExpanded: true,
                          items: const [
                            ComboBoxItem(value: 1, child: Text('Male')),
                            ComboBoxItem(value: 0, child: Text('Female')),
                          ],
                          onChanged: (v) => setStateDialog(() => gender = v ?? 0),
                        ),
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
                InfoLabel(
                  label: 'Phone:',
                  child: TextBox(
                    controller: phoneController,
                    placeholder: 'Phone',
                    keyboardType: material.TextInputType.number,
                    onChanged: (_) {
                      if (phoneError != null) {
                        setStateDialog(() => phoneError = null);
                      }
                    },
                  ),
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
                InfoLabel(
                  label: 'Address:',
                  child: TextBox(
                    controller: addressController,
                    placeholder: 'Address',
                  ),
                ),
                const SizedBox(height: 8),
                InfoLabel(
                  label: 'Notes:',
                  child: TextBox(
                    controller: notesController,
                    placeholder: 'Notes',
                    maxLines: 3,
                  ),
                ),
                const SizedBox(height: 8),
                InfoLabel(
                  label: 'Medical History:',
                  child: SizedBox.shrink(),
                ),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: medicalHistorySuggestions.map((item) {
                    final selected = selectedMedicalHistory.contains(item);
                    return GestureDetector(
                      onTap: () {
                        setStateDialog(() {
                          if (selected) {
                            selectedMedicalHistory.remove(item);
                          } else {
                            selectedMedicalHistory.add(item);
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
                          item,
                          style: TextStyle(
                            color: selected
                                ? Colors.white
                                : const Color(0xFF345982),
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    );
                  }).toList(growable: false),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextBox(
                        controller: customHistoryController,
                        placeholder: 'Add custom medical history item',
                      ),
                    ),
                    const SizedBox(width: 8),
                    FilledButton(
                      onPressed: () {
                        final custom = customHistoryController.text.trim();
                        if (custom.isEmpty) return;
                        setStateDialog(() {
                          selectedMedicalHistory.add(custom);
                          customHistoryController.clear();
                        });
                      },
                      child: const Text('Add'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                InfoLabel(
                  label: 'Referral:',
                  child: ComboBox<String>(
                    isExpanded: true,
                    value: referral,
                    items: const [
                      ComboBoxItem(value: 'None', child: Text('None')),
                      ComboBoxItem(value: 'Google', child: Text('Google')),
                      ComboBoxItem(value: 'Social Media', child: Text('Social Media')),
                      ComboBoxItem(value: 'Friends', child: Text('Friends')),
                      ComboBoxItem(value: 'Camps', child: Text('Camps')),
                      ComboBoxItem(value: 'Name Board', child: Text('Name Board')),
                    ],
                    onChanged: (v) => setStateDialog(() => referral = v ?? 'None'),
                  ),
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
              final computedAgeError = parsedAge <= 0 ? 'Age is required.' : null;
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
