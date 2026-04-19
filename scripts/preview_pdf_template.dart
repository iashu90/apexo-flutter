import 'dart:io';
import 'dart:typed_data';

import 'package:apexo/utils/pdf_export_layout.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

Future<Uint8List?> _loadLogoBytes() async {
  const paths = [
    'assets/images/drnowdentallogo.png',
    'assets/drnowdentallogo.png',
    'assets/images/logo.png',
  ];
  for (final path in paths) {
    final file = File(path);
    if (await file.exists()) {
      return file.readAsBytes();
    }
  }
  return null;
}

pw.Widget _summaryLine(String label, String value, {bool bold = false}) {
  return pw.Padding(
    padding: const pw.EdgeInsets.symmetric(vertical: 1),
    child: pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(
          label,
          style: pw.TextStyle(
            fontSize: 9,
            color: pdfSecondaryTextColor,
            fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
          ),
        ),
        pw.Text(
          value,
          style: pw.TextStyle(
            fontSize: bold ? 12 : 10,
            color: pdfGreenColor,
            fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
          ),
        ),
      ],
    ),
  );
}

Future<void> main(List<String> args) async {
  final logoBytes = await _loadLogoBytes();
  final now = DateTime.now();
  final invoiceId = 'VC-${now.millisecondsSinceEpoch % 10000}';

  final doc = pw.Document();
  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(24),
      header: (context) => exportPdfHeader(
        context,
        title: 'Patient ID: DP-046',
        subtitle: 'Invoice ID: $invoiceId',
        logoBytes: logoBytes,
      ),
      footer: exportPdfFooter,
      build: (context) => [
        pw.Container(
          width: double.infinity,
          padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          decoration: exportPdfCardDecoration(color: pdfCardGrey),
          child: pw.Text(
            'INVOICE / PAYMENT RECEIPT',
            style: pw.TextStyle(
              fontSize: 17,
              fontWeight: pw.FontWeight.bold,
              color: pdfAccentColor,
            ),
          ),
        ),
        pw.SizedBox(height: 8),
        exportPdfBillToSection(
          patientName: 'Sagayamary',
          patientId: 'DP-046',
          phone: '9788000000',
          doctor: 'Dr Nowfar',
        ),
        pw.SizedBox(height: 8),
        pw.TableHelper.fromTextArray(
          headerDecoration: exportPdfTableHeaderDecoration,
          headerStyle: exportPdfTableHeaderTextStyle,
          cellStyle: exportPdfTableCellTextStyle,
          cellAlignment: pw.Alignment.centerLeft,
          headers: const ['Details', 'Description', 'Cost', 'Amount'],
          data: [
            ['02 Apr 2026', 'Root Canal + Crown', 'Rs 1500', 'Rs 1000'],
            ['09 Dec 2026', 'Ceramic Crown', 'Rs 250', 'Rs 250'],
          ],
        ),
        pw.SizedBox(height: 8),
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Expanded(
              child: pw.Container(
                padding: const pw.EdgeInsets.all(10),
                decoration: exportPdfCardDecoration(color: pdfCardGrey),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'Payment Summary',
                      style: pw.TextStyle(
                        color: pdfAccentColor,
                        fontSize: 14,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.SizedBox(height: 6),
                    pw.Text('Amount Paid',
                        style:
                            pw.TextStyle(fontSize: 10, color: pdfSecondaryTextColor)),
                    pw.Text('Rs 2250',
                        style: pw.TextStyle(
                            fontSize: 14,
                            fontWeight: pw.FontWeight.bold,
                            color: pdfPrimaryTextColor)),
                    pw.SizedBox(height: 4),
                    pw.Text('Outstanding',
                        style:
                            pw.TextStyle(fontSize: 10, color: pdfSecondaryTextColor)),
                    pw.Text('Rs 0',
                        style: pw.TextStyle(
                            fontSize: 12, color: pdfPrimaryTextColor)),
                    pw.SizedBox(height: 6),
                    pw.Row(children: [
                      pw.Text('Payment Status  ',
                          style: pw.TextStyle(
                              fontSize: 10, color: pdfSecondaryTextColor)),
                      pw.Container(
                        padding: const pw.EdgeInsets.symmetric(
                            horizontal: 10, vertical: 3),
                        decoration: pw.BoxDecoration(
                          color: pdfGreenColor,
                          borderRadius: pw.BorderRadius.circular(4),
                        ),
                        child: pw.Text(
                          'PAID',
                          style: pw.TextStyle(
                            fontSize: 9,
                            color: PdfColors.white,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                      ),
                    ]),
                  ],
                ),
              ),
            ),
            pw.SizedBox(width: 10),
            pw.Expanded(
              child: pw.Container(
                padding: const pw.EdgeInsets.all(10),
                decoration: exportPdfCardDecoration(color: pdfCardGrey),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text('Total Cost',
                            style: pw.TextStyle(
                                fontSize: 10, color: pdfSecondaryTextColor)),
                        pw.Container(
                          padding: const pw.EdgeInsets.symmetric(
                              horizontal: 10, vertical: 3),
                          decoration: pw.BoxDecoration(
                            color: pdfGreenColor,
                            borderRadius: pw.BorderRadius.circular(4),
                          ),
                          child: pw.Text(
                            'Rs 2500',
                            style: pw.TextStyle(
                              fontSize: 11,
                              color: PdfColors.white,
                              fontWeight: pw.FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    pw.SizedBox(height: 6),
                    _summaryLine('Specimen', 'Rs 2250'),
                    _summaryLine('Paid', 'Rs 2250'),
                    pw.Divider(color: pdfMutedGrey, thickness: 0.5),
                    _summaryLine('TOTAL', 'Rs 2250', bold: true),
                  ],
                ),
              ),
            ),
          ],
        ),
        pw.SizedBox(height: 8),
        pw.Text(
          'Payment History',
          style: pw.TextStyle(
            fontWeight: pw.FontWeight.bold,
            color: pdfPrimaryTextColor,
          ),
        ),
        pw.SizedBox(height: 6),
        pw.TableHelper.fromTextArray(
          headerDecoration: exportPdfTableHeaderDecoration,
          headerStyle: exportPdfTableHeaderTextStyle,
          cellStyle: exportPdfTableCellTextStyle,
          headers: const ['Date', 'Reference', 'Mode', 'Amount'],
          data: const [
            ['02 Apr 2026', 'TX100622', 'UPI', 'Rs 1000'],
            ['09 Dec 2026', 'TX112310', 'Cash', 'Rs 1250'],
          ],
        ),
        pw.SizedBox(height: 10),
        pw.Container(
          width: double.infinity,
          padding: const pw.EdgeInsets.all(10),
          decoration: exportPdfCardDecoration(color: pdfCardGrey),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text('Notes:',
                  style: pw.TextStyle(
                    fontSize: 11,
                    fontWeight: pw.FontWeight.bold,
                    color: pdfPrimaryTextColor,
                  )),
              pw.SizedBox(height: 4),
              pw.Bullet(
                text: 'One year warranty: 5 years.',
                style: pw.TextStyle(fontSize: 9, color: pdfSecondaryTextColor),
              ),
              pw.Bullet(
                text: 'Recall after 6 months.',
                style: pw.TextStyle(fontSize: 9, color: pdfSecondaryTextColor),
              ),
            ],
          ),
        ),
      ],
    ),
  );

  final outputPath = args.isNotEmpty
      ? args.first
      : 'build/pdf_preview/receipt_template_preview.pdf';
  final outputFile = File(outputPath);
  await outputFile.parent.create(recursive: true);
  await outputFile.writeAsBytes(await doc.save());

  stdout.writeln('PDF preview generated: ${outputFile.path}');
}
