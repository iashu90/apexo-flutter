import 'package:apexo/features/appointments/appointment_model.dart';
import 'package:apexo/features/appointments/appointments_store.dart';
import 'package:apexo/features/patients/patient_model.dart';
import 'package:apexo/features/patients/patients_store.dart';
import 'package:fluent_ui/fluent_ui.dart';

typedef PatientLookupAddPatient = Future<Patient?> Function(String query);
typedef PatientLookupOpenExisting = Future<void> Function(
  Appointment appointment,
);
typedef PatientLookupCheckInPatient = Future<void> Function(Patient patient);

Future<void> showPatientCheckinLookupDialog({
  required BuildContext context,
  required DateTime selectedDate,
  required PatientLookupAddPatient onAddPatient,
  required PatientLookupOpenExisting onOpenExisting,
  required PatientLookupCheckInPatient onCheckInPatient,
  String title = 'Patient Check-in',
}) async {
  await showDialog<void>(
    context: context,
    builder: (dialogContext) {
      final queryController = TextEditingController(text: '');
      String query = queryController.text.trim().toLowerCase();

      final allPatients = patients.present.values.toList(growable: false);
      final todaysAppointments = appointments.forDate(selectedDate);

      return StatefulBuilder(
        builder: (context, setDialogState) {
          final matches = allPatients
              .where((p) {
                if (query.isEmpty) return true;
                final name = p.title.toLowerCase();
                final phone = p.phone.toLowerCase();
                return name.contains(query) || phone.contains(query);
              })
              .take(40)
              .toList(growable: false);

          final hasExactMatch = query.isNotEmpty &&
              allPatients.any((p) {
                final name = p.title.trim().toLowerCase();
                final phone = p.phone.trim().toLowerCase();
                return name == query || phone == query;
              });

          return ContentDialog(
            title: Row(
              children: [
                Expanded(child: Text(title)),
                IconButton(
                  icon: const Icon(FluentIcons.chrome_close, size: 12),
                  onPressed: () => Navigator.pop(dialogContext),
                ),
              ],
            ),
            content: SizedBox(
              width: 520,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextBox(
                    controller: queryController,
                    placeholder: 'Search by patient name or phone',
                    autofocus: true,
                    prefix: const Padding(
                      padding: EdgeInsets.only(left: 10),
                      child: Icon(
                        FluentIcons.search,
                        size: 12,
                        color: Color(0xFF6D84A8),
                      ),
                    ),
                    onChanged: (value) {
                      setDialogState(() => query = value.trim().toLowerCase());
                    },
                  ),
                  if (query.isNotEmpty && !hasExactMatch) ...[
                    const SizedBox(height: 8),
                    FilledButton(
                      onPressed: () async {
                        final navigator = Navigator.of(dialogContext);
                        final created = await onAddPatient(queryController.text);
                        if (created == null) return;
                        await onCheckInPatient(created);
                        if (navigator.mounted) {
                          navigator.pop();
                        }
                      },
                      child: Text(
                        'Add "$query" as new patient',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                  const SizedBox(height: 10),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 420),
                    child: matches.isEmpty
                        ? const Center(
                            child: Padding(
                              padding: EdgeInsets.symmetric(vertical: 30),
                              child: Text(
                                'No matching patients.',
                                style: TextStyle(color: Color(0xFF6D84A8)),
                              ),
                            ),
                          )
                        : ListView.separated(
                            shrinkWrap: true,
                            itemCount: matches.length,
                            separatorBuilder: (_, __) => const Divider(size: 1),
                            itemBuilder: (context, index) {
                              final patient = matches[index];
                              final existing = todaysAppointments
                                  .where((a) => a.patientID == patient.id)
                                  .toList(growable: false)
                                  .lastOrNull;

                              return Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 2,
                                  vertical: 6,
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            patient.title.trim().isEmpty
                                                ? 'Unnamed patient'
                                                : patient.title,
                                            style: const TextStyle(
                                              color: Color(0xFF1F446E),
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            '${patient.phone} • ${patient.age}y',
                                            style: const TextStyle(
                                              color: Color(0xFF6D84A8),
                                              fontSize: 11,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    if (existing != null)
                                      Button(
                                        onPressed: () async {
                                          final navigator =
                                              Navigator.of(dialogContext);
                                          if (navigator.mounted) {
                                            navigator.pop();
                                          }
                                          await onOpenExisting(existing);
                                        },
                                        child: const Text('Open'),
                                      )
                                    else
                                      FilledButton(
                                        onPressed: () async {
                                          final navigator =
                                              Navigator.of(dialogContext);
                                          await onCheckInPatient(patient);
                                          if (navigator.mounted) {
                                            navigator.pop();
                                          }
                                        },
                                        child: const Text('Check-in'),
                                      ),
                                  ],
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
            actions: [
              Button(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Close'),
              ),
            ],
          );
        },
      );
    },
  );
}
