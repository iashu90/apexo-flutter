import 'package:apexo/core/observable.dart';
import 'package:apexo/features/appointments/appointment_model.dart';
import 'package:apexo/features/appointments/appointments_store.dart';
import 'package:apexo/features/patients/patient_model.dart';
import 'package:apexo/features/patients/patients_store.dart';
import 'package:apexo/features/dashboard/overall_due_helper.dart';

class _DashboardController {
  _DashboardController() {
    appointments.observableMap.observe((e) {
      // nullify the cache
      _thisMonthAppointments = null;
      _todayAppointments = null;
      _totalDueAmount = null;
    });
  }

  final currentOpenTab = ObservableState(0);

  List<Appointment>? _thisMonthAppointments;
  List<Appointment> get thisMonthAppointments {
    if (_thisMonthAppointments != null) {
      return _thisMonthAppointments!;
    }
    final DateTime now = DateTime.now();
    List<Appointment> res = [];
    for (var appointment in appointments.present.values) {
      if (appointment.date.year != now.year) continue;
      if (appointment.date.month != now.month) continue;
      res.add(appointment);
    }
    return res..sort((a, b) => a.date.compareTo(b.date));
  }

  List<Appointment>? _todayAppointments;
  List<Appointment> get todayAppointments {
    if (_todayAppointments != null) {
      return _todayAppointments!;
    }
    final DateTime now = DateTime.now();
    List<Appointment> res = [];
    for (var appointment in thisMonthAppointments) {
      if (appointment.date.day != now.day) continue;
      res.add(appointment);
    }
    _todayAppointments = res..sort((a, b) => a.date.compareTo(b.date));
    return _todayAppointments!;
  }

  List get tomorrowAppointments => appointments.present.values
      .where((a) =>
          a.date.year == DateTime.now().add(const Duration(days: 1)).year &&
          a.date.month == DateTime.now().add(const Duration(days: 1)).month &&
          a.date.day == DateTime.now().add(const Duration(days: 1)).day)
      .toList();

  double get paymentsToday {
    double res = 0;
    for (var appointment in todayAppointments) {
      res += appointment.paid;
    }
    return res;
  }

  int get newPatientsToday {
    int res = 0;
    for (var appointment in todayAppointments) {
      if (appointment.firstAppointmentForThisPatient == true) res++;
    }
    return res;
  }

  List<Appointment> appointmentsForDate(DateTime date) {
    return appointments.present.values
        .where((appointment) =>
            appointment.date.year == date.year &&
            appointment.date.month == date.month &&
            appointment.date.day == date.day)
        .toList()
      ..sort((a, b) => a.date.compareTo(b.date));
  }

  double paymentsForDate(DateTime date) {
    double res = 0;
    for (var appointment in appointmentsForDate(date)) {
      res += appointment.paid;
    }
    return res;
  }

  double prescriptionPaymentsForDate(DateTime date) {
    double res = 0;
    for (var appointment in appointmentsForDate(date)) {
      res += appointment.prescriptionPaid;
    }
    return res;
  }

  int newPatientsForDate(DateTime date) {
    int res = 0;
    for (var appointment in appointmentsForDate(date)) {
      if (appointment.firstAppointmentForThisPatient == true) res++;
    }
    return res;
  }

  List<Patient> newPatientsForDateObjects(DateTime date) {
    return appointmentsForDate(date)
        .where((appointment) =>
            appointment.firstAppointmentForThisPatient == true &&
            appointment.patientID != null)
        .map((appointment) => patients.get(appointment.patientID!))
        .where((patient) => patient != null)
        .cast<Patient>()
        .toList();
  }

  double? _totalDueAmount;

  double totalDueAmount() {
    if (_totalDueAmount != null) return _totalDueAmount!;

    final result = OverallDueHelper.compute(
      appointments: appointments.present.values,
      patientsById: patients.present,
    );

    _totalDueAmount = result.totalDue;
    return _totalDueAmount!;
  }
}

final dashboardCtrl = _DashboardController();
