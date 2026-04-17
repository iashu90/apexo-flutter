import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:apexo/utils/pdf_export_layout.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  Data carrier for isolate (must be serializable)
// ─────────────────────────────────────────────────────────────────────────────

class _PdfBuildParams {
  final String title;
  final String? subtitle;
  final List<List<String>> rows; // first row = headers

  const _PdfBuildParams({
    required this.title,
    this.subtitle,
    required this.rows,
  });
}

// ─────────────────────────────────────────────────────────────────────────────
//  Top-level builder (runs in isolate via compute)
// ─────────────────────────────────────────────────────────────────────────────

Future<Uint8List> _buildPdfInIsolate(_PdfBuildParams params) async {
  final doc = pw.Document();
  final hasRows = params.rows.length > 1;
  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      header: (context) => exportPdfHeader(
        context,
        title: params.title,
        subtitle: params.subtitle,
      ),
      footer: exportPdfFooter,
      build: (context) => [
        pw.SizedBox(height: 2),
        if (hasRows)
          pw.TableHelper.fromTextArray(
            cellAlignment: pw.Alignment.centerLeft,
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            headers: params.rows.first,
            data: params.rows.skip(1).toList(growable: false),
            cellStyle: const pw.TextStyle(fontSize: 9),
          )
        else
          pw.Text('No data', style: const pw.TextStyle(fontSize: 10)),
      ],
    ),
  );
  return doc.save();
}

// ─────────────────────────────────────────────────────────────────────────────
//  Public API
// ─────────────────────────────────────────────────────────────────────────────

class PdfExportUtility {
  static Future<Uint8List> generatePdfBytes({
    required String title,
    dynamic data,
    String? subtitle,
  }) {
    final rows = _normalizeToRows(data);
    return compute(
      _buildPdfInIsolate,
      _PdfBuildParams(title: title, subtitle: subtitle, rows: rows),
    );
  }

  static Future<String?> savePdf({
    required String title,
    dynamic data,
    String fileName = 'export.pdf',
    String? subtitle,
  }) async {
    final bytes = await generatePdfBytes(
      title: title,
      data: data,
      subtitle: subtitle,
    );

    if (kIsWeb) {
      throw UnsupportedError('Saving PDF file is not supported on web.');
    }

    final savePath = await FilePicker.platform.saveFile(
      dialogTitle: 'Save PDF',
      fileName: fileName.toLowerCase().endsWith('.pdf')
          ? fileName
          : '$fileName.pdf',
      type: FileType.custom,
      allowedExtensions: const ['pdf'],
    );

    if (savePath == null || savePath.trim().isEmpty) return null;
    final target =
        savePath.toLowerCase().endsWith('.pdf') ? savePath : '$savePath.pdf';
    final file = File(target);
    await file.create(recursive: true);
    await file.writeAsBytes(bytes, flush: true);
    return target;
  }

  static List<List<String>> _normalizeToRows(dynamic data) {
    if (data == null) {
      return const [
        ['Value'],
        [''],
      ];
    }

    if (data is List<List<String>> && data.isNotEmpty) {
      return data;
    }

    if (data is String || data is num || data is bool || data is DateTime) {
      return [
        const ['Value'],
        [data.toString()],
      ];
    }

    if (data is Map) {
      final rows = <List<String>>[
        const ['Key', 'Value'],
      ];
      for (final entry in data.entries) {
        rows.add([
          entry.key.toString(),
          _stringifyValue(entry.value),
        ]);
      }
      return rows;
    }

    if (data is Iterable) {
      final items = data.toList(growable: false);
      if (items.isEmpty) {
        return const [
          ['Value'],
        ];
      }

      if (items.every((item) => item is Map)) {
        final keys = <String>[];
        final keySet = <String>{};
        for (final item in items.cast<Map>()) {
          for (final key in item.keys) {
            final keyStr = key.toString();
            if (keySet.add(keyStr)) keys.add(keyStr);
          }
        }
        final rows = <List<String>>[keys];
        for (final item in items.cast<Map>()) {
          rows.add(
            keys.map((key) => _stringifyValue(item[key])).toList(growable: false),
          );
        }
        return rows;
      }

      if (items.every((item) => item is Iterable && item is! String)) {
        var maxCols = 0;
        for (final item in items.cast<Iterable>()) {
          maxCols = maxCols < item.length ? item.length : maxCols;
        }
        final headers = List<String>.generate(
          maxCols,
          (index) => 'Column ${index + 1}',
          growable: false,
        );
        final rows = <List<String>>[headers];
        for (final item in items.cast<Iterable>()) {
          final vals = item.map(_stringifyValue).toList(growable: true);
          while (vals.length < maxCols) {
            vals.add('');
          }
          rows.add(vals);
        }
        return rows;
      }

      return [
        const ['Value'],
        ...items.map((item) => [_stringifyValue(item)]),
      ];
    }

    return [
      const ['Value'],
      [_stringifyValue(data)],
    ];
  }

  static String _stringifyValue(dynamic value) {
    if (value == null) return '';
    if (value is String || value is num || value is bool) {
      return value.toString();
    }
    if (value is DateTime) return value.toIso8601String();
    try {
      return jsonEncode(value);
    } catch (_) {
      return value.toString();
    }
  }
}

/// Backward-compatible helper for table-only generation.
Future<Uint8List> generateTablePdf({
  required String title,
  required List<List<String>> rows,
}) {
  return PdfExportUtility.generatePdfBytes(title: title, data: rows);
}
