import 'dart:async';

import 'package:apexo/core/observable.dart';
import 'package:apexo/services/sync_priority.dart';

class _Network {
  Map<String, void Function()> onOnline = {};
  Map<String, void Function()> onOffline = {};
  final isOnline = ObservableState(false);
  bool _onlineDispatchRunning = false;
  bool _onlineDispatchPending = false;

  Future<void> _drainOnlineCallbacks() async {
    if (_onlineDispatchRunning) {
      _onlineDispatchPending = true;
      return;
    }

    _onlineDispatchRunning = true;
    try {
      do {
        _onlineDispatchPending = false;
        final callbacks = List<void Function()>.from(onOnline.values);
        for (final cb in callbacks) {
          if (!isOnline()) return;
          await syncPriorityDeferral.waitForTypingIdle();
          cb();
          // Stagger store reconnect sync to avoid burst contention.
          await Future.delayed(const Duration(milliseconds: 120));
          if (_onlineDispatchPending) {
            // A newer online wave was requested; restart with freshest callbacks.
            break;
          }
        }
      } while (_onlineDispatchPending && isOnline());
    } finally {
      _onlineDispatchRunning = false;
    }
  }

  _Network() {
    isOnline.observe((_) {
      if (isOnline()) {
        unawaited(_drainOnlineCallbacks());
      } else {
        for (final cb in List<void Function()>.from(onOffline.values)) {
          cb();
        }
      }
    });
  }
}

final network = _Network();
