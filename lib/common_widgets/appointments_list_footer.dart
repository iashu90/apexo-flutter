import 'package:apexo/features/appointments/appointment_model.dart';
import 'package:apexo/features/appointments/open_appointment_panel.dart';
import 'package:apexo/features/labwork/labwork_model.dart';
import 'package:apexo/features/labwork/open_labwork_dialog.dart';
import 'package:apexo/services/localization/locale.dart';
import 'package:fluent_ui/fluent_ui.dart';

class AppointmentsListFooter extends StatelessWidget {
  final String? forDoctorID;
  final String? forPatientID;
  const AppointmentsListFooter({
    super.key,
    this.forDoctorID,
    this.forPatientID,
  });

  @override
  Widget build(BuildContext context) {
    return Acrylic(
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            FilledButton(
                child: Row(
                  children: [
                    const Icon(FluentIcons.add_event),
                    const SizedBox(width: 10),
                    Txt(txt("addAppointment"))
                  ],
                ),
                onPressed: () {
                  openAppointment(Appointment.fromJson({
                    if (forPatientID != null) "patientID": forPatientID,
                    if (forDoctorID != null) "operatorsIDs": [forDoctorID],
                  }));
                }),
            const SizedBox(width: 12),
            FilledButton(
              child: const Row(
                children: [
                  Icon(FluentIcons.test_beaker),
                  SizedBox(width: 10),
                  Txt("Add Labwork"),
                ],
              ),
              onPressed: () {
                openLabworkDialog(
                  context,
                   Labwork.fromJson({
                    if (forPatientID != null) "patientID": forPatientID,
                    if (forDoctorID != null) "operatorsIDs": [forDoctorID],
                  }),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

