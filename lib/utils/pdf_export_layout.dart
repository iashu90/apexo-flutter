import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

pw.Widget exportPdfHeader(
  pw.Context context, {
  required String title,
  String? subtitle,
}) {
  final safeSubtitle = (subtitle ?? '').trim();
  return pw.Container(
    margin: const pw.EdgeInsets.only(bottom: 12),
    padding: const pw.EdgeInsets.only(bottom: 10),
    decoration: const pw.BoxDecoration(
      border: pw.Border(
        bottom: pw.BorderSide(color: PdfColors.blueGrey300, width: 0.8),
      ),
    ),
    child: pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Expanded(
          child: pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Container(
                width: 30,
                height: 30,
                alignment: pw.Alignment.center,
                decoration: pw.BoxDecoration(
                  color: PdfColor.fromInt(0xFFEAF2FF),
                  borderRadius: pw.BorderRadius.circular(6),
                  border: pw.Border.all(color: PdfColor.fromInt(0xFFD0E0F7)),
                ),
                child: pw.Text(
                  'DN',
                  style: pw.TextStyle(
                    fontSize: 11,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColor.fromInt(0xFF1D4D8A),
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
                        color: PdfColor.fromInt(0xFF1F4C86),
                      ),
                    ),
                    pw.SizedBox(height: 2),
                    pw.Text(
                      '15, Kamaraj St, Senthamarai Nagar, Muthialpet, Puducherry - 605003',
                      style: const pw.TextStyle(
                        fontSize: 8,
                        color: PdfColors.blueGrey700,
                      ),
                    ),
                    pw.Text(
                      'drnowfardental.in  |  +91 89035 61075',
                      style: const pw.TextStyle(
                        fontSize: 8,
                        color: PdfColors.blueGrey700,
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
                color: PdfColors.blueGrey700,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            if (safeSubtitle.isNotEmpty)
              pw.Text(
                safeSubtitle,
                style: const pw.TextStyle(
                  fontSize: 8,
                  color: PdfColors.blueGrey500,
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
    decoration: pw.BoxDecoration(
      border: pw.Border.all(color: PdfColors.grey300),
      borderRadius: pw.BorderRadius.circular(8),
      color: PdfColor.fromInt(0xFFF8FAFD),
    ),
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
                color: PdfColor.fromInt(0xFF1F4C86),
                fontSize: 12,
              ),
            ),
            pw.Container(
              padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: pw.BoxDecoration(
                color: PdfColor.fromInt(0xFFEAF0FA),
                borderRadius: pw.BorderRadius.circular(10),
              ),
              child: pw.Text(
                'Patient ID: $patientId',
                style: const pw.TextStyle(
                  fontSize: 8,
                  color: PdfColors.blueGrey700,
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
            color: PdfColor.fromInt(0xFF2A405F),
            fontWeight: pw.FontWeight.bold,
          ),
        ),
        pw.SizedBox(height: 2),
        pw.Text('Phone: $phone',
            style: const pw.TextStyle(
              fontSize: 9,
              color: PdfColors.blueGrey700,
            )),
        pw.Text('Doctor: $doctor',
            style: const pw.TextStyle(
              fontSize: 9,
              color: PdfColors.blueGrey700,
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
    padding: const pw.EdgeInsets.only(top: 8),
    decoration: const pw.BoxDecoration(
      border: pw.Border(
        top: pw.BorderSide(color: PdfColors.blueGrey300, width: 0.8),
      ),
    ),
    child: pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      crossAxisAlignment: pw.CrossAxisAlignment.end,
      children: [
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              'Generated on ${DateTime.now().toIso8601String().substring(0, 10)}',
              style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
            ),
            pw.Text(
              'Page $page / $total',
              style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
            ),
          ],
        ),
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.end,
          children: [
            pw.Container(
              width: 130,
              decoration: const pw.BoxDecoration(
                border: pw.Border(
                  bottom: pw.BorderSide(color: PdfColors.blueGrey300, width: 0.8),
                ),
              ),
            ),
            pw.SizedBox(height: 2),
            pw.Text(
              'Clinic Signature',
              style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
            ),
          ],
        ),
      ],
    ),
  );
}
