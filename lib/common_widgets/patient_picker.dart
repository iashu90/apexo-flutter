import 'package:apexo/services/localization/locale.dart';
import 'package:apexo/features/patients/open_add_patient_popup.dart';
import 'package:apexo/common_widgets/tag_input.dart';
import 'package:apexo/features/patients/patient_model.dart';
import 'package:apexo/features/patients/patients_store.dart';
import 'package:apexo/utils/clinic_time.dart';
import 'package:apexo/widget_keys.dart';
import 'package:fluent_ui/fluent_ui.dart';

class PatientPicker extends StatelessWidget {
  final void Function(String? id) onChanged;
  final String? value;
  final bool allowEditFromSelectedTagTap;
  final bool useCustomSuggestionPanel;
  const PatientPicker(
      {super.key,
      required this.onChanged,
      required this.value,
      this.allowEditFromSelectedTagTap = false,
      this.useCustomSuggestionPanel = true});

  String _suggestionLabel(Patient patient) {
    final name =
        patient.title.trim().isEmpty ? 'Unnamed patient' : patient.title.trim();
    final phone = patient.phone.trim().isEmpty ? '-' : patient.phone.trim();
    final visits = patient.allAppointments.length;
    final lastVisit = visits == 0
        ? 'No visits'
        : formatClinicDate(patient.allAppointments.last.date, pattern: 'dd MMM yyyy');
    return '$name $phone ${patient.age} $lastVisit $visits';
  }

  Widget _suggestionRow(Patient patient) {
    final name =
        patient.title.trim().isEmpty ? 'Unnamed patient' : patient.title.trim();
    final phone = patient.phone.trim().isEmpty ? '-' : patient.phone.trim();
    final visits = patient.allAppointments.length;
    final lastVisit = visits == 0
        ? 'No visits'
        : formatClinicDate(patient.allAppointments.last.date, pattern: 'dd MMM yyyy');
    return SizedBox(
      width: 440,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 2),
            child: Icon(
              FluentIcons.contact,
              size: 12,
              color: Color(0xFF2D7BD8),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '$name • ${patient.age}y • $phone',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF173A67),
                    fontSize: 12,
                  ),
                ),
                Text(
                  'Last: $lastVisit • Visits: $visits',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF557294),
                    fontSize: 11,
                    height: 1.25,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _selectedLabel(String patientId) {
    final patient = patients.get(patientId);
    if (patient == null) return 'Unknown patient';
    final name = patient.title.trim().isEmpty ? 'Unnamed patient' : patient.title;
    final phone = patient.phone.trim().isEmpty ? '-' : patient.phone.trim();
    return '$name • $phone';
  }

  @override
  Widget build(BuildContext context) {
    return TagInputWidget(
      key: WK.fieldPatient,
      onItemTap: allowEditFromSelectedTagTap
          ? (tag) {
              Patient? tapped = patients.get(tag.value ?? "");
              if (tapped == null) return;
              openAddPatientPopup(context: context, existingPatient: tapped);
            }
          : null,
      suggestions: patients.present.values
          .map((e) => TagInputItem(
                value: e.id,
                label: _suggestionLabel(e),
                child: _suggestionRow(e),
              ))
          .toList(),
      onChanged: (s) {
        if (s.isEmpty) return onChanged(null);
        onChanged(s.first.value ?? "");
      },
      initialValue: value != null
          ? [TagInputItem(value: value!, label: _selectedLabel(value!))]
          : [],
      strict: true,
      limit: 1,
      useCustomSuggestionPanel: useCustomSuggestionPanel,
      placeholder: txt("selectPatient"),
    );
  }
}
