import 'package:apexo/common_widgets/dialogs/export_patients_dialog.dart';
import 'package:apexo/core/multi_stream_builder.dart';
import 'package:apexo/features/appointments/appointment_model.dart';
import 'package:apexo/features/appointments/appointments_store.dart';
import 'package:apexo/services/localization/locale.dart';
import 'package:apexo/features/appointments/open_appointment_panel.dart';
import 'package:apexo/features/patients/open_patient_panel.dart';
import 'package:apexo/common_widgets/archive_selected.dart';
import 'package:apexo/common_widgets/archive_toggle.dart';
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
                    archiveSelected(patients),
                    DataTableAction(
                      callback: (ids) {
                        showDialog(
                            context: context,
                            builder: (BuildContext context) {
                              return ExportPatientsDialog(ids: ids);
                            });
                      },
                      icon: FluentIcons.guid,
                      title: txt("exportSelected"),
                    ),
                  ],
                  furtherActions: [
                    const SizedBox(width: 5),
                    ArchiveToggle(notifier: patients.notify)
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
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
