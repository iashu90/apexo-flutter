import 'dart:async';

import 'package:fluent_ui/fluent_ui.dart';

class ExportProgressController {
  bool _cancelled = false;
  bool _disposed = false;
  bool _closed = false;
  final ValueNotifier<double?> progress = ValueNotifier<double?>(null);

  bool get isCancelled => _cancelled;
  bool get isClosed => _closed;

  void cancel() {
    _cancelled = true;
  }

  void setProgress(double? value) {
    if (_disposed || _closed) return;
    if (value == null) {
      progress.value = null;
      return;
    }
    progress.value = value.clamp(0.0, 1.0);
  }

  void markClosed() {
    _closed = true;
  }

  void dispose() {
    _disposed = true;
    progress.dispose();
  }
}

Future<T?> runWithExportProgressDialog<T>({
  required BuildContext context,
  required String title,
  String message = 'Please wait while we process your request.',
  required Future<T?> Function(ExportProgressController controller) task,
}) async {
  final controller = ExportProgressController();
  BuildContext? dialogContext;
  var dialogBuilt = false;

  unawaited(
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        dialogBuilt = true;
        dialogContext = ctx;
        return ContentDialog(
          title: Row(
            children: [
              Expanded(child: Text(title)),
              IconButton(
                icon: const Icon(FluentIcons.chrome_close, size: 10),
                onPressed: () {
                  controller.cancel();
                  controller.markClosed();
                  Navigator.pop(ctx);
                },
              ),
            ],
          ),
          content: SizedBox(
            width: 360,
            child: ValueListenableBuilder<double?>(
              valueListenable: controller.progress,
              builder: (context, progress, _) {
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(message),
                    const SizedBox(height: 12),
                    ProgressBar(value: progress),
                    const SizedBox(height: 8),
                    Text(
                      controller.isCancelled
                          ? 'Cancelling...'
                          : (progress == null
                              ? 'Working...'
                              : '${(progress * 100).clamp(0, 100).toStringAsFixed(0)}%'),
                      style: const TextStyle(
                        color: Color(0xFF64748B),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          actions: [
            Button(
              onPressed: () {
                controller.cancel();
                controller.markClosed();
                Navigator.pop(ctx);
              },
              child: const Text('Close'),
            ),
          ],
        );
      },
    ).whenComplete(controller.markClosed),
  );

  await Future<void>.delayed(Duration.zero);

  try {
    return await task(controller);
  } finally {
    if (dialogBuilt && !controller.isClosed && dialogContext != null && dialogContext!.mounted) {
      Navigator.of(dialogContext!).pop();
      controller.markClosed();
    }
    controller.dispose();
  }
}
