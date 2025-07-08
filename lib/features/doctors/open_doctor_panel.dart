import 'package:apexo/app/routes.dart';
import 'package:apexo/common_widgets/appointments_list_footer.dart';
import 'package:apexo/core/multi_stream_builder.dart';
import 'package:apexo/features/appointments/appointments_store.dart';
import 'package:apexo/services/archived.dart';
import 'package:apexo/services/localization/locale.dart';
import 'package:apexo/common_widgets/appointment_card.dart';
import 'package:apexo/common_widgets/tag_input.dart';
import 'package:apexo/services/login.dart';
import 'package:apexo/features/doctors/doctors_store.dart';
import 'package:apexo/features/doctors/doctor_model.dart';
import 'package:apexo/services/network.dart';
import 'package:apexo/services/users.dart';
import 'package:apexo/widget_keys.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/cupertino.dart';

void openDoctor([Doctor? doctor, int defaultTabIndex = 0]) {
  final editingCopy = Doctor.fromJson(doctor?.toJson() ?? {});
  late Panel panel;

  // Create a placeholder for the tabs
  late List<PanelTab> tabs;

  panel = Panel(
    item: editingCopy,
    store: doctors,
    icon: FluentIcons.medical,
    title: doctors.get(editingCopy.id) == null
        ? txt("newDoctor")
        : editingCopy.title,
    tabs: [],
  );

  // Now that panel is assigned, create the tabs
  tabs = [
    PanelTab(
      title: txt("doctorDetails"),
      icon: FluentIcons.medical,
      body: _DoctorDetails(editingCopy),
    ),
    PanelTab(
      title: "Appointments",
      icon: FluentIcons.calendar_reply,
      body: _AllAppointments(editingCopy),
      onlyIfSaved: true,
      padding: 0,
      footer: AppointmentsListFooter(forDoctorID: editingCopy.id),
    )
  ];

  // Assign the tabs to the panel
  panel.tabs.clear();
  panel.tabs.addAll(tabs);

  panel.selectedTab(defaultTabIndex);
  routes.openPanel(panel);
}

class _DoctorDetails extends StatelessWidget {
  final Doctor doctor;
  const _DoctorDetails(this.doctor);
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        InfoLabel(
          label: "${txt("doctorName")}:",
          child: CupertinoTextField(
            key: WK.fieldDoctorName,
            controller: TextEditingController(text: doctor.title),
            placeholder: "${txt("doctorName")}...",
            onChanged: (val) {
              doctor.title = val;
            },
          ),
        ),
        InfoLabel(
          label: "${txt("doctorEmail")}:",
          child: CupertinoTextField(
            key: WK.fieldDoctorEmail,
            controller: TextEditingController(text: doctor.email),
            placeholder: "${txt("doctorEmail")}...",
            onChanged: (val) {
              doctor.email = val;
            },
          ),
        ),
        InfoLabel(
          label: "${txt("dutyDays")}:",
          child: TagInputWidget(
            key: WK.fieldDutyDays,
            suggestions: [
              ...allDays.map((e) => TagInputItem(value: e, label: txt(e)))
            ],
            onChanged: (data) {
              doctor.dutyDays = data
                  .map((e) => e.value ?? "")
                  .where((e) => e.isNotEmpty)
                  .toList();
            },
            initialValue: [
              ...doctor.dutyDays
                  .map((e) => TagInputItem(value: e, label: txt(e)))
            ],
            strict: true,
            limit: 7,
          ),
        ),
        if (login.isAdmin && network.isOnline())
          InfoLabel(
            label: "${txt("lockToUsers")}:",
            child: TagInputWidget(
              suggestions: [
                ...users.list().map(
                    (e) => TagInputItem(value: e.id, label: e.data["email"]))
              ],
              onChanged: (data) {
                doctor.lockToUserIDs = data
                    .map((e) => e.value ?? "")
                    .where((e) => e.isNotEmpty)
                    .toList();
              },
              initialValue: [
                ...doctor.lockToUserIDs.map((e) => TagInputItem(
                    value: e,
                    label: users
                            .list()
                            .where((u) => u.id == e)
                            .firstOrNull
                            ?.data["email"] ??
                        "NOT FOUND: $e")),
              ],
              strict: true,
              limit: 9999,
            ),
          ),
      ].map((e) => [e, const SizedBox(height: 10)]).expand((e) => e).toList(),
    );
  }
}

class _AllAppointments extends StatelessWidget {
  final Doctor doctor;
  const _AllAppointments(this.doctor);
  @override
  Widget build(BuildContext context) {
    return MStreamBuilder(
        streams: [appointments.observableMap.stream, showArchived.stream],
        builder: (context, snapshot) {
          return doctor.allAppointments.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: InfoBar(
                        title: Txt(txt("noUpcomingAppointmentsForThisDoctor"))),
                  ),
                )
              : Column(
                  children: [
                    ...List.generate(doctor.allAppointments.length, (index) {
                      final reversedIndex =
                          doctor.allAppointments.length - 1 - index;
                      final appointment = doctor.allAppointments[reversedIndex];
                      String? difference;
                      if (reversedIndex != doctor.allAppointments.length - 1) {
                        int differenceInDays = appointment.date
                            .difference(
                                doctor.allAppointments[reversedIndex + 1].date)
                            .inDays
                            .abs();
                        difference =
                            "${txt("before")} $differenceInDays ${txt("day${(differenceInDays > 1) ? "s" : ""}")}";
                      }
                      return AppointmentCard(
                        key: Key(appointment.id),
                        appointment: appointment,
                        difference: difference,
                        hide: const [
                          AppointmentSections.doctors,
                        ],
                        number: reversedIndex + 1,
                      );
                    }),
                  ],
                );
        });
  }
}
