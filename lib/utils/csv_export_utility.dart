import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';

class CsvExportUtility {
  static String escapeCell(String value) {
    final escaped = value.replaceAll('"', '""');
    return '"$escaped"';
  }

  static String toCsv(List<List<String>> rows) {
    return rows
        .map(
          (row) => row.map(escapeCell).join(','),
        )
        .join('\n');
  }

  static Future<String?> saveCsv({
    required List<List<String>> rows,
    String fileName = 'export.csv',
    String dialogTitle = 'Save CSV',
  }) async {
    if (kIsWeb) {
      throw UnsupportedError('Saving CSV file is not supported on web.');
    }

    final savePath = await FilePicker.platform.saveFile(
      dialogTitle: dialogTitle,
      fileName: fileName.toLowerCase().endsWith('.csv')
          ? fileName
          : '$fileName.csv',
      type: FileType.custom,
      allowedExtensions: const ['csv'],
    );

    if (savePath == null || savePath.trim().isEmpty) return null;
    final target = savePath.toLowerCase().endsWith('.csv')
        ? savePath
        : '$savePath.csv';

    final file = File(target);
    await file.parent.create(recursive: true);
    await file.writeAsString(toCsv(rows), encoding: utf8, flush: true);
    return target;
  }
}
