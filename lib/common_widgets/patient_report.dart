import 'package:apexo/features/settings/settings_stores.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class PatientDetailsTable extends StatefulWidget {
  final List<PatientDetailRow> rows;
  final List<String> hiddenColumns;

  const PatientDetailsTable({
    super.key,
    required this.rows,
    this.hiddenColumns = const [],
  });

  @override
  State<PatientDetailsTable> createState() => _PatientDetailsTableState();
}

class _PatientDetailsTableState extends State<PatientDetailsTable> {
  bool _sortAscending = false; // Default to descending order

  void _toggleSort() {
    setState(() {
      _sortAscending = !_sortAscending;
    });
  }

  @override
  Widget build(BuildContext context) {
    final sortedRows = List<PatientDetailRow>.from(widget.rows)
      ..sort((a, b) =>
          _sortAscending ? a.date.compareTo(b.date) : b.date.compareTo(a.date));

    // Calculate dynamic widths
    final screenWidth = MediaQuery.of(context).size.width;
    // Adjust these fractions as needed for your layout
    final teethColWidth = screenWidth * 0.10; // 13% of screen width
    final treatmentColWidth = screenWidth * 0.12;
    final prescriptionColWidth = screenWidth * 0.15;

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Material(
        elevation: 1,
        borderRadius: BorderRadius.circular(8),
        child: DataTable(
          dataRowMinHeight: 40,
          dataRowMaxHeight: 80,
          headingRowColor: WidgetStateProperty.all(Colors.blueGrey.shade50),
          headingTextStyle: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 17,
            color: Colors.blueGrey,
            letterSpacing: 0.5,
          ),
          dataRowColor: WidgetStateProperty.resolveWith<Color?>(
            (Set<MaterialState> states) {
              if (states.contains(MaterialState.selected)) {
                return Colors.blue.withOpacity(0.08);
              }
              return null;
            },
          ),
          columns: [
            if (!widget.hiddenColumns.contains('Date'))
              _plainColumn(
                'Date',
                onTap: _toggleSort,
                sorted: true,
                ascending: _sortAscending,
              ),
            if (!widget.hiddenColumns.contains('Patient') &&
                sortedRows.any((row) => row.patientName != null))
              _plainColumn('Patient'),
            if (!widget.hiddenColumns.contains('Teeth')) _plainColumn('Teeth'),
            if (!widget.hiddenColumns.contains('Treatment'))
              _plainColumn('Treatment'),
            if (!widget.hiddenColumns.contains('Prescription'))
              _plainColumn('Prescription'),
            if (!widget.hiddenColumns.contains('Cost')) _plainColumn('Cost'),
            if (!widget.hiddenColumns.contains('Paid')) _plainColumn('Paid'),
            if (!widget.hiddenColumns.contains('Balance'))
              _plainColumn('Balance'),
            if (!widget.hiddenColumns.contains('Mode')) _plainColumn('Mode'),
          ],
          rows: List.generate(sortedRows.length, (index) {
            final row = sortedRows[index];

            final isEven = index % 2 == 0;
            return DataRow(
              color: WidgetStateProperty.all(
                isEven ? Colors.grey.shade50 : Colors.white,
              ),
              cells: [
                if (!widget.hiddenColumns.contains('Date'))
                  _plainCell(
                    Row(
                      children: [
                        if (row.isDone != null)
                          Container(
                            margin: const EdgeInsets.only(right: 8),
                            width: 18,
                            height: 18,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: row.isDone!
                                  ? Colors.green
                                  : Colors.grey.shade300,
                              border: Border.all(
                                color: row.isDone!
                                    ? Colors.green
                                    : Colors.grey.shade400,
                                width: 2,
                              ),
                            ),
                            child: row.isDone!
                                ? const Icon(Icons.check,
                                    size: 14, color: Colors.white)
                                : null,
                          ),
                        Flexible(
                          child: Text(
                            DateFormat(localSettings.dateFormat)
                                .format(row.date),
                            style: _cellTextStyle,
                            softWrap: true,
                            overflow: TextOverflow.visible,
                          ),
                        ),
                      ],
                    ),
                  ),
                if (!widget.hiddenColumns.contains('Patient') &&
                    row.patientName != null)
                  _plainCell(
                    Text(
                      row.patientName!,
                      style: _cellTextStyle.copyWith(
                        fontWeight: FontWeight.w500,
                        color: Colors.blueGrey.shade700,
                      ),
                      softWrap: true,
                      overflow: TextOverflow.visible,
                    ),
                  ),
                if (!widget.hiddenColumns.contains('Teeth'))
                  _plainCell(
                    SizedBox(
                      width: teethColWidth,
                      child: Tooltip(
                        message: row.teeth,
                        child: Text(
                          row.teeth,
                          style: _teethTextStyle,
                          softWrap: true,
                          overflow: TextOverflow.visible,
                          maxLines: 3,
                        ),
                      ),
                    ),
                  ),
                if (!widget.hiddenColumns.contains('Treatment'))
                  _plainCell(
                    SizedBox(
                      width: treatmentColWidth,
                      child: Tooltip(
                        message: row.treatment,
                        child: Text(
                          row.treatment,
                          style: _cellTextStyle,
                          softWrap: true,
                          overflow: TextOverflow.visible,
                          maxLines: 3,
                        ),
                      ),
                    ),
                  ),
                if (!widget.hiddenColumns.contains('Prescription'))
                  _plainCell(
                    SizedBox(
                      width: prescriptionColWidth,
                      child: Tooltip(
                        message: row.prescription,
                        child: Text(
                          row.prescription,
                          style: _cellTextStyle,
                          softWrap: true,
                          overflow: TextOverflow.visible,
                          maxLines: 3,
                        ),
                      ),
                    ),
                  ),
                if (!widget.hiddenColumns.contains('Cost'))
                  _plainCell(
                    Align(
                      alignment: Alignment.centerRight,
                      child: Text(
                        row.cost,
                        style: _cellTextStyle.copyWith(
                            fontWeight: FontWeight.w600,
                            color: (double.tryParse(row.cost.replaceAll(
                                            RegExp(r'[^\d.]'), '')) ??
                                        0) <=
                                    0
                                ? Colors.grey
                                : Colors.blue),
                        softWrap: false,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.right,
                      ),
                    ),
                  ),
                if (!widget.hiddenColumns.contains('Paid'))
                  _plainCell(
                    Align(
                      alignment: Alignment.centerRight,
                      child: Text(
                        row.paid,
                        style: _cellTextStyle.copyWith(
                          fontWeight: FontWeight.w600,
                          color: (double.tryParse(row.paid
                                          .replaceAll(RegExp(r'[^\d.]'), '')) ??
                                      0) ==
                                  0
                              ? Colors.grey
                              : Colors.green,
                        ),
                        softWrap: false,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.right,
                      ),
                    ),
                  ),
                if (!widget.hiddenColumns.contains('Balance'))
                  _plainCell(
                    Align(
                      alignment: Alignment.centerRight,
                      child: Text(
                        (() {
                          final cost = double.tryParse(
                                  row.cost.replaceAll(RegExp(r'[^\d.]'), '')) ??
                              0;
                          final paid = double.tryParse(
                                  row.paid.replaceAll(RegExp(r'[^\d.]'), '')) ??
                              0;
                          final balance = cost - paid;
                          return balance == 0
                              ? ''
                              : '₹${balance.toStringAsFixed(2)}';
                        })(),
                        style: _cellTextStyle.copyWith(
                          fontWeight: FontWeight.w600,
                          color: (() {
                            final cost = double.tryParse(row.cost
                                    .replaceAll(RegExp(r'[^\d.]'), '')) ??
                                0;
                            final paid = double.tryParse(row.paid
                                    .replaceAll(RegExp(r'[^\d.]'), '')) ??
                                0;
                            final balance = cost - paid;
                            if (cost <= 0) return Colors.green;
                            if (balance > 0) return Colors.red;
                            return Colors.teal.shade700;
                          })(),
                        ),
                        softWrap: false,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.right,
                      ),
                    ),
                  ),
                if (!widget.hiddenColumns.contains('Mode'))
                  _plainCell(
                    Align(
                      alignment: Alignment.center,
                      child: Text(
                        (double.tryParse(row.paid
                                        .replaceAll(RegExp(r'[^\d.]'), '')) ??
                                    0) ==
                                0
                            ? ''
                            : row.mode,
                        style: _cellTextStyle.copyWith(
                          fontWeight: FontWeight.w500,
                          color: row.mode.toLowerCase() == 'gpay'
                              ? Colors.green
                              : Colors.brown,
                        ),
                        softWrap: false,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
              ],
            );
          }),
          dividerThickness: 0.7,
          border: TableBorder(
            horizontalInside: BorderSide(
              color: Colors.grey.shade300,
              width: 0.7,
            ),
          ),
        ),
      ),
    );
  }

  final TextStyle _cellTextStyle = const TextStyle(
    fontSize: 15,
    color: Colors.black87,
    fontWeight: FontWeight.w400,
    letterSpacing: 0.2,
  );

  final TextStyle _teethTextStyle = const TextStyle(
      fontSize: 13,
      color: Colors.deepOrange, // A nice blue, or pick your own
      fontWeight: FontWeight.bold,
      letterSpacing: 0.5);

  DataColumn _plainColumn(String label,
      {VoidCallback? onTap, bool? sorted, bool? ascending}) {
    return DataColumn(
      label: InkWell(
        onTap: onTap,
        child: Row(
          children: [
            Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            if (sorted != null && sorted)
              Icon(
                ascending! ? Icons.arrow_upward : Icons.arrow_downward,
                size: 16,
                color: Colors.blueGrey,
              ),
          ],
        ),
      ),
    );
  }

  DataCell _plainCell(Widget child) {
    return DataCell(
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: child,
      ),
    );
  }
}

class PatientDetailRow {
  final DateTime date;
  final String? patientName;
  final String cost;
  final String paid;
  final String prescription;
  final String treatment;
  final String teeth;
  final bool? isDone;
  final String mode;

  PatientDetailRow({
    required this.date,
    this.patientName,
    required this.cost,
    required this.paid,
    required this.prescription,
    required this.treatment,
    required this.teeth,
    this.isDone,
    this.mode = '',
  });
}
