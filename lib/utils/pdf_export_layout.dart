import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

pw.Widget exportPdfHeader(
  pw.Context context, {
  required String title,
  String? subtitle,
}) {
  return pw.Container(
    margin: const pw.EdgeInsets.only(bottom: 10),
    padding: const pw.EdgeInsets.only(bottom: 8),
    decoration: const pw.BoxDecoration(
      border: pw.Border(
        bottom: pw.BorderSide(color: PdfColors.blueGrey200, width: 0.6),
      ),
    ),
    child: pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              'Apexo',
              style: pw.TextStyle(
                fontSize: 12,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.blue900,
              ),
            ),
            pw.Text(
              title,
              style: const pw.TextStyle(
                fontSize: 9,
                color: PdfColors.blueGrey700,
              ),
            ),
            if ((subtitle ?? '').trim().isNotEmpty)
              pw.Text(
                subtitle!.trim(),
                style: const pw.TextStyle(
                  fontSize: 8,
                  color: PdfColors.blueGrey500,
                ),
              ),
          ],
        ),
        pw.Text(
          'Export',
          style: const pw.TextStyle(
            fontSize: 10,
            color: PdfColors.blueGrey400,
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
    margin: const pw.EdgeInsets.only(top: 10),
    padding: const pw.EdgeInsets.only(top: 6),
    decoration: const pw.BoxDecoration(
      border: pw.Border(
        top: pw.BorderSide(color: PdfColors.blueGrey200, width: 0.6),
      ),
    ),
    child: pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
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
  );
}
