import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

// PDF theme palette (single place for future color changes)
final PdfColor pdfAccentColor = PdfColor.fromInt(0xFF1F4C86);
final PdfColor pdfPrimaryTextColor = PdfColor.fromInt(0xFF2A405F);
final PdfColor pdfSecondaryTextColor = PdfColor.fromInt(0xFF5E6B7A);
final PdfColor pdfPageGrey = PdfColor.fromInt(0xFFF3F4F6);
final PdfColor pdfCardGrey = PdfColor.fromInt(0xFFF7F8FA);
final PdfColor pdfMutedGrey = PdfColor.fromInt(0xFFE8EBEF);
final PdfColor pdfGreenColor = PdfColor.fromInt(0xFF2B8B4A);

pw.BoxDecoration exportPdfCardDecoration({
  PdfColor? color,
  double radius = 8,
}) {
  return pw.BoxDecoration(
    color: color ?? pdfCardGrey,
    borderRadius: pw.BorderRadius.circular(radius),
  );
}

const pw.BoxDecoration exportPdfTableHeaderDecoration =
    pw.BoxDecoration(color: PdfColor.fromInt(0xFFEFF2F6));

final pw.TextStyle exportPdfTableHeaderTextStyle = pw.TextStyle(
  fontSize: 9,
  color: const PdfColor.fromInt(0xFF4C5B6B),
  fontWeight: pw.FontWeight.bold,
);

const pw.TextStyle exportPdfTableCellTextStyle = pw.TextStyle(
  fontSize: 9,
  color: PdfColor.fromInt(0xFF4C5B6B),
);

pw.Widget exportPdfHeader(
  pw.Context context, {
  required String title,
  String? subtitle,
  Uint8List? logoBytes,
}) {
  final safeSubtitle = (subtitle ?? '').trim();
  return pw.Container(
    margin: const pw.EdgeInsets.only(bottom: 12),
    padding: const pw.EdgeInsets.fromLTRB(10, 9, 10, 10),
    decoration: exportPdfCardDecoration(color: pdfCardGrey, radius: 10),
    child: pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Expanded(
          child: pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              if (logoBytes != null)
                pw.ClipRRect(
                  horizontalRadius: 6,
                  verticalRadius: 6,
                  child: pw.Image(
                    pw.MemoryImage(logoBytes),
                    width: 32,
                    height: 32,
                    fit: pw.BoxFit.cover,
                  ),
                )
              else
                pw.Container(
                  width: 32,
                  height: 32,
                  alignment: pw.Alignment.center,
                  decoration: pw.BoxDecoration(
                    color: pdfMutedGrey,
                    borderRadius: pw.BorderRadius.circular(6),
                  ),
                  child: pw.Text(
                    'DN',
                    style: pw.TextStyle(
                      fontSize: 11,
                      fontWeight: pw.FontWeight.bold,
                      color: pdfAccentColor,
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
                      style: pw.TextStyle(
                        fontSize: 13,
                        fontWeight: pw.FontWeight.bold,
                        color: pdfAccentColor,
                      ),
                    ),
                    pw.SizedBox(height: 2),
                    pw.Text(
                      '15, Kamaraj St, Senthamarai Nagar, Muthialpet, Puducherry - 605003',
                      style: pw.TextStyle(
                        fontSize: 8,
                        color: pdfSecondaryTextColor,
                      ),
                    ),
                    pw.Text(
                      'drnowfardental.in  |  +91 89035 61075',
                      style: pw.TextStyle(
                        fontSize: 8,
                        color: pdfSecondaryTextColor,
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
              style: pw.TextStyle(
                fontSize: 9,
                color: pdfSecondaryTextColor,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            if (safeSubtitle.isNotEmpty)
              pw.Text(
                safeSubtitle,
                style: pw.TextStyle(
                  fontSize: 8,
                  color: pdfSecondaryTextColor,
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
    padding: const pw.EdgeInsets.all(12),
    decoration: exportPdfCardDecoration(color: pdfCardGrey),
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              'Bill To:',
              style: pw.TextStyle(
                fontWeight: pw.FontWeight.bold,
                color: pdfAccentColor,
                fontSize: 12,
              ),
            ),
            pw.Container(
              padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: pw.BoxDecoration(
                color: pdfMutedGrey,
                borderRadius: pw.BorderRadius.circular(10),
              ),
              child: pw.Text(
                'Patient ID: $patientId',
                style: pw.TextStyle(
                  fontSize: 8,
                  color: pdfSecondaryTextColor,
                ),
              ),
            ),
          ],
        ),
        pw.SizedBox(height: 6),
        pw.Text(
          patientName,
          style: pw.TextStyle(
            fontSize: 11,
            color: pdfPrimaryTextColor,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
        pw.SizedBox(height: 2),
        pw.Text('Phone: $phone',
            style: pw.TextStyle(
              fontSize: 9,
              color: pdfSecondaryTextColor,
            )),
        pw.Text('Doctor: $doctor',
            style: pw.TextStyle(
              fontSize: 9,
              color: pdfSecondaryTextColor,
            )),
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
    decoration: exportPdfCardDecoration(color: pdfCardGrey, radius: 10),
    child: pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      crossAxisAlignment: pw.CrossAxisAlignment.end,
      children: [
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              'Generated on ${DateTime.now().toIso8601String().substring(0, 10)}',
              style: pw.TextStyle(fontSize: 8, color: pdfSecondaryTextColor),
            ),
            pw.Text(
              'Page $page / $total',
              style: pw.TextStyle(fontSize: 8, color: pdfSecondaryTextColor),
            ),
          ],
        ),
        pw.Column(
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
      ],
    ),
  );
}
