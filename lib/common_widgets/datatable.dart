import 'dart:convert';
import 'dart:math';
import 'package:apexo/app/routes.dart';
import 'package:apexo/common_widgets/patients_report_dialog.dart';
import 'package:apexo/core/activity_logger.dart';
import 'package:apexo/core/store.dart';
import 'package:apexo/features/appointments/appointments_store.dart';
import 'package:apexo/features/doctors/doctor_model.dart';
import 'package:apexo/features/doctors/doctors_screen.dart';
import 'package:apexo/features/labwork/labwork_model.dart';
import 'package:apexo/features/patients/patient_model.dart';
import 'package:apexo/services/localization/locale.dart';
import 'package:apexo/widget_keys.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/cupertino.dart';
import '../utils/colors_without_yellow.dart';
import '../core/model.dart';
import 'item_title.dart';
import 'package:flutter/material.dart' as material;
import 'dart:async';

class _SortableItem<Item> {
  String value;
  Item item;
  _SortableItem(this.value, this.item);
}

class ItemAction {
  IconData icon;
  String title;
  void Function(String) callback;
  ItemAction({required this.icon, required this.title, required this.callback});
}

class DataTableAction {
  void Function(List<String>) callback;
  IconData icon;
  String? title;
  Widget? child;
  bool Function(List<String>)? enabled;
  DataTableAction({
    required this.callback,
    required this.icon,
    this.title,
    this.child,
    this.enabled,
  });
}

class DataTable<Item extends Model> extends StatefulWidget {
  final List<Item> items;
  final Store store;
  final List<DataTableAction> actions;
  final void Function(Item) onSelect;
  final List<Widget> furtherActions;
  final bool compact;
  final List<ItemAction> itemActions;
  final int defaultSortDirection;
  final String defaultSortingName;
  final List<String>? labelOrder;
  final List<String> hiddenColumns;
  final Map<String, Widget Function(Item)>? columnBuilders;
  final Widget? customHeader;
  final Widget? commandBarHeader;
  final void Function(List<Item>)? onFilterChanged;

  const DataTable({
    super.key,
    required this.items,
    required this.store,
    required this.actions,
    required this.onSelect,
    this.furtherActions = const [],
    this.compact = false,
    this.itemActions = const [],
    this.defaultSortDirection = 1,
    this.defaultSortingName = "byTitle",
    this.labelOrder,
    this.columnBuilders,
    this.customHeader,
    this.onFilterChanged,
    this.hiddenColumns = const [],
    this.commandBarHeader,
  });

  @override
  State<StatefulWidget> createState() => DataTableState<Item>();
}

class DataTableState<Item extends Model> extends State<DataTable<Item>> {
  Set<String> checkedIds = {};
  int sortBy = -1;
  int sortDirection = 1;
  int slice = 20;

  /// labels must be cached since this computation would
  /// occur too many times on every rebuild
  List<String>? _labels;
  List<String> get labels {
    if (widget.labelOrder != null) return widget.labelOrder!;

    return _labels ??= widget.items.fold(<String>{},
        (labels, item) => labels..addAll((item.labels.keys.toList()))).toList()
      ..sort((a, b) => a.compareTo(b));
  }

  List<String> get nonNullLabels {
    return labels
        .where((x) => !x.contains("\u200B") && !x.contains("\u200C"))
        .toList();
  }

  List<Item> _computeFilteredItems() {
    return widget.items.where((item) {
      if (Item == Patient && item is Patient) {
        if (_activeQuickFilter != null) {
          if (_activeQuickFilter == "Due") {
            if (item.outstandingPayments <= 0) return false;
          } else if (_activeQuickFilter == "Overpaid") {
            if (item.outstandingPayments >= 0) return false;
          } else if (_activeQuickFilter == "No Name") {
            if (item.title.trim().isNotEmpty) return false;
          } else if (_activeQuickFilter == "Invalid Phone") {
            final digits = item.phone.replaceAll(RegExp(r'\D'), '');
            if (digits.length == 10) return false;
          } else if (_activeQuickFilter == "No Visit") {
            if (item.daysSinceLastAppointment != null) return false;
          } else if (_activeQuickFilter == "Visited Today") {
            if (item.daysSinceLastAppointment != 0) return false;
          }
        }

        if (_activeDaysFilter != null &&
            (item.daysSinceLastAppointment ?? 0) <= _activeDaysFilter!) {
          return false;
        }

        if (_activeTreatmentFilter != null &&
            !item.allAppointments.any((appointment) =>
                appointment.selectedTreatments.any((t) => t
                    .toLowerCase()
                    .contains(_activeTreatmentFilter!.toLowerCase())))) {
          return false;
        }

        if (_activeTreatmentFilter == "RCT" &&
            _activeSubTreatmentFilter != null &&
            _activeSubTreatmentFilter!.isNotEmpty) {
          final hasSubTreatment = item.allAppointments.any((appointment) =>
              appointment.selectedTreatments.contains("RCT") &&
              appointment.subTreatments.contains(_activeSubTreatmentFilter!));
          if (!hasSubTreatment) return false;
        }

        if (_searchValue.isNotEmpty) {
          final searchLower = _searchValue.toLowerCase();
          if (_searchStartsWith) {
            return item.title.toLowerCase().startsWith(searchLower);
          } else {
            return item.title.toLowerCase().contains(searchLower) ||
                item.phone.toLowerCase().contains(searchLower);
          }
        }
      }

      final words =
          _searchValue.toLowerCase().replaceAll(RegExp("أ|إ"), "ا").split(" ");
      final searchIn = (item.title +
              (item is Patient ? item.phone : '') +
              jsonEncode(item.labels.values.toList()))
          .toLowerCase()
          .replaceAll(RegExp("أ|إ"), "ا");
      final bool allTermsFound = words
              .map((word) => searchIn.contains(word))
              .where((x) => x == true)
              .length ==
          words.length;
      return allTermsFound;
    }).toList(growable: false);
  }

  String removeNonNumbers(String input) {
    final regex = RegExp(r'^\D+|\D+$');
    final containsNumbers = RegExp(r'\d').hasMatch(input);

    if (containsNumbers) {
      return input.replaceAll(regex, '');
    }
    return input;
  }

  List<Item> _computeSortedItems(List<Item> filteredItems) {
    List<Item> result = List<Item>.from(filteredItems, growable: true);

    if (sortBy < 0) {
      result.sort((a, b) =>
          a.title.toLowerCase().compareTo(b.title.toLowerCase()) *
          sortDirection);
    } else {
      final labelKey = labels[sortBy];
      final sorted = List<_SortableItem<Item>>.from(
        result.map((e) => _SortableItem(e.labels[labelKey] ?? "", e)),
        growable: true,
      )..sort((a, b) {
          if (double.tryParse(a.value) != null &&
              double.tryParse(b.value) != null) {
            return double.parse(a.value).compareTo(double.parse(b.value)) *
                sortDirection;
          } else if (double.tryParse(removeNonNumbers(a.value)) != null &&
              double.tryParse(removeNonNumbers(b.value)) != null) {
            return double.parse(removeNonNumbers(a.value))
                    .compareTo(double.parse(removeNonNumbers(b.value))) *
                sortDirection;
          } else {
            return a.value.compareTo(b.value) * sortDirection;
          }
        });

      result = sorted.map((e) => e.item).toList(growable: false);
    }

    return result.sublist(0, min(result.length, slice));
  }

  showMore() {
    setState(() {
      slice = slice + 10;
    });
  }

  String _searchValue = '';
  bool _searchStartsWith = false;

  void setSearchTerm(String value, {bool startsWith = false}) {
    setState(() {
      _searchValue = value;
      _searchStartsWith = startsWith;
      _updateFilteredItems();
    });
  }

  itemSelectToggle(Item item, bool? checked) {
    setState(() {
      if (checked == true) {
        checkedIds.add(item.id);
      } else {
        checkedIds.remove(item.id);
      }
    });
  }

  void setSortBy(int? index) {
    setState(() {
      sortBy = index ?? -1;
      ActivityLogger.logAction(
        "Sort By Selected",
        screen: Item.toString(),
        data: {
          "SortBy":
              sortBy == -1 ? widget.defaultSortingName : nonNullLabels[sortBy],
        },
      );
    });
  }

  void toggleSortDirection() {
    setState(() {
      sortDirection = sortDirection * -1;
      ActivityLogger.logAction(
        "Sort Direction Toggled",
        screen: Item.toString(),
        data: {"SortDirection": sortDirection > 0 ? "Ascending" : "Descending"},
      );
    });
  }

  @override
  void initState() {
    super.initState();
    sortDirection = widget.defaultSortDirection;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildCommandBar(),
        _buildListController(),
        if (Item == Patient) _buildAlphabetFilter(),
        if (widget.customHeader != null) widget.customHeader!,
        // _buildItemsList(context),
        Builder(
          builder: (context) {
            final filtered = _computeFilteredItems();
            final sorted = _computeSortedItems(filtered);
            return _buildItemsList(context, filtered, sorted);
          },
        ),
      ],
    );
  }

  void _updateFilteredItems() {
    final filtered = _computeFilteredItems();
    if (widget.onFilterChanged != null) {
      widget.onFilterChanged!(filtered);
    }

    ActivityLogger.logAction(
      "Filter Applied",
      screen: Item.toString(),
      data: {
        "QuickFilter": _activeQuickFilter,
        "DaysFilter": _activeDaysFilter,
        "TreatmentFilter": _activeTreatmentFilter,
        "SubTreatmentFilter": _activeSubTreatmentFilter,
        "SearchValue": _searchValue,
        "ResultsFound": filtered.length,
      },
    );
  }

  final contextMenuControllers = <String, FlyoutController>{};

  Widget _buildAlphabetFilter() {
    final isDark = FluentTheme.of(context).brightness == Brightness.dark;
    final selectedBg = isDark ? Colors.blue : Colors.blue;
    final selectedFg = Colors.white;
    final unselectedBg =
        isDark ? Colors.black.withOpacity(0.2) : Colors.white.withOpacity(0.2);
    final unselectedFg = isDark ? Colors.white : Colors.black;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Wrap(
        spacing: 4,
        children: List.generate(26, (i) {
          final letter = String.fromCharCode(65 + i);
          final isSelected = _searchValue.toUpperCase() == letter;
          return FilledButton(
            style: ButtonStyle(
              backgroundColor: WidgetStatePropertyAll(
                isSelected ? selectedBg : unselectedBg,
              ),
              foregroundColor: WidgetStatePropertyAll(
                  isSelected ? selectedFg : unselectedFg),
              padding: const WidgetStatePropertyAll(
                EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              ),
            ),
            child: Text(letter),
            onPressed: () {
              ActivityLogger.logAction(
                "Alphabet Filter Clicked",
                screen: Item.toString(),
                data: {"letter": letter, "isSelected": isSelected},
              );
              if (isSelected) {
                setSearchTerm('', startsWith: false); // Reset to all
              } else {
                setSearchTerm(letter, startsWith: true);
              }
            },
          );
        })
          ..add(
            FilledButton(
              style: ButtonStyle(
                foregroundColor: WidgetStatePropertyAll(
                    _searchValue.isEmpty ? selectedFg : unselectedFg),
                backgroundColor: WidgetStatePropertyAll(
                  _searchValue.isEmpty ? selectedBg : unselectedBg,
                ),
                padding: const WidgetStatePropertyAll(
                  EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                ),
              ),
              child: const Text("All"),
              onPressed: () {
                ActivityLogger.logAction(
                  "Alphabet Filter Clicked",
                  screen: Item.toString(),
                  data: {"letter": "All", "isSelected": _searchValue.isEmpty},
                );
                setSearchTerm('', startsWith: false);
              },
            ),
          ),
      ),
    );
  }

  Expanded _buildItemsList(
    BuildContext context,
    List<Item> filtered,
    List<Item> sorted,
  ) {
    for (var item in filtered) {
      contextMenuControllers.putIfAbsent(item.id, () => FlyoutController());
    }

    return Expanded(
      child: Container(
        padding: const EdgeInsets.only(top: 10),
        child: Column(
          children: [
            if (filtered.isEmpty) _buildNoItemsFound(),
            Expanded(
              child: ListView.builder(
                key: WK.dataTableListView,
                itemCount: filtered.length > sorted.length
                    ? sorted.length + 1
                    : sorted.length,
                itemBuilder: (context, index) =>
                    filtered.length > sorted.length && index == sorted.length
                        ? _buildShowMore(context)
                        : _buildSingleItem(sorted[index],
                            checkedIds.contains(sorted[index].id)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Center _buildShowMore(BuildContext context) {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(10),
        width: 100,
        height: 60,
        child: FilledButton(
          style: ButtonStyle(
              elevation: const WidgetStatePropertyAll(10),
              backgroundColor:
                  WidgetStatePropertyAll(FluentTheme.of(context).accentColor),
              foregroundColor: const WidgetStatePropertyAll(Colors.white),
              shape: WidgetStatePropertyAll(RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(200)))),
          onPressed: () {
            ActivityLogger.logAction(
              "Show More Clicked",
              screen: Item.toString(),
              data: {},
            );
            showMore();
          },
          child: const Icon(FluentIcons.double_chevron_down),
        ),
      ),
    );
  }

  _buildSingleItem(Item item, bool isChecked) {
    return Container(
      padding: widget.compact
          ? EdgeInsets.zero
          : const EdgeInsets.symmetric(vertical: 1.5),
      decoration: BoxDecoration(
        color: isChecked
            ? FluentTheme.of(context).selectionColor.withValues(alpha: 0.05)
            : null,
        border: Border(
          bottom:
              BorderSide(color: Colors.grey.withValues(alpha: 0.2), width: 0.5),
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(0),
        title: Container(
          margin: const EdgeInsets.fromLTRB(5, 5, 5, 0),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(3),
          ),
          child: Row(
            children: [
              Divider(direction: Axis.vertical, size: widget.compact ? 1 : 45),
              _buildInnerRow(item),
              Divider(direction: Axis.vertical, size: widget.compact ? 1 : 45),
            ],
          ),
        ),
        leading: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildCheckBox(isChecked, item),
            if (item is Patient || item is Doctor) ...[
              const SizedBox(width: 8),
              const Divider(direction: Axis.vertical, size: 40),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(FluentIcons.money, size: 20),
                onPressed: () {
                  ActivityLogger.logAction(
                    "Report Dialog Opened",
                    screen: Item.toString(),
                    data: {
                      Item.toString(): item?.title ?? "",
                      "itemType": Item.toString()
                    },
                  );
                  showDialog(
                    context: context,
                    builder: (_) => Align(
                      alignment: Alignment.center,
                      child: Container(
                        color: Colors.white,
                        child: item is Patient
                            ? PatientDetailsDialog(
                                rows: item.patientDetails,
                                patient: item,
                                hiddenColumns: [
                                  'Prescription',
                                  'P.Mode',
                                  'Doc Paid',
                                  'TotalDocPay'
                                ],
                              )
                            : item is Doctor
                                ? PatientDetailsDialog(
                                    rows: item.doctorDetails,
                                    doctorFilterDate: globalDoctorSelectedDate,
                                    hiddenColumns: [
                                      'Prescription',
                                      'Cost',
                                      'Paid',
                                      'P.Mode',
                                      'T.Mode'
                                    ],
                                    fromWhere: PatientDetailsSource.doctor,
                                  )
                                : const SizedBox.shrink(),
                      ),
                    ),
                  );
                },
              ),
            ],
          ],
        ),
        onPressed: () {
          ActivityLogger.logAction(
            "Item Selected",
            screen: Item.toString(),
            data: {"itemId": item.id, "itemTitle": item.title},
          );
          widget.onSelect(item);
        },
        trailing: FlyoutTarget(
            controller: contextMenuControllers[item.id]!,
            child: IconButton(
              icon: Container(
                padding: const EdgeInsets.all(5),
                child: const Icon(FluentIcons.more),
              ),
              onPressed: () {
                ActivityLogger.logAction(
                  "Context Menu Opened",
                  screen: Item.toString(),
                  data: {"itemId": item.id, "itemTitle": item.title},
                );
                contextMenuControllers[item.id]!.showFlyout(
                  barrierDismissible: true,
                  dismissOnPointerMoveAway: false,
                  dismissWithEsc: true,
                  builder: (context) {
                    return StatefulBuilder(builder: (context, setState) {
                      return MenuFlyout(items: [
                        MenuFlyoutItem(
                          text: Txt(item.title),
                          leading: const Icon(FluentIcons.edit),
                          onPressed: () {
                            ActivityLogger.logAction(
                              "Edit Item Clicked",
                              screen: Item.toString(),
                              data: {
                                "itemId": item.id,
                                "itemTitle": item.title
                              },
                            );
                            widget.onSelect(item);
                          },
                          closeAfterClick: true,
                        ),
                        if (widget.itemActions.isNotEmpty)
                          const MenuFlyoutSeparator(),
                        for (var action in widget.itemActions)
                          MenuFlyoutItem(
                            leading: Icon(action.icon),
                            text: Txt(action.title),
                            onPressed: () {
                              ActivityLogger.logAction(
                                "Item Action Clicked",
                                screen: Item.toString(),
                                data: {
                                  "action": action.title,
                                  "itemId": item.id
                                },
                              );
                              action.callback(item.id);
                            },
                            closeAfterClick: true,
                          ),
                        if (routes
                            .panels()
                            .where((p) => p.item.id == item.id)
                            .isEmpty)
                          MenuFlyoutItem(
                            leading: Icon(item.archived == true
                                ? FluentIcons.archive_undo
                                : FluentIcons.archive),
                            text: Txt(txt(
                                item.archived == true ? "restore" : "archive")),
                            onPressed: () {
                              ActivityLogger.logAction(
                                item.archived == true
                                    ? "Restore Clicked"
                                    : "Archive Clicked",
                                screen: Item.toString(),
                                data: {
                                  "itemId": item.id,
                                  "itemTitle": item.title
                                },
                              );
                              item.archived == true
                                  ? widget.store.unarchive(item.id)
                                  : widget.store.archive(item.id);
                            },
                            closeAfterClick: true,
                          )
                      ]);
                    });
                  },
                );
              },
            )),
      ),
    );
  }

  int getCycledNumber(int num) {
    return (num - 1) % 7;
  }

  Expanded _buildInnerRow(Item item) {
    final itemLabels = item.labels;
    final nonEmptyLabels = labels
        .where((l) => itemLabels[l] != null)
        .where((l) => !widget.hiddenColumns.contains(l))
        .toList(growable: false);

    return Expanded(
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Padding(
          padding: widget.compact
              ? const EdgeInsets.all(0)
              : const EdgeInsets.all(8.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              ItemTitle(
                key: Key(item.id),
                radius: widget.compact ? 1 : 20,
                item: item,
              ),
              ...nonEmptyLabels.asMap().entries.expand((entry) {
                final index = entry.key;
                final labelTitle = entry.value;

                if (widget.columnBuilders != null &&
                    widget.columnBuilders!.containsKey(labelTitle)) {
                  return [
                    widget.columnBuilders![labelTitle]!(item),
                    const SizedBox(width: 8),
                  ];
                }

                return [
                  _buildLabelPill(
                    labelTitle,
                    item,
                    colorsWithoutYellow[getCycledNumber(index)],
                  ),
                  const SizedBox(width: 8),
                ];
              }),
            ],
          ),
        ),
      ),
    );
  }

  _buildCheckBox(bool isChecked, Item item) {
    return Transform.scale(
      scale: 1.25,
      child: Checkbox(
        key: Key("dt_cb_${item.id}"),
        checked: isChecked,
        onChanged: (checked) {
          ActivityLogger.logAction(
            checked == true ? "Item Checked" : "Item Unchecked",
            screen: Item.toString(),
            data: {
              "itemId": item.id,
              "itemTitle": item.title,
              "checked": checked,
            },
          );
          itemSelectToggle(item, checked);
        },
      ),
    );
  }

  String? _activeSubTreatmentFilter;

  Padding _buildListController() {
    final filtered = _computeFilteredItems();
    final shownCount = _computeSortedItems(filtered).length;
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 5, 10, 0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _buildItemsNumIndicator(
            filteredCount: filtered.length,
            shownCount: shownCount,
          ),
          if (Item == Patient)
            Row(
              children: [
                _buildQuickFilterComboBox([
                  "Due",
                  "Overpaid",
                  "No Visit",
                  "Visited Today",
                  "No Name",
                  "Invalid Phone"
                ]),
                const SizedBox(width: 8),
                _buildDaysFilterComboBox([10, 30]),
                const SizedBox(width: 8),
                _buildTagFilterComboBox(),
                const SizedBox(width: 8),
                if (_activeTreatmentFilter == "RCT")
                  _buildSubTreatmentComboBox(rctSittings),
                if (_activeTreatmentFilter == "Crown")
                  _buildSubTreatmentComboBox(crownSittings),
              ],
            ),
          _buildSorters(),
        ],
      ),
    );
  }

  BoxDecoration getFilterBoxDecoration(bool isSelected) {
    return BoxDecoration(
      color: isSelected ? Colors.blue : Colors.transparent,
      borderRadius: BorderRadius.circular(5),
      boxShadow: isSelected
          ? [
              BoxShadow(
                color: Colors.blue.withOpacity(0.3),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ]
          : [],
      border: isSelected
          ? Border.all(color: Colors.blue, width: 2)
          : Border.all(color: Colors.transparent, width: 0),
    );
  }

  int? _activeDaysFilter;
  Widget _buildDaysFilterComboBox(List<int> daysOptions) {
    final isSelected = _activeDaysFilter != null;
    return Container(
      decoration: getFilterBoxDecoration(isSelected),
      child: ComboBox<int?>(
        value: _activeDaysFilter,
        placeholder: const Text("Days Filter"),
        items: [
          const ComboBoxItem<int?>(value: null, child: Text("All")),
          ...daysOptions.map(
            (d) => ComboBoxItem<int?>(
                value: d,
                child: Text(
                  "> $d Days",
                  style: TextStyle(
                    color: isSelected ? Colors.blue : Colors.black,
                  ),
                )),
          ),
        ],
        onChanged: (value) {
          setState(() {
            _activeDaysFilter = value;
            ActivityLogger.logAction(
              "Day Filter Selected",
              screen: Item.toString(),
              data: {"DayFilter": value},
            );
          });
        },
      ),
    );
  }

  String? _activeQuickFilter;
  Widget _buildQuickFilterComboBox(List<String> quickOptions) {
    final isSelected = _activeQuickFilter != null;
    return Container(
      decoration: getFilterBoxDecoration(isSelected),
      child: ComboBox<String?>(
        value: _activeQuickFilter,
        placeholder: const Text("Quick Filter"),
        items: [
          const ComboBoxItem<String?>(value: null, child: Text("All")),
          ...quickOptions.map(
            (option) => ComboBoxItem<String?>(
              value: option,
              child: Text(
                option,
                style: TextStyle(
                  color: isSelected ? Colors.blue : Colors.black,
                ),
              ),
            ),
          ),
        ],
        onChanged: (value) {
          setState(() {
            _activeQuickFilter = value;
            ActivityLogger.logAction(
              "Quick Filter Selected",
              screen: Item.toString(),
              data: {"QuickFilter": value},
            );
          });
        },
      ),
    );
  }

  String? _activeTreatmentFilter;
  Widget _buildTagFilterComboBox() {
    final isSelected = _activeTreatmentFilter != null;
    // Static treatments to show at the top
    final staticTreatments = ["RCT", "Ortho", "Crown"];
    final removeTreatments = [
      "Zirconia Crowns",
      "PFM Crowns"
    ]; // Add any treatment names you want to remove

    final staticTreatmentsLower =
        staticTreatments.map((s) => s.toLowerCase()).toSet();
    final removeTreatmentsLower =
        removeTreatments.map((s) => s.toLowerCase()).toSet();

    final dynamicTreatments = allTreatments
        .map((treatment) => treatment.name)
        .where((name) =>
            !staticTreatmentsLower.contains(name.toLowerCase()) &&
            !removeTreatmentsLower.contains(name.toLowerCase()))
        .toList();
    // Dynamic treatments from allTreatments, excluding static ones

    return Container(
      decoration: getFilterBoxDecoration(isSelected),
      child: ComboBox<String?>(
        value: _activeTreatmentFilter,
        placeholder: const Text("Treatment Filter"),
        items: [
          const ComboBoxItem<String?>(value: null, child: Text("All")),
          // Static treatments at the top
          ...staticTreatments.map(
            (name) => ComboBoxItem<String?>(
              value: name,
              child: Text(
                name,
                style: TextStyle(
                  color: isSelected ? Colors.blue : Colors.black,
                ),
              ),
            ),
          ),
          // Divider
          const ComboBoxItem<String?>(
              value: "__divider__",
              child: Divider(
                style: DividerThemeData(
                  decoration: BoxDecoration(
                    color: Colors.grey,
                  ),
                ),
              )),
          // Dynamic treatments
          ...dynamicTreatments.map(
            (name) => ComboBoxItem<String?>(
              value: name,
              child: Text(
                name,
                style: TextStyle(
                  color: isSelected ? Colors.blue : Colors.black,
                ),
              ),
            ),
          ),
        ],
        onChanged: (value) {
          // Prevent selecting the divider
          if (value == "__divider__") return;
          setState(() {
            _activeTreatmentFilter = value;
            ActivityLogger.logAction(
              "Treatment Filter Selected",
              screen: Item.toString(),
              data: {"TreatmentFilter": value},
            );
          });
        },
      ),
    );
  }

  Widget _buildSubTreatmentComboBox(List<String> subTreatments) {
    final isSelected = _activeSubTreatmentFilter != null;
    return Container(
      decoration: getFilterBoxDecoration(isSelected),
      child: ComboBox<String?>(
        placeholder: const Text("Sub Treatment"),
        value: _activeSubTreatmentFilter,
        items: [
          const ComboBoxItem<String?>(value: null, child: Text("Select")),
          ...subTreatments.map(
            (sitting) => ComboBoxItem<String?>(
              value: sitting,
              child: Text(
                sitting,
                style: TextStyle(
                  color: isSelected ? Colors.blue : Colors.black,
                ),
              ),
            ),
          ),
        ],
        onChanged: (value) {
          setState(() {
            _activeSubTreatmentFilter = value;

            ActivityLogger.logAction(
              "SubTreatment Filter Selected",
              screen: Item.toString(),
              data: {"SubTreatmentFilter": value},
            );
          });
        },
      ),
    );
  }

  Row _buildSorters() {
    return Row(
      children: [
        _buildSortBy(),
        const SizedBox(width: 3),
        _buildSortDirectionToggle()
      ],
    );
  }

  IconButton _buildSortDirectionToggle() {
    return IconButton(
      key: WK.toggleSortDirection,
      icon: sortDirection > 0
          ? const Icon(FluentIcons.sort_up)
          : const Icon(FluentIcons.sort_down),
      onPressed: toggleSortDirection,
    );
  }

  ComboBox<int> _buildSortBy() {
    return ComboBox<int>(
      key: WK.dataTableSortBy,
      items: [
        ComboBoxItem<int>(
            value: -1, child: Txt(txt(widget.defaultSortingName))),
        ...nonNullLabels.map((l) => ComboBoxItem<int>(
            value: nonNullLabels.indexOf(l),
            child: Txt("${txt("by")} ${txt(l)}")))
      ],
      value: sortBy,
      onChanged: setSortBy,
    );
  }

  Widget _buildItemsNumIndicator({
    required int filteredCount,
    required int shownCount,
  }) {
    return Row(
      children: [
        Txt(
          "${txt("showing")} $shownCount/$filteredCount",
          style: TextStyle(
            color: Colors.grey.toAccentColor().lightest,
            fontSize: 11,
            fontWeight: FontWeight.bold,
          ),
        ),
        Visibility(
          visible: filteredCount > 0,
          maintainSize: true,
          maintainAnimation: true,
          maintainState: true,
          child: Row(children: _buildToggleSorters(context)),
        ),
      ],
    );
  }

  List<Widget> _buildToggleSorters(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (routes.panels().isNotEmpty ||
        width < 865 ||
        (width > 1000 && width < 1150)) {
      return [];
    }
    return [
      const SizedBox(width: 30),
      ...([widget.defaultSortingName, ...nonNullLabels])
          .map((e) => [
                Acrylic(
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(3)),
                  elevation: sortBy == nonNullLabels.indexOf(e) ? 12 : 0,
                  child: ToggleButton(
                    checked: sortBy == nonNullLabels.indexOf(e),
                    onChanged: (checked) {
                      if (checked) {
                        setSortBy(nonNullLabels.indexOf(e));
                      } else {
                        toggleSortDirection();
                      }
                    },
                    style: const ToggleButtonThemeData(
                        uncheckedButtonStyle: ButtonStyle(
                      backgroundColor:
                          WidgetStatePropertyAll(Colors.transparent),
                    )),
                    child: Row(
                      children: [
                        Txt(txt(e)),
                        const SizedBox(width: 5),
                        if (sortBy == nonNullLabels.indexOf(e))
                          Icon(sortDirection > 0
                              ? FluentIcons.sort_up
                              : FluentIcons.sort_down)
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 5)
              ])
          .expand((e) => e)
    ];
  }

  Acrylic _buildCommandBar() {
    return Acrylic(
      tintAlpha: 1,
      elevation: 140,
      luminosityAlpha: 0.8,
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Builder(
                builder: (context) => CommandBar(
                  primaryItems: List.generate(widget.actions.length, (index) {
                    final action = widget.actions[index];
                    return CommandBarButton(
                      onPressed: action.enabled == null ||
                              action.enabled!(checkedIds.toList())
                          ? () {
                              ActivityLogger.logAction(
                                "CommandBar Action Clicked",
                                screen: Item.toString(),
                                data: {
                                  "action": action.title,
                                  "checkedIds": checkedIds.toList()
                                },
                              );
                              if (Navigator.canPop(context)) {
                                Navigator.pop(context);
                              }
                              action.callback(checkedIds.toList());
                            }
                          : null,
                      label: action.child ??
                          (action.title != null ? Txt(action.title!) : null),
                      icon: Icon(action.icon),
                    );
                  }),
                  overflowBehavior: CommandBarOverflowBehavior.dynamicOverflow,
                ),
              ),
            ),
            if (widget.commandBarHeader != null) ...[
              const Spacer(),
              Align(
                alignment: Alignment.center,
                child: widget.commandBarHeader!,
              ),
              const Spacer(),
              const Spacer(),
            ],
            const Divider(size: 20, direction: Axis.vertical),
            DataTableSearchField(
              onChanged: setSearchTerm,
              placeholder: _searchValue,
            ),
            ...widget.furtherActions.map((a) => a)
          ],
        ),
      ),
    );
  }

  _buildNoItemsFound() {
    return Padding(
      padding: const EdgeInsets.all(15),
      child: InfoBar(
        isIconVisible: true,
        severity: InfoBarSeverity.warning,
        title: Txt(txt("noItemsFound")),
      ),
    );
  }

  Widget _buildLabelPill(String l, Item item, [Color? color]) {
    var selected = _searchValue.toLowerCase() == item.labels[l]?.toLowerCase();
    color = color ??
        colorsWithoutYellow[
            ((labels.indexOf(l) / labels.length) * colorsWithoutYellow.length)
                .floor()];
    return Padding(
      padding: const EdgeInsets.all(2),
      child: GestureDetector(
        onTap: () {
          if (selected) {
            setSearchTerm("");
          } else {
            setSearchTerm((item.labels[l] ?? "").toLowerCase());
          }
        },
        child: DataTablePill(
          selected: selected,
          color: color,
          title: item is Labwork ? "" : l,
          content: l == "Pay" && item is Patient
              ? Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(item.labels[l] ?? ""),
                    if (item.outstandingPayments != 0) ...[
                      const SizedBox(width: 4),
                      Icon(
                        item.outstandingPayments > 0
                            ? material.Icons.trending_down // red for underpaid
                            : material.Icons.trending_up, // green for overpaid
                        color: item.outstandingPayments > 0
                            ? Colors.red
                            : Colors.green,
                        size: 16,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        item.outstandingPayments.abs().toStringAsFixed(2),
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ],
                  ],
                )
              : Txt(item.labels[l] ?? ""),
        ),
      ),
    );
  }
}

class DataTablePill extends StatelessWidget {
  const DataTablePill({
    super.key,
    required this.selected,
    required this.color,
    required this.title,
    required this.content,
  });

  final bool selected;
  final Color color;
  final String title;
  final Widget content;

  @override
  Widget build(BuildContext context) {
    return Row(
      // textDirection: TextDirection.LTR,
      children: [
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                color.withValues(alpha: 0.15),
                color.withValues(alpha: 0.07),
                color.withValues(alpha: 0.15)
              ],
            ),
            border: Border.all(color: color.withValues(alpha: 0.3), width: 0.3),
            borderRadius: BorderRadius.circular(5),
          ),
          padding: const EdgeInsets.fromLTRB(10, 5, 10, 0),
          child: Wrap(
            children: [
              Txt(
                (txt(title)),
                style: TextStyle(
                    fontStyle: FontStyle.italic,
                    fontWeight: FontWeight.bold,
                    fontSize: 11.5,
                    color: color),
              ),
              const SizedBox(width: 5),
              const Divider(direction: Axis.vertical, size: 10),
              const SizedBox(width: 5),
              content,
            ],
          ),
        ),
        if (selected)
          Container(
            //height: 35,
            padding: const EdgeInsets.all(5),
            decoration: BoxDecoration(
              color: color.withValues(alpha: .15),
              borderRadius: const BorderRadius.only(
                  topRight: Radius.circular(5),
                  bottomRight: Radius.circular(5)),
            ),
            child: Icon(
              FluentIcons.check_mark,
              size: 13,
              color: color,
            ),
          ),
      ],
    );
  }
}

class DataTableSearchField extends StatefulWidget {
  final ValueChanged<String> onChanged;
  final String placeholder;

  const DataTableSearchField({
    super.key,
    required this.onChanged,
    this.placeholder = "",
  });

  @override
  State<DataTableSearchField> createState() => _DataTableSearchFieldState();
}

class _DataTableSearchFieldState extends State<DataTableSearchField> {
  final TextEditingController _controller = TextEditingController();
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 165,
      child: CupertinoTextField(
          suffix: _controller.text.isEmpty
              ? null
              : IconButton(
                  icon: const Icon(FluentIcons.clear),
                  onPressed: () {
                    ActivityLogger.logAction(
                      "Search Cleared",
                      screen: "DataTable",
                      data: {},
                    );
                    _controller.clear();
                    widget.onChanged("");
                  },
                ),
          key: WK.dataTableSearch,
          placeholder: widget.placeholder.isEmpty
              ? "🔍 ${txt("searchPlaceholder")}"
              : "${txt("filter")}: ${widget.placeholder}",
          onChanged: (value) {
            _debounce?.cancel();
            _debounce = Timer(const Duration(milliseconds: 150), () {
              widget.onChanged(value);
            });
          },
          controller: _controller,
          decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(5),
              gradient: LinearGradient(
                end: AlignmentDirectional.topStart,
                begin: AlignmentDirectional.bottomEnd,
                colors: [
                  Colors.white.withValues(alpha: 0.1),
                  Colors.white.withValues(alpha: 0.05),
                ],
              ))),
    );
  }
}
