// ignore_for_file: avoid_print

import 'perf/checkin_perf_core.dart';

void main() {
  const indexThresholdMs = 700;
  const searchThresholdMs = 220;
  const todayMapThresholdMs = 260;
  const nextApptThresholdMs = 320;
  const topTreatmentsThresholdMs = 150;
  final metrics = runCheckinPerfGate();

  final failures = <String>[];
  if (metrics.indexMs > indexThresholdMs) {
    failures.add(
      'index build ${metrics.indexMs}ms > ${indexThresholdMs}ms',
    );
  }
  if (metrics.searchMs > searchThresholdMs) {
    failures.add(
      'search replay ${metrics.searchMs}ms > ${searchThresholdMs}ms',
    );
  }
  if (metrics.todayMapMs > todayMapThresholdMs) {
    failures.add(
      'today map ${metrics.todayMapMs}ms > ${todayMapThresholdMs}ms',
    );
  }
  if (metrics.nextApptMs > nextApptThresholdMs) {
    failures.add(
      'next appointment scan ${metrics.nextApptMs}ms > ${nextApptThresholdMs}ms',
    );
  }
  if (metrics.topTreatmentsMs > topTreatmentsThresholdMs) {
    failures.add(
      'top treatments scan ${metrics.topTreatmentsMs}ms > ${topTreatmentsThresholdMs}ms',
    );
  }

  print('CHECKIN_PERF_GATE');
  print('patients=${metrics.patientCount} appointments=${metrics.appointmentCount} queryHits=${metrics.queryHits} nextRows=${metrics.nextApptRows} top10=${metrics.top10Count}');
  print('indexMs=${metrics.indexMs}');
  print('searchMs=${metrics.searchMs}');
  print('todayMapMs=${metrics.todayMapMs}');
  print('nextApptMs=${metrics.nextApptMs}');
  print('topTreatmentsMs=${metrics.topTreatmentsMs}');

  if (failures.isNotEmpty) {
    for (final failure in failures) {
      print('FAIL: $failure');
    }
    throw StateError('Check-in performance gate failed.');
  }

  print('PASS: check-in performance gate');
}
