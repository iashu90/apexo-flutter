import 'package:apexo/common_widgets/patient_checkin_lookup_dialog.dart';
import 'package:apexo/features/appointments/appointment_model.dart';
import 'package:apexo/features/patients/patient_model.dart';
import 'package:fluent_ui/fluent_ui.dart';

class PatientCheckinSearchButton extends StatelessWidget {
  final DateTime selectedDate;
  final Future<Patient?> Function(String query) onAddPatient;
  final Future<void> Function(Appointment appointment) onOpenExisting;
  final Future<void> Function(Patient patient) onCheckInPatient;
  final String title;
  final bool filled;

  const PatientCheckinSearchButton({
    super.key,
    required this.selectedDate,
    required this.onAddPatient,
    required this.onOpenExisting,
    required this.onCheckInPatient,
    this.title = 'Search Patient',
    this.filled = true,
  });

  Future<void> _openSearch(BuildContext context) async {
    await showPatientCheckinLookupDialog(
      context: context,
      selectedDate: selectedDate,
      title: title,
      onAddPatient: onAddPatient,
      onOpenExisting: onOpenExisting,
      onCheckInPatient: onCheckInPatient,
    );
  }

  @override
  Widget build(BuildContext context) {
    const child = Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(FluentIcons.search, size: 12),
        SizedBox(width: 8),
        Text('Search Patient'),
      ],
    );

    if (filled) {
      return FilledButton(
        onPressed: () => _openSearch(context),
        child: child,
      );
    }

    return Button(
      onPressed: () => _openSearch(context),
      child: child,
    );
  }
}
