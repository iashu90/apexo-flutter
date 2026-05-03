import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:apexo/utils/safe_dir.dart';
import 'package:path/path.dart';

class CriticalWriteBatch {
  final String batchId;
  final String store;
  final DateTime createdAt;
  final Map<String, String> entries;

  const CriticalWriteBatch({
    required this.batchId,
    required this.store,
    required this.createdAt,
    required this.entries,
  });
}

class _JournalEvent {
  final String type;
  final String batchId;
  final String store;
  final DateTime createdAt;
  final Map<String, String> entries;

  const _JournalEvent({
    required this.type,
    required this.batchId,
    required this.store,
    required this.createdAt,
    this.entries = const <String, String>{},
  });

  Map<String, dynamic> toJson() {
    return {
      'type': type,
      'batchId': batchId,
      'store': store,
      'createdAt': createdAt.toIso8601String(),
      if (entries.isNotEmpty) 'entries': entries,
    };
  }

  static _JournalEvent? fromLine(String line) {
    try {
      final decoded = jsonDecode(line);
      if (decoded is! Map<String, dynamic>) return null;
      final type = decoded['type'] as String?;
      final batchId = decoded['batchId'] as String?;
      final store = decoded['store'] as String?;
      final createdAtRaw = decoded['createdAt'] as String?;
      if (type == null || batchId == null || store == null || createdAtRaw == null) {
        return null;
      }
      final entriesRaw = decoded['entries'];
      final entries = entriesRaw is Map
          ? Map<String, String>.from(
              entriesRaw.map((key, value) => MapEntry(key.toString(), value.toString())),
            )
          : const <String, String>{};
      return _JournalEvent(
        type: type,
        batchId: batchId,
        store: store,
        createdAt: DateTime.parse(createdAtRaw),
        entries: entries,
      );
    } catch (_) {
      return null;
    }
  }
}

class CriticalWriteJournal {
  static const _journalFileName = '.critical_write_journal.jsonl';
  static const int _compactEveryAppends = 200;
  static const int _compactMinBytes = 512 * 1024;
  Future<void> _operationQueue = Future<void>.value();
  int _appendCountSinceCompaction = 0;

  Future<T> _enqueue<T>(Future<T> Function() action) {
    final completer = Completer<T>();
    _operationQueue = _operationQueue.then((_) async {
      try {
        final result = await action();
        completer.complete(result);
      } catch (e, s) {
        completer.completeError(e, s);
      }
    });
    return completer.future;
  }

  Future<File> _journalFile() async {
    final dirPath = await filesDir();
    final dir = Directory(dirPath);
    if (!dir.existsSync()) {
      dir.createSync(recursive: true);
    }
    final file = File(join(dirPath, _journalFileName));
    if (!file.existsSync()) {
      file.createSync(recursive: true);
    }
    return file;
  }

  String _newBatchId(String store) {
    return '$store-${DateTime.now().microsecondsSinceEpoch}';
  }

  Future<void> _appendEvent(_JournalEvent event) async {
    final file = await _journalFile();
    final sink = file.openWrite(mode: FileMode.append);
    sink.writeln(jsonEncode(event.toJson()));
    await sink.flush();
    await sink.close();

    _appendCountSinceCompaction++;
    if (_appendCountSinceCompaction >= _compactEveryAppends) {
      _appendCountSinceCompaction = 0;
      await _compactIfNeeded(file);
    }
  }

  Future<String> journalPath() {
    return _enqueue(() async {
      final file = await _journalFile();
      return file.path;
    });
  }

  Future<String> recordPendingWrite({
    required String store,
    required Map<String, String> entries,
  }) {
    return _enqueue(() async {
      if (store.trim().isEmpty || entries.isEmpty) {
        return '';
      }
      final batchId = _newBatchId(store);
      final now = DateTime.now().toUtc();
      await _appendEvent(
        _JournalEvent(
          type: 'pending_write',
          batchId: batchId,
          store: store,
          createdAt: now,
          entries: Map<String, String>.from(entries),
        ),
      );
      return batchId;
    });
  }

  Future<void> markBatchApplied({
    required String store,
    required String batchId,
  }) {
    return _enqueue(() async {
      if (store.trim().isEmpty || batchId.trim().isEmpty) {
        return;
      }
      final now = DateTime.now().toUtc();
      await _appendEvent(
        _JournalEvent(
          type: 'applied',
          batchId: batchId,
          store: store,
          createdAt: now,
        ),
      );
    });
  }

  Future<List<CriticalWriteBatch>> pendingWriteBatchesForStore(String store) {
    return _enqueue(() async {
      if (store.trim().isEmpty) return <CriticalWriteBatch>[];
      final events = await _readAllEvents();
      final pending = <String, CriticalWriteBatch>{};
      final applied = <String>{};

      for (final event in events) {
        if (event.store != store) continue;
        if (event.type == 'pending_write') {
          pending[event.batchId] = CriticalWriteBatch(
            batchId: event.batchId,
            store: event.store,
            createdAt: event.createdAt,
            entries: event.entries,
          );
        } else if (event.type == 'applied') {
          applied.add(event.batchId);
        }
      }

      final unresolved = pending.entries
          .where((entry) => !applied.contains(entry.key))
          .map((entry) => entry.value)
          .toList(growable: false)
        ..sort((a, b) => a.createdAt.compareTo(b.createdAt));

      return unresolved;
    });
  }

  Future<List<_JournalEvent>> _readAllEvents() async {
    final file = await _journalFile();
    if (!file.existsSync()) {
      return <_JournalEvent>[];
    }
    final lines = await file.readAsLines();
    final events = <_JournalEvent>[];
    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;
      final event = _JournalEvent.fromLine(trimmed);
      if (event != null) {
        events.add(event);
      }
    }
    return events;
  }

  Future<void> _compactIfNeeded(File file) async {
    if (!file.existsSync()) return;
    final length = await file.length();
    if (length < _compactMinBytes) return;

    final events = await _readAllEvents();
    if (events.isEmpty) {
      await file.writeAsString('', flush: true);
      return;
    }

    final pending = <String, _JournalEvent>{};
    final applied = <String>{};

    for (final event in events) {
      if (event.type == 'pending_write') {
        pending[event.batchId] = event;
      } else if (event.type == 'applied') {
        applied.add(event.batchId);
      }
    }

    final unresolved = pending.entries
        .where((entry) => !applied.contains(entry.key))
        .map((entry) => entry.value)
        .toList(growable: false)
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));

    final temp = File('${file.path}.tmp');
    final sink = temp.openWrite(mode: FileMode.write);
    for (final event in unresolved) {
      sink.writeln(jsonEncode(event.toJson()));
    }
    await sink.flush();
    await sink.close();

    if (file.existsSync()) {
      await file.delete();
    }
    await temp.rename(file.path);
  }
}

final criticalWriteJournal = CriticalWriteJournal();
