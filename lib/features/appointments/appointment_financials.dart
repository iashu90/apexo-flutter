import 'package:apexo/features/appointments/appointment_model.dart';

extension AppointmentFinancials on Appointment {
  double get doctorPayableAmount {
    return priceToPayDoctor > 0 ? priceToPayDoctor : paidToDoctor;
  }
}
