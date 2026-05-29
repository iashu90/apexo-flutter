// ignore_for_file: avoid_print

import 'perf/checkin_search_sync_core.dart';

Future<void> main() async {
  const searchP95ThresholdMs = 20;
  const searchMaxThresholdMs = 40;
  const resumeLatencyThresholdMs = 1000;

  final metrics = await runCheckinSearchSyncGate();

  final failures = <String>[];
  if (metrics.syncStartedDuringTypingCount > 0) {
    failures.add(
      'sync started during typing ${metrics.syncStartedDuringTypingCount} times',
    );
  }
  if (metrics.resumeLatencyMs > resumeLatencyThresholdMs) {
    failures.add(
      'sync resume latency ${metrics.resumeLatencyMs}ms > ${resumeLatencyThresholdMs}ms',
    );
  }
  if (metrics.searchP95Ms > searchP95ThresholdMs) {
    failures.add(
      'search p95 ${metrics.searchP95Ms}ms > ${searchP95ThresholdMs}ms',
    );
  }
  if (metrics.searchMaxMs > searchMaxThresholdMs) {
    failures.add(
      'search max ${metrics.searchMaxMs}ms > ${searchMaxThresholdMs}ms',
    );
  }
  if (metrics.syncRunCount > metrics.syncTriggerCount) {
    failures.add(
      'sync runs ${metrics.syncRunCount} > triggers ${metrics.syncTriggerCount}',
    );
  }

  print('CHECKIN_SEARCH_SYNC_GATE');
  print(
    'patients=${metrics.patientCount} appointments=${metrics.appointmentCount} '
    'typingMs=${metrics.typingDurationMs} keystrokes=${metrics.keyStrokeCount}',
  );
  print(
    'searchP50Ms=${metrics.searchP50Ms} searchP95Ms=${metrics.searchP95Ms} searchMaxMs=${metrics.searchMaxMs}',
  );
  print(
    'syncTriggers=${metrics.syncTriggerCount} syncRuns=${metrics.syncRunCount} '
    'startedDuringTyping=${metrics.syncStartedDuringTypingCount} '
    'resumeLatencyMs=${metrics.resumeLatencyMs}',
  );

  if (failures.isNotEmpty) {
    for (final failure in failures) {
      print('FAIL: $failure');
    }
    throw StateError('Check-in search sync gate failed.');
  }

  print('PASS: check-in search sync gate');
}
