import 'package:apexo/features/settings/settings_stores.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class PatientDetailsTable extends StatefulWidget {
  final List<PatientDetailRow> rows;

  const PatientDetailsTable({super.key, required this.rows});

  @override
  State<PatientDetailsTable> createState() => _PatientDetailsTableState();
}

class _PatientDetailsTableState extends State<PatientDetailsTable> {
  bool _sortAscending = false; // Default to descending order

  late List<PatientDetailRow> _sortedRows;

  @override
  void initState() {
    super.initState();
    _sortedRows = List.from(widget.rows);
    _sortRows();
  }

  void _sortRows() {
    _sortedRows.sort((a, b) {
      final aDate = DateTime.tryParse(a.date) ?? DateTime(1900);
      final bDate = DateTime.tryParse(b.date) ?? DateTime(1900);
      return _sortAscending ? aDate.compareTo(bDate) : bDate.compareTo(aDate);
    });
  }

  void _toggleSort() {
    setState(() {
      _sortAscending = !_sortAscending;
      _sortRows();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: DataTable(
        headingRowColor: WidgetStateProperty .all(Colors.blueGrey.shade50),
        headingTextStyle: const TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 16,
          color: Colors.blueGrey,
          letterSpacing: 0.5,
        ),
        dataRowColor: WidgetStateProperty .resolveWith<Color?>(
            (Set<MaterialState> states) {
          if (states.contains(MaterialState.selected)) {
            return Colors.blue.withOpacity(0.08);
          }
          return null;
        }),
        columns: [
          DataColumn(
            label: InkWell(
              onTap: _toggleSort,
              child: Row(
                children: [
                  const Text('Date',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(width: 4),
                  Icon(
                    _sortAscending ? Icons.arrow_upward : Icons.arrow_downward,
                    size: 16,
                    color: Colors.blueGrey,
                  ),
                ],
              ),
            ),
          ),
          if (_sortedRows.any((row) => row.patientName != null))
            _plainColumn('Patient'),
          _plainColumn('Teeth'),
          _plainColumn('Treatment'),
          _plainColumn('Prescription'),
          _plainColumn('Cost'),
          _plainColumn('Paid'),
        ],
        rows: List.generate(_sortedRows.length, (index) {
          final row = _sortedRows[index];
          final isEven = index % 2 == 0;
          return DataRow(
            color: WidgetStateProperty .all(
                isEven ? Colors.grey.shade50 : Colors.white),
            cells: [
              DataCell(Row(
                children: [
                  // Circle tick indicator
                  if (row.isDone != null)
                    Container(
                      margin: const EdgeInsets.only(right: 8),
                      width: 18,
                      height: 18,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color:
                            row.isDone! ? Colors.green : Colors.grey.shade300,
                        border: Border.all(
                          color:
                              row.isDone! ? Colors.green : Colors.grey.shade400,
                          width: 2,
                        ),
                      ),
                      child: row.isDone!
                          ? const Icon(Icons.check,
                              size: 14, color: Colors.white)
                          : null,
                    ),
                  Text(
                    row.date.isNotEmpty
                        ? DateFormat(localSettings.dateFormat).format(
                            DateTime.tryParse(row.date) ?? DateTime(1900))
                        : '',
                    style: _cellTextStyle,
                  ),
                ],
              )),
              if (row.patientName != null)
                _plainCell(Text(row.patientName!, style: _cellTextStyle)),
              _plainCell(Text(row.teeth, style: _cellTextStyle)),
              DataCell(
                Tooltip(
                  message: row.treatment,
                  waitDuration: const Duration(milliseconds: 300),
                  child: SizedBox(
                    width: 180, // Fixed width for treatment cell
                    child: Text(
                      row.treatment,
                      style: _cellTextStyle,
                    ),
                  ),
                ),
              ),
              _plainCell(Text(row.prescription, style: _cellTextStyle)),
              _plainCell(Text(row.cost, style: _cellTextStyle)),
              _plainCell(Text(row.paid, style: _cellTextStyle)),
            ],
          );
        }),
        dividerThickness: 1.0,
      ),
    );
  }

  final TextStyle _cellTextStyle = const TextStyle(
    fontSize: 15,
    color: Colors.black87,
    fontWeight: FontWeight.w400,
    letterSpacing: 0.2,
  );

  DataColumn _plainColumn(String label) {
    return DataColumn(
      label: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
      ),
    );
  }

  DataCell _plainCell(Widget child) {
    return DataCell(
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: child,
      ),
    );
  }
}

class PatientDetailRow {
  final String date;
  final String? patientName;
  final String cost;
  final String paid;
  final String prescription;
  final String treatment;
  final String teeth;
  final bool? isDone;

  PatientDetailRow({
    required this.date,
    this.patientName,
    required this.cost,
    required this.paid,
    required this.prescription,
    required this.treatment,
    required this.teeth,
    this.isDone,
  });
}
