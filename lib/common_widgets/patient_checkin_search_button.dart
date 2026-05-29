import 'dart:async';

import 'package:apexo/common_widgets/patient_checkin_lookup_dialog.dart';
import 'package:apexo/features/appointments/appointment_model.dart';
import 'package:apexo/features/appointments/appointments_store.dart';
import 'package:apexo/features/patients/patient_model.dart';
import 'package:apexo/features/patients/patients_store.dart';
import 'package:apexo/core/perf/perf_markers.dart';
import 'package:apexo/core/ui/components/app_button.dart';
import 'package:apexo/services/sync_priority.dart';
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
  StreamSubscription? _patientsSubscription;
  StreamSubscription? _appointmentsSubscription;
  List<_PatientSearchIndexEntry> _searchIndex = const [];
  Map<String, Appointment> _todayAppointmentByPatient = const {};
  List<Patient> _matches = const [];
  bool _showInlineResults = false;

  @override
  void initState() {
    super.initState();
    _queryController = TextEditingController();
    _rebuildSearchIndex();
    _rebuildTodayAppointmentCache();
    _patientsSubscription = patients.observableMap.stream.listen((_) {
      if (!mounted) return;
      _rebuildSearchIndex();
      if (_queryController.text.trim().isNotEmpty) {
        _refreshInlineResults(_queryController.text);
      }
    });
    _appointmentsSubscription = appointments.observableMap.stream.listen((_) {
      if (!mounted) return;
      _rebuildTodayAppointmentCache();
      if (_showInlineResults) {
        setState(() {});
      }
    });
  }

  @override
  void didUpdateWidget(covariant PatientCheckinSearchButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_sameDay(oldWidget.selectedDate, widget.selectedDate)) {
      _rebuildTodayAppointmentCache();
      if (_showInlineResults) {
        setState(() {});
      }
    }
  }

  @override
  void dispose() {
    _patientsSubscription?.cancel();
    _appointmentsSubscription?.cancel();
    _queryController.dispose();
    super.dispose();
  }

  bool _sameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  Appointment? _todayAppointmentFor(Patient patient) {
    return _todayAppointmentByPatient[patient.id];
  }

  void _rebuildSearchIndex() {
    final entries = <_PatientSearchIndexEntry>[];
    for (final patient in patients.present.values) {
      entries.add(
        _PatientSearchIndexEntry(
          patient: patient,
          normalizedName: patient.title.toLowerCase(),
          normalizedPhone: patient.phone.toLowerCase(),
        ),
      );
    }
    _searchIndex = entries;
  }

  void _rebuildTodayAppointmentCache() {
    final byPatient = <String, Appointment>{};
    for (final appointment in appointments.present.values) {
      final pid = appointment.patientID;
      if (pid == null || pid.isEmpty) continue;
      if (!_sameDay(appointment.date, widget.selectedDate)) continue;
      final existing = byPatient[pid];
      if (existing == null || appointment.date.isAfter(existing.date)) {
        byPatient[pid] = appointment;
      }
    }
    _todayAppointmentByPatient = byPatient;
  }

  void _refreshInlineResults(String raw) {
    syncPriorityDeferral.markTyping();
    PerfMarkers.track(
      'checkin.search.inlineFilter',
      () {
        final query = raw.trim().toLowerCase();
        if (query.isEmpty) {
          setState(() {
            _matches = const [];
            _showInlineResults = false;
          });
          return;
        }

        final rows = _searchIndex
            .where((entry) =>
                entry.normalizedName.contains(query) ||
                entry.normalizedPhone.contains(query))
            .take(8)
            .map((entry) => entry.patient)
            .toList(growable: false);

        setState(() {
          _matches = rows;
          _showInlineResults = rows.isNotEmpty;
        });
      },
      data: {
        'queryLen': raw.trim().length,
      },
    );
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

class _PatientSearchIndexEntry {
  final Patient patient;
  final String normalizedName;
  final String normalizedPhone;

  const _PatientSearchIndexEntry({
    required this.patient,
    required this.normalizedName,
    required this.normalizedPhone,
  });
}
