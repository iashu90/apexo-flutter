import 'synthetic_clinic_data.dart';

class CheckinPerfMetrics {
  final int patientCount;
  final int appointmentCount;
  final int queryHits;
  final int nextApptRows;
  final int top10Count;
  final int indexMs;
  final int searchMs;
  final int todayMapMs;
  final int nextApptMs;
  final int topTreatmentsMs;

  const CheckinPerfMetrics({
    required this.patientCount,
    required this.appointmentCount,
    required this.queryHits,
    required this.nextApptRows,
    required this.top10Count,
    required this.indexMs,
    required this.searchMs,
    required this.todayMapMs,
    required this.nextApptMs,
    required this.topTreatmentsMs,
  });
}

CheckinPerfMetrics runCheckinPerfGate({
  int patientCount = 10000,
  int appointmentCount = 50000,
  int seed = 42,
}) {
  final data = buildSyntheticClinicData(
    patientCount: patientCount,
    appointmentCount: appointmentCount,
    seed: seed,
  );
  final now = data.now;

  final indexStopwatch = Stopwatch()..start();
  final searchIndex = data.patients
      .map((p) => (p: p, n: p.name.toLowerCase(), ph: p.phone.toLowerCase()))
      .toList(growable: false);
  indexStopwatch.stop();

  final queryStopwatch = Stopwatch()..start();
  const sampleQueries = [
    '9',
    '90',
    '901',
    '9012',
    'patient 12',
    'patient 123',
  ];
  var queryHits = 0;
  for (var r = 0; r < 80; r++) {
    for (final query in sampleQueries) {
      final q = query.toLowerCase();
      queryHits += searchIndex
          .where((entry) => entry.n.contains(q) || entry.ph.contains(q))
          .take(8)
          .length;
    }
  }
  queryStopwatch.stop();

  final today = DateTime(now.year, now.month, now.day);
  bool sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  final todayMapStopwatch = Stopwatch()..start();
  final todayByPatient = <String, SyntheticAppointmentRow>{};
  for (final row in data.appointments) {
    if (!sameDay(row.date, today)) continue;
    final existing = todayByPatient[row.patientId];
    if (existing == null || row.date.isAfter(existing.date)) {
      todayByPatient[row.patientId] = row;
    }
  }
  todayMapStopwatch.stop();

  final nextApptStopwatch = Stopwatch()..start();
  var nextApptRows = 0;
  final step = (data.appointments.length / 200).floor().clamp(1, 1000000);
  for (var i = 0; i < 200; i++) {
    final anchor = data.appointments[(i * step) % data.appointments.length];
    final upcoming = <SyntheticAppointmentRow>[];
    for (final row in data.appointments) {
      if (row.patientId != anchor.patientId) continue;
      if (row.id == anchor.id) continue;
      if ((row.stage != 'scheduled' && row.stage != 'pending') ||
          row.isCheckedIn ||
          !row.date.isAfter(now)) {
        continue;
      }
      upcoming.add(row);
    }
    upcoming.sort((a, b) => a.date.compareTo(b.date));
    nextApptRows += upcoming.length;
  }
  nextApptStopwatch.stop();

  final topTreatmentsStopwatch = Stopwatch()..start();
  final treatmentCounts = <String, int>{};
  var scanned = 0;
  for (final row in data.appointments) {
    if (scanned >= 600) break;
    scanned++;
    for (final t in row.selectedTreatments) {
      treatmentCounts[t] = (treatmentCounts[t] ?? 0) + 1;
    }
  }
  final rows = treatmentCounts.entries.toList(growable: false)
    ..sort((a, b) => b.value.compareTo(a.value));
  final top10 = rows.take(10).toList(growable: false);
  topTreatmentsStopwatch.stop();

  return CheckinPerfMetrics(
    patientCount: patientCount,
    appointmentCount: appointmentCount,
    queryHits: queryHits,
    nextApptRows: nextApptRows,
    top10Count: top10.length,
    indexMs: indexStopwatch.elapsedMilliseconds,
    searchMs: queryStopwatch.elapsedMilliseconds,
    todayMapMs: todayMapStopwatch.elapsedMilliseconds,
    nextApptMs: nextApptStopwatch.elapsedMilliseconds,
    topTreatmentsMs: topTreatmentsStopwatch.elapsedMilliseconds,
  );
}
