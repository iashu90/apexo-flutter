import 'dart:convert';
import 'dart:math';
import 'package:apexo/core/activity_logger.dart';
import 'package:apexo/utils/constants.dart';
import 'package:apexo/utils/logger.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:intl/intl.dart';
import 'dart:async';
import 'package:pocketbase/pocketbase.dart';

class RowToWriteRemotely {
  String id;
  String data;
  String store = "";
  RowToWriteRemotely({required this.id, required this.data});
  toJson() {
    return {
      "id": id,
      "data": data,
      "store": store,
    };
  }
}

class Row extends RowToWriteRemotely {
  int ts;
  Row({required super.id, required super.data, required this.ts});
}

class VersionedResult {
  int version;
  List<Row> rows;
  VersionedResult(this.version, this.rows);
}

class SaveRemote {
  static const int _syncPageSize = 200;
  static const int _syncOverlapMs = 5 * 60 * 1000;
  static const int _sessionRecoveryLookbackMs = 2 * 24 * 60 * 60 * 1000;
  static const Duration _readTimeout = Duration(seconds: 8);
  static const Duration _writeTimeout = Duration(seconds: 12);
  static const int _transientMaxRetries = 2;
  static const int _retryBaseDelayMs = 350;
  static final Set<String> _sessionRecoveryDoneStores = <String>{};

  final String storeName;
  final PocketBase pbInstance;

  // timer to debounce online status checks
  Timer? timer;

  // callback to notify the app of online status changes
  void Function(bool)? onOnlineStatusChange;

  bool isOnline = true;
  SaveRemote({
    required this.storeName,
    required this.pbInstance,
    this.onOnlineStatusChange,
  }) {
    checkOnline();
  }

  RecordService get remoteRows {
    return pbInstance.collection(dataCollectionName);
  }

  bool _isTransientError(Object error) {
    final text = error.toString().toLowerCase();
    return text.contains('statuscode: 0') ||
        text.contains('connection closed') ||
        text.contains('timed out') ||
        text.contains('timeout') ||
        text.contains('socket') ||
        text.contains('connection reset') ||
        text.contains('network') ||
        text.contains('abort');
  }

  Duration _retryDelayForAttempt(int attempt) {
    final exp = min(3, attempt);
    final base = _retryBaseDelayMs * (1 << exp);
    final jitter = Random().nextInt(180);
    return Duration(milliseconds: base + jitter);
  }

  Future<T> _runWithRetry<T>({
    required Future<T> Function() operation,
    required String opName,
    Duration timeout = _readTimeout,
    int maxRetries = _transientMaxRetries,
  }) async {
    Object? lastError;
    StackTrace? lastStack;

    for (var attempt = 0; attempt <= maxRetries; attempt++) {
      try {
        return await operation().timeout(timeout);
      } catch (e, s) {
        lastError = e;
        lastStack = s;
        await checkOnline();
        final isTransient = _isTransientError(e);
        if (!isTransient || attempt >= maxRetries) {
          ActivityLogger.logException(e, s, opName);
          rethrow;
        }
        await Future.delayed(_retryDelayForAttempt(attempt));
      }
    }

    throw Exception('$opName failed: $lastError\n$lastStack');
  }

  void retryConnection() {
    if (timer != null && timer!.isActive) {
      return;
    }
    Timer.periodic(const Duration(seconds: 5), (t) {
      timer = t;
      if (isOnline) {
        timer!.cancel();
      } else {
        checkOnline();
      }
    });
  }

  Future<void> checkOnline() async {
    try {
      await pbInstance.health.check().timeout(const Duration(seconds: 3));
    } catch (e) {
      isOnline = false;
      retryConnection();
      if (onOnlineStatusChange != null) onOnlineStatusChange!(isOnline);
      return;
    }
    isOnline = true;
    if (timer != null) {
      timer!.cancel();
    }
    if (onOnlineStatusChange != null) onOnlineStatusChange!(isOnline);
  }

  String formatForPocketBase(int input) {
    // for some reason, pocketbase doesn't accept the ISO8601 format
    // it stores "updated" and "created" fields in the following format: "2024-11-28 12:00:00.000Z"
    // and it disregards the time if a "T" was included in the comparison
    // this format is the more preferable one for pocketbase
    // This behavior is deeply rooted in SQLite: https://www.sqlite.org/lang_datefunc.html
    return "${DateFormat('yyyy-MM-dd HH:mm:ss.SSS').format(DateTime.fromMillisecondsSinceEpoch(input, isUtc: true))}Z";
  }

  Future<VersionedResult> getSince({int version = 0}) async {
    final needsRecoveryPass =
      version > 0 && !_sessionRecoveryDoneStores.contains(storeName);
    final overlapToUse =
      needsRecoveryPass ? _sessionRecoveryLookbackMs : _syncOverlapMs;
    final effectiveVersion = max(0, version - overlapToUse);
    var cursorTs = effectiveVersion;
    var cursorId = "";
    final latestById = <String, Row>{};
    var fetchedCount = 0;
    var cursorAdvancedCount = 0;
    var pages = 0;

    while (true) {
      try {
        final formattedCursorTs = formatForPocketBase(cursorTs);
        final filter =
            '(updated>"$formattedCursorTs"||(updated="$formattedCursorTs"&&id>"$cursorId"))&&store="$storeName"';

        ActivityLogger.logApi(
          "${pbInstance.baseURL}/api/collections/data/records",
          "GET",
          params: {
            "filter": filter,
            "sort": "updated,id",
            "perPage": _syncPageSize,
            "page": 1,
            "fields": "data,id,updated,imgs",
          },
        );

        final pageResult = await _runWithRetry(
          opName: 'getSince.getList',
          timeout: _readTimeout,
          operation: () => remoteRows.getList(
            filter: filter,
            sort: "updated,id",
            perPage: _syncPageSize,
            page: 1,
            fields: "data,id,updated,imgs",
          ),
        );

        ActivityLogger.logApi(
          "${pbInstance.baseURL}/api/collections/data/records",
          "GET_RESPONSE",
          params: {
            "count": pageResult.items.length,
            if (pageResult.items.isNotEmpty) "firstId": pageResult.items.first.id,
            if (pageResult.items.isNotEmpty)
              "firstUpdated": pageResult.items.first.get<String>("updated"),
            if (pageResult.items.isNotEmpty) "lastId": pageResult.items.last.id,
            if (pageResult.items.isNotEmpty)
              "lastUpdated": pageResult.items.last.get<String>("updated"),
          },
        );

        if (pageResult.items.isEmpty) {
          break;
        }

        pages++;
        fetchedCount += pageResult.items.length;

        for (final item in pageResult.items) {
          final ts = DateTime.parse(item.get<String>("updated"))
              .millisecondsSinceEpoch;
          final nextRow =
              Row(id: item.id, data: jsonEncode(item.data["data"]), ts: ts);
          final existing = latestById[item.id];
          if (existing == null || ts >= existing.ts) {
            latestById[item.id] = nextRow;
          }
          fullNamesCache
              .addAll({item.id: List<String>.from(item.data["imgs"])});
        }

        final lastItem = pageResult.items.last;
        final nextCursorTs = DateTime.parse(lastItem.get<String>("updated"))
            .millisecondsSinceEpoch;
        final nextCursorId = lastItem.id;

        // Defensive stop to avoid infinite loops if the backend repeats the same edge item.
        if (nextCursorTs == cursorTs && nextCursorId == cursorId) {
          break;
        }

        cursorTs = nextCursorTs;
        cursorId = nextCursorId;
        cursorAdvancedCount++;

        if (pageResult.items.length < _syncPageSize) {
          break;
        }
      } catch (e) {
        ActivityLogger.logException(e, null, "getSince");
        await checkOnline();
        rethrow;
      }
    }

    final result = latestById.values.toList()
      ..sort((a, b) {
        final tsCmp = a.ts.compareTo(b.ts);
        return tsCmp != 0 ? tsCmp : a.id.compareTo(b.id);
      });

    final dedupedCount = max(0, fetchedCount - result.length);
    ActivityLogger.logSyncTelemetry(
      store: storeName,
      fetched: fetchedCount,
      deduped: dedupedCount,
      cursorAdvanced: cursorAdvancedCount,
      recoveryPassUsed: needsRecoveryPass,
      uniqueRows: result.length,
      pages: pages,
    );

    if (needsRecoveryPass) {
      _sessionRecoveryDoneStores.add(storeName);
    }

    return VersionedResult(
      result.isNotEmpty ? result.map((r) => r.ts).reduce(max) : version,
      result,
    );
  }

  Future<int> getVersion() async {
    try {
      final result = await _runWithRetry(
        opName: 'getVersion.getList',
        timeout: _readTimeout,
        operation: () => remoteRows.getList(
            sort: "-updated",
            perPage: 1,
            filter: 'store="$storeName"',
            fields: "updated"),
      );
      if (result.items.isEmpty) {
        return 0;
      }
      return DateTime.parse(result.items.first.get<String>("updated"))
          .millisecondsSinceEpoch;
    } catch (e) {
      await checkOnline();
      throw Exception(e);
    }
  }

  Future<bool> put(List<RowToWriteRemotely> data) async {
    if (data.isEmpty) {
      return true;
    }

    // split data into chunks of 100
    List<List<RowToWriteRemotely>> chunks = [];
    for (var i = 0; i < data.length; i += 100) {
      chunks.add(data.sublist(i, min(i + 100, data.length)));
    }

    for (var chunk in chunks) {
      try {
        final batchOperation = pbInstance.createBatch();
        for (var item in chunk) {
          batchOperation.collection(dataCollectionName).upsert(
              body: {"store": storeName, "data": item.data, "id": item.id});
        }
        await _runWithRetry(
          opName: 'put.batchSend',
          timeout: _writeTimeout,
          operation: () => batchOperation.send(),
        );
      } catch (e) {
        await checkOnline();
        rethrow;
      }
    }
    return true;
  }

  Future<void> waitForAnotherProcess({
    required String fileName,
    Duration checkInterval = const Duration(milliseconds: 500),
    Duration timeout = const Duration(seconds: 15),
  }) async {
    final stopwatch = Stopwatch()..start();

    while (stopwatch.elapsed < timeout) {
      // Check if the string has been removed
      if (!inProgress.contains(fileName)) {
        return; // Resolves the future if the string is no longer in the set
      }

      // Wait for the next interval before checking again
      await Future.delayed(checkInterval);
    }

    // If we exit the loop, it means the timeout has been reached
    throw TimeoutException(
      'The image was not uploaded in time in another process',
    );
  }

  // some synchronization processes happens too fast
  // that an image might be uploaded twice
  // this is a workaround to avoid that
  Set<String> inProgress = <String>{};
  Future<bool> uploadImage(String rowID, http.MultipartFile file) async {
    final nameWithoutExt = p.basenameWithoutExtension(file.filename ?? "null");
    try {
      if (inProgress.contains(nameWithoutExt)) {
        await waitForAnotherProcess(fileName: nameWithoutExt);
        await Future.delayed(const Duration(milliseconds: 100));
      }
      late List<String> alreadyUploaded;
      try {
        final row = await _runWithRetry(
          opName: 'uploadImage.getOne',
          timeout: _readTimeout,
          operation: () => remoteRows.getOne(rowID, fields: "imgs"),
        );
        alreadyUploaded = List<String>.from(row.data["imgs"]);
      } catch (e, s) {
        alreadyUploaded = [];
        logger(
            "Error while trying to get a list of already uploaded images: $e",
            s);
      }

      // skip if file was already uploaded
      if (alreadyUploaded
          .any((uploaded) => uploaded.contains(nameWithoutExt))) {
        return false;
      }
      inProgress.add(nameWithoutExt);
      final updatedRecord = await _runWithRetry(
        opName: 'uploadImage.update',
        timeout: _writeTimeout,
        operation: () => remoteRows.update(rowID, files: [file], fields: "imgs"),
      );
      fullNamesCache
          .addAll({rowID: List<String>.from(updatedRecord.data["imgs"])});
    } catch (e) {
      inProgress.remove(nameWithoutExt);
      await checkOnline();
      rethrow;
    }
    inProgress.remove(nameWithoutExt);
    return true;
  }

  Future<bool> deleteImage(String rowID, String imgName) async {
    try {
      final nameWithoutExt = p.basenameWithoutExtension(imgName);
      final row = await _runWithRetry(
        opName: 'deleteImage.getOne',
        timeout: _readTimeout,
        operation: () => remoteRows.getOne(rowID, fields: "imgs"),
      );
      final allFullNames = List<String>.from(row.data["imgs"]);
      final fullNameToDelete =
          allFullNames.where((e) => e.contains(nameWithoutExt)).firstOrNull;
      if (fullNameToDelete == null) {
        return false;
      }
      await _runWithRetry(
        opName: 'deleteImage.update',
        timeout: _writeTimeout,
        operation: () => remoteRows.update(rowID, body: {
          "imgs-": [fullNameToDelete],
        }),
      );
    } catch (e) {
      await checkOnline();
      rethrow;
    }
    return true;
  }

  Future<String?> getImageLink(String rowID, String imageName) async {
    try {
      List<String> fullNames;
      if (fullNamesCache.containsKey(rowID)) {
        fullNames = fullNamesCache[rowID]!;
      } else {
        final record = await _runWithRetry(
          opName: 'getImageLink.getOne',
          timeout: _readTimeout,
          operation: () => remoteRows.getOne(rowID, fields: "imgs"),
        );
        fullNames = List<String>.from(record.data["imgs"]);
      }
      fullNamesCache[rowID] = fullNames;
      final candidates = fullNames
          .where((e) => e.contains(imageName.split(".").first))
          .toList();
      if (candidates.isEmpty) {
        return null;
      } else {
        return "${pbInstance.baseURL}/api/files/$dataCollectionName/$rowID/${candidates.first}";
      }
    } catch (e) {
      await checkOnline();
      rethrow;
    }
  }

  Future<void> deleteRow(String id) async {
    await _runWithRetry(
      opName: 'deleteRow.delete',
      timeout: _writeTimeout,
      operation: () => remoteRows.delete(id),
    );
  }

  Map<String, List<String>> fullNamesCache = {};
}
