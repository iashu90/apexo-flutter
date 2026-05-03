import 'package:apexo/core/observable.dart';

class StoreWriteHealth {
  final DateTime? lastLocalWriteAt;
  final DateTime? lastPushAt;
  final DateTime? lastFailureAt;
  final String? lastFailureMessage;

  const StoreWriteHealth({
    this.lastLocalWriteAt,
    this.lastPushAt,
    this.lastFailureAt,
    this.lastFailureMessage,
  });

  StoreWriteHealth copyWith({
    DateTime? lastLocalWriteAt,
    DateTime? lastPushAt,
    DateTime? lastFailureAt,
    String? lastFailureMessage,
    bool clearFailure = false,
  }) {
    return StoreWriteHealth(
      lastLocalWriteAt: lastLocalWriteAt ?? this.lastLocalWriteAt,
      lastPushAt: lastPushAt ?? this.lastPushAt,
      lastFailureAt: clearFailure ? null : (lastFailureAt ?? this.lastFailureAt),
      lastFailureMessage:
          clearFailure ? null : (lastFailureMessage ?? this.lastFailureMessage),
    );
  }
}

class SyncWriteHealthSnapshot {
  final Map<String, StoreWriteHealth> stores;

  const SyncWriteHealthSnapshot({required this.stores});

  static const empty = SyncWriteHealthSnapshot(stores: {});

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
}

class SyncWriteHealthController {
  final ObservableState<SyncWriteHealthSnapshot> _state =
      ObservableState<SyncWriteHealthSnapshot>(SyncWriteHealthSnapshot.empty);

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
    next[store] = current.copyWith(lastPushAt: DateTime.now());
    _state(SyncWriteHealthSnapshot(stores: next));
  }

  void recordWriteFailure({required String store, required Object error}) {
    if (store.trim().isEmpty) return;
    final next = _copyStores();
    final current = next[store] ?? const StoreWriteHealth();
    next[store] = current.copyWith(
      lastFailureAt: DateTime.now(),
      lastFailureMessage: error.toString(),
    );
    _state(SyncWriteHealthSnapshot(stores: next));
  }

  void ensureHealthyForStores(
    Iterable<String> stores, {
    String operation = 'write',
  }) {
    final blocking = snapshot.latestBlockingFailure(stores);
    if (blocking == null) return;
    throw StateError(
      'Blocked $operation for ${blocking.store}: ${blocking.message}',
    );
  }

  Map<String, StoreWriteHealth> _copyStores() {
    return Map<String, StoreWriteHealth>.from(snapshot.stores);
  }
}

final syncWriteHealth = SyncWriteHealthController();
