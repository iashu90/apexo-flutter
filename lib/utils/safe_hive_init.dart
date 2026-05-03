import 'package:apexo/utils/safe_dir.dart';
import 'package:hive_flutter/adapters.dart';

Future<void> safeHiveInit() async {
  await migrateLegacyFilesDirIfNeeded();
  try {
    await Hive.initFlutter();
  } catch (e) {
    Hive.init(baseDir);
  }
}
