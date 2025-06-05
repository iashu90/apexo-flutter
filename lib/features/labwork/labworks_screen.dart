import 'package:apexo/features/settings/settings_stores.dart';
import 'package:apexo/services/localization/locale.dart';
import 'package:apexo/features/labwork/open_labwork_panel.dart';
import 'package:apexo/common_widgets/archive_selected.dart';
import 'package:apexo/common_widgets/archive_toggle.dart';
import 'package:apexo/features/labwork/labwork_model.dart';
import 'package:apexo/features/labwork/labworks_store.dart';
import 'package:apexo/widget_keys.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';
import "../../common_widgets/datatable.dart";
import 'package:flutter/material.dart' show showDatePicker;
import 'package:flutter/material.dart' as material;

class LabworksScreen extends StatefulWidget {
  const LabworksScreen({super.key});

  @override
  State<LabworksScreen> createState() => _LabworksScreenState();
}

class _LabworksScreenState extends State<LabworksScreen> {
  DateTime? _fromDate;
  DateTime? _toDate;

  @override
  Widget build(BuildContext context) {
    final allLabworks = labworks.present.values.toList();

    // Filter by date range if set
    final filteredLabworks = allLabworks.where((labwork) {
      final lwDate =
          DateTime(labwork.date.year, labwork.date.month, labwork.date.day);
      if (_fromDate != null) {
        final from =
            DateTime(_fromDate!.year, _fromDate!.month, _fromDate!.day);
        if (lwDate.isBefore(from)) return false;
      }
      if (_toDate != null) {
        final to = DateTime(_toDate!.year, _toDate!.month, _toDate!.day);
        if (lwDate.isAfter(to)) return false;
      }
      return true;
    }).toList();

    // Calculate total money owed (unpaid labworks in filtered range)
    final double totalOwed = filteredLabworks
        .where((lw) => !lw.paid)
        .fold(0.0, (sum, lw) => sum + (lw.price ?? 0));

    return ScaffoldPage(
      key: WK.labworksScreen,
      padding: EdgeInsets.zero,
      content: Column(
        children: [
          // --- Date Range Filter UI ---
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Row(
              children: [
                Text("Filter by date:",
                    style: const TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(width: 12),
                Button(
                  child: Text(_fromDate == null
                      ? "From"
                      : DateFormat(localSettings.dateFormat)
                          .format(_fromDate!)),
                  onPressed: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _fromDate ?? DateTime.now(),
                      firstDate: DateTime(2000),
                      lastDate: DateTime(2100),
                    );
                    if (picked != null) {
                      setState(() {
                        _fromDate = picked;
                        // If start date is after end date, clear end date
                        if (_toDate != null && _fromDate!.isAfter(_toDate!)) {
                          _toDate = null;
                        }
                      });
                    }
                  },
                ),
                const SizedBox(width: 8),
                Button(
                  child: Text(_toDate == null
                      ? "To"
                      : DateFormat(localSettings.dateFormat).format(_toDate!)),
                  onPressed: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _toDate ?? DateTime.now(),
                      firstDate: DateTime(2000),
                      lastDate: DateTime(2100),
                    );
                    if (picked != null) {
                      setState(() {
                        _toDate = picked;
                        // If end date is before start date, clear start date
                        if (_fromDate != null &&
                            _toDate!.isBefore(_fromDate!)) {
                          _fromDate = null;
                        }
                      });
                    }
                  },
                ),
                if (_fromDate != null || _toDate != null) ...[
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(FluentIcons.clear),
                    onPressed: () => setState(() {
                      _fromDate = null;
                      _toDate = null;
                    }),
                  ),
                ],
                const Spacer(),
                Text(
                  "Total Owed: ₹${totalOwed.toStringAsFixed(2)}",
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: material.Colors.red,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
          // --- DataTable ---
          Expanded(
            child: StreamBuilder(
              stream: labworks.observableMap.stream,
              builder: (context, snapshot) {
                return DataTable<Labwork>(
                  compact: true,
                  items: filteredLabworks,
                  store: labworks,
                  labelOrder: [
                    "Patient",
                    "Type",
                    "Units",
                    "Shade",
                    "Paid",
                    "Laboratory",
                    "Delivered",
                    "doctors",
                  ],
                  actions: [
                    DataTableAction(
                      callback: (_) => openLabwork(),
                      icon: FluentIcons.manufacturing,
                      title: txt("add"),
                    ),
                    archiveSelected(labworks)
                  ],
                  furtherActions: [
                    const SizedBox(width: 5),
                    ArchiveToggle(notifier: labworks.notify)
                  ],
                  onSelect: openLabwork,
                  itemActions: [
                    ItemAction(
                      icon: FluentIcons.phone,
                      title: txt("callLaboratory"),
                      callback: (id) {
                        final lab = labworks.get(id);
                        if (lab == null) return;
                        launchUrl(Uri.parse('tel:${lab.phoneNumber}'));
                      },
                    ),
                  ],
                  defaultSortDirection: -1,
                  defaultSortingName: "byDate",
                  columnBuilders: {
                    "Paid": (labwork) => Row(
                          children: [
                            Text(
                              labwork.paid ? "+ ₹" : "- ₹",
                              style: TextStyle(
                                fontSize: 14,
                                color: labwork.paid ? Colors.green : Colors.red,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              labwork.price.toStringAsFixed(2),
                              style: TextStyle(
                                fontSize: 14,
                                color: labwork.paid ? Colors.green : Colors.red,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
