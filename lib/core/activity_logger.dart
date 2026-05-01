import 'dart:async';
import 'package:apexo/utils/logger.dart'; // Use your existing logger for output
import 'package:intl/intl.dart';
import 'dart:io';

class ActivityLogger {
  static final String _logDir = "${Directory.current.path}/.log"; // Use .log folder
  static final List<String> _pendingMessages = <String>[];
  static IOSink? _sink;
  static String? _activeLogDate;
  static Timer? _flushTimer;
  static bool _isFlushing = false;
  static const Duration _flushInterval = Duration(milliseconds: 350);
  static const int _immediateFlushThreshold = 20;

  static File _fileForDate(String dateStr) {
    // Ensure the .log directory exists
    final dir = Directory(_logDir);
    if (!dir.existsSync()) {
      dir.createSync(recursive: true);
    }
    return File('$_logDir/activity_log_$dateStr.txt');
  }

  static void _writeToFile(String message) {
    _pendingMessages.add(message);

    if (_pendingMessages.length >= _immediateFlushThreshold) {
      _scheduleFlush(immediate: true);
      return;
    }
    _scheduleFlush();
  }

  static void _scheduleFlush({bool immediate = false}) {
    if (immediate) {
      _flushTimer?.cancel();
      _flushTimer = null;
      unawaited(_flushBuffer());
      return;
    }

    _flushTimer ??= Timer(_flushInterval, () {
      _flushTimer = null;
      unawaited(_flushBuffer());
    });
  }

  static Future<void> _flushBuffer() async {
    if (_isFlushing || _pendingMessages.isEmpty) {
      return;
    }

    _isFlushing = true;
    final payload = _pendingMessages.join();
    _pendingMessages.clear();

    try {
      final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
      if (_sink == null || _activeLogDate != today) {
        final previous = _sink;
        _sink = _fileForDate(today).openWrite(mode: FileMode.append);
        _activeLogDate = today;
        if (previous != null) {
          await previous.flush();
          await previous.close();
        }
      }

      _sink!.write(payload);
      await _sink!.flush();
    } catch (e) {
      // Optionally handle file write errors
    } finally {
      _isFlushing = false;
      if (_pendingMessages.isNotEmpty) {
        _scheduleFlush(immediate: true);
      }
    }
  }

  static void logAction(String action, {String? screen, Map<String, dynamic>? data}) {
    final timestamp = DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now());
    final msg = "[$timestamp] ACTION: $action"
        "${screen != null ? " | Screen: $screen" : ""}"
        "${data != null ? " | Data: ${data.toString()}" : ""}\n";
    log.info(msg);
    _writeToFile(msg);
  }

  static void logPanel(String panelName, String event) {
    final timestamp = DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now());
    final msg = "[$timestamp] PANEL: $panelName | Event: $event\n";
    log.info(msg);
    _writeToFile(msg);
  }

  static void logApi(String endpoint, String method, {Map<String, dynamic>? params}) {
    final timestamp = DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now());
    final msg = "[$timestamp] API: $method $endpoint"
        "${params != null ? " | Params: ${params.toString()}" : ""}\n";
    log.info(msg);
    _writeToFile(msg);
  }

  static void logException(dynamic error, [StackTrace? stacktrace, String? context]) {
    final timestamp = DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now());
    final msg = "[$timestamp] EXCEPTION: ${error.toString()}${context != null ? " | Context: $context" : ""}\n";
    log.severe(msg);
    _writeToFile(msg);
    if (stacktrace != null) {
      _writeToFile("$stacktrace\n");
      log.info("$stacktrace\n");
    }
  }

  static void logSyncTelemetry({
    required String store,
    required int fetched,
    required int deduped,
    required int cursorAdvanced,
    required bool recoveryPassUsed,
    required int uniqueRows,
    int? pages,
  }) {
    logAction(
      'Sync Telemetry',
      screen: 'Sync',
      data: {
        'store': store,
        'fetched': fetched,
        'deduped': deduped,
        'cursorAdvanced': cursorAdvanced,
        'recoveryPassUsed': recoveryPassUsed,
        'uniqueRows': uniqueRows,
        if (pages != null) 'pages': pages,
      },
    );
  }

  static void logEvent(
    String category,
    String event, {
    Map<String, dynamic>? data,
  }) {
    logAction(
      event,
      screen: category,
      data: data,
    );
  }

  static void logSyncCycleSummary({
    required String store,
    required int attempts,
    required int pulled,
    required int pushed,
    required int conflicts,
    required bool deferredPresent,
    required bool online,
    String? terminalException,
    int? durationMs,
  }) {
    final compact =
        'SYNC_SUMMARY store=$store attempts=$attempts pulled=$pulled pushed=$pushed conflicts=$conflicts deferred=$deferredPresent online=$online'
        '${durationMs != null ? ' durationMs=$durationMs' : ''}'
        '${terminalException != null && terminalException.isNotEmpty ? ' terminal=$terminalException' : ''}';

    logAction(
      compact,
      screen: 'SyncSummary',
    );
  }
}