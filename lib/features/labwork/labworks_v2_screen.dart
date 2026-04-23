// ignore_for_file: unused_element

import 'package:apexo/common_widgets/custom_date_range_picker.dart';
import 'package:apexo/common_widgets/export_file_action_button.dart';
import 'package:apexo/common_widgets/lab_bulk_update_dialog.dart';
import 'package:apexo/common_widgets/month_navigator_bar.dart';
import 'package:apexo/common_widgets/patient_history_modal_v2.dart';
import 'package:apexo/core/ui/components/app_button.dart';
import 'package:apexo/core/ui/components/app_dropdown_menu.dart';
import 'package:apexo/core/ui/components/app_search_field.dart';
import 'package:apexo/core/ui/components/top_widget_cards.dart';
import 'package:apexo/features/labwork/labwork_model.dart';
import 'package:apexo/features/labwork/labworks_store.dart';
import 'package:apexo/features/labwork/open_labwork_v2_dialog.dart';
import 'package:apexo/utils/csv_export_utility.dart';
import 'package:apexo/utils/pdf_export_utility.dart';
import 'package:apexo/widget_keys.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:intl/intl.dart';

String _lwTitleCase(String input) {
  final cleaned = input.trim();
  if (cleaned.isEmpty) return cleaned;
  return cleaned.split(RegExp(r'\s+')).map((w) {
    if (w.isEmpty) return w;
    return w[0].toUpperCase() +
        (w.length > 1 ? w.substring(1).toLowerCase() : '');
  }).join(' ');
}

class LabworksScreen extends StatefulWidget {
  const LabworksScreen({super.key});

  @override
  State<LabworksScreen> createState() => _LabworksScreenState();
}

class _LabworksScreenState extends State<LabworksScreen> {
  final TextEditingController _searchCtrl = TextEditingController();

  String _query = '';
  String _paymentFilter = 'all';
  String _rangeFilter = 'monthly';
  String _labFilter = 'all';
  DateTime _monthAnchor =
      DateTime(DateTime.now().year, DateTime.now().month, 1);
  DateTime? _fromDate;
  DateTime? _toDate;
  bool _inLabCollapsed = false;
  bool _readyCollapsed = false;
  bool _deliveredCollapsed = false;
  bool _isExportingCsv = false;
  bool _isExportingPdf = false;

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(() {
      setState(() {
        _query = _searchCtrl.text.trim().toLowerCase();
      });
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaffoldPage.scrollable(
      key: WK.labworksScreenV2,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      children: [
        Container(
          color: FluentTheme.of(context).scaffoldBackgroundColor,
          child: StreamBuilder(
            stream: labworks.observableMap.stream,
            builder: (context, _) {
              final all = labworks.present.values.toList(growable: false)
                ..sort((a, b) => b.date.compareTo(a.date));

              final filtered = _applyFilters(all);
              final inLab = filtered
                  .where((l) => !l.deliveredToDoctor)
                  .toList(growable: false);
              final ready = filtered
                  .where((l) => l.deliveredToDoctor && !l.deliveredToPatient)
                  .toList(growable: false);
              final delivered = filtered
                  .where((l) => l.deliveredToPatient)
                  .toList(growable: false);

              return Column(
                children: [
                  _buildHeader(filtered),
                  const SizedBox(height: 10),
                  _buildStatStrip(all, filtered),
                  const SizedBox(height: 10),
                  _buildSearchAndDateFilters(filtered),
                  const SizedBox(height: 10),
                  filtered.isEmpty
                      ? _EmptyState(onClear: _clearFilters)
                      : _LabworkBoard(
                          inLab: inLab,
                          ready: ready,
                          delivered: delivered,
                          inLabCollapsed: _inLabCollapsed,
                          readyCollapsed: _readyCollapsed,
                          deliveredCollapsed: _deliveredCollapsed,
                          onToggleInLab: () =>
                              setState(() => _inLabCollapsed = !_inLabCollapsed),
                          onToggleReady: () =>
                              setState(() => _readyCollapsed = !_readyCollapsed),
                          onToggleDelivered: () => setState(
                            () => _deliveredCollapsed = !_deliveredCollapsed,
                          ),
                          onOpen: (item) => openLabworkDialog(context, item),
                          onHistory: (item) {
                            final patient = item.patient;
                            if (patient == null) return;
                            showPatientHistoryDialog(
                              context: context,
                              patient: patient,
                              rows: patient.patientDetails,
                              labsOnly: true,
                            );
                          },
                        ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildHeader(List<Labwork> rows) {
    return Row(
      children: [
        const Text(
          'Labwork',
          style: TextStyle(
            color: Color(0xFF233B5F),
            fontSize: 34,
            fontWeight: FontWeight.w700,
          ),
        ),
        const Spacer(),
        ExportFileActionButton(
          type: ExportFileType.csv,
          busy: _isExportingCsv,
          onPressed: (_isExportingCsv || rows.isEmpty)
              ? null
              : () => _exportCsv(rows),
        ),
        const SizedBox(width: 8),
        ExportFileActionButton(
          type: ExportFileType.pdf,
          busy: _isExportingPdf,
          onPressed: (_isExportingPdf || rows.isEmpty)
              ? null
              : () => _exportPdf(rows),
        ),
        const SizedBox(width: 8),
        AppButton(
          onPressed: () => showLabBulkUpdateDialog(context),
          label: 'Lab Bulk Update',
          leading: const Icon(FluentIcons.edit, size: 12),
          variant: AppButtonVariant.secondary,
        ),
        const SizedBox(width: 8),
        AppButton(
          onPressed: () => openLabworkDialog(context),
          label: 'New Labwork',
          leading: const Icon(FluentIcons.add, size: 14),
        ),
      ],
    );
  }

  Future<void> _exportCsv(List<Labwork> rows) async {
    if (_isExportingCsv || rows.isEmpty) return;
    setState(() => _isExportingCsv = true);
    try {
      final csvRows = <List<String>>[
        ['Date', 'Patient', 'Lab', 'Type', 'Teeth', 'Amount', 'Paid', 'Delivered'],
        ...rows.map((item) {
          final patient = item.patient?.title.trim().isNotEmpty == true
              ? item.patient!.title
              : 'Unnamed patient';
          final delivered = item.deliveredToPatient
              ? 'Delivered'
              : (item.deliveredToDoctor ? 'Ready' : 'In Lab');
          return [
            DateFormat('yyyy-MM-dd').format(item.date),
            patient,
            item.lab.trim().isEmpty ? '-' : item.lab.trim(),
            item.typeOfWork.trim().isEmpty ? '-' : item.typeOfWork.trim(),
            item.selectedTeeth.isEmpty ? '-' : item.selectedTeeth.join(', '),
            item.price.toStringAsFixed(0),
            item.paid ? 'Yes' : 'No',
            delivered,
          ];
        }),
      ];

      await CsvExportUtility.saveCsv(
        rows: csvRows,
        fileName: 'labwork_${DateFormat('yyyyMMdd').format(DateTime.now())}.csv',
      );
    } finally {
      if (mounted) setState(() => _isExportingCsv = false);
    }
  }

  Future<void> _exportPdf(List<Labwork> rows) async {
    if (_isExportingPdf || rows.isEmpty) return;
    setState(() => _isExportingPdf = true);
    try {
      final pdfRows = <List<String>>[
        ['Date', 'Patient', 'Lab', 'Type', 'Teeth', 'Amount', 'Paid', 'Delivered'],
        ...rows.map((item) {
          final patient = item.patient?.title.trim().isNotEmpty == true
              ? item.patient!.title
              : 'Unnamed patient';
          final delivered = item.deliveredToPatient
              ? 'Delivered'
              : (item.deliveredToDoctor ? 'Ready' : 'In Lab');
          return [
            DateFormat('yyyy-MM-dd').format(item.date),
            patient,
            item.lab.trim().isEmpty ? '-' : item.lab.trim(),
            item.typeOfWork.trim().isEmpty ? '-' : item.typeOfWork.trim(),
            item.selectedTeeth.isEmpty ? '-' : item.selectedTeeth.join(', '),
            'Rs ${item.price.toStringAsFixed(0)}',
            item.paid ? 'Yes' : 'No',
            delivered,
          ];
        }),
      ];

      await PdfExportUtility.savePdf(
        title: 'Labwork Export',
        subtitle: DateFormat('dd MMM yyyy').format(DateTime.now()),
        data: pdfRows,
        fileName: 'labwork_${DateFormat('yyyyMMdd').format(DateTime.now())}.pdf',
      );
    } finally {
      if (mounted) setState(() => _isExportingPdf = false);
    }
  }

  Widget _buildStatStrip(List<Labwork> all, List<Labwork> filtered) {
    final inLab = all.where((l) => !l.deliveredToDoctor).length;
    final ready =
        all.where((l) => l.deliveredToDoctor && !l.deliveredToPatient).length;
    final filteredDues = filtered.where((l) => !l.paid).toList(growable: false);
    final filteredDueAmount =
        filteredDues.fold<double>(0, (sum, l) => sum + l.price);

    final cards = [
      (
        title: 'In Lab',
        subtitle: 'cases',
        value: '$inLab',
        color: const Color(0xFFE09C31),
        bg: const Color(0xFFFFFCF4),
        border: const Color(0xFFF5E9CC),
        icon: FluentIcons.test_beaker,
      ),
      (
        title: 'Ready',
        subtitle: 'cases',
        value: '$ready',
        color: const Color(0xFF2D7BD8),
        bg: const Color(0xFFF8FBFF),
        border: const Color(0xFFE4EEF9),
        icon: FluentIcons.check_mark,
      ),
      (
        title: 'Delivered',
        subtitle:
            '${filteredDues.length} due${filteredDues.length == 1 ? '' : 's'}',
        value: filteredDueAmount <= 0
            ? '₹0'
            : '₹${NumberFormat('#,##0').format(filteredDueAmount)}',
        color: filteredDues.isEmpty
            ? const Color(0xFF2BA58D)
            : const Color(0xFFD6455D),
        bg: const Color(0xFFFAFCFB),
        border: const Color(0xFFE8F2EC),
        icon: FluentIcons.checkbox_composite,
      ),
    ];

    return Align(
      alignment: Alignment.centerLeft,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.start,
          children: List.generate(cards.length, (i) {
            return Padding(
              padding: EdgeInsets.only(right: i == cards.length - 1 ? 0 : 8),
              child: TopWidgetSmallCard(
                title: cards[i].title,
                subtitle: cards[i].subtitle,
                value: cards[i].value,
                valueColor: cards[i].color,
                cardColor: cards[i].bg,
                borderColor: cards[i].border,
                icon: Icon(cards[i].icon, size: 14, color: cards[i].color),
                width: 200,
              ),
            );
          }),
        ),
      ),
    );
  }

  Widget _buildSearchAndDateFilters(List<Labwork> filtered) {
    final hasActiveFilter = _hasActiveFilter();

    final labs = ['all', '__unassigned__', ...labworks.allLabs.toSet()]
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

    final labItems = {
      for (final v in labs)
        v: v == 'all'
            ? 'All Labs'
            : v == '__unassigned__'
                ? 'Unassigned Lab'
                : v,
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxWidth < 1180) {
              return SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: 390,
                      child: AppSearchField(
                        hint: 'Search patient / phone / teeth / doctor',
                        controller: _searchCtrl,
                        width: 390,
                        onClear: () {
                          _searchCtrl.clear();
                          setState(() => _query = '');
                        },
                      ),
                    ),
                    if (_rangeFilter == 'monthly') ...[
                      const SizedBox(width: 12),
                      SizedBox(width: 290, child: _buildMonthNavigator()),
                    ],
                    const SizedBox(width: 12),
                    _dropFilter(
                      width: 190,
                      value: _labFilter,
                      items: labItems,
                      onChanged: (v) => setState(() => _labFilter = v),
                    ),
                    const SizedBox(width: 8),
                    _dropFilter(
                      width: 150,
                      value: _rangeFilter,
                      items: const {
                        'all': 'All Dates',
                        'monthly': 'Monthly',
                        'today': 'Today',
                        'week': 'This Week',
                        'last_month': 'Last Month',
                        'custom': 'Custom Date',
                      },
                      onChanged: (v) {
                        if (v == 'custom') {
                          _openDateRangePicker();
                          return;
                        }
                        setState(() {
                          _rangeFilter = v;
                          if (v != 'custom') {
                            _fromDate = null;
                            _toDate = null;
                          }
                        });
                      },
                    ),
                    const SizedBox(width: 8),
                    _dropFilter(
                      width: 120,
                      value: _paymentFilter,
                      items: const {
                        'all': 'All',
                        'paid': 'Paid',
                        'due': 'Due',
                        'no_due': 'No Due',
                      },
                      onChanged: (v) => setState(() => _paymentFilter = v),
                    ),
                  ],
                ),
              );
            }

            return Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  flex: 4,
                  child: AppSearchField(
                    hint: 'Search patient / phone / teeth / doctor',
                    controller: _searchCtrl,
                    width: double.infinity,
                    onClear: () {
                      _searchCtrl.clear();
                      setState(() => _query = '');
                    },
                  ),
                ),
                if (_rangeFilter == 'monthly')
                  Expanded(
                    flex: 3,
                    child: Align(
                      alignment: Alignment.center,
                      child: SizedBox(width: 290, child: _buildMonthNavigator()),
                    ),
                  ),
                Expanded(
                  flex: _rangeFilter == 'monthly' ? 4 : 7,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      _dropFilter(
                        width: 190,
                        value: _labFilter,
                        items: labItems,
                        onChanged: (v) => setState(() => _labFilter = v),
                      ),
                      const SizedBox(width: 8),
                      _dropFilter(
                        width: 150,
                        value: _rangeFilter,
                        items: const {
                          'all': 'All Dates',
                          'monthly': 'Monthly',
                          'today': 'Today',
                          'week': 'This Week',
                          'last_month': 'Last Month',
                          'custom': 'Custom Date',
                        },
                        onChanged: (v) {
                          if (v == 'custom') {
                            _openDateRangePicker();
                            return;
                          }
                          setState(() {
                            _rangeFilter = v;
                            if (v != 'custom') {
                              _fromDate = null;
                              _toDate = null;
                            }
                          });
                        },
                      ),
                      const SizedBox(width: 8),
                      _dropFilter(
                        width: 120,
                        value: _paymentFilter,
                        items: const {
                          'all': 'All',
                          'paid': 'Paid',
                          'due': 'Due',
                          'no_due': 'No Due',
                        },
                        onChanged: (v) => setState(() => _paymentFilter = v),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            if (_rangeFilter == 'custom' &&
                (_fromDate != null || _toDate != null))
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: const Color(0xFFD2E1F6)),
                ),
                child: Text(
                  '${DateFormat('dd MMM').format(_fromDate ?? _toDate!)} - ${DateFormat('dd MMM').format(_toDate ?? _fromDate!)}',
                  style: const TextStyle(
                    color: Color(0xFF2D4A70),
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              ),
            const Spacer(),
            Text(
              '${filtered.length} result${filtered.length == 1 ? '' : 's'}',
              style: const TextStyle(
                color: Color(0xFF36557C),
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
            const SizedBox(width: 10),
            HyperlinkButton(
              onPressed: hasActiveFilter ? _clearFilters : null,
              child: const Text(
                'Clear filters',
                style: TextStyle(fontSize: 12),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMonthNavigator() {
    final canGoNext = _monthAnchor.year < DateTime.now().year ||
        (_monthAnchor.year == DateTime.now().year &&
            _monthAnchor.month < DateTime.now().month);
    final monthModeActive = _rangeFilter == 'monthly';

    return Opacity(
      opacity: monthModeActive ? 1 : 0.45,
      child: IgnorePointer(
        ignoring: !monthModeActive,
        child: MonthNavigatorBar(
          selectedMonth: _monthAnchor,
          onPrevious: () {
            setState(() {
              _monthAnchor = DateTime(
                _monthAnchor.year,
                _monthAnchor.month - 1,
                1,
              );
            });
          },
          onNext: canGoNext
              ? () {
                  setState(() {
                    _monthAnchor = DateTime(
                      _monthAnchor.year,
                      _monthAnchor.month + 1,
                      1,
                    );
                  });
                }
              : null,
          onPick: (value) {
            setState(() {
              _monthAnchor = value;
            });
          },
        ),
      ),
    );
  }

  bool _hasActiveFilter() {
    return _query.isNotEmpty ||
        _paymentFilter != 'all' ||
        _rangeFilter != 'monthly' ||
        _labFilter != 'all';
  }

  Widget _buildFilterSummaryCard(List<Labwork> filtered) {
    final dues = filtered.where((l) => !l.paid).toList(growable: false);
    final paymentDue = dues.fold<double>(0, (sum, l) => sum + l.price);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF7FBFF),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFD6E2F0)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const Icon(FluentIcons.filter, size: 14, color: Color(0xFF2D4A70)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '${filtered.length} result${filtered.length == 1 ? '' : 's'} match current filters',
              style: const TextStyle(
                color: Color(0xFF36557C),
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: dues.isEmpty
                  ? const Color(0xFFEAF2FF)
                  : const Color(0xFFFDECEC),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '₹${NumberFormat('#,##0').format(paymentDue)} DUE',
                  style: TextStyle(
                    color: dues.isEmpty
                        ? const Color(0xFF1D3E67)
                        : const Color(0xFFD6455D),
                    fontWeight: FontWeight.w800,
                    fontSize: 18,
                  ),
                ),
                Text(
                  '${dues.length} due item${dues.length == 1 ? '' : 's'}',
                  style: const TextStyle(
                    color: Color(0xFF5E7396),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          HyperlinkButton(
            onPressed: _clearFilters,
            child: const Text(
              'Clear filters',
              style: TextStyle(fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMonthSelector() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF4FB),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFD6E2F0)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 24,
            height: 24,
            child: IconButton(
              icon: const Icon(FluentIcons.chevron_left, size: 10),
              onPressed: () {
                setState(() {
                  _monthAnchor = DateTime(
                    _monthAnchor.year,
                    _monthAnchor.month - 1,
                    1,
                  );
                });
              },
            ),
          ),
          const SizedBox(width: 6),
          Text(
            DateFormat('MMMM yyyy').format(_monthAnchor),
            style: const TextStyle(
              color: Color(0xFF355279),
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
          const SizedBox(width: 6),
          SizedBox(
            width: 24,
            height: 24,
            child: IconButton(
              icon: const Icon(FluentIcons.chevron_right, size: 10),
              onPressed: _monthAnchor.year < DateTime.now().year ||
                      (_monthAnchor.year == DateTime.now().year &&
                          _monthAnchor.month < DateTime.now().month)
                  ? () {
                      setState(() {
                        _monthAnchor = DateTime(
                          _monthAnchor.year,
                          _monthAnchor.month + 1,
                          1,
                        );
                      });
                    }
                  : null,
            ),
          ),
        ],
      ),
    );
  }

  Widget _dropFilter({
    required double width,
    required String value,
    required Map<String, String> items,
    required void Function(String) onChanged,
  }) {
    return AppDropdownMenu<String>(
      width: width,
      value: value,
      items: items.entries
          .map(
            (entry) => AppDropdownItem<String>(
              value: entry.key,
              label: entry.value,
            ),
          )
          .toList(growable: false),
      onChanged: onChanged,
    );
  }

  Future<void> _openDateRangePicker() async {
    final range = await showCustomDateRangePicker(
      context,
      initialStart: _fromDate,
      initialEnd: _toDate,
    );
    if (range == null || !mounted) return;
    setState(() {
      _rangeFilter = 'custom';
      _fromDate =
          DateTime(range.start.year, range.start.month, range.start.day);
      _toDate = DateTime(range.end.year, range.end.month, range.end.day);
    });
  }

  List<Labwork> _applyFilters(List<Labwork> input) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    DateTime? from;
    DateTime? to;

    if (_rangeFilter == 'today') {
      from = today;
      to = today;
    } else if (_rangeFilter == 'week') {
      final start = today.subtract(Duration(days: today.weekday - 1));
      from = start;
      to = start.add(const Duration(days: 6));
    } else if (_rangeFilter == 'last_month') {
      from = DateTime(today.year, today.month - 1, 1);
      to = DateTime(today.year, today.month, 0);
    } else if (_rangeFilter == 'monthly' || _rangeFilter == 'month') {
      from = DateTime(_monthAnchor.year, _monthAnchor.month, 1);
      to = DateTime(_monthAnchor.year, _monthAnchor.month + 1, 0);
    } else if (_rangeFilter == 'custom') {
      from = _fromDate;
      to = _toDate;
    }

    return input.where((l) {
      if (_query.isNotEmpty) {
        final haystack = [
          l.patient?.title ?? '',
          l.patient?.phone ?? '',
          l.typeOfWork,
          l.shade,
          l.lab,
          l.selectedTeeth.join(','),
          l.operators.map((d) => d.title).join(','),
        ].join(' ').toLowerCase();
        if (!haystack.contains(_query)) return false;
      }

      if (_labFilter == '__unassigned__') {
        if (l.lab.trim().isNotEmpty) return false;
      } else if (_labFilter != 'all' && l.lab.trim() != _labFilter) {
        return false;
      }

      if (_paymentFilter == 'paid' && !l.paid) return false;
      if (_paymentFilter == 'due' && (l.paid || l.price <= 0)) return false;
      if (_paymentFilter == 'no_due' && (l.paid || l.price > 0)) return false;

      if (from != null || to != null) {
        final d = DateTime(l.date.year, l.date.month, l.date.day);
        if (from != null && d.isBefore(from)) return false;
        if (to != null && d.isAfter(to)) return false;
      }

      return true;
    }).toList(growable: false);
  }

  List<(String, List<Labwork>)> _groupByDate(List<Labwork> list) {
    final grouped = <String, List<Labwork>>{};
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));

    for (final labwork in list) {
      final d =
          DateTime(labwork.date.year, labwork.date.month, labwork.date.day);
      final label = d == today
          ? 'TODAY'
          : d == yesterday
              ? 'YESTERDAY'
              : DateFormat('MMM yyyy').format(d).toUpperCase();
      grouped.putIfAbsent(label, () => []).add(labwork);
    }

    return grouped.entries.map((e) => (e.key, e.value)).toList(growable: false);
  }

  bool _isMonthSection(String title) {
    return title != 'TODAY' && title != 'YESTERDAY';
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  void _clearFilters() {
    setState(() {
      _query = '';
      _searchCtrl.text = '';
      _paymentFilter = 'all';
      _rangeFilter = 'monthly';
      _labFilter = 'all';
      _monthAnchor = DateTime(DateTime.now().year, DateTime.now().month, 1);
      _fromDate = null;
      _toDate = null;
    });
  }
}

class _LabworkBoard extends StatelessWidget {
  final List<Labwork> inLab;
  final List<Labwork> ready;
  final List<Labwork> delivered;
  final bool inLabCollapsed;
  final bool readyCollapsed;
  final bool deliveredCollapsed;
  final VoidCallback onToggleInLab;
  final VoidCallback onToggleReady;
  final VoidCallback onToggleDelivered;
  final void Function(Labwork?) onOpen;
  final void Function(Labwork) onHistory;

  const _LabworkBoard({
    required this.inLab,
    required this.ready,
    required this.delivered,
    required this.inLabCollapsed,
    required this.readyCollapsed,
    required this.deliveredCollapsed,
    required this.onToggleInLab,
    required this.onToggleReady,
    required this.onToggleDelivered,
    required this.onOpen,
    required this.onHistory,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final stacked = constraints.maxWidth < 1120;

        final inLabColumn = _LabworkBoardColumn(
          title: 'In Lab',
          count: inLab.length,
          color: const Color(0xFFE4A11B),
          items: inLab,
          collapsed: inLabCollapsed,
          onToggle: onToggleInLab,
          onOpen: onOpen,
          onHistory: onHistory,
        );
        final readyColumn = _LabworkBoardColumn(
          title: 'Ready',
          count: ready.length,
          color: const Color(0xFF2D7BD8),
          items: ready,
          collapsed: readyCollapsed,
          onToggle: onToggleReady,
          onOpen: onOpen,
          onHistory: onHistory,
        );
        final deliveredColumn = _LabworkBoardColumn(
          title: 'Delivered',
          count: delivered.length,
          color: const Color(0xFF2BA58D),
          items: delivered,
          collapsed: deliveredCollapsed,
          onToggle: onToggleDelivered,
          onOpen: onOpen,
          onHistory: onHistory,
        );

        if (stacked) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              inLabColumn,
              const SizedBox(height: 10),
              readyColumn,
              const SizedBox(height: 10),
              deliveredColumn,
            ],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _LabworkBoardColumn(
                title: 'In Lab',
                count: inLab.length,
                color: const Color(0xFFE4A11B),
                items: inLab,
                collapsed: inLabCollapsed,
                onToggle: onToggleInLab,
                onOpen: onOpen,
                onHistory: onHistory,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _LabworkBoardColumn(
                title: 'Ready',
                count: ready.length,
                color: const Color(0xFF2D7BD8),
                items: ready,
                collapsed: readyCollapsed,
                onToggle: onToggleReady,
                onOpen: onOpen,
                onHistory: onHistory,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _LabworkBoardColumn(
                title: 'Delivered',
                count: delivered.length,
                color: const Color(0xFF2BA58D),
                items: delivered,
                collapsed: deliveredCollapsed,
                onToggle: onToggleDelivered,
                onOpen: onOpen,
                onHistory: onHistory,
              ),
            ),
          ],
        );
      },
    );
  }
}

class _LabworkBoardColumn extends StatelessWidget {
  final String title;
  final int count;
  final Color color;
  final List<Labwork> items;
  final bool collapsed;
  final VoidCallback onToggle;
  final void Function(Labwork?) onOpen;
  final void Function(Labwork) onHistory;

  const _LabworkBoardColumn({
    required this.title,
    required this.count,
    required this.color,
    required this.items,
    required this.collapsed,
    required this.onToggle,
    required this.onOpen,
    required this.onHistory,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFD6E2F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(11)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    '$title ($count)',
                    style: TextStyle(
                      color: color,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                IconButton(
                  icon: Icon(
                    collapsed
                        ? FluentIcons.chevron_right
                        : FluentIcons.chevron_down,
                    size: 12,
                    color: color,
                  ),
                  onPressed: onToggle,
                ),
              ],
            ),
          ),
          if (collapsed)
            const Padding(
              padding: EdgeInsets.all(12),
              child: Text(
                'Collapsed',
                style: TextStyle(color: Color(0xFF6D84A8)),
              ),
            )
          else if (items.isEmpty)
            const Padding(
              padding: EdgeInsets.all(12),
              child: Text(
                'No labworks in this state.',
                style: TextStyle(color: Color(0xFF6D84A8)),
              ),
            )
          else
            ...items.asMap().entries.map(
                  (entry) => Column(
                    children: [
                      _LabworkRow(
                        item: entry.value,
                        onOpen: onOpen,
                        onHistory: onHistory,
                      ),
                      if (entry.key < items.length - 1)
                        Container(
                          height: 1,
                          margin: const EdgeInsets.symmetric(horizontal: 8),
                          color: const Color(0xFFDCE8F6),
                        ),
                    ],
                  ),
                ),
        ],
      ),
    );
  }
}

class _LabworkBoardCard extends StatelessWidget {
  final Labwork item;
  final void Function(Labwork?) onOpen;
  final void Function(Labwork) onHistory;

  const _LabworkBoardCard({
    required this.item,
    required this.onOpen,
    required this.onHistory,
  });

  @override
  Widget build(BuildContext context) {
    final dueColor =
        item.paid ? const Color(0xFF2A8AD9) : const Color(0xFFD54A4A);
    final dueLabel = item.paid
        ? '₹${NumberFormat('#,##0').format(item.price)} Paid'
        : '₹${NumberFormat('#,##0').format(item.price)} Due';

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FBFF),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFDCE8F6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  item.patient?.title.trim().isNotEmpty == true
                      ? _lwTitleCase(item.patient!.title)
                      : 'Unknown patient',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF1F2B40),
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
              ),
              Text(
                DateFormat('dd MMM').format(item.date),
                style: const TextStyle(
                  color: Color(0xFF5A7397),
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 3),
          Text(
            item.typeOfWork.trim().isEmpty ? 'Type: -' : item.typeOfWork,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Color(0xFF4D5C77),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            'Lab: ${item.lab.trim().isEmpty ? '-' : item.lab}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Color(0xFF6E7E99),
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            dueLabel,
            style: TextStyle(
              color: dueColor,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              AppButton(
                onPressed: item.patient == null ? null : () => onHistory(item),
                label: 'History',
                variant: AppButtonVariant.secondary,
              ),
              const SizedBox(width: 6),
              AppButton(
                onPressed: () => onOpen(item),
                label: 'Open',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DateSection extends StatelessWidget {
  final String title;
  final int count;
  final bool collapsible;
  final bool collapsed;
  final VoidCallback onToggle;
  final List<Labwork> items;
  final void Function(Labwork?) onOpen;
  final void Function(Labwork) onHistory;

  const _DateSection({
    required this.title,
    required this.count,
    required this.collapsible,
    required this.collapsed,
    required this.onToggle,
    required this.items,
    required this.onOpen,
    required this.onHistory,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: collapsible ? onToggle : null,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
              child: Row(
                children: [
                  Text(
                    '$title ($count)',
                    style: const TextStyle(
                      fontSize: 20,
                      letterSpacing: 0.5,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF4A5A74),
                    ),
                  ),
                  if (collapsible) ...[
                    const SizedBox(width: 6),
                    Icon(
                      collapsed
                          ? FluentIcons.chevron_right
                          : FluentIcons.chevron_down,
                      size: 12,
                      color: const Color(0xFF4A5A74),
                    ),
                  ],
                ],
              ),
            ),
          ),
          if (!collapsed)
            ...items.map(
              (item) => _LabworkRow(
                item: item,
                onOpen: onOpen,
                onHistory: onHistory,
              ),
            ),
        ],
      ),
    );
  }
}

class _LabworkRow extends StatelessWidget {
  final Labwork item;
  final void Function(Labwork?) onOpen;
  final void Function(Labwork) onHistory;

  const _LabworkRow({
    required this.item,
    required this.onOpen,
    required this.onHistory,
  });

  @override
  Widget build(BuildContext context) {
    final dueColor =
        item.paid ? const Color(0xFF2A8AD9) : const Color(0xFFD54A4A);
    final hasDueLabel = item.paid || item.price > 0;
    final doctorNames = item.operators
        .map((d) => d.title)
        .where((n) => n.trim().isNotEmpty)
        .join(', ');

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => onOpen(item),
      child: Container(
        padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
        color: Colors.white,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 980;

            final head = Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                SizedBox(
                  width: compact ? 70 : 76,
                  child: FittedBox(
                    alignment: Alignment.centerLeft,
                    fit: BoxFit.scaleDown,
                    child: Text(
                      DateFormat('dd MMM').format(item.date),
                      style: const TextStyle(
                        color: Color(0xFF4C5C77),
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
                Container(width: 1, height: 30, color: const Color(0xFFE7ECF5)),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        item.patient?.title.trim().isNotEmpty == true
                            ? _lwTitleCase(item.patient!.title)
                            : 'Unknown patient',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1F2B40),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        item.patient?.phone ?? '-',
                        style: const TextStyle(
                          color: Color(0xFF6E7A90),
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                      if (doctorNames.isNotEmpty)
                        Text(
                          'Dr: $doctorNames',
                          style: const TextStyle(
                            color: Color(0xFF5C7090),
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                ),
                if (hasDueLabel)
                  SizedBox(
                    width: compact ? 112 : 132,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '₹${NumberFormat('#,##0').format(item.price)}',
                          style: TextStyle(
                            color: dueColor,
                            fontSize: compact ? 16 : 18,
                            fontWeight: FontWeight.w800,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          item.paid ? 'PAID' : 'DUE',
                          style: TextStyle(
                            color: dueColor,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(width: 2),
                if (item.patient != null)
                  IconButton(
                    icon: const Icon(FluentIcons.history, size: 15),
                    onPressed: () => onHistory(item),
                  ),
              ],
            );

            final meta = Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                _Tag(
                    text:
                        item.typeOfWork.isEmpty ? 'Type N/A' : item.typeOfWork),
                _Tag(
                    text:
                        item.shade.isEmpty ? 'Shade -' : 'Shade ${item.shade}'),
                _Tag(
                  text:
                      item.noOfUnits > 0 ? '${item.noOfUnits} Unit' : '0 Unit',
                  bg: const Color(0xFFE8F2FD),
                ),
                _Tag(
                  text: item.lab.trim().isEmpty ? 'Lab -' : item.lab,
                  bg: const Color(0xFFEAF5EC),
                ),
                _Tag(
                  text: item.selectedTeeth.isEmpty
                      ? 'Teeth -'
                      : 'Teeth ${item.selectedTeeth.take(6).join(', ')}${item.selectedTeeth.length > 6 ? '...' : ''}',
                  bg: const Color(0xFFF0EDF9),
                ),
              ],
            );

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [head, const SizedBox(height: 6), meta],
            );
          },
        ),
      ),
    );
  }

  String _initials(String name) {
    final t = name.trim();
    if (t.isEmpty) return 'U';
    final parts = t
        .split(RegExp(r'\s+'))
        .where((e) => e.isNotEmpty)
        .toList(growable: false);
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts[0].substring(0, 1) + parts[1].substring(0, 1)).toUpperCase();
  }
}

class _Tag extends StatelessWidget {
  final String text;
  final Color bg;

  const _Tag({
    required this.text,
    this.bg = const Color(0xFFF1F4F9),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(7),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Color(0xFF4D5C77),
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final VoidCallback onClear;

  const _EmptyState({required this.onClear});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 420,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        decoration: BoxDecoration(
          color: const Color(0xFFF7FAFF),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFDCE6F5)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              FluentIcons.search_issue,
              size: 28,
              color: Color(0xFF5E7396),
            ),
            const SizedBox(height: 10),
            const Text(
              'No labworks match your filters',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: Color(0xFF334865),
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Try another search or clear the active filters.',
              style: TextStyle(color: Color(0xFF6E7E99)),
            ),
            const SizedBox(height: 12),
            AppButton(
              onPressed: onClear,
              label: 'Clear filters',
              variant: AppButtonVariant.secondary,
            ),
          ],
        ),
      ),
    );
  }
}
