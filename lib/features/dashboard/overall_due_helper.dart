import 'package:apexo/common_widgets/patient_report.dart';
import 'package:apexo/features/appointments/appointment_model.dart';
import 'package:apexo/features/patients/patient_model.dart';

class OverallDueComputation {
  final double totalDue;
  final List<ReportDetailRow> rows;

  const OverallDueComputation({
    required this.totalDue,
    required this.rows,
  });
}

class OverallDueHelper {
  /// Single-pass aggregation for cost/paid by patient.
  /// Returns:
  /// - total due amount across all patients
  /// - rows for due-details dialog
  static OverallDueComputation compute({
    required Iterable<Appointment> appointments,
    required Map<String, Patient> patientsById,
  }) {
    final Map<String, double> costByPatient = {};
    final Map<String, double> paidByPatient = {};

    for (final a in appointments) {
      final patientId = a.patientID;
      if (patientId == null || patientId.isEmpty) continue;

      costByPatient[patientId] = (costByPatient[patientId] ?? 0) + a.price;
      paidByPatient[patientId] = (paidByPatient[patientId] ?? 0) + a.paid;
    }

    double totalDue = 0;
    final rows = <ReportDetailRow>[];

    for (final entry in costByPatient.entries) {
      final patientId = entry.key;
      final cost = entry.value;
      final paid = paidByPatient[patientId] ?? 0;
      final due = cost - paid;

      if (due <= 0) continue;

      totalDue += due;

      final patient = patientsById[patientId];
      if (patient == null) continue;

      rows.add(
        ReportDetailRow(
          patient: patient,
          cost: cost.toStringAsFixed(2),
          paid: paid.toStringAsFixed(2),
          treatment: '',
          teeth: '',
          prescription: '',
          date: DateTime.now(),
        ),
      );
    }

    return OverallDueComputation(totalDue: totalDue, rows: rows);
  }
}