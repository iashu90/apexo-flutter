import 'package:apexo/common_widgets/patient_report.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/material.dart' as material;
import 'package:intl/intl.dart';

Future<void> showReportTableModalV2({
  required BuildContext context,
  required String title,
  required List<ReportDetailRow> rows,
  List<String> hiddenColumns = const [],
}) async {
  await showDialog<void>(
    context: context,
    builder: (_) => _ReportTableModalV2(
      title: title,
      rows: rows,
      hiddenColumns: hiddenColumns,
    ),
  );
}

class _ReportTableModalV2 extends StatefulWidget {
  final String title;
  final List<ReportDetailRow> rows;
  final List<String> hiddenColumns;

  const _ReportTableModalV2({
    required this.title,
    required this.rows,
    required this.hiddenColumns,
  });

  @override
  State<_ReportTableModalV2> createState() => _ReportTableModalV2State();
}

class _ReportTableModalV2State extends State<_ReportTableModalV2> {
  static const int _pageSize = 15;
  int _page = 1;

  int get _pageCount {
    if (widget.rows.isEmpty) return 1;
    return ((widget.rows.length + _pageSize - 1) / _pageSize).floor();
  }

  List<ReportDetailRow> get _pageRows {
    final sorted = widget.rows.toList(growable: false)
      ..sort((a, b) => b.date.compareTo(a.date));
    final start = (_page - 1) * _pageSize;
    final end = (start + _pageSize).clamp(0, sorted.length);
    if (start >= sorted.length) return const <ReportDetailRow>[];
    return sorted.sublist(start, end);
  }

  double _sumOf(String Function(ReportDetailRow row) getter) {
    var total = 0.0;
    for (final row in widget.rows) {
      total += double.tryParse(getter(row).replaceAll(RegExp(r'[^\d.]'), '')) ??
          0.0;
    }
    return total;
  }

  @override
  Widget build(BuildContext context) {
    final totalCost = _sumOf((row) => row.cost);
    final totalPaid = _sumOf((row) => row.paid);
    final totalBalance = totalCost - totalPaid;
    final dialogWidth = (MediaQuery.of(context).size.width * 0.95).clamp(960.0, 1500.0);
    final dialogHeight = (MediaQuery.of(context).size.height * 0.84).clamp(580.0, 900.0);

    return Center(
      child: Container(
        width: dialogWidth,
        height: dialogHeight,
        decoration: BoxDecoration(
          color: material.Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: const [
            BoxShadow(
              color: Color(0x2A0D2F5B),
              blurRadius: 24,
              offset: Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF2D7BD8), Color(0xFF1D61B8)],
                ),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(14),
                  topRight: Radius.circular(14),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(FluentIcons.cancel, size: 12),
                    style: ButtonStyle(
                      foregroundColor: WidgetStateProperty.all(Colors.white),
                    ),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: const BoxDecoration(
                color: Color(0xFFF6FAFF),
                border: Border(bottom: BorderSide(color: Color(0xFFD6E2F0))),
              ),
              child: Wrap(
                spacing: 16,
                runSpacing: 8,
                children: [
                  Text(
                    'Rows: ${widget.rows.length}',
                    style: const TextStyle(
                      color: Color(0xFF345982),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    'Total Cost: ₹${totalCost.toStringAsFixed(0)}',
                    style: const TextStyle(
                      color: Color(0xFF1459AD),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    'Total Paid: ₹${totalPaid.toStringAsFixed(0)}',
                    style: const TextStyle(
                      color: Color(0xFF2BA58D),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    'Balance: ₹${totalBalance.toStringAsFixed(0)}',
                    style: const TextStyle(
                      color: Color(0xFFD6455D),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: _pageRows.isEmpty
                  ? const Center(
                      child: Text(
                        'No rows available.',
                        style: TextStyle(color: Color(0xFF5B789F)),
                      ),
                    )
                  : SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: SingleChildScrollView(
                        scrollDirection: Axis.vertical,
                        child: PatientDetailsTable(
                          rows: _pageRows,
                          hiddenColumns: widget.hiddenColumns,
                          initialDateSortAscending: false,
                        ),
                      ),
                    ),
            ),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: Color(0xFFD6E2F0))),
              ),
              child: Row(
                children: [
                  Text(
                    'Page $_page of $_pageCount',
                    style: const TextStyle(
                      color: Color(0xFF5A7397),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  Button(
                    onPressed: _page > 1
                        ? () => setState(() => _page -= 1)
                        : null,
                    child: const Text('Previous'),
                  ),
                  const SizedBox(width: 8),
                  Button(
                    onPressed: _page < _pageCount
                        ? () => setState(() => _page += 1)
                        : null,
                    child: const Text('Next'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Close'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
