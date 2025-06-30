import 'package:apexo/common_widgets/delete_confirmation.dart';
import 'package:apexo/core/multi_stream_builder.dart';
import 'package:apexo/features/appointments/appointment_model.dart';
import 'package:apexo/features/appointments/appointments_store.dart';
import 'package:apexo/services/localization/locale.dart';
import 'package:apexo/features/appointments/open_appointment_panel.dart';
import 'package:apexo/features/doctors/open_doctor_panel.dart';
import 'package:apexo/features/doctors/doctors_store.dart';
import 'package:apexo/features/doctors/doctor_model.dart';
import 'package:apexo/widget_keys.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:url_launcher/url_launcher.dart';
import "../../common_widgets/datatable.dart";

class DoctorsScreen extends StatelessWidget {
  const DoctorsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ScaffoldPage(
      key: WK.doctorsScreen,
      padding: EdgeInsets.zero,
      content: MStreamBuilder(
          streams: [
            doctors.observableMap.stream,
            appointments.observableMap.stream
          ],
          builder: (context, snapshot) {
            return DataTable<Doctor>(
              items: doctors.present.values.toList(),
              store: doctors,
              actions: [
                DataTableAction(
                  callback: (_) => openDoctor(),
                  icon: FluentIcons.medical,
                  title: txt("add"),
                ),
                DataTableAction(
                  icon: FluentIcons.delete,
                  title: txt("delete"),
                  enabled: (ids) => ids.isNotEmpty,
                  callback: (ids) async {
                    final names = ids
                        .map((id) {
                          final doc = doctors.get(id);
                          if (doc == null) return null;
                          return doc.title;
                        })
                        .where((str) => str != null && str.isNotEmpty)
                        .join("\n");
                    final confirmed = await showConfirmDeleteDialog(
                      context,
                      message:
                          "Are you sure you want to delete the selected doctors?",
                      customDetails: names.isNotEmpty ? names : null,
                    );
                    if (confirmed == true) {
                      for (final id in ids) {
                        await doctors.hardDelete(id);
                      }
                    }
                  },
                ),
              ],
              furtherActions: [
                const SizedBox(width: 5),
              ],
              onSelect: (item) => openDoctor(item),
              itemActions: [
                ItemAction(
                  icon: FluentIcons.add_event,
                  title: txt("addAppointment"),
                  callback: (id) async {
                    openAppointment(Appointment.fromJson({
                      "operatorsIDs": [id]
                    }));
                  },
                ),
                ItemAction(
                  icon: FluentIcons.mail,
                  title: txt("emailDoctor"),
                  callback: (id) {
                    final doctor = doctors.get(id);
                    if (doctor == null) return;
                    launchUrl(Uri.parse('mailto:${doctor.email}'));
                  },
                ),
              ],
            );
          }),
    );
  }
}
