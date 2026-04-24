import 'package:fluent_ui/fluent_ui.dart';
import 'package:apexo/core/ui/components/app_button.dart';

const String kBulkUpdatePassword = '0001';

Future<bool> showPasswordGuardDialog(
  BuildContext context, {
  String title = 'Protected Access',
  String message = 'Enter password to continue.',
  String confirmLabel = 'Continue',
  String password = kBulkUpdatePassword,
}) async {
  final passwordController = TextEditingController();
  String? error;

  final unlocked = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (context, setStateDialog) => ContentDialog(
        title: Text(title),
        content: SizedBox(
          width: 360,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(message),
              const SizedBox(height: 8),
              TextBox(
                controller: passwordController,
                placeholder: 'Password',
                obscureText: true,
                onChanged: (_) {
                  if (error != null) {
                    setStateDialog(() => error = null);
                  }
                },
              ),
              if (error != null) ...[
                const SizedBox(height: 6),
                Text(
                  error!,
                  style: const TextStyle(
                    color: Color(0xFFD6455D),
                    fontSize: 12,
                  ),
                ),
              ],
            ],
          ),
        ),
        actions: [
          AppButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            label: 'Cancel',
            variant: AppButtonVariant.secondary,
          ),
          AppButton(
            onPressed: () {
              if (passwordController.text.trim() != password) {
                setStateDialog(() => error = 'Invalid password.');
                return;
              }
              Navigator.pop(dialogContext, true);
            },
            label: confirmLabel,
          ),
        ],
      ),
    ),
  );

  return unlocked == true;
}

Future<void> runPasswordProtectedAction(
  BuildContext context, {
  String title = 'Protected Access',
  String message = 'Enter password to continue.',
  String confirmLabel = 'Continue',
  String password = kBulkUpdatePassword,
  required Future<void> Function() onAuthorized,
}) async {
  final unlocked = await showPasswordGuardDialog(
    context,
    title: title,
    message: message,
    confirmLabel: confirmLabel,
    password: password,
  );

  if (!unlocked || !context.mounted) return;
  await onAuthorized();
}
