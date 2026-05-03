import 'package:apexo/core/observable.dart';
import 'package:apexo/core/activity_logger.dart';

class CriticalWriteBlockedException implements Exception {
  final String message;

  CriticalWriteBlockedException(this.message);

  @override
  String toString() => message;
}

class StoreWriteHealth {
  final DateTime? lastLocalWriteAt;
  final DateTime? lastPushAt;
  final DateTime? lastFailureAt;
  final String? lastFailureMessage;
  final DateTime? lastSyncFailureAt;
  final String? lastSyncFailureMessage;

  const StoreWriteHealth({
    this.lastLocalWriteAt,
    this.lastPushAt,
    this.lastFailureAt,
    this.lastFailureMessage,
    this.lastSyncFailureAt,
    this.lastSyncFailureMessage,
  });

  StoreWriteHealth copyWith({
    DateTime? lastLocalWriteAt,
    DateTime? lastPushAt,
    DateTime? lastFailureAt,
    String? lastFailureMessage,
    DateTime? lastSyncFailureAt,
    String? lastSyncFailureMessage,
    bool clearFailure = false,
    bool clearSyncFailure = false,
  }) {
    return StoreWriteHealth(
      lastLocalWriteAt: lastLocalWriteAt ?? this.lastLocalWriteAt,
      lastPushAt: lastPushAt ?? this.lastPushAt,
      lastFailureAt: clearFailure ? null : (lastFailureAt ?? this.lastFailureAt),
      lastFailureMessage:
          clearFailure ? null : (lastFailureMessage ?? this.lastFailureMessage),
      lastSyncFailureAt: clearSyncFailure
          ? null
          : (lastSyncFailureAt ?? this.lastSyncFailureAt),
      lastSyncFailureMessage: clearSyncFailure
          ? null
          : (lastSyncFailureMessage ?? this.lastSyncFailureMessage),
    );
  }
}

class SyncWriteHealthSnapshot {
  final Map<String, StoreWriteHealth> stores;
  final bool criticalReadOnlyMode;
  final String? criticalReadOnlyReason;
  final DateTime? storageProbeAt;

  const SyncWriteHealthSnapshot({
    required this.stores,
    this.criticalReadOnlyMode = false,
    this.criticalReadOnlyReason,
    this.storageProbeAt,
  });

  static const empty = SyncWriteHealthSnapshot(stores: {});

  SyncWriteHealthSnapshot copyWith({
    Map<String, StoreWriteHealth>? stores,
    bool? criticalReadOnlyMode,
    String? criticalReadOnlyReason,
    DateTime? storageProbeAt,
    bool clearCriticalReadOnlyReason = false,
  }) {
    return SyncWriteHealthSnapshot(
      stores: stores ?? this.stores,
      criticalReadOnlyMode: criticalReadOnlyMode ?? this.criticalReadOnlyMode,
      criticalReadOnlyReason: clearCriticalReadOnlyReason
          ? null
          : (criticalReadOnlyReason ?? this.criticalReadOnlyReason),
      storageProbeAt: storageProbeAt ?? this.storageProbeAt,
    );
  }

  StoreWriteHealth forStore(String store) {
    return stores[store] ?? const StoreWriteHealth();
  }

  ({String store, DateTime at})? latestLocalWrite() {
    String? bestStore;
    DateTime? bestTime;
    for (final entry in stores.entries) {
      final at = entry.value.lastLocalWriteAt;
      if (at == null) continue;
      if (bestTime == null || at.isAfter(bestTime)) {
        bestTime = at;
        bestStore = entry.key;
      }
    }
    if (bestStore == null || bestTime == null) return null;
    return (store: bestStore, at: bestTime);
  }

  ({String store, DateTime at})? latestPush() {
    String? bestStore;
    DateTime? bestTime;
    for (final entry in stores.entries) {
      final at = entry.value.lastPushAt;
      if (at == null) continue;
      if (bestTime == null || at.isAfter(bestTime)) {
        bestTime = at;
        bestStore = entry.key;
      }
    }
    if (bestStore == null || bestTime == null) return null;
    return (store: bestStore, at: bestTime);
  }

  ({String store, DateTime at, String message})? latestBlockingFailure(
    Iterable<String> criticalStores,
  ) {
    String? bestStore;
    DateTime? bestTime;
    String? bestMessage;

    for (final store in criticalStores) {
      final status = forStore(store);
      final failureAt = status.lastFailureAt;
      if (failureAt == null) continue;

      final localSuccessAt = status.lastLocalWriteAt;
      final isBlocking =
          localSuccessAt == null || failureAt.isAfter(localSuccessAt);
      if (!isBlocking) continue;

      if (bestTime == null || failureAt.isAfter(bestTime)) {
        bestTime = failureAt;
        bestStore = store;
        bestMessage = status.lastFailureMessage ?? 'Local write failure';
      }
    }

    if (bestStore == null || bestTime == null || bestMessage == null) {
      return null;
    }
    return (store: bestStore, at: bestTime, message: bestMessage);
  }

  ({String store, DateTime at, String message})? latestCriticalSyncFailure(
    Iterable<String> criticalStores,
  ) {
    String? bestStore;
    DateTime? bestTime;
    String? bestMessage;

    for (final store in criticalStores) {
      final status = forStore(store);
      final failureAt = status.lastSyncFailureAt;
      if (failureAt == null) continue;

      final pushAt = status.lastPushAt;
      final unresolved = pushAt == null || failureAt.isAfter(pushAt);
      if (!unresolved) continue;

      if (bestTime == null || failureAt.isAfter(bestTime)) {
        bestTime = failureAt;
        bestStore = store;
        bestMessage = status.lastSyncFailureMessage ?? 'Sync/API failure';
      }
    }

    if (bestStore == null || bestTime == null || bestMessage == null) {
      return null;
    }

    return (store: bestStore, at: bestTime, message: bestMessage);
  }
}

class SyncWriteHealthController {
  final ObservableState<SyncWriteHealthSnapshot> _state =
      ObservableState<SyncWriteHealthSnapshot>(SyncWriteHealthSnapshot.empty);
  final Set<String> _blockingFailureAlertedStores = <String>{};

  Stream<SyncWriteHealthSnapshot> get stream => _state.stream;

  SyncWriteHealthSnapshot get snapshot => _state();

  void recordLocalWriteSuccess({required String store, int records = 0}) {
    if (store.trim().isEmpty) return;
    final next = _copyStores();
    final current = next[store] ?? const StoreWriteHealth();
    next[store] = current.copyWith(
      lastLocalWriteAt: DateTime.now(),
      clearFailure: true,
    );
    _state(SyncWriteHealthSnapshot(stores: next));
  }

  void recordPushSuccess({required String store, int records = 0}) {
    if (store.trim().isEmpty) return;
    final next = _copyStores();
    final current = next[store] ?? const StoreWriteHealth();
    next[store] = current.copyWith(
      lastPushAt: DateTime.now(),
      clearSyncFailure: true,
    );
    _state(SyncWriteHealthSnapshot(stores: next));
  }

  void recordWriteFailure({required String store, required Object error}) {
    if (store.trim().isEmpty) return;
    final existing = snapshot.forStore(store);
    final wasBlocking = existing.lastFailureAt != null &&
        (existing.lastLocalWriteAt == null ||
            existing.lastFailureAt!.isAfter(existing.lastLocalWriteAt!));

    final next = _copyStores();
    final current = next[store] ?? const StoreWriteHealth();
    next[store] = current.copyWith(
      lastFailureAt: DateTime.now(),
      lastFailureMessage: error.toString(),
    );
    _state(SyncWriteHealthSnapshot(stores: next));

    final updated = snapshot.forStore(store);
    final isBlocking = updated.lastFailureAt != null &&
        (updated.lastLocalWriteAt == null ||
            updated.lastFailureAt!.isAfter(updated.lastLocalWriteAt!));

    if (!wasBlocking && isBlocking && !_blockingFailureAlertedStores.contains(store)) {
      _blockingFailureAlertedStores.add(store);
      ActivityLogger.logAction(
        'CRITICAL_STORAGE_FAILURE_FIRST_BLOCKING',
        screen: 'StorageHealth',
        data: {
          'store': store,
          'error': error.toString(),
          'severity': 'HIGH',
        },
      );
    }
  }

  void recordSyncFailure({required String store, required Object error}) {
    if (store.trim().isEmpty) return;
    final next = _copyStores();
    final current = next[store] ?? const StoreWriteHealth();
    next[store] = current.copyWith(
      lastSyncFailureAt: DateTime.now(),
      lastSyncFailureMessage: error.toString(),
    );
    _state(SyncWriteHealthSnapshot(stores: next));
  }

  void recordStorageProbeSuccess() {
    _state(
      snapshot.copyWith(
        criticalReadOnlyMode: false,
        clearCriticalReadOnlyReason: true,
        storageProbeAt: DateTime.now(),
      ),
    );
  }

  void recordStorageProbeFailure(Object error) {
    _state(
      snapshot.copyWith(
        criticalReadOnlyMode: true,
        criticalReadOnlyReason: error.toString(),
        storageProbeAt: DateTime.now(),
      ),
    );

    ActivityLogger.logAction(
      'CRITICAL_STORAGE_PROBE_FAILURE',
      screen: 'StorageHealth',
      data: {
        'severity': 'HIGH',
        'reason': error.toString(),
      },
    );
  }

  void ensureHealthyForStores(
    Iterable<String> stores, {
    String operation = 'write',
  }) {
    if (snapshot.criticalReadOnlyMode) {
      throw CriticalWriteBlockedException(
        'Read-only safety mode is active: ${snapshot.criticalReadOnlyReason ?? 'storage probe failed'}',
      );
    }

    final blocking = snapshot.latestBlockingFailure(stores);
    if (blocking == null) return;
    throw CriticalWriteBlockedException(
      'Blocked $operation for ${blocking.store}: ${blocking.message}',
    );
  }

  Map<String, StoreWriteHealth> _copyStores() {
    return Map<String, StoreWriteHealth>.from(snapshot.stores);
  }
}

final syncWriteHealth = SyncWriteHealthController();
