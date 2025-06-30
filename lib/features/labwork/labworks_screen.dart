import 'package:apexo/common_widgets/delete_confirmation.dart';
import 'package:apexo/features/settings/settings_stores.dart';
import 'package:apexo/services/localization/locale.dart';
import 'package:apexo/features/labwork/open_labwork_panel.dart';
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
  double _totalOwed = 0.0;

  @override
  void initState() {
    super.initState();
    // Calculate initial total owed for all labworks
    final allLabworks = labworks.present.values.toList();
    _totalOwed = allLabworks.fold(
      0.0,
      (sum, lw) => sum + (lw.paid ? -lw.price : (lw.price ?? 0)),
    );
  }

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

    return ScaffoldPage(
      key: WK.labworksScreen,
      padding: EdgeInsets.zero,
      content: Column(
        children: [
          // --- DataTable ---
          Expanded(
            child: StreamBuilder(
              stream: labworks.observableMap.stream,
              builder: (context, snapshot) {
                final allLabworks = labworks.present.values.toList();

                // Filter by date range if set
                final filteredLabworks = allLabworks.where((labwork) {
                  final lwDate = DateTime(
                      labwork.date.year, labwork.date.month, labwork.date.day);
                  if (_fromDate != null) {
                    final from = DateTime(
                        _fromDate!.year, _fromDate!.month, _fromDate!.day);
                    if (lwDate.isBefore(from)) return false;
                  }
                  if (_toDate != null) {
                    final to =
                        DateTime(_toDate!.year, _toDate!.month, _toDate!.day);
                    if (lwDate.isAfter(to)) return false;
                  }
                  return true;
                }).toList();

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
                    "Price",
                    "Laboratory",
                    "Delivered",
                    "doctors",
                  ],
                  onFilterChanged: (filteredList) {
                    setState(() {
                      _totalOwed = filteredList.fold(
                        0.0,
                        (sum, lw) =>
                            sum + (lw.paid ? -lw.price : (lw.price ?? 0)),
                      );
                    });
                  },
                  columnBuilders: {
                    "Price": (labwork) => Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: labwork.paid
                                ? Colors.green.withOpacity(0.15)
                                : Colors.red.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            (labwork.paid ? "+ ₹" : "- ₹") +
                                labwork.price.toStringAsFixed(2),
                            style: TextStyle(
                              color: labwork.paid ? Colors.green : Colors.red,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                    // ...other column builders...
                  },
                  customHeader: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                    child: Row(
                      children: [
                        Text("Filter by date:",
                            style:
                                const TextStyle(fontWeight: FontWeight.w600)),
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
                                if (_toDate != null &&
                                    _fromDate!.isAfter(_toDate!)) {
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
                              : DateFormat(localSettings.dateFormat)
                                  .format(_toDate!)),
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
                        Expanded(
                          child: Center(
                            child: _buildTotalOwed(_totalOwed),
                          ),
                        ),
                      ],
                    ),
                  ),
                  actions: [
                    DataTableAction(
                      callback: (_) => openLabwork(),
                      icon: FluentIcons.manufacturing,
                      title: txt("add"),
                    ),
                    DataTableAction(
                      icon: FluentIcons.delete,
                      title: txt("delete"),
                      enabled: (ids) => ids.isNotEmpty,
                      callback: (ids) async {
                        print("Selected IDs: $ids"); // Debug
                        final names = ids
                            .map((id) {
                              final lw = labworks.get(id);
                              if (lw == null) return null;
                              return "${lw.patient?.title ?? "Unknown"} ${lw.title}";
                            })
                            .where((str) => str != null && str.isNotEmpty)
                            .join("\n");
                        final confirmed = await showConfirmDeleteDialog(
                          context,
                          message:
                              "Are you sure you want to delete the selected lab works?",
                          customDetails: names.isNotEmpty ? names : null,
                        );
                        if (confirmed == true) {
                          final visibleIds =
                              filteredLabworks.map((lw) => lw.id).toSet();
                          final validSelectedIds = ids
                              .where((id) => visibleIds.contains(id))
                              .toList();
                          for (final id in validSelectedIds) {
                            await labworks.hardDelete(id);
                          }
                        }
                      },
                    ),
                  ],
                  furtherActions: [
                    const SizedBox(width: 5),
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
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTotalOwed(double totalOwed) {
    IconData icon;
    Color color;
    String label;

    if (totalOwed > 0) {
      icon = material.Icons.trending_down;
      color = material.Colors.red;
      label = "Total Owed";
    } else if (totalOwed < 0) {
      icon = material.Icons.trending_up;
      color = material.Colors.green;
      label = "Paid Extra";
    } else {
      icon = material.Icons.check_circle_outline;
      color = material.Colors.blueGrey;
      label = "Settled";
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: 22),
        const SizedBox(width: 8),
        Text(
          "$label: ₹${totalOwed.abs().toStringAsFixed(2)}",
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: color,
            fontSize: 16,
          ),
        ),
      ],
    );
  }
}
