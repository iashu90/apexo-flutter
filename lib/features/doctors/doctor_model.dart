import 'package:apexo/common_widgets/patient_report.dart';
import 'package:apexo/core/model.dart';
import 'package:apexo/features/patients/patients_store.dart';
import 'package:apexo/services/archived.dart';
import 'package:apexo/services/login.dart';
import 'package:apexo/features/appointments/appointment_model.dart';
import 'package:apexo/features/appointments/appointments_store.dart';
import 'package:table_calendar/table_calendar.dart';

final allDays = StartingDayOfWeek.values.map((e) => e.name).toList();

extension DoctorPayments on Doctor {
  /// Returns the total amount paid to this doctor from all their appointments.
  double get totalPaidToDoctor {
    return allAppointments.fold<double>(
      0,
      (sum, appointment) => sum + (appointment.paidToDoctor ?? 0),
    );
  }

  List<Appointment> appointmentsOnDate(DateTime date) {
    return allAppointments
        .where((a) =>
            a.date.year == date.year &&
            a.date.month == date.month &&
            a.date.day == date.day)
        .toList();
  }

  int totalAppointmentsOnDate(DateTime date) {
    return appointmentsOnDate(date).length;
  }

  /// Returns a list of this doctor's appointments where paidToDoctor > 0.
  List<Appointment> get appointmentsWithDoctorPayment {
    return allAppointments.where((a) => (a.paidToDoctor ?? 0) > 0).toList();
  }

  List<ReportDetailRow> get doctorDetails => allAppointments
          .where((appointment) => appointment.operatorsIDs.contains(id))
          .map((appointment) {
        // Fetch patient details
        final patient = patients.get(appointment.patientID ?? '');

        final dateStr = appointment.date;
        final costStr = '₹${(appointment.price ?? 0).toStringAsFixed(2)}';
        final paidStr = '₹${(appointment.paid ?? 0).toStringAsFixed(2)}';

        final prescriptionStr = (appointment.prescriptions != null &&
                appointment.prescriptions.isNotEmpty)
            ? appointment.prescriptions.join(', ')
            : '';

        final treatmentStr = (appointment.selectedTreatments != null &&
                appointment.selectedTreatments.isNotEmpty)
            ? appointment.subTreatments != null &&
                    appointment.subTreatments.isNotEmpty
                ? "${appointment.selectedTreatments.join(', ')} - ${appointment.subTreatments.join(', ')}"
                : appointment.selectedTreatments.join(', ')
            : '';

        final teethStr = (appointment.selectedTeeth != null &&
                appointment.selectedTeeth.isNotEmpty)
            ? appointment.selectedTeeth.join(', ')
            : '';

        final treatmentPaymentMode =
            appointment.treatmentGpayPaid == true ? 'GPay' : 'Cash';
        final preceptionPaymentMode =
            appointment.prescriptionGpayPaid == true ? 'GPay' : 'Cash';

        return ReportDetailRow(
          date: dateStr,
          cost: costStr,
          paid: paidStr,
          prescription: prescriptionStr,
          treatment: treatmentStr,
          teeth: teethStr,
          isDone: appointment.isDone,
          treatmentPaymentMode: treatmentPaymentMode,
          preceptionPaymentMode: preceptionPaymentMode,
          patient: patient,
          doctorPaid: '₹${(appointment.paidToDoctor ?? 0).toStringAsFixed(2)}',
          doctorTotalPay: '₹${appointment.priceToPayDoctor.toStringAsFixed(2)}',
        );
      }).toList();
}

class Doctor extends Model {
  List<Appointment> get allAppointments {
    return (appointments.byDoctor[id]?["all"] ?? [])
        .where((appointment) => appointment.archived != true || showArchived())
        .toList()
      ..sort((a, b) => a.date.compareTo(b.date));
  }

  List<Appointment> get upcomingAppointments {
    return (appointments.byDoctor[id]?["upcoming"] ?? [])
        .where((appointment) => appointment.archived != true || showArchived())
        .toList()
      ..sort((a, b) => a.date.compareTo(b.date));
  }

  List<Appointment> get pastDoneAppointments {
    return (appointments.byDoctor[id]?["past"] ?? [])
        .where((appointment) => appointment.archived != true || showArchived())
        .toList()
      ..sort((a, b) => a.date.compareTo(b.date));
  }

  @override
  bool get locked {
    if (lockToUserIDs.isEmpty) return false;
    if (login.isAdmin) return false;
    return !lockToUserIDs.contains(login.currentUserID);
  }

  Map<String, String>? _labels;
  @override
  Map<String, String> get labels {
    return _labels ??= {
      "Appointments": allAppointments.length.toString(),
      "Paid": totalPaidToDoctor.toString(),
      // "Total Appointments": allAppointments.length.toString(),
      // "Total Paid": totalPaidToDoctor.toString(),
    };
  }

  // id: id of the member (inherited from Model)
  // title: name of the member (inherited from Model)
  /* 1 */ List<String> dutyDays = allDays;
  /* 2 */ String email = "";
  /* 3 */ String phone = "";
  /* 4 */ List<String> lockToUserIDs = [];

  @override
  Doctor.fromJson(Map<String, dynamic> json) : super.fromJson(json) {
    /* 1 */ dutyDays = List<String>.from(json['dutyDays'] ?? dutyDays);
    /* 2 */ email = json["email"] ?? email;
    /* 3 */ phone = json["phone"] ?? phone;
    /* 4 */ lockToUserIDs =
        List<String>.from(json['lockToUserIDs'] ?? lockToUserIDs);
  }
  @override
  Map<String, dynamic> toJson() {
    final json = super.toJson();
    final d = Doctor.fromJson({});
    /* 1 */ if (dutyDays.toString() != d.dutyDays.toString())
      json['dutyDays'] = dutyDays;
    /* 2 */ if (email != d.email) json["email"] = email;
    /* 3 */ if (phone != d.phone) json["phone"] = phone;
    /* 4 */ if (lockToUserIDs.toString() != d.lockToUserIDs.toString())
      json["lockToUserIDs"] = lockToUserIDs;
    return json;
  }
}
