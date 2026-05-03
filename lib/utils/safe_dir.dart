import 'dart:io';

import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';

const baseDir = 'apexo-files';
bool _legacyMigrationDone = false;

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
