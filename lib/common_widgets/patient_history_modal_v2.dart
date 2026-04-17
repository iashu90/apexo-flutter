import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:apexo/common_widgets/export_progress_dialog.dart';
import 'package:apexo/common_widgets/patient_report.dart';
import 'package:apexo/features/patients/patient_model.dart';
import 'package:apexo/utils/pdf_export_layout.dart';
import 'package:apexo/utils/share_actions.dart';
import 'package:file_picker/file_picker.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

Future<void> showPatientHistoryDialogV2({
  required BuildContext context,
  required Patient patient,
  required List<ReportDetailRow> rows,
}) {
  return showDialog<void>(
    context: context,
    builder: (_) => Align(
      alignment: Alignment.center,
      child: PatientHistoryDialogV2(patient: patient, rows: rows),
    ),
  );
}

class _LedgerRowData {
  final String id;
  final DateTime date;
  final String tooth;
  final String treatment;
  final String doctor;
  final double cost;
  final double paid;
  final String mode;
  final String notes;
  final String prescription;

  const _LedgerRowData({
    required this.id,
    required this.date,
    required this.tooth,
    required this.treatment,
    required this.doctor,
    required this.cost,
    required this.paid,
    required this.mode,
    required this.notes,
    required this.prescription,
  });

  double get balance => cost - paid;

  String get status {
    if (paid <= 0 && cost > 0) return 'Due';
    if (paid >= cost) return 'Paid';
    return 'Partial';
  }
}

class PatientHistoryDialogV2 extends StatefulWidget {
  final Patient patient;
  final List<ReportDetailRow> rows;

  const PatientHistoryDialogV2({
    super.key,
    required this.patient,
    required this.rows,
  });

  @override
  State<PatientHistoryDialogV2> createState() => _PatientHistoryDialogV2State();
}

class _PatientHistoryDialogV2State extends State<PatientHistoryDialogV2> {
  static const int _maxRowsPerPdfExport = 120;
  static const Duration _pdfBuildTimeout = Duration(seconds: 45);
  final TextEditingController _searchController = TextEditingController();
  int _exportLogSequence = 0;
  String _query = '';
  String _statusFilter = 'All';
  String _modeFilter = 'All';
  String _dateRange = 'All';
  String _doctorFilter = 'All Doctors';
  String? _expandedRowId;
  String _sortBy = 'date';
  bool _sortAscending = false;
  bool _isExportingCsv = false;
  bool _isExportingPdf = false;

  double _toAmount(String source) {
    return double.tryParse(source.replaceAll(RegExp(r'[^0-9.]'), '')) ?? 0;
  }

  String _normalizeMode(String raw) {
    final value = raw.trim().toLowerCase();
    if (value.isEmpty) return 'Cash';
    if (value.contains('cash')) return 'Cash';
    return 'UPI';
  }

  String _fileStem() {
    final safeName = (widget.patient.title.trim().isEmpty
            ? 'patient'
            : widget.patient.title.trim())
        .replaceAll(RegExp(r'[^a-zA-Z0-9]+'), '_');
    final age = widget.patient.age;
    final date = DateFormat('dd_MMM-yyyy').format(DateTime.now()).toLowerCase();
    return '${safeName}_${age}_$date';
  }

  String _nextExportTag(String prefix) {
    _exportLogSequence += 1;
    return '$prefix-${DateTime.now().millisecondsSinceEpoch}-$_exportLogSequence';
  }

  void _logExport(String tag, String message, [Object? error, StackTrace? stackTrace]) {
    debugPrint('[Export][$tag] $message');
    if (error != null) {
      debugPrint('[Export][$tag] ERROR: $error');
    }
    if (stackTrace != null) {
      debugPrint('[Export][$tag] STACK: $stackTrace');
    }
  }

  void _showExportError(String title, String message) {
    if (!mounted) return;
    displayInfoBar(
      context,
      builder: (ctx, close) => InfoBar(
        title: Text(title),
        content: Text(message),
        severity: InfoBarSeverity.error,
        action: IconButton(
          icon: const Icon(FluentIcons.clear),
          onPressed: close,
        ),
      ),
    );
  }

  Iterable<List<int>> _chunkBytes(List<int> bytes, int chunkSize) sync* {
    for (var offset = 0; offset < bytes.length; offset += chunkSize) {
      final end = (offset + chunkSize < bytes.length)
          ? offset + chunkSize
          : bytes.length;
      yield bytes.sublist(offset, end);
    }
  }

  String _csvRow(_LedgerRowData row) {
    final values = [
      DateFormat('yyyy-MM-dd').format(row.date),
      row.tooth,
      row.treatment,
      row.doctor,
      row.cost.toStringAsFixed(0),
      row.paid.toStringAsFixed(0),
      row.balance.toStringAsFixed(0),
      row.status,
      row.mode,
    ];
    return values.map((v) => '"${v.replaceAll('"', '""')}"').join(',');
  }

  Future<void> _writeCsvWithRetry({
    required String target,
    required List<_LedgerRowData> rows,
    required ExportProgressController progress,
    required String logTag,
  }) async {
    final tempFile = File('$target.tmp');
    const maxAttempts = 3;

    for (var attempt = 1; attempt <= maxAttempts; attempt++) {
      IOSink? sink;
      try {
        _logExport(logTag, 'CSV write attempt $attempt started: $target');
        if (await tempFile.exists()) {
          await tempFile.delete();
        }

        sink = tempFile.openWrite();
        final encodedLines = <List<int>>[
          utf8.encode('Date,Tooth,Treatment,Doctor,Cost,Paid,Balance,Status,Mode\n'),
        ];

        for (var i = 0; i < rows.length; i++) {
          if (progress.isCancelled) {
            _logExport(logTag, 'CSV write cancelled at row $i');
            break;
          }
          encodedLines.add(utf8.encode('${_csvRow(rows[i])}\n'));
          progress.setProgress(0.1 + 0.65 * ((i + 1) / rows.length));
        }

        await sink.addStream(Stream<List<int>>.fromIterable(encodedLines));
        await sink.flush();
        await sink.close();
        sink = null;
        await tempFile.openRead().drain<void>();

        if (!progress.isCancelled) {
          final targetFile = File(target);
          if (await targetFile.exists()) {
            await targetFile.delete();
          }
          await tempFile.rename(target);
          _logExport(logTag, 'CSV write finished successfully: $target');
        }
        return;
      } catch (error, stackTrace) {
        _logExport(logTag, 'CSV write attempt $attempt failed', error, stackTrace);
        await sink?.close();
        if (attempt == maxAttempts) rethrow;
        await Future<void>.delayed(Duration(milliseconds: 200 * attempt));
      } finally {
        await sink?.close();
        if (await tempFile.exists() && progress.isCancelled) {
          await tempFile.delete();
        }
      }
    }
  }

  Future<void> _writePdfWithRetry({
    required String target,
    required List<int> bytes,
    required ExportProgressController progress,
    required String logTag,
  }) async {
    final tempFile = File('$target.tmp');
    const maxAttempts = 3;

    for (var attempt = 1; attempt <= maxAttempts; attempt++) {
      IOSink? sink;
      try {
        _logExport(logTag, 'PDF write attempt $attempt started: $target (${bytes.length} bytes)');
        if (await tempFile.exists()) {
          await tempFile.delete();
        }

        sink = tempFile.openWrite();
        final stream = Stream<List<int>>.fromIterable(_chunkBytes(bytes, 128 * 1024));
        await sink.addStream(stream);
        if (progress.isCancelled) {
          _logExport(logTag, 'PDF write cancelled before flush');
        }
        await sink.flush();
        await sink.close();
        sink = null;
        await tempFile.openRead().drain<void>();

        if (!progress.isCancelled) {
          final targetFile = File(target);
          if (await targetFile.exists()) {
            await targetFile.delete();
          }
          await tempFile.rename(target);
          _logExport(logTag, 'PDF write finished successfully: $target');
        }
        return;
      } catch (error, stackTrace) {
        _logExport(logTag, 'PDF write attempt $attempt failed', error, stackTrace);
        await sink?.close();
        if (attempt == maxAttempts) rethrow;
        await Future<void>.delayed(Duration(milliseconds: 200 * attempt));
      } finally {
        await sink?.close();
        if (await tempFile.exists() && progress.isCancelled) {
          await tempFile.delete();
        }
      }
    }
  }

  String _composeShareMessage([_LedgerRowData? row]) {
    final target = row ?? (_visibleRows.isEmpty ? null : _visibleRows.first);
    if (target == null) {
      return 'Patient ${widget.patient.title} invoice details are currently unavailable.';
    }
    final patientName = widget.patient.title.trim().isEmpty
      ? widget.patient.id
      : widget.patient.title;
    final date = DateFormat('dd MMM yyyy').format(target.date);

    return 
      'Hello $patientName,\n\n'
      'This is a message from Dr. Nowfar Dental Clinic. We are reaching out to provide a summary of your recent visit and confirm your next scheduled appointment.\n'
      'Treatment Summary\n\n'
      'Last Visit: $date ${DateFormat('hh:mm a').format(target.date)}\n'
      'Treatment: ${target.treatment}\n'
      'Notes/Follow-up: ${target.notes}\n\n'
      'Cost: Rs ${target.cost.toStringAsFixed(0)}\n'
        'Paid: Rs ${target.paid.toStringAsFixed(0)}\n'
        'Balance: Rs ${target.balance.toStringAsFixed(0)}\n\n'
      'Dr. Nowfar Dental Clinic\n'
      'Address: 15, Kamaraj St, Senthamarai Nagar, Muthialpet, Puducherry, 605003, India\n'
      'Phone: +91 89035 61075\n'
      'Website: drnowfardental.in\n'
      'Google Maps: https://maps.app.goo.gl/KJNqKbk3U9VujcCKA';
  }

  pw.Document _buildPdfDocument(List<_LedgerRowData> rows) {
    final totalCost = rows.fold<double>(0, (sum, r) => sum + r.cost);
    final totalPaid = rows.fold<double>(0, (sum, r) => sum + r.paid);
    final outstanding = (totalCost - totalPaid).clamp(0, double.infinity);
    final firstRow = rows.isEmpty ? null : rows.first;

    final doc = pw.Document();
    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(24),
        header: (context) => exportPdfHeader(
          context,
          title: 'Patient Invoice / Payment Receipt',
          subtitle: widget.patient.title.trim().isEmpty
              ? widget.patient.id
              : widget.patient.title,
        ),
        footer: exportPdfFooter,
        build: (context) => [
          pw.Text(
            'INVOICE / PAYMENT RECEIPT',
            style: pw.TextStyle(fontSize: 21, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900),
          ),
          pw.SizedBox(height: 12),
          pw.Container(
            width: double.infinity,
            padding: const pw.EdgeInsets.all(12),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.grey300),
              borderRadius: pw.BorderRadius.circular(8),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'Dr. Nowfar Dental Clinic',
                      style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text('Patient ID: ${widget.patient.id}'),
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text('Invoice ID: VC-${DateTime.now().millisecondsSinceEpoch % 10000}'),
                    pw.Text('Date: ${DateFormat('dd MMM yyyy').format(DateTime.now())}'),
                  ],
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 12),
          pw.Container(
            width: double.infinity,
            padding: const pw.EdgeInsets.all(12),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.grey300),
              borderRadius: pw.BorderRadius.circular(8),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('Bill To:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 6),
                pw.Text(widget.patient.title.trim().isEmpty ? 'Unnamed patient' : widget.patient.title),
                pw.Text('Phone: ${widget.patient.phone.trim().isEmpty ? '-' : widget.patient.phone}'),
                pw.Text('Doctor: Dr Nowfar'),
              ],
            ),
          ),
          pw.SizedBox(height: 12),
          pw.TableHelper.fromTextArray(
            headerDecoration: const pw.BoxDecoration(color: PdfColors.blueGrey50),
            headers: const [
              'Date',
              'Tooth',
              'Treatment',
              'Doctor',
              'Cost',
              'Paid',
              'Balance',
              'Status',
              'Mode',
            ],
            data: rows
                .map(
                  (r) => [
                    DateFormat('dd MMM yyyy').format(r.date),
                    r.tooth,
                    r.treatment,
                    r.doctor,
                    'Rs ${r.cost.toStringAsFixed(0)}',
                    'Rs ${r.paid.toStringAsFixed(0)}',
                    'Rs ${r.balance.toStringAsFixed(0)}',
                    r.status,
                    r.mode,
                  ],
                )
                .toList(growable: false),
          ),
          pw.SizedBox(height: 12),
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(
                child: pw.Container(
                  padding: const pw.EdgeInsets.all(10),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.green50,
                    borderRadius: pw.BorderRadius.circular(8),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('Payment Summary', style: pw.TextStyle(color: PdfColors.green800, fontWeight: pw.FontWeight.bold)),
                      pw.SizedBox(height: 6),
                      pw.Text('Amount Paid: Rs ${totalPaid.toStringAsFixed(0)}'),
                      pw.Text('Outstanding: Rs ${outstanding.toStringAsFixed(0)}'),
                      pw.Text('Payment Status: ${outstanding <= 0 ? 'PAID' : 'DUE'}'),
                    ],
                  ),
                ),
              ),
              pw.SizedBox(width: 10),
              pw.Expanded(
                child: pw.Container(
                  padding: const pw.EdgeInsets.all(10),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.grey100,
                    borderRadius: pw.BorderRadius.circular(8),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('Treatment Cost: Rs ${totalCost.toStringAsFixed(0)}'),
                      pw.Text('Paid: Rs ${totalPaid.toStringAsFixed(0)}'),
                      pw.Text('TOTAL: Rs ${totalCost.toStringAsFixed(0)}'),
                    ],
                  ),
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 12),
          pw.Text('Payment History', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 6),
          pw.TableHelper.fromTextArray(
            headerDecoration: const pw.BoxDecoration(color: PdfColors.blueGrey50),
            headers: const ['Date', 'For Service', 'Mode', 'Amount'],
            data: rows
                .map(
                  (r) => [
                    DateFormat('dd MMM yyyy').format(r.date),
                    r.treatment,
                    r.mode,
                    'Rs ${r.paid.toStringAsFixed(0)}',
                  ],
                )
                .toList(growable: false),
          ),
          pw.SizedBox(height: 12),
          pw.Text('Notes: ${firstRow == null ? '-' : firstRow.notes}'),
        ],
      ),
    );
    return doc;
  }

  List<_LedgerRowData> get _allRows {
    return widget.rows
        .asMap()
        .entries
        .map((entry) {
          final row = entry.value;
            final modeRaw = row.treatmentPaymentMode.trim().isEmpty
              ? (row.preceptionPaymentMode.trim().isEmpty
                  ? 'Cash'
                  : row.preceptionPaymentMode)
              : row.treatmentPaymentMode;
            final mode = _normalizeMode(modeRaw);
          return _LedgerRowData(
            id: '${row.date.millisecondsSinceEpoch}_${entry.key}',
            date: row.date,
            tooth: row.teeth.trim().isEmpty ? '-' : row.teeth,
            treatment: row.treatment.trim().isEmpty ? '-' : row.treatment,
            doctor: 'Dr Nowfar',
            cost: _toAmount(row.cost),
            paid: _toAmount(row.paid),
            mode: mode,
            notes: row.treatment.trim().isEmpty
                ? 'No additional doctor notes.'
                : 'Follow-up required based on treatment response.',
            prescription: row.prescription.trim().isEmpty
                ? 'No medicines listed.'
                : row.prescription,
          );
        })
        .toList(growable: false)
      ..sort((a, b) => b.date.compareTo(a.date));
  }

  List<_LedgerRowData> get _visibleRows {
    final now = DateTime.now();
    DateTime? startDate;
    if (_dateRange == '1 Month') {
      startDate = now.subtract(const Duration(days: 30));
    } else if (_dateRange == '3 Months') {
      startDate = now.subtract(const Duration(days: 90));
    } else if (_dateRange == '6 Months') {
      startDate = now.subtract(const Duration(days: 182));
    } else if (_dateRange == '1 Year') {
      startDate = now.subtract(const Duration(days: 365));
    }

    final filtered = _allRows.where((row) {
      if (startDate != null && row.date.isBefore(startDate)) return false;

      if (_statusFilter != 'All' && row.status != _statusFilter) {
        return false;
      }

      if (_modeFilter != 'All' && row.mode != _modeFilter) {
        return false;
      }

      if (_doctorFilter != 'All Doctors' && row.doctor != _doctorFilter) {
        return false;
      }

      if (_query.isNotEmpty) {
        final haystack = [
          DateFormat('dd MMM yyyy').format(row.date),
          row.tooth,
          row.treatment,
          row.doctor,
          row.mode,
          row.status,
        ].join(' ').toLowerCase();
        if (!haystack.contains(_query)) return false;
      }

      return true;
    }).toList(growable: false);

    filtered.sort((a, b) {
      int result;
      switch (_sortBy) {
        case 'tooth':
          result = a.tooth.toLowerCase().compareTo(b.tooth.toLowerCase());
          break;
        case 'treatment':
          result = a.treatment.toLowerCase().compareTo(b.treatment.toLowerCase());
          break;
        case 'doctor':
          result = a.doctor.toLowerCase().compareTo(b.doctor.toLowerCase());
          break;
        case 'cost':
          result = a.cost.compareTo(b.cost);
          break;
        case 'paid':
          result = a.paid.compareTo(b.paid);
          break;
        case 'balance':
          result = a.balance.compareTo(b.balance);
          break;
        case 'status':
          result = a.status.compareTo(b.status);
          break;
        case 'mode':
          result = a.mode.compareTo(b.mode);
          break;
        case 'date':
        default:
          result = a.date.compareTo(b.date);
          break;
      }
      return _sortAscending ? result : -result;
    });

    return filtered;
  }

  void _onSort(String key) {
    setState(() {
      if (_sortBy == key) {
        _sortAscending = !_sortAscending;
      } else {
        _sortBy = key;
        _sortAscending = true;
      }
    });
  }

  Color _statusColor(String status) {
    if (status == 'Paid') return const Color(0xFF16A34A);
    if (status == 'Partial') return const Color(0xFFF59E0B);
    return const Color(0xFFDC2626);
  }

  Future<void> _exportCsv() async {
    if (_isExportingCsv || _isExportingPdf) return;
    final rows = _visibleRows;
    if (rows.isEmpty) return;

    setState(() => _isExportingCsv = true);

    try {
      await runWithExportProgressDialog<void>(
        context: context,
        title: 'Exporting CSV',
        task: (progress) async {
          final logTag = _nextExportTag('csv');
          _logExport(logTag, 'CSV export started with ${rows.length} rows');
          progress.setProgress(0.1);

          final savePath = await FilePicker.platform.saveFile(
            dialogTitle: 'Save CSV',
            fileName: '${_fileStem()}.csv',
          );

          if (savePath == null || savePath.trim().isEmpty || progress.isCancelled) {
            _logExport(logTag, 'CSV export cancelled before write');
            return;
          }

          final target = savePath.toLowerCase().endsWith('.csv')
              ? savePath
              : '$savePath.csv';
          await _writeCsvWithRetry(
            target: target,
            rows: rows,
            progress: progress,
            logTag: logTag,
          );
          progress.setProgress(1.0);
          _logExport(logTag, 'CSV export completed');
        },
      );
    } catch (error, stackTrace) {
      _showExportError('CSV export failed', '$error');
      _logExport('csv-ui', 'CSV export surfaced error to user', error, stackTrace);
    } finally {
      if (mounted) {
        setState(() => _isExportingCsv = false);
      }
    }
  }

  Future<void> _exportPdf() async {
    if (_isExportingCsv || _isExportingPdf) return;
    final rows = _visibleRows;
    if (rows.isEmpty) return;

    setState(() => _isExportingPdf = true);

    try {
      await runWithExportProgressDialog<void>(
        context: context,
        title: 'Exporting PDF',
        task: (progress) async {
          final logTag = _nextExportTag('pdf');
          _logExport(logTag, 'PDF export started with ${rows.length} rows');
          final pdfRows = rows.length > _maxRowsPerPdfExport
              ? rows.take(_maxRowsPerPdfExport).toList(growable: false)
              : rows;
          if (rows.length > _maxRowsPerPdfExport) {
            _logExport(
              logTag,
              'PDF rows limited to $_maxRowsPerPdfExport from ${rows.length} to avoid memory crash',
            );
          }
          progress.setProgress(0.2);
          List<int> bytes;
          try {
            bytes = await _buildPdfDocument(pdfRows).save().timeout(_pdfBuildTimeout);
          } on TimeoutException {
            throw StateError(
              'PDF generation timed out. Please use CSV export for large histories or narrow the date range.',
            );
          }
          if (progress.isCancelled) return;
          progress.setProgress(0.6);

          final savePath = await FilePicker.platform.saveFile(
            dialogTitle: 'Save PDF',
            fileName: '${_fileStem()}.pdf',
          );

          if (savePath == null || savePath.trim().isEmpty || progress.isCancelled) {
            _logExport(logTag, 'PDF export cancelled before write');
            return;
          }

          final target = savePath.toLowerCase().endsWith('.pdf')
              ? savePath
              : '$savePath.pdf';
          await _writePdfWithRetry(
            target: target,
            bytes: bytes,
            progress: progress,
            logTag: logTag,
          );
          progress.setProgress(1.0);
          _logExport(logTag, 'PDF export completed');
        },
      );
    } catch (error, stackTrace) {
      _showExportError('PDF export failed', '$error');
      _logExport('pdf-ui', 'PDF export surfaced error to user', error, stackTrace);
    } finally {
      if (mounted) {
        setState(() => _isExportingPdf = false);
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() => _query = _searchController.text.trim().toLowerCase());
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _openShareOptions([_LedgerRowData? row]) async {
    final message = _composeShareMessage(row);
    final email = widget.patient.email.trim();
    final canEmail = email.isNotEmpty;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => ContentDialog(
        title: const Text('Share Invoice'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 360,
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilledButton(
                    onPressed: () async {
                      try {
                        await openWhatsApp(widget.patient.phone, message);
                      } catch (_) {
                        if (!dialogContext.mounted) return;
                        displayInfoBar(
                          dialogContext,
                          builder: (ctx, close) => InfoBar(
                            title: const Text('Unable to open WhatsApp'),
                            severity: InfoBarSeverity.error,
                            action: IconButton(
                              icon: const Icon(FluentIcons.clear),
                              onPressed: close,
                            ),
                          ),
                        );
                      }
                    },
                    child: const Text('WhatsApp'),
                  ),
                  Button(
                    onPressed: canEmail
                        ? () async {
                            try {
                              await sendEmail(
                                to: email,
                                subject: 'Patient Invoice Details',
                                body: message,
                              );
                            } catch (_) {
                              if (!dialogContext.mounted) return;
                              displayInfoBar(
                                dialogContext,
                                builder: (ctx, close) => InfoBar(
                                  title: const Text('Unable to open email client'),
                                  severity: InfoBarSeverity.error,
                                  action: IconButton(
                                    icon: const Icon(FluentIcons.clear),
                                    onPressed: close,
                                  ),
                                ),
                              );
                            }
                          }
                        : null,
                    child: Text(canEmail ? 'Email' : 'Email (No address)'),
                  ),
                  const Button(
                    onPressed: null,
                    child: Text('SMS (Coming Soon)'),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          Button(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<void> _openPrintOptions([_LedgerRowData? row]) async {
    final stateContext = context; // capture before StatefulBuilder shadows it
    String invoiceType = 'Full Invoice';
    bool showBranding = true;
    bool showSignature = true;

    await showDialog<void>(
      context: stateContext,
      builder: (dialogContext) => StatefulBuilder(
        builder: (ctx, setStateDialog) => ContentDialog(
          title: const Text('Print Options'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Invoice Type'),
              const SizedBox(height: 8),
              ComboBox<String>(
                value: invoiceType,
                items: const [
                  ComboBoxItem(value: 'Full Invoice', child: Text('Full Invoice')),
                  ComboBoxItem(value: 'Payment Receipt', child: Text('Payment Receipt')),
                  ComboBoxItem(value: 'Treatment Report', child: Text('Treatment Report')),
                ],
                onChanged: (v) {
                  if (v == null) return;
                  setStateDialog(() => invoiceType = v);
                },
              ),
              const SizedBox(height: 10),
              const Text('Paper: A4'),
              const SizedBox(height: 10),
              Checkbox(
                checked: showBranding,
                content: const Text('Show clinic branding'),
                onChanged: (v) => setStateDialog(() => showBranding = v ?? true),
              ),
              Checkbox(
                checked: showSignature,
                content: const Text('Show signature'),
                onChanged: (v) => setStateDialog(() => showSignature = v ?? true),
              ),
            ],
          ),
          actions: [
            FilledButton(
              onPressed: () async {
                Navigator.pop(dialogContext);
                final rows = row == null ? _visibleRows : [row];
                if (rows.isEmpty) return;
                final doc = _buildPdfDocument(rows);
                try {
                  await Printing.layoutPdf(onLayout: (_) async => doc.save());
                } catch (_) {
                  // Print cancelled or virtual printer error – ignore
                }
              },
              child: const Text('Print'),
            ),
            Button(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Close'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screen = MediaQuery.of(context).size;
    final modalWidth = screen.width < 900
      ? screen.width * 0.99
      : screen.width < 1500
        ? screen.width * 0.95
        : 1360.0;
    final modalHeight = screen.height * 0.92;

    final totalCost = _allRows.fold<double>(0, (s, r) => s + r.cost);
    final totalPaid = _allRows.fold<double>(0, (s, r) => s + r.paid);
    final totalBalance = totalCost - totalPaid;

    final lastVisit = _allRows.isEmpty
        ? '-'
        : DateFormat('dd MMM yyyy').format(_allRows.first.date);

    final avatarText = widget.patient.title.trim().isEmpty
        ? 'P'
        : widget.patient.title.trim().substring(0, 1).toUpperCase();
    final hasActiveFilters =
      _statusFilter != 'All' ||
      _modeFilter != 'All' ||
      _dateRange != 'All' ||
      _doctorFilter != 'All Doctors' ||
      _query.isNotEmpty;

    return Container(
      width: modalWidth,
      height: modalHeight,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFDCE6F2)),
      ),
      child: Column(
        children: [
          Container(
            constraints: const BoxConstraints(minHeight: 96),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x120D2F5B),
                  blurRadius: 10,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE3ECFF),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Center(
                    child: Text(
                      avatarText,
                      style: const TextStyle(
                        color: Color(0xFF2563EB),
                        fontWeight: FontWeight.w700,
                        fontSize: 20,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        widget.patient.title.trim().isEmpty
                            ? 'Unnamed Patient'
                            : widget.patient.title,
                        style: const TextStyle(
                          fontSize: 20,
                          color: Color(0xFF1E293B),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Patient ID: ${widget.patient.id}  •  Phone: ${widget.patient.phone.trim().isEmpty ? '-' : widget.patient.phone}  •  Last Visit: $lastVisit  •  Doctor: Dr Nowfar',
                        style: const TextStyle(
                          color: Color(0xFF64748B),
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  alignment: WrapAlignment.end,
                  children: [
                    FilledButton(
                      style: ButtonStyle(
                        backgroundColor:
                            WidgetStateProperty.all(const Color(0xFF2563EB)),
                      ),
                      onPressed: () {},
                      child: const Text('+ Add Treatment'),
                    ),
                    FilledButton(
                      style: ButtonStyle(
                        backgroundColor:
                            WidgetStateProperty.all(const Color(0xFF16A34A)),
                      ),
                      onPressed: () {},
                      child: const Text('Collect Payment'),
                    ),
                    Button(onPressed: _openShareOptions, child: const Text('Share')),
                    Button(onPressed: _openPrintOptions, child: const Text('Print')),
                    Button(
                      onPressed: _isExportingCsv || _isExportingPdf ? null : _exportCsv,
                      child: const Text('Download CSVs'),
                    ),
                    Button(
                      onPressed: _isExportingCsv || _isExportingPdf ? null : _exportPdf,
                      child: const Text('Download PDF'),
                    ),
                  ],
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(FluentIcons.chrome_close, size: 10),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x120D2F5B),
                  blurRadius: 10,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _summaryCard('Total Treatment Cost', '₹${totalCost.toStringAsFixed(0)}', const Color(0xFF1459AD), const Color(0xFFF1F5FB)),
                _summaryCard('Total Paid', '₹${totalPaid.toStringAsFixed(0)}', const Color(0xFF1E293B), const Color(0xFFF1FBF4)),
                _summaryCard('Outstanding Balance', '₹${totalBalance.toStringAsFixed(0)}', const Color(0xFFDC2626), const Color(0xFFFFF3F3)),
                _summaryCard('Payment Status', totalBalance <= 0 ? 'Paid' : 'Partially Paid', totalBalance <= 0 ? const Color(0xFF16A34A) : const Color(0xFFF59E0B), const Color(0xFFFFF8EF)),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x120D2F5B),
                  blurRadius: 10,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextBox(
                    controller: _searchController,
                    placeholder: 'Search treatments...',
                    prefix: const Padding(
                      padding: EdgeInsets.only(left: 8),
                      child: Icon(FluentIcons.search, size: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                _filterHeaderIcon(
                  icon: FluentIcons.completed,
                  tooltip: 'Status',
                  selected: _statusFilter != 'All',
                ),
                const SizedBox(width: 6),
                _combo(
                  value: _statusFilter,
                  values: const ['All', 'Paid', 'Due', 'Partial'],
                  onChanged: (v) => setState(() => _statusFilter = v),
                  width: 140,
                ),
                const SizedBox(width: 8),
                _filterHeaderIcon(
                  icon: FluentIcons.payment_card,
                  tooltip: 'Mode',
                  selected: _modeFilter != 'All',
                ),
                const SizedBox(width: 6),
                _combo(
                  value: _modeFilter,
                  values: const ['All', 'Cash', 'UPI'],
                  onChanged: (v) => setState(() => _modeFilter = v),
                  width: 120,
                ),
                const SizedBox(width: 8),
                _filterHeaderIcon(
                  icon: FluentIcons.date_time,
                  tooltip: 'Date',
                  selected: _dateRange != 'All',
                ),
                const SizedBox(width: 6),
                _combo(
                  value: _dateRange,
                  values: const ['1 Month', '3 Months', '6 Months', '1 Year', 'All'],
                  onChanged: (v) => setState(() => _dateRange = v),
                  width: 150,
                ),
                const SizedBox(width: 8),
                _filterHeaderIcon(
                  icon: FluentIcons.medical,
                  tooltip: 'Doctor',
                  selected: _doctorFilter != 'All Doctors',
                ),
                const SizedBox(width: 6),
                _combo(
                  value: _doctorFilter,
                  values: const ['All Doctors', 'Dr Nowfar'],
                  onChanged: (v) => setState(() => _doctorFilter = v),
                  width: 140,
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x120D2F5B),
                    blurRadius: 10,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Container(
                    color: hasActiveFilters
                        ? const Color(0xFFEAF2FF)
                        : Colors.transparent,
                    child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    child: Row(
                      children: [
                        Expanded(flex: 12, child: _sortableHead('Date', 'date')),
                        Expanded(flex: 10, child: _sortableHead('Tooth', 'tooth')),
                        Expanded(flex: 16, child: _sortableHead('Treatment', 'treatment')),
                        Expanded(flex: 12, child: _sortableHead('Doctor', 'doctor')),
                        Expanded(flex: 8, child: _sortableHead('Cost', 'cost')),
                        Expanded(flex: 8, child: _sortableHead('Paid', 'paid')),
                        Expanded(flex: 9, child: _sortableHead('Balance', 'balance')),
                        Expanded(flex: 9, child: _sortableHead('Status', 'status')),
                        Expanded(flex: 8, child: _sortableHead('Mode', 'mode')),
                        const Expanded(flex: 14, child: Text('Actions', style: TextStyle(fontWeight: FontWeight.w600))),
                      ],
                    ),
                  ),
                  ),
                  const Divider(size: 1),
                  Expanded(
                    child: ListView.builder(
                      itemCount: _visibleRows.length,
                      itemBuilder: (context, index) {
                        final row = _visibleRows[index];
                        final expanded = _expandedRowId == row.id;
                        final statusColor = _statusColor(row.status);

                        return MouseRegion(
                          cursor: SystemMouseCursors.click,
                          child: Column(
                            children: [
                              GestureDetector(
                                onTap: () {
                                  setState(() {
                                    _expandedRowId = expanded ? null : row.id;
                                  });
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                                  color: index.isEven
                                      ? const Color(0xFFF9FBFF)
                                      : Colors.white,
                                  child: Row(
                                    children: [
                                      Expanded(
                                        flex: 12,
                                        child: Text('📅 ${DateFormat('dd MMM yyyy').format(row.date)}'),
                                      ),
                                      Expanded(flex: 10, child: Text('🦷 ${row.tooth}')),
                                      Expanded(flex: 16, child: Text(row.treatment)),
                                      Expanded(flex: 12, child: Text(row.doctor)),
                                      Expanded(
                                        flex: 8,
                                        child: Text('₹${row.cost.toStringAsFixed(0)}'),
                                      ),
                                      Expanded(
                                        flex: 8,
                                        child: Text(
                                          '₹${row.paid.toStringAsFixed(0)}',
                                          style: TextStyle(
                                            color: row.paid < row.cost
                                                ? const Color(0xFFD97706)
                                                : const Color(0xFF16A34A),
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                      Expanded(
                                        flex: 9,
                                        child: Text(
                                          '₹${row.balance.toStringAsFixed(0)}',
                                          style: const TextStyle(
                                            color: Color(0xFFDC2626),
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                      Expanded(
                                        flex: 9,
                                        child: Align(
                                          alignment: Alignment.centerLeft,
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: statusColor.withValues(alpha: 0.12),
                                              borderRadius: BorderRadius.circular(999),
                                              border: Border.all(color: statusColor),
                                            ),
                                            child: Text(
                                              row.status,
                                              style: TextStyle(
                                                color: statusColor,
                                                fontWeight: FontWeight.w700,
                                                fontSize: 11,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                      Expanded(flex: 8, child: Text(row.mode)),
                                      Expanded(
                                        flex: 14,
                                        child: Wrap(
                                          spacing: 6,
                                          runSpacing: 6,
                                          children: [
                                            _actionIcon(
                                              icon: FluentIcons.view,
                                              tooltip: 'View',
                                              onTap: () {},
                                            ),
                                            _actionIcon(
                                              icon: FluentIcons.share,
                                              tooltip: 'Share Invoice',
                                              onTap: () => _openShareOptions(row),
                                            ),
                                            _actionIcon(
                                              icon: FluentIcons.print,
                                              tooltip: 'Print Receipt',
                                              onTap: () => _openPrintOptions(row),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              if (expanded)
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(12),
                                  color: const Color(0xFFF3F7FC),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Treatment Details',
                                        style: TextStyle(fontWeight: FontWeight.w700),
                                      ),
                                      const SizedBox(height: 6),
                                      Text('Notes by doctor: ${row.notes}'),
                                      const SizedBox(height: 4),
                                      Text('Medicines prescribed: ${row.prescription}'),
                                      const SizedBox(height: 4),
                                      const Text('Lab charges: -'),
                                      const SizedBox(height: 4),
                                      const Text('Attachments: No files attached'),
                                      const SizedBox(height: 10),
                                      const Text(
                                        'Payment Breakdown',
                                        style: TextStyle(fontWeight: FontWeight.w700),
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        '₹${row.paid.toStringAsFixed(0)} — ${row.mode} — ${DateFormat('dd MMM yyyy').format(row.date)}',
                                      ),
                                    ],
                                  ),
                                ),
                              const Divider(size: 1),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _combo({
    required String value,
    required List<String> values,
    required ValueChanged<String> onChanged,
    required double width,
  }) {
    return SizedBox(
      width: width,
      child: ComboBox<String>(
        value: value,
        items: values
            .map((v) => ComboBoxItem(value: v, child: Text(v)))
            .toList(growable: false),
        onChanged: (v) {
          if (v != null) onChanged(v);
        },
      ),
    );
  }

  Widget _sortableHead(String label, String keyName) {
    final selected = _sortBy == keyName;
    return GestureDetector(
      onTap: () => _onSort(keyName),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: selected ? const Color(0xFF1459AD) : const Color(0xFF334155),
            ),
          ),
          const SizedBox(width: 4),
          Icon(
            selected
                ? (_sortAscending
                    ? FluentIcons.chevron_up
                    : FluentIcons.chevron_down)
                : FluentIcons.chevron_down,
            size: 10,
            color: selected ? const Color(0xFF1459AD) : const Color(0xFF94A3B8),
          ),
        ],
      ),
    );
  }

  Widget _actionIcon({
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
  }) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: const Color(0xFFE7F1FF),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: const Color(0xFFBFD8F8)),
            ),
            child: Icon(icon, size: 13, color: const Color(0xFF2D7BD8)),
          ),
        ),
      ),
    );
  }

  Widget _summaryCard(String title, String value, Color valueColor, Color bg) {
    return SizedBox(
      width: 300,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE2E8F2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                color: Color(0xFF334155),
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                color: valueColor,
                fontSize: 24,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _filterHeaderIcon({
    required IconData icon,
    required String tooltip,
    required bool selected,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: selected ? const Color(0xFFE4EEFF) : const Color(0xFFF1F5FB),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: selected ? const Color(0xFF2D7BD8) : const Color(0xFFD7E2EF),
        ),
      ),
      child: Tooltip(
        message: tooltip,
        child: Icon(
          icon,
          size: 12,
          color: selected ? const Color(0xFF1459AD) : const Color(0xFF64748B),
        ),
      ),
    );
  }
}
