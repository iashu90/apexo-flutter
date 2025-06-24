import 'package:apexo/common_widgets/patient_report.dart';
import 'package:apexo/features/settings/settings_stores.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/material.dart' as material;

class PatientDetailsDialog extends StatelessWidget {
  final List<PatientDetailRow> rows;
  final String? patientName;

  const PatientDetailsDialog({super.key, required this.rows, this.patientName});

  @override
  Widget build(BuildContext context) {
    double totalCost = 0;
    double totalPaid = 0;
    const currency = "₹";

    for (final row in rows) {
      totalCost += double.tryParse(row.cost.replaceAll(currency, '')) ?? 0;
      totalPaid += double.tryParse(row.paid.replaceAll(currency, '')) ?? 0;
    }

    return Container(
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
      constraints: const BoxConstraints(
        minWidth: 600,
        maxWidth: 800,
        minHeight: 300,
        maxHeight: 600,
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
                      child: Text(
                        patientName != null && patientName!.isNotEmpty
                            ? "$patientName's Details"
                            : "Patient Details",
                        style: const TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 16),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 1,
                    child: Center(
                      child: Text(
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
              const SizedBox(height: 2),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 450,
            child: Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: PatientDetailsTable(
                        rows: rows,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(left: 12.0),
                      child: Text(
                        "Total Cost: $currency${totalCost.toStringAsFixed(2)}",
                        style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: material.Colors.blue,
                            fontSize: 16),
                      ),
                    ),
                    const SizedBox(width: 24),
                    Text(
                      "Total Paid: $currency${totalPaid.toStringAsFixed(2)}",
                      style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: material.Colors.green,
                          fontSize: 16),
                    ),
                    const SizedBox(width: 24),
                    if (totalPaid > totalCost)
                      Text(
                        "Overpaid: $currency${(totalPaid - totalCost).toStringAsFixed(2)}",
                        style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: material.Colors.orange,
                            fontSize: 16),
                      )
                    else if (totalPaid < totalCost)
                      Text(
                        "Due: $currency${(totalCost - totalPaid).toStringAsFixed(2)}",
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
