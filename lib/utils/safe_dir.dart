import 'dart:io';

import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';

const baseDir = 'apexo-files';
bool _legacyMigrationDone = false;

class StorageSelfTestResult {
  final bool success;
  final String message;

  const StorageSelfTestResult({required this.success, required this.message});
}

Future<String> filesDir() async {
  try {
    return join((await getApplicationSupportDirectory()).path, baseDir);
  } catch (e) {
    return baseDir;
  }
}

Future<void> migrateLegacyFilesDirIfNeeded() async {
  if (_legacyMigrationDone) return;
  _legacyMigrationDone = true;

  try {
    final targetPath = await filesDir();
    final targetDir = Directory(targetPath);
    if (!targetDir.existsSync()) {
      targetDir.createSync(recursive: true);
    }

    if (targetDir.listSync().isNotEmpty) {
      return;
    }

    final legacyPath =
        join((await getApplicationDocumentsDirectory()).path, baseDir);
    final legacyDir = Directory(legacyPath);
    if (!legacyDir.existsSync()) {
      return;
    }

    for (final entity in legacyDir.listSync(recursive: false)) {
      final name = basename(entity.path);
      final destination = join(targetPath, name);
      if (entity is File) {
        entity.copySync(destination);
      }
    }
  } catch (_) {
    // If migration fails, we still keep running with the new directory.
  }
}

Future<StorageSelfTestResult> runStorageSelfTest() async {
  try {
    final path = await filesDir();
    final dir = Directory(path);
    if (!dir.existsSync()) {
      dir.createSync(recursive: true);
    }

    final probeName = '.storage_probe_${DateTime.now().millisecondsSinceEpoch}.tmp';
    final probe = File(join(path, probeName));
    const payload = 'apexo-storage-self-test';

    await probe.writeAsString(payload, flush: true);
    final readBack = await probe.readAsString();
    if (readBack != payload) {
      try {
        await probe.delete();
      } catch (_) {}
      return const StorageSelfTestResult(
        success: false,
        message: 'Probe read mismatch after write',
      );
    }

    await probe.delete();
    return StorageSelfTestResult(
      success: true,
      message: 'Storage self-test passed at $path',
    );
  } catch (e) {
    return StorageSelfTestResult(
      success: false,
      message: 'Storage self-test failed: $e',
    );
  }
}
