import 'package:apexo/common_widgets/patient_report.dart';
import 'package:apexo/features/patients/patient_model.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/material.dart' as material;
import 'package:intl/intl.dart';

Future<void> showPatientHistoryDialogV2({
  required BuildContext context,
  required Patient patient,
  required List<ReportDetailRow> rows,
}) {
  return showDialog<void>(
    context: context,
    builder: (_) => Align(
      alignment: Alignment.center,
      child: PatientHistoryDialogV2(
        patient: patient,
        rows: rows,
      ),
    ),
  );
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
  final TextEditingController _searchController = TextEditingController();
  String _query = '';
  String _statusFilter = 'all';

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() {
        _query = _searchController.text.trim().toLowerCase();
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  double _toAmount(String source) {
    return double.tryParse(source.replaceAll(RegExp(r'[^0-9.]'), '')) ?? 0;
  }

  List<ReportDetailRow> get _filteredRows {
    final q = _query;
    var rows = widget.rows.toList(growable: false)
      ..sort((a, b) => b.date.compareTo(a.date));

    if (q.isNotEmpty) {
      rows = rows.where((row) {
        final text = [
          row.treatment,
          row.teeth,
          row.cost,
          row.paid,
          DateFormat('dd MMM yyyy').format(row.date),
        ].join(' ').toLowerCase();
        return text.contains(q);
      }).toList(growable: false);
    }

    if (_statusFilter == 'due') {
      rows = rows
          .where((row) => _toAmount(row.paid) < _toAmount(row.cost))
          .toList(growable: false);
    } else if (_statusFilter == 'paid') {
      rows = rows
          .where((row) => _toAmount(row.paid) >= _toAmount(row.cost))
          .toList(growable: false);
    }

    return rows;
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final height = MediaQuery.of(context).size.height;
    final dialogWidth = width < 900 ? width * 0.98 : width * 0.92;
    final dialogHeight = height * 0.88;

    final totalCost = widget.rows.fold<double>(0, (s, r) => s + _toAmount(r.cost));
    final totalPaid = widget.rows.fold<double>(0, (s, r) => s + _toAmount(r.paid));
    final balance = totalCost - totalPaid;

    return Container(
      width: dialogWidth,
      height: dialogHeight,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFD6E2F0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x160D2F5B),
            blurRadius: 12,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.patient.title.trim().isEmpty
                          ? 'Patient History'
                          : widget.patient.title,
                      style: const TextStyle(
                        color: Color(0xFF1C3557),
                        fontSize: 28,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Patient ID: ${widget.patient.id}  •  Phone: ${widget.patient.phone.trim().isEmpty ? '-' : widget.patient.phone}',
                      style: const TextStyle(
                        color: Color(0xFF5A7397),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(FluentIcons.chrome_close, size: 12),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _metricTile('Total Treatment Cost', '₹${totalCost.toStringAsFixed(0)}', const Color(0xFF1D3E67), const Color(0xFFF2F6FC)),
              _metricTile('Total Paid', '₹${totalPaid.toStringAsFixed(0)}', const Color(0xFF1F7A39), const Color(0xFFEFF8F2)),
              _metricTile('Outstanding Balance', '₹${balance.toStringAsFixed(0)}', const Color(0xFFD64545), const Color(0xFFFFF1F1)),
              _metricTile('Payment Status', balance <= 0 ? 'Paid' : 'Partially Paid', balance <= 0 ? const Color(0xFF1F7A39) : const Color(0xFFE0952E), const Color(0xFFFFF8EF)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextBox(
                  controller: _searchController,
                  placeholder: 'Search treatments, teeth, amount...',
                  prefix: const Padding(
                    padding: EdgeInsets.only(left: 8),
                    child: Icon(FluentIcons.search, size: 12),
                  ),
                  suffix: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(FluentIcons.clear),
                          onPressed: _searchController.clear,
                        )
                      : null,
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 180,
                child: ComboBox<String>(
                  value: _statusFilter,
                  items: const [
                    ComboBoxItem(value: 'all', child: Text('All')),
                    ComboBoxItem(value: 'due', child: Text('Due')),
                    ComboBoxItem(value: 'paid', child: Text('Paid')),
                  ],
                  onChanged: (v) => setState(() => _statusFilter = v ?? 'all'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                if (constraints.maxWidth < 840) {
                  return ListView.builder(
                    itemCount: _filteredRows.length,
                    itemBuilder: (context, i) {
                      final row = _filteredRows[i];
                      final cost = _toAmount(row.cost);
                      final paid = _toAmount(row.paid);
                      final due = cost - paid;
                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF9FBFF),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFDCE8F6)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              DateFormat('dd MMM yyyy').format(row.date),
                              style: const TextStyle(fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 4),
                            Text('Treatment: ${row.treatment.isEmpty ? '-' : row.treatment}'),
                            Text('Teeth: ${row.teeth.isEmpty ? '-' : row.teeth}'),
                            const SizedBox(height: 4),
                            Text('Cost: ₹${cost.toStringAsFixed(0)} • Paid: ₹${paid.toStringAsFixed(0)} • Balance: ₹${due.toStringAsFixed(0)}'),
                          ],
                        ),
                      );
                    },
                  );
                }

                return material.SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: material.SingleChildScrollView(
                    child: material.DataTable(
                      columns: const [
                        material.DataColumn(label: Text('Date')),
                        material.DataColumn(label: Text('Teeth')),
                        material.DataColumn(label: Text('Treatment')),
                        material.DataColumn(label: Text('Cost')),
                        material.DataColumn(label: Text('Paid')),
                        material.DataColumn(label: Text('Balance')),
                        material.DataColumn(label: Text('Status')),
                      ],
                      rows: _filteredRows.map((row) {
                        final cost = _toAmount(row.cost);
                        final paid = _toAmount(row.paid);
                        final due = cost - paid;
                        return material.DataRow(
                          cells: [
                            material.DataCell(Text(DateFormat('dd MMM yyyy').format(row.date))),
                            material.DataCell(Text(row.teeth.isEmpty ? '-' : row.teeth)),
                            material.DataCell(Text(row.treatment.isEmpty ? '-' : row.treatment)),
                            material.DataCell(Text('₹${cost.toStringAsFixed(0)}')),
                            material.DataCell(Text('₹${paid.toStringAsFixed(0)}')),
                            material.DataCell(Text('₹${due.toStringAsFixed(0)}')),
                            material.DataCell(Text(due > 0 ? 'Due' : 'Paid')),
                          ],
                        );
                      }).toList(growable: false),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Text(
                'Total Cost: ₹${totalCost.toStringAsFixed(0)}',
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 20),
              ),
              const SizedBox(width: 20),
              Text(
                'Paid: ₹${totalPaid.toStringAsFixed(0)}',
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 20,
                  color: Color(0xFF1F7A39),
                ),
              ),
              const SizedBox(width: 20),
              Text(
                'Balance: ₹${balance.toStringAsFixed(0)}',
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 20,
                  color: Color(0xFFD64545),
                ),
              ),
              const Spacer(),
              FilledButton(
                onPressed: () {},
                child: const Text('Collect Payment'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _metricTile(String title, String value, Color valueColor, Color bg) {
    return Container(
      width: 260,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE3EAF5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Color(0xFF385477),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              color: valueColor,
              fontWeight: FontWeight.w700,
              fontSize: 36,
            ),
          ),
        ],
      ),
    );
  }
}
