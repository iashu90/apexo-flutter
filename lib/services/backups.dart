import 'dart:convert';

import 'package:apexo/core/observable.dart';
import 'package:apexo/core/save_local.dart';
import 'package:apexo/utils/logger.dart';
import 'package:apexo/services/login.dart';
import 'package:file_picker/file_picker.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:hive_flutter/adapters.dart';
import 'package:http/http.dart';
import 'package:intl/intl.dart';
import 'package:pocketbase/pocketbase.dart';
import 'package:http_parser/http_parser.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'package:googleapis_auth/googleapis_auth.dart';
import 'google_drive_service.dart';

class BackupFile {
  late String key;
  late int size;
  late DateTime date;
  BackupFile(BackupFileInfo info) {
    key = info.key;
    size = info.size;
    date = DateTime.parse(info.modified);
  }
}

class _Backups {
  final list = ObservableState(List<BackupFile>.from([]));
  final loaded = ObservableState(false);
  final loading = ObservableState(false);
  final creating = ObservableState(false);
  final uploading = ObservableState(false);
  final downloading = ObservableState(Map<String, bool>.from({}));
  final deleting = ObservableState(Map<String, bool>.from({}));
  final restoring = ObservableState(Map<String, bool>.from({}));

  Future<void> newBackup() async {
    creating(true);
    await login.pb!.backups.create("");
    await reloadFromRemote();
    creating(false);
  }

  Future<void> delete(String key) async {
    deleting(deleting()..addAll({key: true}));
    await login.pb!.backups.delete(key);
    deleting(deleting()..remove(key));
    await reloadFromRemote();
  }

  Future<Uri> downloadUri(String key) async {
    downloading(downloading()..addAll({key: true}));
    final token = await login.pb!.files.getToken();
    downloading(downloading()..remove(key));
    return login.pb!.backups.getDownloadURL(token, key);
  }

  Future<Uri?> downloadLatestBackup() async {
    // Ensure the list is loaded and not empty
    if (list().isEmpty) {
      await reloadFromRemote();
    }
    if (list().isEmpty) return null;

    // The list is sorted by date descending, so first is latest
    final latestBackup = list().first;
    return await downloadUri(latestBackup.key);
  }

  Future<File?> downloadLatestBackupFile() async {
    final uri = await downloadLatestBackup();
    if (uri == null) return null;

    // Download the file bytes
    final response = await http.get(uri);
    if (response.statusCode != 200) return null;

    // Get a suitable directory to save the file
    final directory = await getTemporaryDirectory();
    final filePath = '${directory.path}/latest_backup.zip';

    // Write the bytes to a file
    final file = File(filePath);
    await file.writeAsBytes(response.bodyBytes);

    return file;
  }

  Future<void> restore(String key) async {
    restoring(restoring()..addAll({key: true}));
    await login.pb!.backups.restore(key);
    await Future.wait(removeAllLocalData.map((e) => e()));
    restoring(restoring()..remove(key));
    login.logout();
  }

  Future<void> pickAndUpload() async {
    final filePickerRes = await FilePicker.platform.pickFiles(
      allowMultiple: false,
      allowedExtensions: ["zip"],
      withReadStream: true,
      allowCompression: true,
      type: FileType.custom,
    );
    if (filePickerRes == null) {
      return;
    }
    if (filePickerRes.files.isEmpty) {
      return;
    }
    final file = filePickerRes.files.first;
    final multipartFile = MultipartFile(
      "file",
      file.readStream!,
      file.size,
      filename:
          "uploaded-${DateTime.now().millisecondsSinceEpoch}-${file.name}",
      contentType: MediaType("application", "zip"),
    );
    uploading(true);
    await login.pb!.backups.upload(multipartFile);
    uploading(false);
    await reloadFromRemote();
  }

  Future<void> reloadFromRemote() async {
    if (login.isAdmin == false ||
        login.pb == null ||
        login.token.isEmpty ||
        login.pb!.authStore.isValid == false) {
      return;
    }
    loading(true);
    try {
      list((await login.pb!.backups.getFullList())
          .map((e) => BackupFile(e))
          .toList()
        ..sort((a, b) => b.date.compareTo(a.date)));
    } catch (e, s) {
      logger("Error when getting full list of backups service: $e", s);
    }
    loaded(true);
    loading(false);
  }

  Future<void> backupToDriveOncePerDay(BuildContext context) async {
    final box = await Hive.openBox('settings');
    final lastBackup = box.get('lastBackupDate') as String?;
    final today = DateTime.now();
    final todayString = "${today.year}-${today.month}-${today.day}";

    if (lastBackup == todayString) {
      // Already backed up today
      return;
    }

    if (!context.mounted) {
      // If the context is not mounted, we cannot show dialogs or interact with the UI
      print('Context is not mounted, skipping backup.');
      return;
    }

    try {
      await uploadLatestBackupToGoogleDrive(context);
      await box.put('lastBackupDate', todayString);
      print('Backup uploaded to Google Drive for $todayString');
    } catch (e) {
      print('Backup failed: $e');
    }
  }

  Future<Map<String, dynamic>> loadConfig() async {
    final file = File('config.json');
    final contents = await file.readAsString();
    return jsonDecode(contents);
  }

  Future<void> uploadLatestBackupToGoogleDrive(
    BuildContext context, {
    void Function()? onSuccess,
  }) async {
    final config = await loadConfig();
    final googleDrive = GoogleDriveService(
      identifier: config['googleDriveIdentifier'],
      secret: config['googleDriveSecret'],
      scopes: ['https://www.googleapis.com/auth/drive.file'],
    );
    AuthClient? client = await googleDrive.getSavedAuthClient();
    client ??= await googleDrive.getUserConsentAuthClient(context);

    final file = await downloadLatestBackupFile();
    if (file == null) {
      print('No backup file found.');
      client.close();
      return;
    }

    final now = DateTime.now();
    final formatted = DateFormat('dd_MM_yyyy_HH_mm_ss').format(now);

    await googleDrive.uploadFileToDrive(
      client: client,
      file: file,
      folderName: 'DrNowfarDentalBackups',
      fileName: '$formatted.zip',
      onSuccess: onSuccess, // Pass the callback down
    );

    client.close();
  }
}

final backups = _Backups();
