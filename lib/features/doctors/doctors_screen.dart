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
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import "../../common_widgets/datatable.dart";
import 'package:flutter/material.dart' as material;

final dataTableKey = GlobalKey<DataTableState<Doctor>>();

class DoctorsScreen extends StatefulWidget {
  const DoctorsScreen({super.key});
  @override
  State<DoctorsScreen> createState() => _DoctorsScreenState();
}

class _DoctorsScreenState extends State<DoctorsScreen> {
  DateTime selectedDate = DateTime.now();
  bool onlyToday = true;

  @override
  Widget build(BuildContext context) {
    // Filter doctors based on onlyToday
    final filteredDoctors = onlyToday
        ? doctors.present.values
            .where((doctor) => doctor.allAppointments.any((a) =>
                a.date.year == selectedDate.year &&
                a.date.month == selectedDate.month &&
                a.date.day == selectedDate.day))
            .toList()
        : doctors.present.values.toList();

    return ScaffoldPage(
      key: WK.doctorsScreen,
      padding: EdgeInsets.zero,
      content: MStreamBuilder(
          streams: [
            doctors.observableMap.stream,
            appointments.observableMap.stream
          ],
          builder: (context, snapshot) {
            return Column(
              children: [
                Expanded(
                  child: DataTable<Doctor>(
                    key: dataTableKey,
                    customHeader: _buildDoctorDateFilterButton(),
                    items: filteredDoctors,
                    store: doctors,
                    labelOrder: [
                      "Appointments",
                      "Paid",
                      "Total Appointments",
                      "Total Paid",
                    ],
                    columnBuilders: {
                      "Appointments": (doctor) {
                        final appointmentsToday =
                            doctor.totalAppointmentsOnDate(selectedDate);

                        return Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.blue.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            "Appointments: ${appointmentsToday.toString()}",
                            style: TextStyle(
                              color: Colors.blue,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        );
                      },
                      "Paid": (doctor) {
                        final appointmentsToday =
                            doctor.appointmentsOnDate(selectedDate);
                        final paidToday = appointmentsToday.fold<double>(
                          0,
                          (sum, a) => sum + (a.paidToDoctor ?? 0),
                        );

                        if (paidToday == 0) return const SizedBox.shrink();

                        return Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.blue.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            "Paid ₹${paidToday.toStringAsFixed(2)}",
                            style: TextStyle(
                              color: Colors.blue,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        );
                      },
                      // ...other column builders...
                    },
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
                                return "Dr. ${doc.title}";
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
                            await Future.wait(
                                ids.map((id) => doctors.hardDelete(id)));
                          }
                        },
                      ),
                    ],
                    furtherActions: [
                      const SizedBox(width: 5),
                    ],
                    onSelect: (item) => openDoctor(item, 1),
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
                  ),
                ),
              ],
            );
          }),
    );
  }

  Widget _buildDoctorDateFilterButton() {
    final date = selectedDate ?? DateTime.now();
    return Center(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(FluentIcons.chevron_left),
            onPressed: () {
              setState(() {
                selectedDate = date.subtract(const Duration(days: 1));
              });
            },
          ),
          material.TextButton(
            style: material.TextButton.styleFrom(
              foregroundColor: Colors.blue,
            ),
            child: Text(
              DateFormat('d MMM yyyy').format(date),
              style: TextStyle(
                color: Colors.blue,
                fontWeight: FontWeight.w600,
                fontSize: 16,
              ),
            ),
            onPressed: () {
              setState(() {});
            },
          ),
          IconButton(
            icon: const Icon(FluentIcons.chevron_right),
            onPressed: () {
              setState(() {
                selectedDate = date.add(const Duration(days: 1));
              });
            },
          ),
          const SizedBox(width: 16),
          Checkbox(
            checked: onlyToday,
            onChanged: (value) {
              setState(() {
                onlyToday = value ?? true;
              });
            },
          ),
          const SizedBox(width: 4),
          const Text(
            "Only today",
            style: TextStyle(
              fontWeight: FontWeight.w500,
              fontSize: 15,
            ),
          ),
        ],
      ),
    );
  }
}
