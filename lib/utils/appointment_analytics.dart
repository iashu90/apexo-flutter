import 'package:apexo/features/appointments/appointment_model.dart';

List<DateTime> monthOptionsFromAppointments(List<Appointment> rows) {
  return rows
      .map((appointment) => DateTime(appointment.date.year, appointment.date.month, 1))
      .toSet()
      .toList(growable: false)
    ..sort((a, b) => b.compareTo(a));
}
