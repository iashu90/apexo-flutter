// ignore_for_file: avoid_print

import 'perf/checkin_search_sync_core.dart';

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

Future<void> main() async {
  const runs = 5;

  final searchP95Samples = <int>[];
  final resumeLatencySamples = <int>[];
  final startedDuringTypingSamples = <int>[];

  for (var i = 0; i < runs; i++) {
    final metrics = await runCheckinSearchSyncGate(
      seed: 42 + i,
      typingDurationMs: 3500,
    );
    searchP95Samples.add(metrics.searchP95Ms);
    resumeLatencySamples.add(metrics.resumeLatencyMs);
    startedDuringTypingSamples.add(metrics.syncStartedDuringTypingCount);
    print(
      'run=$i searchP95Ms=${metrics.searchP95Ms} '
      'resumeLatencyMs=${metrics.resumeLatencyMs} '
      'startedDuringTyping=${metrics.syncStartedDuringTypingCount} '
      'triggers=${metrics.syncTriggerCount} runs=${metrics.syncRunCount}',
    );
  }

  final failures = <String>[];
  _validate(
    'searchP95',
    searchP95Samples,
    p50Max: 20,
    p95Max: 35,
    failures: failures,
  );
  _validate(
    'resumeLatency',
    resumeLatencySamples,
    p50Max: 900,
    p95Max: 1000,
    failures: failures,
  );

  final anyTypingStarts = startedDuringTypingSamples.any((v) => v > 0);
  if (anyTypingStarts) {
    failures.add(
      'sync started during typing in some runs: $startedDuringTypingSamples',
    );
  }

  if (failures.isNotEmpty) {
    for (final failure in failures) {
      print('FAIL: $failure');
    }
    throw StateError('Check-in search sync stability gate failed.');
  }

  print('PASS: check-in search sync stability gate');
}
