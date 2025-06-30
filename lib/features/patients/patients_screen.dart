import 'package:apexo/common_widgets/delete_confirmation.dart';
import 'package:apexo/common_widgets/dialogs/export_patients_dialog.dart';
import 'package:apexo/core/multi_stream_builder.dart';
import 'package:apexo/features/appointments/appointment_model.dart';
import 'package:apexo/features/appointments/appointments_store.dart';
import 'package:apexo/services/localization/locale.dart';
import 'package:apexo/features/appointments/open_appointment_panel.dart';
import 'package:apexo/features/patients/open_patient_panel.dart';
import 'package:apexo/features/patients/patient_model.dart';
import 'package:apexo/features/patients/patients_store.dart';
import 'package:apexo/widget_keys.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:url_launcher/url_launcher.dart';
import "../../common_widgets/datatable.dart";

class PatientsScreen extends StatefulWidget {
  const PatientsScreen({super.key});

  @override
  _PatientsScreenState createState() => _PatientsScreenState();
}

class _PatientsScreenState extends State<PatientsScreen> {
  @override
  Widget build(BuildContext context) {
    return ScaffoldPage(
      key: WK.patientsScreen,
      padding: EdgeInsets.zero,
      content: Column(
        children: [
          Expanded(
            child: MStreamBuilder(
              streams: [
                patients.observableMap.stream,
                appointments.observableMap.stream
              ],
              builder: (context, snapshot) {
                return DataTable<Patient>(
                  items: patients.present.values.toList(),
                  store: patients,
                  actions: [
                    DataTableAction(
                      callback: (_) async {
                        openPatient();
                      },
                      icon: FluentIcons.add_friend,
                      title: txt("add"),
                    ),
                    DataTableAction(
                      enabled: (ids) => ids.isNotEmpty,
                      callback: (ids) async {
                        // Get the names of the selected patients
                        final names = ids
                            .map((id) => patients.get(id)?.title)
                            .where((name) => name != null && name.isNotEmpty)
                            .join(", ");

                        final confirmed = await showConfirmDeleteDialog(
                          context,
                          message:
                              "Are you sure you want to delete the selected patients?",
                          customDetails: names.isNotEmpty
                              ? ids
                                  .map((id) => patients.get(id)?.title)
                                  .where(
                                      (name) => name != null && name.isNotEmpty)
                                  .join("\n")
                              : null,
                        );
                        if (confirmed == true) {
                          for (final id in ids) {
                            // Delete all appointments for this patient
                            final relatedAppointments = appointments
                                .present.values
                                .where((a) => a.patientID == id)
                                .toList();
                            // Now delete the patient
                            await patients.hardDelete(id);
                            for (final appointment in relatedAppointments) {
                              await appointments.hardDelete(appointment.id);
                            }
                          }
                        }
                      },
                      icon: FluentIcons.delete,
                      title: txt("delete"),
                    ),
                    DataTableAction(
                      callback: (ids) {
                        showDialog(
                          context: context,
                          builder: (BuildContext context) {
                            return ExportPatientsDialog(ids: ids);
                          },
                        );
                      },
                      icon: FluentIcons.guid,
                      title: txt("exportSelected"),
                    ),
                  ],
                  furtherActions: [
                    const SizedBox(width: 5),
                  ],
                  onSelect: openPatient,
                  itemActions: [
                    ItemAction(
                      icon: FluentIcons.add_event,
                      title: txt("addAppointment"),
                      callback: (id) async {
                        final patient = patients.get(id);
                        if (patient == null) return;
                        if (context.mounted) {
                          openAppointment(
                              Appointment.fromJson({"patientID": id}));
                        }
                      },
                    ),
                    ItemAction(
                      icon: FluentIcons.phone,
                      title: txt("callPatient"),
                      callback: (id) {
                        final patient = patients.get(id);
                        if (patient == null) return;
                        launchUrl(Uri.parse('tel:${patient.phone}'));
                      },
                    ),
                  ],
                  hiddenColumns: ["Pay"],
                  columnBuilders: {
                    "Price": (patient) => patient.outstandingPayments == 0
                        ? const SizedBox.shrink()
                        : Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: patient.overPaid
                                  ? Colors.green.withOpacity(0.15)
                                  : Colors.red.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              (patient.overPaid ? "+ ₹" : "- ₹") +
                                  patient.outstandingPayments
                                      .abs()
                                      .toStringAsFixed(2),
                              style: TextStyle(
                                color: patient.overPaid
                                    ? Colors.green
                                    : Colors.red,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                    // ...other column builders...
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
