import 'dart:async';

import 'package:apexo/services/sync_priority.dart';
import 'synthetic_clinic_data.dart';

class CheckinSearchSyncPerfMetrics {
  final int patientCount;
  final int appointmentCount;
  final int typingDurationMs;
  final int keyStrokeCount;
  final int searchP50Ms;
  final int searchP95Ms;
  final int searchMaxMs;
  final int syncTriggerCount;
  final int syncRunCount;
  final int syncStartedDuringTypingCount;
  final int resumeLatencyMs;

  const CheckinSearchSyncPerfMetrics({
    required this.patientCount,
    required this.appointmentCount,
    required this.typingDurationMs,
    required this.keyStrokeCount,
    required this.searchP50Ms,
    required this.searchP95Ms,
    required this.searchMaxMs,
    required this.syncTriggerCount,
    required this.syncRunCount,
    required this.syncStartedDuringTypingCount,
    required this.resumeLatencyMs,
  });
}

class _CoalescedSyncRunner {
  final Future<void> Function() beforeRun;
  final Future<void> Function() runOne;
  final bool Function() isTyping;
  final DateTime? Function() typingEndedAt;

  bool _running = false;
  bool _pending = false;
  Future<void>? _inFlight;

  int triggerCount = 0;
  int runCount = 0;
  int startedDuringTypingCount = 0;
  DateTime? firstStartAfterTyping;

  _CoalescedSyncRunner({
    required this.beforeRun,
    required this.runOne,
    required this.isTyping,
    required this.typingEndedAt,
  });

  void trigger() {
    triggerCount++;
    _pending = true;
    _ensureRunning();
  }

  void _ensureRunning() {
    if (_running) return;
    _inFlight = _drain();
  }

  Future<void> _drain() async {
    if (_running) return;
    _running = true;
    try {
      while (_pending) {
        _pending = false;
        await beforeRun();

        final now = DateTime.now();
        if (isTyping()) {
          startedDuringTypingCount++;
        } else {
          final endedAt = typingEndedAt();
          if (endedAt != null && firstStartAfterTyping == null) {
            firstStartAfterTyping = now;
          }
        }

        runCount++;
        await runOne();
      }
    } finally {
      _running = false;
      if (_pending) {
        _ensureRunning();
      }
    }
  }

  Future<void> waitForIdle({Duration timeout = const Duration(seconds: 4)}) async {
    final sw = Stopwatch()..start();
    while (_running || _pending) {
      if (sw.elapsed > timeout) break;
      await Future.delayed(const Duration(milliseconds: 20));
    }
    await _inFlight;
  }
}

int _percentile(List<int> values, double q) {
  if (values.isEmpty) return 0;
  final sorted = [...values]..sort();
  final index = (sorted.length * q).floor().clamp(0, sorted.length - 1);
  return sorted[index];
}

void _simulateSyncUnit(List<SyntheticAppointmentRow> appointments) {
  var checksum = 0;
  final limit = appointments.length < 12000 ? appointments.length : 12000;
  for (var i = 0; i < limit; i++) {
    final row = appointments[i];
    checksum ^= row.id.hashCode;
    checksum ^= row.patientId.hashCode;
    checksum ^= row.selectedTreatments.length;
  }
  if (checksum == -1) {
    throw StateError('Impossible checksum');
  }
}

Future<CheckinSearchSyncPerfMetrics> runCheckinSearchSyncGate({
  int patientCount = 10000,
  int appointmentCount = 50000,
  int seed = 42,
  int typingDurationMs = 6000,
  int keyIntervalMs = 90,
  int routeBurstIntervalMs = 120,
  int networkBurstIntervalMs = 180,
}) async {
  final data = buildSyntheticClinicData(
    patientCount: patientCount,
    appointmentCount: appointmentCount,
    seed: seed,
  );

  final index = data.patients
      .map((p) => (n: p.name.toLowerCase(), ph: p.phone.toLowerCase()))
      .toList(growable: false);

  final searchSamples = <int>[];
  final queries = <String>[
    'p',
    'pa',
    'pat',
    'patient',
    'patient 1',
    '901',
    '9012',
  ];

  var typingActive = true;
  DateTime? typingEndedAt;

  final runner = _CoalescedSyncRunner(
    beforeRun: syncPriorityDeferral.waitForTypingIdle,
    runOne: () async => _simulateSyncUnit(data.appointments),
    isTyping: () => typingActive,
    typingEndedAt: () => typingEndedAt,
  );

  final routeTimer = Timer.periodic(
    Duration(milliseconds: routeBurstIntervalMs),
    (_) => runner.trigger(),
  );
  final networkTimer = Timer.periodic(
    Duration(milliseconds: networkBurstIntervalMs),
    (_) => runner.trigger(),
  );

  final typingStopwatch = Stopwatch()..start();
  var keyStrokeCount = 0;
  while (typingStopwatch.elapsedMilliseconds < typingDurationMs) {
    syncPriorityDeferral.markTyping();
    final query = queries[keyStrokeCount % queries.length];

    final sw = Stopwatch()..start();
    index
        .where((entry) =>
            entry.n.contains(query) || entry.ph.contains(query))
        .take(8)
        .toList(growable: false);
    sw.stop();
    searchSamples.add(sw.elapsedMicroseconds ~/ 1000);

    keyStrokeCount++;
    await Future.delayed(Duration(milliseconds: keyIntervalMs));
  }

  typingActive = false;
  typingEndedAt = DateTime.now();
  final typingStoppedAt = typingEndedAt;

  routeTimer.cancel();
  networkTimer.cancel();

  runner.trigger();
  await runner.waitForIdle();

  final firstAfterTyping = runner.firstStartAfterTyping;
    final resumeLatencyMs = firstAfterTyping == null
      ? 9999
      : firstAfterTyping.difference(typingStoppedAt).inMilliseconds;

  return CheckinSearchSyncPerfMetrics(
    patientCount: patientCount,
    appointmentCount: appointmentCount,
    typingDurationMs: typingDurationMs,
    keyStrokeCount: keyStrokeCount,
    searchP50Ms: _percentile(searchSamples, 0.5),
    searchP95Ms: _percentile(searchSamples, 0.95),
    searchMaxMs: searchSamples.isEmpty ? 0 : (searchSamples..sort()).last,
    syncTriggerCount: runner.triggerCount,
    syncRunCount: runner.runCount,
    syncStartedDuringTypingCount: runner.startedDuringTypingCount,
    resumeLatencyMs: resumeLatencyMs,
  );
}
