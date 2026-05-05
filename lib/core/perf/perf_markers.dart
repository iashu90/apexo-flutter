import 'dart:math';

import 'package:apexo/core/activity_logger.dart';

class PerfMarkers {
  static const bool enabled =
      bool.fromEnvironment('APEXO_PERF_MARKERS', defaultValue: false);
  static const int slowMsThreshold = 12;
  static const int samplePercent = 5;

  static final Random _random = Random();

  static bool _shouldSample() {
    if (!enabled) return false;
    if (samplePercent <= 0) return false;
    if (samplePercent >= 100) return true;
    return _random.nextInt(100) < samplePercent;
  }

  static T track<T>(String name, T Function() action,
      {Map<String, dynamic>? data}) {
    final shouldSample = _shouldSample();
    if (!shouldSample) {
      return action();
    }

    final stopwatch = Stopwatch()..start();
    try {
      return action();
    } finally {
      stopwatch.stop();
      final elapsedMs = stopwatch.elapsedMilliseconds;
      if (elapsedMs >= slowMsThreshold) {
        ActivityLogger.logEvent(
          'PerfMarker',
          name,
          data: {
            'elapsedMs': elapsedMs,
            if (data != null) ...data,
          },
        );
      }
    }
  }

  static Future<T> trackAsync<T>(String name, Future<T> Function() action,
      {Map<String, dynamic>? data}) async {
    final shouldSample = _shouldSample();
    if (!shouldSample) {
      return action();
    }

    final stopwatch = Stopwatch()..start();
    try {
      return await action();
    } finally {
      stopwatch.stop();
      final elapsedMs = stopwatch.elapsedMilliseconds;
      if (elapsedMs >= slowMsThreshold) {
        ActivityLogger.logEvent(
          'PerfMarker',
          name,
          data: {
            'elapsedMs': elapsedMs,
            if (data != null) ...data,
          },
        );
      }
    }
  }
}
