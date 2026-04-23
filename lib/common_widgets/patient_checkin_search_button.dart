import 'package:apexo/common_widgets/patient_checkin_lookup_dialog.dart';
import 'package:apexo/features/appointments/appointment_model.dart';
import 'package:apexo/features/appointments/appointments_store.dart';
import 'package:apexo/features/patients/patient_model.dart';
import 'package:apexo/features/patients/patients_store.dart';
import 'package:apexo/core/ui/components/app_button.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:intl/intl.dart';

class PatientCheckinSearchButton extends StatefulWidget {
  final DateTime selectedDate;
  final Future<Patient?> Function(String query) onAddPatient;
  final Future<void> Function(Appointment appointment) onOpenExisting;
  final Future<void> Function(Patient patient) onCheckInPatient;
  final String title;
  final bool compact;
  final bool showInput;

  const PatientCheckinSearchButton({
    super.key,
    required this.selectedDate,
    required this.onAddPatient,
    required this.onOpenExisting,
    required this.onCheckInPatient,
    this.title = 'Search Patient',
    this.compact = false,
    this.showInput = true,
  });

  @override
  State<PatientCheckinSearchButton> createState() =>
      _PatientCheckinSearchButtonState();
}

class _PatientCheckinSearchButtonState extends State<PatientCheckinSearchButton> {
  late final TextEditingController _queryController;
  List<Patient> _matches = const [];
  bool _showInlineResults = false;

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

  bool _sameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  Appointment? _todayAppointmentFor(Patient patient) {
    final todayRows = appointments.present.values
        .where((a) => a.patientID == patient.id && _sameDay(a.date, widget.selectedDate))
        .toList(growable: false);
    if (todayRows.isEmpty) return null;
    todayRows.sort((a, b) => a.date.compareTo(b.date));
    return todayRows.last;
  }

  void _refreshInlineResults(String raw) {
    final query = raw.trim().toLowerCase();
    if (query.isEmpty) {
      setState(() {
        _matches = const [];
        _showInlineResults = false;
      });
      return;
    }

    final rows = patients.present.values
        .where((p) {
          final name = p.title.toLowerCase();
          final phone = p.phone.toLowerCase();
          return name.contains(query) || phone.contains(query);
        })
        .take(8)
        .toList(growable: false);

    setState(() {
      _matches = rows;
      _showInlineResults = rows.isNotEmpty;
    });
  }

  Future<void> _openSearch(BuildContext context) async {
    setState(() => _showInlineResults = false);
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

  String _statusLabel(Appointment? existing) {
    if (existing == null) return 'No appointment today';
    final stage = existing.checkinStage.trim().toLowerCase();
    if (stage == 'waiting') return 'Waiting';
    if (stage == 'scheduled' || stage == 'pending') {
      return 'Scheduled ${DateFormat('h:mm a').format(existing.date)}';
    }
    if (stage == 'with_doctor' || stage == 'treatment') return 'With doctor';
    if (stage == 'checkout') return 'Billing';
    if (stage == 'completed' || existing.isDone) return 'Completed';
    return stage;
  }

  Future<void> _onSelectPatient(Patient patient) async {
    final existing = _todayAppointmentFor(patient);
    setState(() => _showInlineResults = false);
    if (existing != null) {
      await widget.onOpenExisting(existing);
      return;
    }
    await widget.onCheckInPatient(patient);
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.showInput) {
      return AppButton(
        label: widget.title,
        onPressed: () => _openSearch(context),
        leading: const Icon(FluentIcons.search, size: 12),
        expanded: true,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: TextBox(
                controller: _queryController,
                placeholder: 'Search by name or phone',
                prefix: const Padding(
                  padding: EdgeInsets.only(left: 8),
                  child: Icon(FluentIcons.search, size: 12),
                ),
                onChanged: _refreshInlineResults,
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
              AppButton(
                label: 'Search',
                onPressed: () => _openSearch(context),
              ),
          ],
        ),
        AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutBack,
          margin: EdgeInsets.only(top: _showInlineResults ? 8 : 0),
          height: _showInlineResults ? null : 0,
          child: _showInlineResults
              ? Container(
                  constraints: const BoxConstraints(maxHeight: 280),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFD8E3EF)),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x140D2F5B),
                        blurRadius: 12,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: _matches.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 1.0),
                    itemBuilder: (context, index) {
                      final patient = _matches[index];
                      final existing = _todayAppointmentFor(patient);
                      final name = patient.title.trim().isEmpty
                          ? 'Unnamed patient'
                          : patient.title;
                      final phone = patient.phone.trim().isEmpty ? '-' : patient.phone;
                      return ListTile.selectable(
                        title: Text(name),
                        subtitle: Text('$phone • ${_statusLabel(existing)}'),
                        onPressed: () => _onSelectPatient(patient),
                      );
                    },
                  ),
                )
              : const SizedBox.shrink(),
        ),
      ],
    );
  }
}
