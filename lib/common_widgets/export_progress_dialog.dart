import 'dart:async';

import 'package:fluent_ui/fluent_ui.dart';

class ExportProgressController {
  bool _cancelled = false;
  final ValueNotifier<double?> progress = ValueNotifier<double?>(null);

  bool get isCancelled => _cancelled;

  void cancel() {
    _cancelled = true;
  }

  void setProgress(double? value) {
    progress.value = value;
  }

  void dispose() {
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
  var dialogOpen = true;

  unawaited(
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return ContentDialog(
          title: Row(
            children: [
              Expanded(child: Text(title)),
              IconButton(
                icon: const Icon(FluentIcons.chrome_close, size: 10),
                onPressed: () {
                  controller.cancel();
                  Navigator.pop(dialogContext);
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
                Navigator.pop(dialogContext);
              },
              child: const Text('Close'),
            ),
          ],
        );
      },
    ).then((_) => dialogOpen = false),
  );

  try {
    return await task(controller);
  } finally {
    controller.dispose();
    if (dialogOpen && context.mounted) {
      Navigator.of(context, rootNavigator: true).pop();
    }
  }
}
