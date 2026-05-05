// ignore_for_file: avoid_print

import 'perf/synthetic_clinic_data.dart';

void main() {
  const dashboardThresholdMs = 420;
  const patientThresholdMs = 520;
  const doctorThresholdMs = 420;

  final data = buildSyntheticClinicData();
  final now = data.now;
  final today = DateTime(now.year, now.month, now.day);

  bool sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  final dashboardStopwatch = Stopwatch()..start();
  final stageCounts = <String, int>{};
  var grossRevenueToday = 0.0;
  var netCollectionToday = 0.0;
  for (final row in data.appointments) {
    stageCounts[row.stage] = (stageCounts[row.stage] ?? 0) + 1;
    if (!sameDay(row.date, today)) continue;
    grossRevenueToday += row.price;
    netCollectionToday += row.paid;
  }
  dashboardStopwatch.stop();

  final patientStopwatch = Stopwatch()..start();
  final byPatient = <String, List<SyntheticAppointmentRow>>{};
  for (final row in data.appointments) {
    (byPatient[row.patientId] ??= <SyntheticAppointmentRow>[]).add(row);
  }
  for (final rows in byPatient.values) {
    rows.sort((a, b) => b.date.compareTo(a.date));
  }
  patientStopwatch.stop();

  final doctorStopwatch = Stopwatch()..start();
  final byDoctor = <String, List<SyntheticAppointmentRow>>{};
  for (final row in data.appointments) {
    (byDoctor[row.doctorId] ??= <SyntheticAppointmentRow>[]).add(row);
  }
  final todayQueueByDoctor = <String, int>{};
  for (final entry in byDoctor.entries) {
    final queue = entry.value.where((row) {
      if (!sameDay(row.date, today)) return false;
      return row.stage == 'waiting' || row.stage == 'with_doctor';
    }).length;
    todayQueueByDoctor[entry.key] = queue;
  }
  doctorStopwatch.stop();

  final failures = <String>[];
  if (dashboardStopwatch.elapsedMilliseconds > dashboardThresholdMs) {
    failures.add(
      'dashboard ${dashboardStopwatch.elapsedMilliseconds}ms > ${dashboardThresholdMs}ms',
    );
  }
  if (patientStopwatch.elapsedMilliseconds > patientThresholdMs) {
    failures.add(
      'patient screen ${patientStopwatch.elapsedMilliseconds}ms > ${patientThresholdMs}ms',
    );
  }
  if (doctorStopwatch.elapsedMilliseconds > doctorThresholdMs) {
    failures.add(
      'doctor screen ${doctorStopwatch.elapsedMilliseconds}ms > ${doctorThresholdMs}ms',
    );
  }

  print('SCREEN_PERF_GATE');
  print('patients=${data.patients.length} appointments=${data.appointments.length} doctors=${data.doctorIds.length}');
  print('dashboardMs=${dashboardStopwatch.elapsedMilliseconds} grossToday=${grossRevenueToday.toStringAsFixed(0)} collectedToday=${netCollectionToday.toStringAsFixed(0)} stages=${stageCounts.length}');
  print('patientMs=${patientStopwatch.elapsedMilliseconds} patientGroups=${byPatient.length}');
  print('doctorMs=${doctorStopwatch.elapsedMilliseconds} doctorGroups=${byDoctor.length} todayQueues=${todayQueueByDoctor.length}');

  if (failures.isNotEmpty) {
    for (final failure in failures) {
      print('FAIL: $failure');
    }
    throw StateError('Screen performance gate failed.');
  }

  print('PASS: screen performance gate');
}
