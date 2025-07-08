import 'package:apexo/common_widgets/patient_report.dart';
import 'package:apexo/features/patients/patient_model.dart';
import 'package:apexo/features/settings/settings_stores.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/material.dart' as material;
import 'package:intl/intl.dart';

enum PatientDetailsSource { patient, dashboard, doctor }

class PatientDetailsDialog extends StatefulWidget {
  final List<ReportDetailRow> rows;
  final Patient? patient;
  final List<String> hiddenColumns;
  final DateTime? initialDate;
  final DateTime? doctorFilterDate;
  final PatientDetailsSource fromWhere;

  const PatientDetailsDialog({
    super.key,
    required this.rows,
    this.patient,
    this.hiddenColumns = const [],
    this.initialDate,
    this.doctorFilterDate,
    this.fromWhere = PatientDetailsSource.patient,
  });

  @override
  State<PatientDetailsDialog> createState() => _PatientDetailsDialogState();
}

class _PatientDetailsDialogState extends State<PatientDetailsDialog> {
  late DateTime selectedDate;
  late DateTime doctorFilterDate;
  late List<ReportDetailRow> _rows;
  String modeFilter = 'All';
  String dueFilter = 'All'; // Options: All, Due, Fully Paid
  bool doctorOnlyToday = true;

  @override
  void initState() {
    super.initState();
    selectedDate = widget.initialDate ?? DateTime.now();
    doctorFilterDate = widget.doctorFilterDate ?? DateTime.now();
    _rows = widget.rows;
  }

  List<ReportDetailRow> get filteredRows {
    List<ReportDetailRow> base = widget.initialDate == null
        ? widget.rows
        : widget.rows
            .where((row) =>
                row.date.year == selectedDate.year &&
                row.date.month == selectedDate.month &&
                row.date.day == selectedDate.day)
            .toList();

    if (widget.fromWhere == PatientDetailsSource.doctor && doctorOnlyToday) {
      base = base
          .where((row) =>
              row.date.year == doctorFilterDate.year &&
              row.date.month == doctorFilterDate.month &&
              row.date.day == doctorFilterDate.day)
          .toList();
    }

    if (dueFilter == 'Due') {
      base = base.where((row) {
        final paid =
            double.tryParse(row.paid.replaceAll(RegExp(r'[^\d.]'), '')) ?? 0;
        final cost =
            double.tryParse(row.cost.replaceAll(RegExp(r'[^\d.]'), '')) ?? 0;
        return paid < cost;
      }).toList();
    } else if (dueFilter == 'Fully Paid') {
      base = base.where((row) {
        final paid =
            double.tryParse(row.paid.replaceAll(RegExp(r'[^\d.]'), '')) ?? 0;
        final cost =
            double.tryParse(row.cost.replaceAll(RegExp(r'[^\d.]'), '')) ?? 0;
        return paid >= cost && cost > 0;
      }).toList();
    }

    if (modeFilter != 'All') {
      base = base.where((row) {
        final paid =
            double.tryParse(row.paid.replaceAll(RegExp(r'[^\d.]'), '')) ?? 0;
        // Only filter by mode if paid > 0
        return paid > 0 && row.mode == modeFilter;
      }).toList();
    }
    return base;
  }

  @override
  Widget build(BuildContext context) {
    final isFromDoctor = widget.fromWhere == PatientDetailsSource.doctor;

    double totalCost = 0;
    double totalPaid = 0;
    const currency = "₹";

    for (final row in filteredRows) {
      final cost = double.tryParse(row.cost.replaceAll(currency, '')) ?? 0;
      final paid = double.tryParse(row.paid.replaceAll(currency, '')) ?? 0;
      // Skip if cost is 0 and paid is greater than 0
      // if (cost == 0 && paid > 0) continue;
      totalCost += cost;
      totalPaid += paid;
    }

    final double dialogWidth = MediaQuery.of(context).size.width * 0.95;
    final double dialogHeight = MediaQuery.of(context).size.height * 0.80;

    return Container(
      width: dialogWidth,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: material.Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: material.Colors.black.withOpacity(0.1),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      constraints: BoxConstraints(
        maxWidth: dialogWidth,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Flexible(
                    flex: 1,
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.fromWhere == PatientDetailsSource.doctor
                                ? "Doctor Details"
                                : (widget.patient != null &&
                                        widget.patient!.title.isNotEmpty)
                                    ? "${widget.patient!.title}'s Details"
                                    : "Patient Details",
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 16,
                            ),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                          if (selectedDate != null && widget.patient == null)
                            Padding(
                              padding: const EdgeInsets.only(top: 2.0),
                              child: Text(
                                "Date: ${DateFormat('d MMM yyyy').format(selectedDate)}",
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: material.Colors.grey,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 1,
                    child: Center(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            globalSettings.get("prescriptionFot").value,
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 16,
                              color: material.Colors.blue.shade600,
                            ),
                            textAlign: TextAlign.center,
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                          if (widget.fromWhere ==
                              PatientDetailsSource.doctor) ...[
                            const SizedBox(width: 16),
                            Checkbox(
                              checked: doctorOnlyToday,
                              onChanged: (val) {
                                setState(() {
                                  doctorOnlyToday = val ?? false;
                                  // You can add your filter logic here if needed
                                });
                              },
                            ),
                            const SizedBox(width: 8),
                            const Text(
                              "Only Today",
                              style: TextStyle(
                                fontWeight: FontWeight.w500,
                                fontSize: 15,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  Flexible(
                    flex: 1,
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: IconButton(
                        icon: const Icon(FluentIcons.cancel),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (!isFromDoctor)
                Center(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Label for Payment Status filter
                      Padding(
                        padding: const EdgeInsets.only(right: 8.0),
                        child: Text(
                          "Payment Status:",
                          style: TextStyle(
                            color: material.Colors.blue.shade700,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      // Due filter ComboBox
                      ComboBox<String>(
                        value: dueFilter,
                        items: [
                          ComboBoxItem(child: Text('All'), value: 'All'),
                          ComboBoxItem(child: Text('Due'), value: 'Due'),
                          ComboBoxItem(
                              child: Text('Fully Paid'), value: 'Fully Paid'),
                        ],
                        onChanged: (value) {
                          setState(() {
                            dueFilter = value ?? 'All';
                          });
                        },
                        placeholder: const Text('Payment Status'),
                        style: TextStyle(
                          color: material.Colors.blue.shade700,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 24),
                      // Label for Mode filter
                      Padding(
                        padding: const EdgeInsets.only(right: 8.0),
                        child: Text(
                          "Mode:",
                          style: TextStyle(
                            color: material.Colors.blue.shade700,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      // Mode filter ComboBox
                      ComboBox<String>(
                        value: modeFilter,
                        items: [
                          ComboBoxItem(child: Text('All'), value: 'All'),
                          ComboBoxItem(child: Text('Cash'), value: 'Cash'),
                          ComboBoxItem(child: Text('GPay'), value: 'GPay'),
                        ],
                        onChanged: (value) {
                          setState(() {
                            modeFilter = value ?? 'All';
                          });
                        },
                        placeholder: const Text('Mode'),
                        style: TextStyle(
                          color: material.Colors.blue.shade700,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 2),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: dialogWidth,
            height: dialogHeight,
            child: Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: SingleChildScrollView(
                      scrollDirection: Axis.vertical,
                      child: PatientDetailsTable(
                        rows: filteredRows,
                        hiddenColumns: widget.hiddenColumns,
                        initialDateSortAscending: false,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                if (!isFromDoctor)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(left: 12.0),
                        child: Text(
                          "Total Cost: $currency${totalCost.toStringAsFixed(2).replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (match) => ',')}",
                          style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: material.Colors.blue,
                              fontSize: 16),
                        ),
                      ),
                      const SizedBox(width: 24),
                      Text(
                        "Total Paid: $currency${totalPaid.toStringAsFixed(2).replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (match) => ',')}",
                        style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: material.Colors.green,
                            fontSize: 16),
                      ),
                      const SizedBox(width: 24),
                      if (totalPaid > totalCost)
                        Text(
                          "Overpaid: $currency${(totalPaid - totalCost).toStringAsFixed(2).replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (match) => ',')}",
                          style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: material.Colors.orange,
                              fontSize: 16),
                        )
                      else
                        Text(
                          "Balance: $currency${(totalCost - totalPaid).toStringAsFixed(2).replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (match) => ',')}",
                          style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: material.Colors.red,
                              fontSize: 16),
                        ),
                    ],
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Align(
            alignment: Alignment.centerRight,
            child: Button(
              child: const Text("Close"),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),
        ],
      ),
    );
  }
}
