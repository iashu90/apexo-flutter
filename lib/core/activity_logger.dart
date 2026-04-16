import 'package:apexo/utils/logger.dart'; // Use your existing logger for output
import 'package:intl/intl.dart';
import 'dart:io';

class ActivityLogger {
  static final String _logDir = "${Directory.current.path}/.log"; // Use .log folder

  static File get _logFile {
    // Ensure the .log directory exists
    final dir = Directory(_logDir);
    if (!dir.existsSync()) {
      dir.createSync(recursive: true);
    }
    final dateStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
    return File('$_logDir/activity_log_$dateStr.txt');
  }

  static void _writeToFile(String message) {
    try {
      _logFile.writeAsStringSync(message, mode: FileMode.append, flush: true);
    } catch (e) {
      // Optionally handle file write errors
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
}