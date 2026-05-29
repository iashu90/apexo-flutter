import 'dart:async';

/// Defers non-urgent sync work while the user is actively typing.
class SyncPriorityDeferral {
  int _typingUntilEpochMs = 0;

  void markTyping({Duration holdFor = const Duration(milliseconds: 900)}) {
    final until = DateTime.now().add(holdFor).millisecondsSinceEpoch;
    if (until > _typingUntilEpochMs) {
      _typingUntilEpochMs = until;
    }
  }

  bool get isTypingWindowActive {
    return DateTime.now().millisecondsSinceEpoch < _typingUntilEpochMs;
  }

  Future<void> waitForTypingIdle() async {
    while (isTypingWindowActive) {
      final remaining = _typingUntilEpochMs - DateTime.now().millisecondsSinceEpoch;
      if (remaining <= 0) break;
      final waitMs = remaining > 120 ? 120 : remaining;
      await Future.delayed(Duration(milliseconds: waitMs));
    }
  }
}

final syncPriorityDeferral = SyncPriorityDeferral();
