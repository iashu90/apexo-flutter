import 'package:apexo/common_widgets/delete_confirmation.dart';
import 'package:apexo/common_widgets/dialogs/export_patients_dialog.dart';
import 'package:apexo/core/activity_logger.dart';
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
                        ActivityLogger.logAction(
                          "Add Patient Clicked",
                          screen: "PatientsScreen",
                        );
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

                        ActivityLogger.logAction(
                          "Delete Patients Clicked",
                          screen: "PatientsScreen",
                          data: {"patientNames": names},
                        );

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
                          // Gather all appointment delete futures
                          final appointmentDeleteFutures = <Future>[];
                          for (final id in ids) {
                            final relatedAppointments = appointments
                                .present.values
                                .where((a) => a.patientID == id)
                                .toList();
                            ActivityLogger.logAction(
                              "Appointments To Be Deleted",
                              screen: "PatientsScreen",
                              data: {
                                "patientId": id,
                                "patientName": patients.get(id)?.title,
                                "appointmentsCount": relatedAppointments.length,
                                "appointmentIds": relatedAppointments
                                    .map((a) => a.id)
                                    .toList(),
                              },
                            );
                            for (final appointment in relatedAppointments) {
                              appointmentDeleteFutures
                                  .add(appointments.hardDelete(appointment.id));
                            }
                          }

                          // Delete all patients in parallel
                          final patientDeleteFutures =
                              ids.map((id) => patients.hardDelete(id)).toList();

                          // Wait for all deletes (appointments and patients) in parallel
                          await Future.wait([
                            ...appointmentDeleteFutures,
                            ...patientDeleteFutures,
                          ]);
                        }
                      },
                      icon: FluentIcons.delete,
                      title: txt("delete"),
                    ),
                    DataTableAction(
                      callback: (ids) {
                        ActivityLogger.logAction(
                          "Export Selected Patients Clicked",
                          screen: "PatientsScreen",
                          data: {"ids": ids},
                        );
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
                  onSelect: (patient) => openPatient(patient, 1),
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
                  hiddenColumns: ["Pay", "T.Mode", 'Doc Paid', 'TotalDocPay'],
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
