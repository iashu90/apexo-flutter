import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

// ─────────────────────────────────────────────────────────────────────────────
//  Data carrier for isolate (must be serializable)
// ─────────────────────────────────────────────────────────────────────────────

class _PdfBuildParams {
  final String title;
  final List<List<String>> rows; // first row = headers

  const _PdfBuildParams({required this.title, required this.rows});
}

// ─────────────────────────────────────────────────────────────────────────────
//  Top-level builder (runs in isolate via compute)
// ─────────────────────────────────────────────────────────────────────────────

Future<Uint8List> _buildPdfInIsolate(_PdfBuildParams params) async {
  final doc = pw.Document();
  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      build: (context) => [
        pw.Text(
          params.title,
          style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 8),
        pw.TableHelper.fromTextArray(
          cellAlignment: pw.Alignment.centerLeft,
          headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
          headers: params.rows.first,
          data: params.rows.skip(1).toList(growable: false),
          cellStyle: const pw.TextStyle(fontSize: 9),
        ),
      ],
    ),
  );
  return doc.save();
}

// ─────────────────────────────────────────────────────────────────────────────
//  Public API
// ─────────────────────────────────────────────────────────────────────────────

/// Builds a simple table PDF in a background isolate and returns the raw bytes.
/// [rows] must include a header row as the first element.
Future<Uint8List> generateTablePdf({
  required String title,
  required List<List<String>> rows,
}) {
  return compute(_buildPdfInIsolate, _PdfBuildParams(title: title, rows: rows));
}
