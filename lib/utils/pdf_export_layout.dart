import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

// PDF theme palette (single place for future color changes)
final PdfColor pdfAccentColor = PdfColor.fromInt(0xFF3069BD);
final PdfColor pdfPrimaryTextColor = PdfColor.fromInt(0xFF2A405F);
final PdfColor pdfSecondaryTextColor = PdfColor.fromInt(0xFF5E6B7A);
final PdfColor pdfPageGrey = PdfColor.fromInt(0xFFF3F4F6);
final PdfColor pdfCardGrey = PdfColor.fromInt(0xFFFEFEFE);
final PdfColor pdfMutedGrey = PdfColor.fromInt(0xFFE8EBEF);
final PdfColor pdfGreenColor = PdfColor.fromInt(0xFF2B8B4A);
final PdfColor pdfDangerColor = PdfColor.fromInt(0xFFD4483B);
final PdfColor pdfTableHeaderBgColor = PdfColor.fromInt(0xFFECEFF2);
final PdfColor pdfTableBorderColor = PdfColor.fromInt(0xFFF0F1F1);
final PdfColor pdfTableHeaderTextColor = PdfColor.fromInt(0xFF4C5B6B);
final PdfColor pdfTableCellTextColor = PdfColor.fromInt(0xFF455A64);
final PdfColor pdfWhiteColor = PdfColors.white;
final PdfColor pdfBlackColor = PdfColors.black;

const List<String> _pdfLogoPaths = [
  'assets/app_icon.png',
  'assets/drnowdentallogo.png',
  'assets/images/logo.png',
];

Uint8List? _exportPdfHeaderLogoBytes;
bool _exportPdfHeaderLogoLoadAttempted = false;
pw.Font? _pdfBaseFont;
pw.Font? _pdfBoldFont;
bool _exportPdfFontLoadAttempted = false;

Future<void> ensureExportPdfHeaderLogoLoaded() async {
  if (_exportPdfHeaderLogoBytes != null || _exportPdfHeaderLogoLoadAttempted) {
    return;
  }

  _exportPdfHeaderLogoLoadAttempted = true;
  for (final assetPath in _pdfLogoPaths) {
    try {
      final byteData = await rootBundle.load(assetPath);
      _exportPdfHeaderLogoBytes = byteData.buffer.asUint8List();
      return;
    } catch (_) {
      // Try next fallback asset.
    }
  }
}

Future<void> ensureExportPdfFontsLoaded() async {
  if (_exportPdfFontLoadAttempted) return;
  _exportPdfFontLoadAttempted = true;

  try {
    final regular = await rootBundle.load('assets/fonts/readex.ttf');
    _pdfBaseFont = pw.Font.ttf(regular);
  } catch (_) {
    // Keep default PDF font when Readex is unavailable.
  }

  try {
    final bold = await rootBundle.load('assets/fonts/readex-bold.ttf');
    _pdfBoldFont = pw.Font.ttf(bold);
  } catch (_) {
    // Keep default PDF bold font when Readex Bold is unavailable.
  }

}

Future<void> ensureExportPdfAssetsLoaded() async {
  await ensureExportPdfHeaderLogoLoaded();
  await ensureExportPdfFontsLoaded();
}

pw.TextStyle _withPdfFont(
  pw.TextStyle style, {
  bool bold = false,
}) {
  return style.copyWith(
    font: bold ? (_pdfBoldFont ?? _pdfBaseFont) : _pdfBaseFont,
  );
}

final PdfColor pdfBackgroundColor = PdfColor.fromInt(0xFFF5F7F9);
const pw.EdgeInsets exportPdfContentMargin =
    pw.EdgeInsets.symmetric(horizontal: 24);

List<pw.Widget> exportPdfBodyWithMargins(
  List<pw.Widget> children, {
  pw.EdgeInsetsGeometry margin = exportPdfContentMargin,
}) {
  return children
      .map(
        (child) => pw.Padding(
          padding: margin,
          child: child,
        ),
      )
      .toList(growable: false);
}

pw.PageTheme exportPdfPageTheme({
  PdfPageFormat pageFormat = PdfPageFormat.a4,
  pw.EdgeInsetsGeometry margin = const pw.EdgeInsets.all(0),
}) {
  return pw.PageTheme(
    pageFormat: pageFormat,
    margin: margin,
    buildBackground: (context) => pw.FullPage(
      ignoreMargins: true,
      child: pw.Container(color: pdfBackgroundColor),
    ),
  );
}

pw.BoxDecoration exportPdfCardDecoration({
  PdfColor? color,
  double radius = 0,
}) {
  return pw.BoxDecoration(
    color: color ?? pdfCardGrey,
    borderRadius: pw.BorderRadius.circular(radius),
  );
}

final pw.BoxDecoration exportPdfTableHeaderDecoration = pw.BoxDecoration(
  color: pdfTableHeaderBgColor,
  border: pw.Border(
    bottom: pw.BorderSide(
      color: pdfTableBorderColor,
      width: 0.5,
    ),
  ),
);

pw.TableBorder exportPdfTableBorder({double width = 0.5}) {
  return pw.TableBorder.all(color: pdfTableBorderColor, width: width);
}

final pw.BoxDecoration exportPdfTableRowDecoration = pw.BoxDecoration(
  color: pdfCardGrey,
);

final pw.EdgeInsetsGeometry headerPadding =
    const pw.EdgeInsets.symmetric(vertical: 18);
final pw.EdgeInsetsGeometry cellPadding =
    const pw.EdgeInsets.symmetric(vertical: 10);

final pw.TextStyle exportPdfTableHeaderTextStyle = pw.TextStyle(
  fontSize: 11,
  lineSpacing: 2,
  color: pdfTableHeaderTextColor,
  fontWeight: pw.FontWeight.bold,
);

final pw.TextStyle exportPdfTableCellTextStyle = pw.TextStyle(
  fontSize: 12,
  color: pdfTableCellTextColor,
);

pw.Widget exportPdfHeader(
  pw.Context context, {
  required String title,
  String? subtitle,
}) {
  final safeSubtitle = (subtitle ?? '').trim();
  return pw.Container(
    color: pdfCardGrey,
    padding: const pw.EdgeInsets.all(8),
    margin: const pw.EdgeInsets.only(bottom: 12),
    child: pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Expanded(
          child: pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              if (_exportPdfHeaderLogoBytes != null)
                pw.ClipRRect(
                  horizontalRadius: 6,
                  verticalRadius: 6,
                  child: pw.Image(
                    pw.MemoryImage(_exportPdfHeaderLogoBytes!),
                    width: 40,
                    height: 40,
                    fit: pw.BoxFit.cover,
                  ),
                )
              else
                pw.Container(
                  width: 40,
                  height: 40,
                  alignment: pw.Alignment.center,
                  decoration: pw.BoxDecoration(
                    color: pdfMutedGrey,
                    borderRadius: pw.BorderRadius.circular(6),
                  ),
                  child: pw.Text(
                    'DN',
                    style: _withPdfFont(
                      pw.TextStyle(
                        fontSize: 11,
                        fontWeight: pw.FontWeight.bold,
                        color: pdfAccentColor,
                      ),
                      bold: true,
                    ),
                  ),
                ),
              pw.SizedBox(width: 8),
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'Dr Nowfar Dental Clinic',
                      style: _withPdfFont(
                        pw.TextStyle(
                          fontSize: 16,
                          fontWeight: pw.FontWeight.bold,
                          color: pdfAccentColor,
                        ),
                        bold: true,
                      ),
                    ),
                    pw.SizedBox(height: 2),
                    pw.Text(
                      '15, Kamaraj St, Senthamarai Nagar, Muthialpet, Puducherry - 605003',
                      style: _withPdfFont(
                        pw.TextStyle(
                          fontSize: 8,
                          color: pdfSecondaryTextColor,
                        ),
                      ),
                    ),
                    pw.Text(
                      'drnowfardental.in  |  +91 89035 61075',
                      style: _withPdfFont(
                        pw.TextStyle(
                          fontSize: 8,
                          color: pdfSecondaryTextColor,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        pw.SizedBox(width: 12),
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.end,
          children: [
            pw.Text(
              title,
              style: _withPdfFont(
                pw.TextStyle(
                  fontSize: 9,
                  color: pdfSecondaryTextColor,
                  fontWeight: pw.FontWeight.bold,
                ),
                bold: true,
              ),
            ),
            if (safeSubtitle.isNotEmpty)
              pw.Text(
                safeSubtitle,
                style: _withPdfFont(
                  pw.TextStyle(
                    fontSize: 8,
                    color: pdfSecondaryTextColor,
                  ),
                ),
              ),
          ],
        ),
      ],
    ),
  );
}

pw.Widget exportPdfBillToSection({
  required String patientName,
  required String patientId,
  required String phone,
  required String doctor,
}) {
  return pw.Container(
    width: double.infinity,
    padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 12),
    decoration: exportPdfCardDecoration(color: pdfCardGrey),
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              'Bill To:',
              style: _withPdfFont(
                pw.TextStyle(
                  fontWeight: pw.FontWeight.bold,
                  color: pdfBlackColor,
                  fontSize: 14,
                ),
                bold: true,
              ),
            ),
            pw.Container(
              padding:
                  const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: pw.BoxDecoration(
                color: pdfMutedGrey,
                borderRadius: pw.BorderRadius.circular(10),
              ),
              child: pw.Text(
                'Patient ID: $patientId',
                style: _withPdfFont(
                  pw.TextStyle(
                    fontSize: 8,
                    color: pdfSecondaryTextColor,
                  ),
                ),
              ),
            ),
          ],
        ),
        pw.SizedBox(height: 6),
        pw.Text(
          patientName,
          style: _withPdfFont(
            pw.TextStyle(
              fontSize: 12,
              color: pdfSecondaryTextColor,
              fontWeight: pw.FontWeight.bold,
            ),
            bold: true,
          ),
        ),
        pw.SizedBox(height: 2),
        pw.Text(
          phone,
          style: _withPdfFont(
            pw.TextStyle(
              fontSize: 9,
              color: pdfSecondaryTextColor,
            ),
          ),
        ),
      ],
    ),
  );
}

pw.Widget exportPdfFooter(pw.Context context) {
  final page = context.pageNumber;
  final total = context.pagesCount;
  return pw.Container(
    margin: const pw.EdgeInsets.only(top: 12),
    padding: const pw.EdgeInsets.fromLTRB(10, 8, 10, 8),
    child: pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      crossAxisAlignment: pw.CrossAxisAlignment.end,
      children: [
        pw.Expanded(
          child: pw.Text(
            'Generated on ${DateTime.now().toIso8601String().substring(0, 10)}',
            style: pw.TextStyle(fontSize: 8, color: pdfSecondaryTextColor),
          ),
        ),
        pw.Text(
          'Page $page / $total',
          style: pw.TextStyle(fontSize: 8, color: pdfSecondaryTextColor),
        ),
      ],
    ),
  );
}

pw.Widget exportPdfDoctorSignatureSection() {
  return pw.Align(
    alignment: pw.Alignment.centerRight,
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.end,
      children: [
        pw.Text(
          'Dr Nowfar Dental Clinic',
          style: pw.TextStyle(
            fontSize: 8,
            color: pdfSecondaryTextColor,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
        pw.SizedBox(height: 2),
        pw.Container(
          width: 130,
          decoration: pw.BoxDecoration(
            border: pw.Border(
              bottom: pw.BorderSide(color: pdfSecondaryTextColor, width: 0.6),
            ),
          ),
        ),
      ],
    ),
  );
}
