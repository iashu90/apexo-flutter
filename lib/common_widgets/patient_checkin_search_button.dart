import 'package:apexo/common_widgets/patient_checkin_lookup_dialog.dart';
import 'package:apexo/features/appointments/appointment_model.dart';
import 'package:apexo/features/patients/patient_model.dart';
import 'package:fluent_ui/fluent_ui.dart';

class PatientCheckinSearchButton extends StatefulWidget {
  final DateTime selectedDate;
  final Future<Patient?> Function(String query) onAddPatient;
  final Future<void> Function(Appointment appointment) onOpenExisting;
  final Future<void> Function(Patient patient) onCheckInPatient;
  final String title;
  final bool compact;

  const PatientCheckinSearchButton({
    super.key,
    required this.selectedDate,
    required this.onAddPatient,
    required this.onOpenExisting,
    required this.onCheckInPatient,
    this.title = 'Search Patient',
    this.compact = false,
  });

  @override
  State<PatientCheckinSearchButton> createState() =>
      _PatientCheckinSearchButtonState();
}

class _PatientCheckinSearchButtonState extends State<PatientCheckinSearchButton> {
  late final TextEditingController _queryController;

  @override
  void initState() {
    super.initState();
    _queryController = TextEditingController();
  }

  @override
  void dispose() {
    _queryController.dispose();
    super.dispose();
  }

  Future<void> _openSearch(BuildContext context) async {
    await showPatientCheckinLookupDialog(
      context: context,
      selectedDate: widget.selectedDate,
      title: widget.title,
      initialQuery: _queryController.text,
      onAddPatient: widget.onAddPatient,
      onOpenExisting: widget.onOpenExisting,
      onCheckInPatient: widget.onCheckInPatient,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: TextBox(
            controller: _queryController,
            placeholder: 'Search by name or phone',
            prefix: const Padding(
              padding: EdgeInsets.only(left: 8),
              child: Icon(FluentIcons.search, size: 12),
            ),
            onSubmitted: (_) => _openSearch(context),
          ),
        ),
        const SizedBox(width: 8),
        if (widget.compact)
          IconButton(
            icon: const Icon(FluentIcons.search, size: 12),
            onPressed: () => _openSearch(context),
          )
        else
          FilledButton(
            onPressed: () => _openSearch(context),
            child: const Text('Search'),
          ),
      ],
    );
  }
}
