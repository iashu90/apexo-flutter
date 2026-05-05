// ignore_for_file: avoid_print

import 'perf/checkin_perf_core.dart';

int _p50(List<int> values) {
  final sorted = [...values]..sort();
  return sorted[(sorted.length * 0.5).floor().clamp(0, sorted.length - 1)];
}

int _p95(List<int> values) {
  final sorted = [...values]..sort();
  return sorted[(sorted.length * 0.95).floor().clamp(0, sorted.length - 1)];
}

void _validate(String label, List<int> samples,
    {required int p50Max, required int p95Max, required List<String> failures}) {
  final p50 = _p50(samples);
  final p95 = _p95(samples);
  print('$label: p50=${p50}ms p95=${p95}ms samples=$samples');
  if (p50 > p50Max) {
    failures.add('$label p50 ${p50}ms > ${p50Max}ms');
  }
  if (p95 > p95Max) {
    failures.add('$label p95 ${p95}ms > ${p95Max}ms');
  }
}

void main() {
  const runs = 9;

  final index = <int>[];
  final search = <int>[];
  final todayMap = <int>[];
  final nextAppt = <int>[];
  final topTreatments = <int>[];

  for (var i = 0; i < runs; i++) {
    final metrics = runCheckinPerfGate(seed: 42 + i);
    index.add(metrics.indexMs);
    search.add(metrics.searchMs);
    todayMap.add(metrics.todayMapMs);
    nextAppt.add(metrics.nextApptMs);
    topTreatments.add(metrics.topTreatmentsMs);
  }

  final failures = <String>[];

  _validate(
    'index',
    index,
    p50Max: 750,
    p95Max: 1100,
    failures: failures,
  );
  _validate(
    'search',
    search,
    p50Max: 260,
    p95Max: 420,
    failures: failures,
  );
  _validate(
    'todayMap',
    todayMap,
    p50Max: 300,
    p95Max: 500,
    failures: failures,
  );
  _validate(
    'nextAppt',
    nextAppt,
    p50Max: 360,
    p95Max: 560,
    failures: failures,
  );
  _validate(
    'topTreatments',
    topTreatments,
    p50Max: 180,
    p95Max: 300,
    failures: failures,
  );

  if (failures.isNotEmpty) {
    for (final failure in failures) {
      print('FAIL: $failure');
    }
    throw StateError('Check-in stability performance gate failed.');
  }

  print('PASS: check-in stability performance gate');
}
