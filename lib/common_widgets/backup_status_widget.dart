import 'package:fluent_ui/fluent_ui.dart';
import 'package:hive/hive.dart';
import 'package:apexo/services/backups.dart';

class BackupStatusWidget extends StatefulWidget {
  const BackupStatusWidget({super.key});

  @override
  State<BackupStatusWidget> createState() => _BackupStatusWidgetState();
}

class _BackupStatusWidgetState extends State<BackupStatusWidget> {
  Future<bool> _isTodayBackupDone() async {
    final box = await Hive.openBox('settings');
    final lastBackup = box.get('lastBackupDate') as String?;
    final today = DateTime.now();
    final todayString = "${today.year}-${today.month}-${today.day}";
    return lastBackup == todayString;
  }

  void _handleBackup(BuildContext context) async {
    await backups.uploadLatestBackupToGoogleDrive(
      context,
      onSuccess: () {
        showDialog(
          context: context,
          builder: (context) => ContentDialog(
            title: const Text('Backup Successful'),
            content: const Text('Google Drive backup completed successfully!'),
            actions: [
              Button(
                child: const Text('OK'),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
        );
      },
    );
    setState(() {}); // Refresh status after backup
  }

  @override
  Widget build(BuildContext context) {
    final textStyle = TextStyle(
      color: (FluentTheme.of(context).iconTheme.color ?? Colors.grey)
          .withAlpha(102),
      fontSize: 12,
    );
    return Row(
      crossAxisAlignment:
          CrossAxisAlignment.center, // vertical center alignment
      children: [
        FutureBuilder(
          future: _isTodayBackupDone(),
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const SizedBox(width: 16, height: 16);
            }
            if (snapshot.data == true) {
              return Row(
                children: [
                  Icon(FluentIcons.cloud_download,
                      color: Colors.green, size: 16),
                  const SizedBox(width: 3),
                  Text("Drive backup done", style: textStyle),
                ],
              );
            } else {
              return Row(
                children: [
                  Icon(FluentIcons.cloud_flow, color: Colors.red, size: 16),
                  const SizedBox(width: 3),
                  Text("No Drive backup", style: textStyle),
                ],
              );
            }
          },
        ),
        const SizedBox(width: 12),
        FilledButton(
          style: ButtonStyle(
            backgroundColor:
                ButtonState.all(Colors.blue.lighter), // milder color
            padding: ButtonState.all(
                const EdgeInsets.symmetric(horizontal: 10, vertical: 6)),
          ),
          onPressed: () async {
            _handleBackup(context);
          },
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(FluentIcons.sync, size: 10),
              SizedBox(width: 4),
              Text("Manual Backup", style: TextStyle(fontSize: 10)),
            ],
          ),
        ),
      ],
    );
  }
}
