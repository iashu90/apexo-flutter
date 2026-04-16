import 'package:apexo/services/localization/locale.dart';
import 'package:apexo/features/patients/open_add_patient_popup.dart';
import 'package:apexo/common_widgets/tag_input.dart';
import 'package:apexo/features/patients/patient_model.dart';
import 'package:apexo/features/patients/patients_store.dart';
import 'package:apexo/widget_keys.dart';
import 'package:fluent_ui/fluent_ui.dart';

class PatientPicker extends StatelessWidget {
  final void Function(String? id) onChanged;
  final String? value;
  const PatientPicker(
      {super.key, required this.onChanged, required this.value});

  @override
  Widget build(BuildContext context) {
    return TagInputWidget(
      key: WK.fieldPatient,
      onItemTap: (tag) {
        Patient? tapped = patients.get(tag.value ?? "");
        if (tapped == null) return;
        openAddPatientPopup(context: context, existingPatient: tapped);
      },
      suggestions: patients.present.values
          .map((e) => TagInputItem(
                value: e.id,
                label: "${e.title}-${e.phone}",
              ))
          .toList(),
      onChanged: (s) {
        if (s.isEmpty) return onChanged(null);
        onChanged(s.first.value ?? "");
      },
      initialValue: value != null
          ? [TagInputItem(value: value!, label: patients.get(value!)!.title)]
          : [],
      strict: true,
      limit: 1,
      placeholder: txt("selectPatient"),
    );
  }
}
