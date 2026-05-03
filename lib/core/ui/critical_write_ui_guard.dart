import 'package:apexo/core/sync_write_health.dart';
import 'package:fluent_ui/fluent_ui.dart';

bool runCriticalWriteUiGuard(
  BuildContext context, {
  required String actionLabel,
}) {
  try {
    syncWriteHealth.ensureHealthyForStores(
      const ['appointments', 'patients'],
      operation: actionLabel,
    );
    return true;
  } on CriticalWriteBlockedException catch (e) {
    displayInfoBar(
      context,
      builder: (ctx, close) => InfoBar(
        title: const Text('Write blocked to prevent data loss'),
        content: Text('Please wait for storage recovery before $actionLabel.\n$e'),
        severity: InfoBarSeverity.error,
        action: IconButton(
          icon: const Icon(FluentIcons.clear),
          onPressed: close,
        ),
      ),
    );
    return false;
  }
}
