import 'package:apexo/core/multi_stream_builder.dart';
import 'package:apexo/services/localization/locale.dart';
import 'package:apexo/features/appointments/open_appointment_panel.dart';
import 'package:apexo/features/settings/settings_stores.dart';
import 'package:apexo/features/doctors/doctors_store.dart';
import 'package:apexo/widget_keys.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:table_calendar/table_calendar.dart';
import 'calendar_widget.dart';
import 'appointment_model.dart';
import 'appointments_store.dart';

class CalendarScreen extends StatelessWidget {
  const CalendarScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ScaffoldPage(
      key: WK.calendarScreen,
      padding: EdgeInsets.zero,
      content: MStreamBuilder(
          streams: [
            appointments.observableMap.stream,
            appointments.doctorId.stream
          ],
          builder: (context, snapshot) {
            return WeekAgendaCalendar<Appointment>(
              items: appointments.filtered.values.toList(),
              actions: [
                ComboBox<String>(
                  style: const TextStyle(overflow: TextOverflow.ellipsis),
                  items: [
                    ComboBoxItem<String>(
                      value: "",
                      child: Txt(txt("allDoctors")),
                    ),
                    ...doctors.present.values.map((e) {
                      var doctorName = e.title;
                      if (doctorName.length > 20) {
                        doctorName = "${doctorName.substring(0, 17)}...";
                      }
                      return ComboBoxItem(value: e.id, child: Txt(doctorName));
                    }),
                  ],
                  onChanged: (id) => appointments.doctorId(id ?? ""),
                  value: appointments.doctorId(),
                ),
                const SizedBox(width: 5),
              ],
              startDay: StartingDayOfWeek.values.firstWhere(
                  (v) => v.name == globalSettings.get("start_day_of_wk").value,
                  orElse: () => StartingDayOfWeek.monday),
              initiallySelectedDay: DateTime.now().millisecondsSinceEpoch,
              onSetTime: (item) {
                appointments.set(item);
              },
              onSelect: openAppointment,
              onAddNew: (selectedDate) {
                openAppointment(Appointment.fromJson(
                    {"date": selectedDate.millisecondsSinceEpoch}));
              },
            );
          }),
    );
  }
}
