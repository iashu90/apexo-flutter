import 'dart:async';
import 'package:apexo/common_widgets/custom_date_range_picker.dart';
import 'package:apexo/common_widgets/delete_confirmation.dart';
import 'package:apexo/common_widgets/export_buttons.dart';
import 'package:apexo/core/theme/app_theme.dart';
import 'package:apexo/core/theme/app_colors.dart';
import 'package:apexo/core/ui/components/app_button.dart';
import 'package:apexo/core/ui/components/app_dropdown_menu.dart';
import 'package:apexo/core/ui/components/app_pagination.dart';
import 'package:apexo/features/doctors/doctors_store.dart';
import 'package:apexo/features/expenses/expense_model.dart';
import 'package:apexo/features/expenses/expenses_store.dart';
import 'package:apexo/theme/material_date_picker_theme.dart';
import 'package:apexo/utils/clinic_time.dart';
import 'package:apexo/utils/csv_export_utility.dart';
import 'package:apexo/utils/pdf_export_utility.dart';
import 'package:apexo/widget_keys.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/material.dart' as material;
import 'package:intl/intl.dart';

class ExpensesScreen extends StatefulWidget {
  const ExpensesScreen({super.key});

  @override
  State<ExpensesScreen> createState() => _ExpensesScreenState();
}

class _ExpensesScreenState extends State<ExpensesScreen> {
  final TextEditingController _searchCtrl = TextEditingController();

  String _query = '';
  String _categoryFilter = 'all';
  String _paymentFilter = 'all';
  String _statusFilter = 'all';
  String _rangeFilter = 'month';
  String _quickFilter = 'this_month';
  String _doctorIdFilter = 'all';
  String _amountFilter = 'all';
  DateTime _monthAnchor =
      DateTime(DateTime.now().year, DateTime.now().month, 1);
  DateTime? _fromDate;
  DateTime? _toDate;
  int _page = 1;
  String _sortBy = 'date';
  bool _sortAscending = false;
  bool _isExportingCsv = false;
  bool _isExportingPdf = false;
  bool _recurringOnly = false;
  bool _recurringSyncInProgress = false;

  static const int _pageSize = 10;
  static const List<String> _defaultExpenseCategories = [
    'Consultant',
    'Labwork',
    'Doctor 1',
    'Doctor 2',
    'Receptionist',
    'Sister 1',
    'Sister 2',
    'Maid',
    'Electricity',
    'BioMedical Waste',
    'Medication',
  ];

  List<String> _orderedExpenseCategories() {
    final dedup = <String>{};
    final ordered = <String>[];

    for (final category in _defaultExpenseCategories) {
      final normalized = category.trim();
      if (normalized.isEmpty) continue;
      if (dedup.add(normalized.toLowerCase())) {
        ordered.add(normalized);
      }
    }

    for (final category in expenses.allItems) {
      final normalized = category.trim();
      if (normalized.isEmpty) continue;
      if (dedup.add(normalized.toLowerCase())) {
        ordered.add(normalized);
      }
    }

    return ordered;
  }

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(() {
      setState(() {
        _query = _searchCtrl.text.trim().toLowerCase();
        _page = 1;
      });
    });
    unawaited(Future<void>.microtask(_ensureRecurringEntriesUpToDate));
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  bool _isRecurringExpense(Expense expense) {
    return expense.tags
        .any((tag) => tag.toLowerCase().startsWith('recurring:'));
  }

  bool _isRecurringMonthly(Expense expense) {
    return expense.tags
        .any((tag) => tag.trim().toLowerCase() == 'recurring:monthly');
  }

  bool _isGeneratedRecurring(Expense expense) {
    return expense.tags
        .any((tag) => tag.trim().toLowerCase() == 'recurring:generated');
  }

  String? _tagValueByPrefix(Expense expense, String prefix) {
    final p = prefix.toLowerCase();
    for (final tag in expense.tags) {
      final lower = tag.toLowerCase();
      if (lower.startsWith(p)) {
        return tag.substring(prefix.length).trim();
      }
    }
    return null;
  }

  Future<void> _ensureRecurringEntriesUpToDate() async {
    if (_recurringSyncInProgress) return;
    _recurringSyncInProgress = true;
    try {
      final now = DateTime.now();
      final thisMonth = DateTime(now.year, now.month, 1);
      final roots = expenses.present.values
          .where((expense) =>
              _isRecurringMonthly(expense) && !_isGeneratedRecurring(expense))
          .toList(growable: false)
        ..sort((a, b) => a.date.compareTo(b.date));

      for (final root in roots) {
        var seriesId = _tagValueByPrefix(root, 'recurring:series:');
        if (seriesId == null || seriesId.isEmpty) {
          seriesId = root.id;
          root.tags = [
            ...root.tags.where((tag) =>
                !tag.toLowerCase().startsWith('recurring:series:')),
            'recurring:series:$seriesId',
          ];
          expenses.set(root);
        }

        var cursor = DateTime(root.date.year, root.date.month, 1);
        while (!cursor.isAfter(thisMonth)) {
          final lastDay = DateTime(cursor.year, cursor.month + 1, 0).day;
          final day = root.date.day > lastDay ? lastDay : root.date.day;
          final dueDate = DateTime(cursor.year, cursor.month, day);

          if (!dueDate.isAfter(now)) {
            final exists = expenses.present.values.any((expense) {
              final sameSeries = expense.tags
                  .any((tag) => tag.toLowerCase() == 'recurring:series:$seriesId');
              if (!sameSeries) return false;
              return expense.date.year == dueDate.year &&
                  expense.date.month == dueDate.month;
            });

            if (!exists) {
              final generated = Expense.fromJson({});
              generated.date = dueDate;
              generated.amount = root.amount;
              generated.paid = root.paid;
              generated.issuer = root.issuer;
              generated.phoneNumber = root.phoneNumber;
              generated.note = root.note;
              generated.items = root.items.toList(growable: false);
              generated.operatorsIDs = root.operatorsIDs.toList(growable: false);

              final cleanedTags = root.tags
                  .where((tag) {
                    final lower = tag.toLowerCase();
                    return lower != 'recurring:generated' &&
                        !lower.startsWith('recurring:source:') &&
                        !lower.startsWith('recurring:series:');
                  })
                  .toList(growable: false);
              generated.tags = [
                ...cleanedTags,
                'recurring:monthly',
                'recurring:generated',
                'recurring:series:$seriesId',
                'recurring:source:${root.id}',
              ];
              expenses.set(generated);
            }
          }

          cursor = DateTime(cursor.year, cursor.month + 1, 1);
        }
      }
    } finally {
      _recurringSyncInProgress = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
        color: AppTheme.light.primaryColor,
        child: ScaffoldPage(
          key: WK.expensesScreen,
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
          content: StreamBuilder(
            stream: expenses.observableMap.stream,
            builder: (context, _) {
              final rows = expenses.present.values.toList(growable: false)
                ..sort((a, b) => b.date.compareTo(a.date));

              final filtered = _applyFilters(rows);
              final sorted = _sortRows(filtered);
              final cards = _summaryCards(sorted);

              final totalPages = sorted.isEmpty
                  ? 1
                  : ((sorted.length + _pageSize - 1) / _pageSize).ceil();
              if (_page > totalPages) {
                _page = totalPages;
              }
              var start = (sorted.isEmpty ? 0 : (_page - 1) * _pageSize)
                  .clamp(0, sorted.length);
              var end = (start + _pageSize).clamp(0, sorted.length);
              if (sorted.isNotEmpty && start >= end) {
                _page = 1;
                start = 0;
                end = _pageSize.clamp(0, sorted.length);
              }
              final paged = sorted.sublist(start, end);

              return Column(
                children: [
                  _buildHeader(filtered),
                  const SizedBox(height: 10),
                  // Summary strip + overview side by side (matching screenshot)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 65,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildSummaryStrip(cards),
                            const SizedBox(height: 10),
                            _buildFilters(rows),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        flex: 35,
                        child: _buildExpenseOverviewCard(sorted),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),
                  Expanded(
                    child: _buildTableCard(
                      rows: paged,
                      total: sorted.length,
                      start: sorted.isEmpty ? 0 : start + 1,
                      end: end,
                      page: _page,
                      totalPages: totalPages,
                    ),
                  ),
                ],
              );
            },
          ),
        ));
  }

  Widget _buildHeader(List<Expense> rows) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        children: [
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Expenses',
                  style: TextStyle(
                    color: AppColors.blue7503,
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Track and manage your clinic expenses',
                  style: TextStyle(
                    color: AppColors.blue6006,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          AppButton(
            onPressed: () => _openExpenseModal(),
            label: 'New Expense',
            leading: const Icon(FluentIcons.add, size: 14),
          ),
          const SizedBox(width: 8),
          AppButton(
            onPressed: _openRecurringExpenseDialog,
            label: 'Recurring Expenses',
            variant: AppButtonVariant.secondary,
            leading: const Icon(FluentIcons.repeat_all, size: 13),
          ),
          const SizedBox(width: 8),
          ExportButtons(
            csvBusy: _isExportingCsv,
            pdfBusy: _isExportingPdf,
            onCsv: (_isExportingCsv || rows.isEmpty)
                ? null
                : () => _exportCsv(rows),
            onPdf: (_isExportingPdf || rows.isEmpty)
                ? null
                : () => _exportPdf(rows),
          ),
        ],
      ),
    );
  }

  Future<void> _exportCsv(List<Expense> rows) async {
    if (_isExportingCsv || rows.isEmpty) return;
    setState(() => _isExportingCsv = true);
    try {
      final csvRows = <List<String>>[
        ['Date', 'Category', 'Amount', 'Paid', 'Doctor', 'Note'],
        ...rows.map((expense) {
          final category =
              expense.items.isEmpty ? '-' : expense.items.join(', ');
          final doctor = expense.operators.isEmpty
              ? '-'
              : expense.operators.map((d) => d.title).join(', ');
          return [
            formatClinicDate(expense.date, pattern: 'yyyy-MM-dd'),
            category,
            expense.amount.toStringAsFixed(0),
            expense.paid ? 'Yes' : 'No',
            doctor,
            expense.note.trim().isEmpty ? '-' : expense.note.trim(),
          ];
        }),
      ];

      await CsvExportUtility.saveCsv(
        rows: csvRows,
        fileName:
            'expenses_${DateFormat('yyyyMMdd').format(DateTime.now())}.csv',
      );
    } finally {
      if (mounted) setState(() => _isExportingCsv = false);
    }
  }

  Future<void> _exportPdf(List<Expense> rows) async {
    if (_isExportingPdf || rows.isEmpty) return;
    setState(() => _isExportingPdf = true);
    try {
      final pdfRows = <List<String>>[
        ['Date', 'Category', 'Amount', 'Paid', 'Doctor', 'Note'],
        ...rows.map((expense) {
          final category =
              expense.items.isEmpty ? '-' : expense.items.join(', ');
          final doctor = expense.operators.isEmpty
              ? '-'
              : expense.operators.map((d) => d.title).join(', ');
          return [
            formatClinicDate(expense.date, pattern: 'yyyy-MM-dd'),
            category,
            'Rs ${expense.amount.toStringAsFixed(0)}',
            expense.paid ? 'Yes' : 'No',
            doctor,
            expense.note.trim().isEmpty ? '-' : expense.note.trim(),
          ];
        }),
      ];

      await PdfExportUtility.savePdf(
        title: 'Expenses Export',
        subtitle: formatClinicDate(DateTime.now(), pattern: 'dd MMM yyyy'),
        data: pdfRows,
        fileName:
            'expenses_${DateFormat('yyyyMMdd').format(DateTime.now())}.pdf',
      );
    } finally {
      if (mounted) setState(() => _isExportingPdf = false);
    }
  }

  Widget _buildExpenseOverviewCard(List<Expense> rows) {
    final total = rows.fold<double>(0, (sum, e) => sum + e.amount);
    final byCategory = <String, double>{};
    for (final expense in rows) {
      final key = expense.items.isEmpty ? 'Others' : expense.items.first;
      byCategory[key] = (byCategory[key] ?? 0) + expense.amount;
    }
    final sorted = byCategory.entries.toList(growable: true)
      ..sort((a, b) => b.value.compareTo(a.value));

    const pieColors = [
      AppColors.brandBlue,
      AppColors.dangerRose,
      AppColors.amber5002,
      AppColors.green5503,
      AppColors.violet600,
      AppColors.green5002,
      AppColors.rose550,
    ];

    // Group smaller items into "Others"
    final List<MapEntry<String, double>> display = [];
    double othersTotal = 0.0;
    for (var i = 0; i < sorted.length; i++) {
      if (i < 4) {
        display.add(sorted[i]);
      } else {
        othersTotal += sorted[i].value;
      }
    }
    if (othersTotal > 0) {
      display.add(MapEntry('Others', othersTotal));
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderSoft),
        boxShadow: const [
          BoxShadow(
              color: AppColors.overlay15, blurRadius: 10, offset: Offset(0, 3)),
        ],
      ),
      child: total <= 0
          ? const Row(
              children: [
                Icon(FluentIcons.pie_single,
                    size: 16, color: AppColors.blue6002),
                SizedBox(width: 8),
                Text(
                  'Expense Overview',
                  style: TextStyle(
                      color: AppColors.blue7507, fontWeight: FontWeight.w800),
                ),
                SizedBox(width: 12),
                Text('No records',
                    style: TextStyle(
                        color: AppColors.violet450, fontWeight: FontWeight.w600)),
              ],
            )
          : Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Left: legend
                Expanded(
                  flex: 3,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(FluentIcons.pie_single,
                              size: 16, color: AppColors.blue6002),
                          const SizedBox(width: 8),
                          const Text(
                            'Expense Overview',
                            style: TextStyle(
                                color: AppColors.blue7507,
                                fontWeight: FontWeight.w800,
                                fontSize: 14),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            'Total ₹${NumberFormat('#,##0').format(total)}',
                            style: const TextStyle(
                                color: AppColors.textBlueMuted,
                                fontWeight: FontWeight.w700,
                                fontSize: 12),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      ...display.asMap().entries.map((entry) {
                        final idx = entry.key;
                        final item = entry.value;
                        final pct =
                            total > 0 ? (item.value / total * 100) : 0.0;
                        final color = pieColors[idx % pieColors.length];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Row(
                            children: [
                              Container(
                                width: 12,
                                height: 12,
                                decoration: BoxDecoration(
                                    color: color, shape: BoxShape.circle),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  item.key,
                                  style: const TextStyle(
                                      color: AppColors.blue75010,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Text(
                                '${pct.toStringAsFixed(0)}%',
                                style: TextStyle(
                                    color: color,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 13),
                              ),
                            ],
                          ),
                        );
                      }),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                // Right: pie chart
                SizedBox(
                  width: 130,
                  height: 130,
                  child: PieChart(
                    PieChartData(
                      sectionsSpace: 2,
                      centerSpaceRadius: 36,
                      sections: display.asMap().entries.map((entry) {
                        final idx = entry.key;
                        final item = entry.value;
                        final pct =
                            total > 0 ? (item.value / total * 100) : 0.0;
                        final color = pieColors[idx % pieColors.length];
                        return PieChartSectionData(
                          value: item.value,
                          color: color,
                          title: '${pct.toStringAsFixed(0)}%',
                          radius: 40,
                          titleStyle: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                          showTitle: pct >= 8,
                        );
                      }).toList(growable: false),
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildSummaryStrip(List<_ExpenseSummaryCardData> cards) {
    final accents = [
      AppColors.brandBlue,
      AppColors.dangerRose,
      AppColors.amber5002,
      AppColors.green5503,
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final useWrap = constraints.maxWidth < 920;
        final children = List.generate(cards.length, (i) {
          final data = cards[i];
          return Container(
            width: useWrap ? double.infinity : (constraints.maxWidth - 24) / 4,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: Colors.white,
              border: Border.all(color: AppColors.borderBlueSoft),
              boxShadow: const [
                BoxShadow(
                  color: AppColors.overlay18,
                  blurRadius: 12,
                  offset: Offset(0, 3),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 6,
                  height: 44,
                  decoration: BoxDecoration(
                    color: accents[i % accents.length],
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        data.title,
                        style: const TextStyle(
                          color: AppColors.textBlueMuted,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.3,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '₹${NumberFormat('#,##0').format(data.value)}',
                        style: TextStyle(
                          color: data.valueColor,
                          fontSize: 21,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        });

        if (useWrap) {
          return Wrap(spacing: 8, runSpacing: 8, children: children);
        }

        return Row(
          children: List.generate(
            children.length,
            (i) => Expanded(
              child: Padding(
                padding:
                    EdgeInsets.only(right: i == children.length - 1 ? 0 : 8),
                child: children[i],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildFilters(List<Expense> allRows) {
    final categories = ['all', ..._orderedExpenseCategories()];
    final doctorItems = [
      const AppDropdownItem<String>(value: 'all', label: 'Doctor'),
      ...doctors.present.values.toList(growable: false).map((d) =>
          AppDropdownItem<String>(
              value: d.id,
              label: d.title.trim().isEmpty ? 'Unnamed' : d.title)),
    ];

    // Date range label for second row
    String dateLabel;
    if (_rangeFilter == 'month') {
      dateLabel =
          '${DateFormat('01 MMM').format(_monthAnchor)} – ${DateFormat('dd MMM yyyy').format(DateTime(_monthAnchor.year, _monthAnchor.month + 1, 0))}';
    } else if (_rangeFilter == 'custom' &&
        (_fromDate != null || _toDate != null)) {
      final a = _fromDate ?? _toDate!;
      final b = _toDate ?? _fromDate!;
      dateLabel =
          '${DateFormat('dd MMM').format(a)} – ${DateFormat('dd MMM yyyy').format(b)}';
    } else if (_rangeFilter == 'today') {
      dateLabel = 'Today';
    } else if (_rangeFilter == 'week') {
      dateLabel = 'This Week';
    } else if (_rangeFilter == 'last_month') {
      dateLabel = 'Last Month';
    } else {
      dateLabel = 'All Dates';
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 9, 12, 9),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderBlueSoft),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Row 1: fixed quick-filter chips
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _buildTimeChip(label: 'This Week', value: 'this_week'),
              _buildTimeChip(label: 'This Month', value: 'this_month'),
              _buildTimeChip(label: 'Pending Payments', value: 'pending'),
              _buildTimeChip(label: 'Lab Expenses', value: 'lab'),
              _buildTimeChip(label: 'Salaries', value: 'salaries'),
              _buildTimeChip(label: 'High Value > ₹10k', value: 'high_value'),
            ],
          ),
          const SizedBox(height: 8),
          // Row 2: dropdowns + date range + clear all
          Wrap(
            spacing: 6,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              AppDropdownMenu<String>(
                width: 160,
                value: _categoryFilter,
                items: categories
                    .map((v) => AppDropdownItem<String>(
                        value: v, label: v == 'all' ? 'Category' : v))
                    .toList(growable: false),
                onChanged: (v) => setState(() {
                  _categoryFilter = v;
                  _page = 1;
                }),
              ),
              AppDropdownMenu<String>(
                width: 150,
                value: _paymentFilter,
                items: const [
                  AppDropdownItem<String>(value: 'all', label: 'Payment Mode'),
                  AppDropdownItem<String>(value: 'upi', label: 'UPI'),
                  AppDropdownItem<String>(value: 'cash', label: 'Cash'),
                ],
                onChanged: (v) => setState(() {
                  _paymentFilter = v;
                  _page = 1;
                }),
              ),
              AppDropdownMenu<String>(
                width: 160,
                value: _doctorIdFilter,
                items: doctorItems,
                onChanged: (v) => setState(() {
                  _doctorIdFilter = v;
                  _page = 1;
                }),
              ),
              AppDropdownMenu<String>(
                width: 150,
                value: _amountFilter,
                items: const [
                  AppDropdownItem<String>(value: 'all', label: 'Amount'),
                  AppDropdownItem<String>(value: 'lt1000', label: '< ₹1,000'),
                  AppDropdownItem<String>(value: '1k5k', label: '₹1k – ₹5k'),
                  AppDropdownItem<String>(value: 'gt5000', label: '> ₹5,000'),
                  AppDropdownItem<String>(value: 'gt10000', label: '> ₹10,000'),
                ],
                onChanged: (v) => setState(() {
                  _amountFilter = v;
                  _page = 1;
                }),
              ),
              // Date range button
              GestureDetector(
                onTap: () async {
                  final options = [
                    'All Dates',
                    'Today',
                    'This Week',
                    'This Month',
                    'Last Month',
                    'Custom Range'
                  ];
                  await showDialog<void>(
                    context: context,
                    builder: (ctx) => ContentDialog(
                      title: const Text('Select Date Range'),
                      content: SizedBox(
                        width: 300,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: options.map((opt) {
                            return ListTile(
                              title: Text(opt),
                              onPressed: () async {
                                Navigator.pop(ctx);
                                final map = {
                                  'All Dates': 'all',
                                  'Today': 'today',
                                  'This Week': 'week',
                                  'This Month': 'month',
                                  'Last Month': 'last_month',
                                  'Custom Range': 'custom'
                                };
                                final val = map[opt]!;
                                if (val == 'custom') {
                                  await _pickCustomRange();
                                  return;
                                }
                                setState(() {
                                  _rangeFilter = val;
                                  if (val == 'month')
                                    _monthAnchor = DateTime(DateTime.now().year,
                                        DateTime.now().month, 1);
                                  _fromDate = null;
                                  _toDate = null;
                                  _page = 1;
                                });
                              },
                            );
                          }).toList(growable: false),
                        ),
                      ),
                    ),
                  );
                },
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.slate1006,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.violet150),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(FluentIcons.calendar,
                          size: 13, color: AppColors.blue6003),
                      const SizedBox(width: 6),
                      Text(dateLabel,
                          style: const TextStyle(
                              color: AppColors.blue7007,
                              fontWeight: FontWeight.w700,
                              fontSize: 12)),
                      const SizedBox(width: 4),
                      const Icon(FluentIcons.chevron_down,
                          size: 10, color: AppColors.blue6003),
                    ],
                  ),
                ),
              ),
              if (_rangeFilter == 'month') _buildMonthSelector(),
              // Clear All
              GestureDetector(
                onTap: () => setState(() {
                  _query = '';
                  _searchCtrl.text = '';
                  _categoryFilter = 'all';
                  _paymentFilter = 'all';
                  _doctorIdFilter = 'all';
                  _amountFilter = 'all';
                  _statusFilter = 'all';
                  _recurringOnly = false;
                  _quickFilter = 'this_month';
                  _rangeFilter = 'month';
                  _monthAnchor =
                      DateTime(DateTime.now().year, DateTime.now().month, 1);
                  _fromDate = null;
                  _toDate = null;
                  _sortBy = 'date';
                  _sortAscending = false;
                  _page = 1;
                }),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.violet150),
                  ),
                  child: const Text('Clear All',
                      style: TextStyle(
                          color: AppColors.blue6502,
                          fontWeight: FontWeight.w700,
                          fontSize: 12)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTimeChip({required String label, required String value}) {
    final selected = _quickFilter == value;
    return GestureDetector(
      onTap: () => setState(() {
        _quickFilter = value;
        _page = 1;
      }),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? AppColors.brandBlue : AppColors.slate10010,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
              color:
                  selected ? AppColors.brandBlue : AppColors.violet15011),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : AppColors.textBlueStrong,
            fontWeight: FontWeight.w700,
            fontSize: 11.5,
          ),
        ),
      ),
    );
  }

  Widget _buildMonthSelector() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.slate1004,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.violet1506),
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
                  _page = 1;
                });
              },
            ),
          ),
          const SizedBox(width: 6),
          Text(
            formatClinicDate(_monthAnchor, pattern: 'MMMM yyyy'),
            style: const TextStyle(
              color: AppColors.textBlueStrong,
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
                        _page = 1;
                      });
                    }
                  : null,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTableCard({
    required List<Expense> rows,
    required int total,
    required int start,
    required int end,
    required int page,
    required int totalPages,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderSoft),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: const BoxDecoration(
              color: AppColors.slate10012,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: Row(
              children: [ 
                const Text(
                  'Expense Ledger',
                  style: TextStyle(
                    color: AppColors.blue7509,
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                  ),
                ),
                const Spacer(),
                _SortableHead(
                  label: 'Date',
                  selected: _sortBy == 'date',
                  ascending: _sortAscending,
                  onTap: () => _onSort('date'),
                ),
                const SizedBox(width: 8),
                _SortableHead(
                  label: 'Amount',
                  selected: _sortBy == 'amount',
                  ascending: _sortAscending,
                  onTap: () => _onSort('amount'),
                ),
                const SizedBox(width: 8),
                _SortableHead(
                  label: 'Category',
                  selected: _sortBy == 'category',
                  ascending: _sortAscending,
                  onTap: () => _onSort('category'),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: const BoxDecoration(
              border: Border(
                bottom: BorderSide(color: AppColors.slate1002),
              ),
            ),
            child: const Row(
              children: [
                Expanded(flex: 12, child: _LedgerHeadCell('Date')),
                Expanded(flex: 26, child: _LedgerHeadCell('Expense')),
                Expanded(flex: 12, child: _LedgerHeadCell('Category')),
                Expanded(flex: 12, child: _LedgerHeadCell('Doctor')),
                Expanded(flex: 10, child: _LedgerHeadCell('Mode')),
                Expanded(
                  flex: 10,
                  child: _LedgerHeadCell('Amount', align: TextAlign.end),
                ),
                Expanded(
                  flex: 10,
                  child: _LedgerHeadCell('To Pay', align: TextAlign.end),
                ),
                Expanded(flex: 10, child: _LedgerHeadCell('Status')),
                Expanded(
                  flex: 8,
                  child: _LedgerHeadCell('Actions', align: TextAlign.center),
                ),
              ],
            ),
          ),
          Expanded(
            child: rows.isEmpty
                ? const Center(
                    child: Text(
                      'No expenses found for selected filters.',
                      style: TextStyle(color: AppColors.blue5003),
                    ),
                  )
                : _buildLedgerTableRows(rows),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: AppColors.slate1002)),
            ),
            child: Row(
              children: [
                Text(
                  total == 0
                      ? 'Showing 0 of 0'
                      : 'Showing $start-$end of $total',
                  style: const TextStyle(color: AppColors.textBlueMuted),
                ),
                const Spacer(),
                SizedBox(
                  width: 340,
                  child: AppPagination(
                    currentPage: page,
                    totalPages: totalPages,
                    onPageChanged: (newPage) => setState(() {
                      final safePage = newPage.clamp(1, totalPages);
                      final hasRows = ((safePage - 1) * _pageSize) < total;
                      _page = hasRows ? safePage : 1;
                    }),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLedgerTableRows(List<Expense> rows) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      itemCount: rows.length,
      itemBuilder: (context, index) {
        final expense = rows[index];
        final category = expense.items.isEmpty ? '-' : expense.items.first;
        final expenseLabel = expense.note.trim().isEmpty
            ? category
            : expense.note.trim();
        final paymentMode = _paymentMode(expense);
        final toPay = expense.paid ? 0.0 : expense.amount;
        final status = _expenseStatus(expense);
        final recurring = _isRecurringExpense(expense);

        return GestureDetector(
          onTap: () => unawaited(_openExpenseModal(expense)),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
            decoration: const BoxDecoration(
              border: Border(
                bottom: BorderSide(color: AppColors.slate1002),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  flex: 12,
                  child: Text(
                    formatClinicDate(expense.date, pattern: 'dd MMM yyyy'),
                    style: const TextStyle(
                      color: AppColors.blue7003,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                ),
                Expanded(
                  flex: 26,
                  child: Row(
                    children: [
                      if (recurring)
                        const Padding(
                          padding: EdgeInsets.only(right: 6),
                          child: Tooltip(
                            message: 'Recurring monthly expense',
                            child: Icon(
                              FluentIcons.repeat_all,
                              size: 12,
                              color: AppColors.violet550,
                            ),
                          ),
                        ),
                      Expanded(
                        child: Text(
                          expenseLabel,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppColors.blue7506,
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  flex: 12,
                  child: Text(
                    category,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.textBlueMuted,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Expanded(
                  flex: 12,
                  child: Text(
                    _doctorDetails(expense),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.blue6004,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                ),
                Expanded(
                  flex: 10,
                  child: _ExpenseModeBadge(mode: paymentMode),
                ),
                Expanded(
                  flex: 10,
                  child: Text(
                    '₹${NumberFormat('#,##0').format(expense.amount)}',
                    textAlign: TextAlign.end,
                    style: const TextStyle(
                      color: AppColors.blue750,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                ),
                Expanded(
                  flex: 10,
                  child: Text(
                    toPay <= 0 ? '-' : '₹${NumberFormat('#,##0').format(toPay)}',
                    textAlign: TextAlign.end,
                    style: TextStyle(
                      color: toPay <= 0 ? AppColors.textBlueMuted : AppColors.amber5002,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                ),
                Expanded(flex: 10, child: _ExpenseStatusPill(status: status)),
                Expanded(
                  flex: 8,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _ExpenseActionIconButton(
                        icon: FluentIcons.edit,
                        color: AppColors.violet550,
                        hoverColor: AppColors.slate1008,
                        onTap: () => unawaited(_openExpenseModal(expense)),
                      ),
                      const SizedBox(width: 6),
                      _ExpenseActionIconButton(
                        icon: FluentIcons.delete,
                        color: AppColors.dangerRose,
                        hoverColor: AppColors.amber100,
                        onTap: () => _deleteExpense(expense),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  _ExpenseStatus _expenseStatus(Expense expense) {
    if (expense.paid) return _ExpenseStatus.paid;
    if (expense.amount >= 10000) return _ExpenseStatus.highValue;
    return _ExpenseStatus.toPay;
  }

  // ignore: unused_element
  Widget _buildDetailsPane(Expense? selected, {VoidCallback? onClose}) {
    final category =
        selected == null || selected.items.isEmpty ? '-' : selected.items.first;
    final paymentMode = selected == null ? '-' : _paymentMode(selected);
    final outstanding = selected == null ? 0 : _doctorOutstanding(selected);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderSoft),
      ),
      padding: const EdgeInsets.all(14),
      child: selected == null
          ? const Center(
              child: Text(
                'Select an expense to inspect details.',
                style: TextStyle(
                  color: AppColors.blue5003,
                  fontWeight: FontWeight.w600,
                ),
              ),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Expense Details',
                  style: TextStyle(
                    color: AppColors.blue7504,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (onClose != null)
                  Align(
                    alignment: Alignment.topRight,
                    child: IconButton(
                      icon: const Icon(FluentIcons.chrome_close, size: 10),
                      onPressed: onClose,
                    ),
                  ),
                const SizedBox(height: 10),
                _DetailRow(
                    label: 'Date',
                    value: formatClinicDate(selected.date,
                        pattern: 'dd MMM yyyy')),
                _DetailRow(label: 'Category', value: category),
                _DetailRow(
                    label: 'Amount',
                    value: '₹${NumberFormat('#,##0').format(selected.amount)}'),
                _DetailRow(label: 'Payment', value: paymentMode),
                _DetailRow(label: 'Doctor', value: _doctorDetails(selected)),
                const SizedBox(height: 10),
                const Text(
                  'Note',
                  style: TextStyle(
                    color: AppColors.blue6004,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.slate50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.violet100),
                  ),
                  child: Text(
                    selected.note.trim().isEmpty
                        ? 'No note provided.'
                        : selected.note.trim(),
                    style: const TextStyle(
                      color: AppColors.textBlueStrong,
                      height: 1.35,
                    ),
                  ),
                ),
                if (outstanding > 0) ...[
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.amber1004,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.amber200),
                    ),
                    child: Text(
                      'Consultant outstanding: ₹${NumberFormat('#,##0').format(outstanding)}',
                      style: const TextStyle(
                        color: AppColors.rose6002,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
                const Spacer(),
                Row(
                  children: [
                    Expanded(
                      child: AppButton(
                        label: 'Edit',
                        variant: AppButtonVariant.secondary,
                        onPressed: () async {
                          onClose?.call();
                          await _openExpenseModal(selected);
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: AppButton(
                        label: 'Delete',
                        onPressed: () async {
                          onClose?.call();
                          await _deleteExpense(selected);
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
    );
  }

  void _onSort(String key) {
    setState(() {
      if (_sortBy == key) {
        _sortAscending = !_sortAscending;
      } else {
        _sortBy = key;
        _sortAscending = true;
      }
      _page = 1;
    });
  }

  List<Expense> _sortRows(List<Expense> rows) {
    final sorted = List<Expense>.from(rows);
    sorted.sort((a, b) {
      late int compare;
      switch (_sortBy) {
        case 'category':
          compare = (a.items.isEmpty ? '' : a.items.first)
              .toLowerCase()
              .compareTo((b.items.isEmpty ? '' : b.items.first).toLowerCase());
          break;
        case 'doctor':
          compare = _doctorDetails(a)
              .toLowerCase()
              .compareTo(_doctorDetails(b).toLowerCase());
          break;
        case 'note':
          compare = a.note.toLowerCase().compareTo(b.note.toLowerCase());
          break;
        case 'amount':
          compare = a.amount.compareTo(b.amount);
          break;
        case 'mode':
          compare = _paymentMode(a).compareTo(_paymentMode(b));
          break;
        case 'date':
        default:
          compare = a.date.compareTo(b.date);
          break;
      }
      return _sortAscending ? compare : -compare;
    });
    return sorted;
  }

  Future<void> _pickCustomRange() async {
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
      _page = 1;
    });
  }

  List<Expense> _applyFilters(List<Expense> input) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    // Quick filter date range
    DateTime? quickFrom;
    DateTime? quickTo;
    String? quickCategoryKey;
    bool? quickPendingOnly;
    bool? quickHighValue;
    switch (_quickFilter) {
      case 'this_week':
        final monday = today.subtract(Duration(days: today.weekday - 1));
        quickFrom = monday;
        quickTo = monday.add(const Duration(days: 6));
        break;
      case 'this_month':
        quickFrom = DateTime(today.year, today.month, 1);
        quickTo = DateTime(today.year, today.month + 1, 0);
        break;
      case 'pending':
        quickPendingOnly = true;
        break;
      case 'lab':
        quickCategoryKey = 'labwork';
        break;
      case 'salaries':
        quickCategoryKey = 'salaries';
        break;
      case 'high_value':
        quickHighValue = true;
        break;
    }

    DateTime? from;
    DateTime? to;
    if (_rangeFilter == 'today') {
      from = today;
      to = today;
    } else if (_rangeFilter == 'week') {
      final monday = today.subtract(Duration(days: today.weekday - 1));
      final sunday = monday.add(const Duration(days: 6));
      from = monday;
      to = sunday;
    } else if (_rangeFilter == 'month') {
      from = DateTime(_monthAnchor.year, _monthAnchor.month, 1);
      to = DateTime(_monthAnchor.year, _monthAnchor.month + 1, 0);
    } else if (_rangeFilter == 'last_month') {
      final prev = DateTime(today.year, today.month - 1, 1);
      from = prev;
      to = DateTime(prev.year, prev.month + 1, 0);
    } else if (_rangeFilter == 'custom') {
      from = _fromDate;
      to = _toDate;
    }

    return input.where((e) {
      // Quick filter
      if (quickFrom != null || quickTo != null) {
        final d = DateTime(e.date.year, e.date.month, e.date.day);
        if (quickFrom != null && d.isBefore(quickFrom)) return false;
        if (quickTo != null && d.isAfter(quickTo)) return false;
      }
      if (quickPendingOnly == true && e.paid) return false;
      if (quickCategoryKey != null &&
          !e.items.any((item) => item.trim().toLowerCase() == quickCategoryKey))
        return false;
      if (quickHighValue == true && e.amount < 10000) return false;

      if (_query.isNotEmpty) {
        final hay = [
          _doctorDetails(e),
          e.note,
          e.phoneNumber,
          e.items.join(' '),
          e.tags.join(' '),
        ].join(' ').toLowerCase();
        if (!hay.contains(_query)) return false;
      }

      if (_categoryFilter != 'all') {
        final hasCategory = e.items.any((item) =>
            item.trim().toLowerCase() == _categoryFilter.toLowerCase());
        if (!hasCategory) return false;
      }

      // Doctor filter
      if (_doctorIdFilter != 'all' && !e.operatorsIDs.contains(_doctorIdFilter))
        return false;

      // Amount filter
      if (_amountFilter == 'lt1000' && e.amount >= 1000) return false;
      if (_amountFilter == '1k5k' && (e.amount < 1000 || e.amount > 5000))
        return false;
      if (_amountFilter == 'gt5000' && e.amount <= 5000) return false;
      if (_amountFilter == 'gt10000' && e.amount <= 10000) return false;

      final mode = _paymentMode(e);
      if (_paymentFilter == 'upi' && mode != 'UPI') return false;
      if (_paymentFilter == 'cash' && mode != 'Cash') return false;

      if (_statusFilter == 'paid' && !e.paid) return false;
      if (_statusFilter == 'pending' && e.paid) return false;
      if (_statusFilter == 'high' && e.amount < 10000) return false;

      if (_recurringOnly && !_isRecurringExpense(e)) return false;

      if (from != null || to != null) {
        final d = DateTime(e.date.year, e.date.month, e.date.day);
        if (from != null && d.isBefore(from)) return false;
        if (to != null && d.isAfter(to)) return false;
      }

      return true;
    }).toList(growable: false);
  }

  List<_ExpenseSummaryCardData> _summaryCards(List<Expense> rows) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final weekStart = today.subtract(Duration(days: today.weekday - 1));
    final weekEnd = weekStart.add(const Duration(days: 6));
    final monthStart = DateTime(today.year, today.month, 1);
    final monthEnd = DateTime(today.year, today.month + 1, 0);

    double todaySpent = 0;
    double pendingSpent = 0;
    double monthlySpent = 0;

    for (final e in rows) {
      final dateOnly = DateTime(e.date.year, e.date.month, e.date.day);
      if (!e.paid) {
        pendingSpent += e.amount;
      }
      if (dateOnly == today) {
        todaySpent += e.amount;
      }
      if (!dateOnly.isBefore(monthStart) && !dateOnly.isAfter(monthEnd)) {
        monthlySpent += e.amount;
      }
    }

    final weekDays = weekEnd.difference(weekStart).inDays + 1;
    final avgDaily = weekDays <= 0
        ? 0.0
        : rows.where((e) {
              final d = DateTime(e.date.year, e.date.month, e.date.day);
              return !d.isBefore(weekStart) && !d.isAfter(weekEnd);
            }).fold<double>(0, (sum, e) => sum + e.amount) /
            weekDays;

    return [
      _ExpenseSummaryCardData(
        title: 'Today Spent',
        value: todaySpent,
        valueColor: AppColors.blue7006,
      ),
      _ExpenseSummaryCardData(
        title: 'This Month',
        value: monthlySpent,
        valueColor: AppColors.dangerRose,
      ),
      _ExpenseSummaryCardData(
        title: 'Pending Payments',
        value: pendingSpent,
        valueColor: AppColors.amber5002,
      ),
      _ExpenseSummaryCardData(
        title: 'Avg Daily Spend',
        value: avgDaily,
        valueColor: AppColors.green5503,
      ),
    ];
  }

  String _paymentMode(Expense expense) {
    final hay =
        '${expense.tags.join(' ')} ${expense.note} ${expense.items.join(' ')}'
            .toLowerCase();
    if (hay.contains('upi') || hay.contains('gpay') || hay.contains('qr')) {
      return 'UPI';
    }
    return 'Cash';
  }

  String _doctorDetails(Expense expense) {
    final names = expense.operators
        .map((d) => d.title.trim())
        .where((name) => name.isNotEmpty)
        .toList(growable: false);
    if (names.isEmpty) return '-';
    return names.join(', ');
  }

  /// Sum of ALL Consultant category expenses for the doctors on this expense.
  double _doctorOutstanding(Expense expense) {
    if (expense.operators.isEmpty) return 0;
    final doctorIds = expense.operators.map((d) => d.id).toSet();
    double total = 0;
    for (final e in expenses.present.values) {
      final isConsultant =
          e.items.any((item) => item.trim().toLowerCase() == 'consultant');
      if (!isConsultant) continue;
      final hasCommonDoctor =
          e.operatorsIDs.any((id) => doctorIds.contains(id));
      if (!hasCommonDoctor) continue;
      total += e.amount;
    }
    return total;
  }

  Future<void> _deleteExpense(Expense expense) async {
    final category = expense.items.isEmpty ? '-' : expense.items.join(', ');
    final note = expense.note.trim().isEmpty ? '-' : expense.note.trim();
    final date = formatClinicDate(expense.date, pattern: 'dd MMM yyyy');
    final confirmed = await showConfirmDeleteDialog(
      context,
      message: 'Delete this expense?',
      customDetails:
          'Date: $date\nAmount: Rs ${expense.amount.toStringAsFixed(0)}\nCategory: $category\nDoctor: ${_doctorDetails(expense)}\nNote: $note',
    );
    if (confirmed != true) return;
    await expenses.hardDelete(expense.id);
  }

  Future<void> _openExpenseModal([Expense? editing]) async {
    final draft = Expense.fromJson(editing?.toJson() ?? {});

    DateTime selectedDate = draft.date;
    String selectedCategory = draft.items.isEmpty ? '' : draft.items.first;
    String selectedMode = _paymentMode(draft) == 'UPI' ? 'upi' : 'cash';
    bool isRecurring = _isRecurringExpense(draft);
    double amount = draft.amount;
    final noteController = TextEditingController(text: draft.note);
    final customCategoryController = TextEditingController();
    final selectedDoctors = draft.operatorsIDs.toSet();
    String? amountError;
    String? categoryError;

    final availableCategories = _orderedExpenseCategories();

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setStateDialog) {
          final categoryOptions = [
            ...availableCategories,
            'Other',
          ];

          return ContentDialog(
            title: Row(
              children: [
                Expanded(
                  child: Text(
                    editing == null ? 'Log Expense' : 'Edit Expense',
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 30,
                      color: AppColors.blue8002,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(FluentIcons.chrome_close, size: 12),
                  onPressed: () => Navigator.pop(dialogContext),
                ),
              ],
            ),
            content: SizedBox(
              width: 860,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 560),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      InfoLabel(
                        label: 'Expense Date:',
                        child: AppButton(
                          variant: AppButtonVariant.secondary,
                          onPressed: () async {
                            final picked = await material.showDatePicker(
                              context: context,
                              initialDate: selectedDate,
                              firstDate: DateTime(2000),
                              lastDate: DateTime(2100),
                              builder: apexoDatePickerBuilder(context),
                            );
                            if (picked == null) return;
                            setStateDialog(() {
                              selectedDate = DateTime(
                                picked.year,
                                picked.month,
                                picked.day,
                                selectedDate.hour,
                                selectedDate.minute,
                              );
                            });
                          },
                          label: formatClinicDate(
                            selectedDate,
                            pattern: 'dd/MM/yyyy',
                          ),
                          leading: const Icon(FluentIcons.calendar, size: 12),
                          expanded: true,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: InfoLabel(
                              label: 'Expense Category:',
                              child: ComboBox<String>(
                                value: selectedCategory.isEmpty
                                    ? null
                                    : selectedCategory,
                                isExpanded: true,
                                placeholder: const Text('Select category'),
                                items: categoryOptions
                                    .map(
                                      (value) => ComboBoxItem<String>(
                                        value: value,
                                        child: Text(value),
                                      ),
                                    )
                                    .toList(growable: false),
                                onChanged: (value) {
                                  setStateDialog(() {
                                    selectedCategory = value ?? '';
                                    if (categoryError != null) {
                                      categoryError = null;
                                    }
                                  });
                                },
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: InfoLabel(
                              label: 'Payment Mode:',
                              child: Container(
                                padding: const EdgeInsets.all(2),
                                decoration: BoxDecoration(
                                  border: Border.all(
                                      color: AppColors.violet1503),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: _ModeTab(
                                        label: 'UPI',
                                        selected: selectedMode == 'upi',
                                        onTap: () => setStateDialog(() {
                                          selectedMode = 'upi';
                                        }),
                                      ),
                                    ),
                                    Expanded(
                                      child: _ModeTab(
                                        label: 'Cash',
                                        selected: selectedMode == 'cash',
                                        onTap: () => setStateDialog(() {
                                          selectedMode = 'cash';
                                        }),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      ToggleSwitch(
                        checked: isRecurring,
                        content: const Text('Recurring monthly expense'),
                        onChanged: (value) {
                          setStateDialog(() {
                            isRecurring = value;
                          });
                        },
                      ),
                      if (categoryError != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            categoryError!,
                            style: const TextStyle(
                                color: AppColors.dangerRose, fontSize: 11),
                          ),
                        ),
                      if (selectedCategory == 'Other') ...[
                        const SizedBox(height: 8),
                        InfoLabel(
                          label: 'Custom Category:',
                          child: TextBox(
                            controller: customCategoryController,
                            placeholder: 'Enter custom category',
                          ),
                        ),
                      ],
                      const SizedBox(height: 10),
                      InfoLabel(
                        label: 'Amount Paid (INR):',
                        child: NumberBox(
                          value: amount,
                          min: 0,
                          clearButton: false,
                          mode: SpinButtonPlacementMode.inline,
                          onChanged: (value) {
                            setStateDialog(() {
                              amount = value ?? 0;
                              if (amountError != null) amountError = null;
                            });
                          },
                        ),
                      ),
                      if (amountError != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            amountError!,
                            style: const TextStyle(
                                color: AppColors.dangerRose, fontSize: 11),
                          ),
                        ),
                      const SizedBox(height: 10),
                      InfoLabel(
                        label: 'Payment Note:',
                        child: TextBox(
                          controller: noteController,
                          placeholder: 'Enter notes (optional)...',
                          maxLines: 3,
                        ),
                      ),
                      const SizedBox(height: 10),
                      if (selectedCategory == 'Consultant')
                        InfoLabel(
                          label: 'Doctor Details:',
                          child: Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: doctors.present.values.map((doctor) {
                              final selected =
                                  selectedDoctors.contains(doctor.id);
                              return GestureDetector(
                                onTap: () {
                                  setStateDialog(() {
                                    if (selected) {
                                      selectedDoctors.remove(doctor.id);
                                    } else {
                                      selectedDoctors.add(doctor.id);
                                    }
                                  });
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: selected
                                        ? AppColors.brandBlue
                                        : AppColors.slate1004,
                                    borderRadius: BorderRadius.circular(999),
                                    border: Border.all(
                                      color: selected
                                          ? AppColors.brandBlue
                                          : AppColors.violet1503,
                                    ),
                                  ),
                                  child: Text(
                                    doctor.title.trim().isEmpty
                                        ? 'Doctor'
                                        : doctor.title,
                                    style: TextStyle(
                                      color: selected
                                          ? Colors.white
                                          : AppColors.blue6503,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 11,
                                    ),
                                  ),
                                ),
                              );
                            }).toList(growable: false),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
            actions: [
              AppButton(
                label: 'Cancel',
                onPressed: () => Navigator.pop(dialogContext),
                variant: AppButtonVariant.secondary,
              ),
              AppButton(
                label: draft.id.isEmpty ? 'Create Expense' : 'Save Changes',
                onPressed: () {
                  final normalizedCategory = selectedCategory == 'Other'
                      ? customCategoryController.text.trim()
                      : selectedCategory.trim();

                  setStateDialog(() {
                    amountError = amount <= 0 ? 'Amount is required.' : null;
                    categoryError = normalizedCategory.isEmpty
                        ? 'Category is required.'
                        : null;
                  });

                  if (amountError != null || categoryError != null) return;

                  draft.date = selectedDate;
                  draft.amount = amount;
                  draft.note = noteController.text.trim();
                  draft.items = [normalizedCategory];
                  draft.operatorsIDs = selectedDoctors.toList(growable: false);

                  final tags = draft.tags.where((t) {
                    final lower = t.toLowerCase();
                    return lower != 'upi' &&
                        lower != 'cash' &&
                        !lower.startsWith('recurring:');
                  }).toList(growable: true);
                  tags.add(selectedMode == 'upi' ? 'UPI' : 'Cash');
                  if (isRecurring) {
                    tags.add('recurring:monthly');
                  }
                  draft.tags = tags;

                  // Auto-upsert monthly doctor fee per doctor
                  if (normalizedCategory.toLowerCase() == 'consultant' &&
                      selectedDoctors.isNotEmpty) {
                    for (final doctorId in selectedDoctors) {
                      // Find existing Consultant expense for same doctor + same month
                      final existing = expenses.present.values.where((e) {
                        if (e.id == draft.id) return false;
                        if (e.items.isEmpty ||
                            e.items.first.toLowerCase() != 'consultant')
                          return false;
                        if (!e.operatorsIDs.contains(doctorId)) return false;
                        return e.date.year == selectedDate.year &&
                            e.date.month == selectedDate.month;
                      });
                      if (existing.isNotEmpty) {
                        final toUpdate = existing.first;
                        toUpdate.amount = amount;
                        expenses.set(toUpdate);
                      } else {
                        // Create a new per-doctor record
                        final perDoctor = Expense.fromJson({});
                        perDoctor.date = selectedDate;
                        perDoctor.amount = amount;
                        perDoctor.note = noteController.text.trim();
                        perDoctor.items = [normalizedCategory];
                        perDoctor.operatorsIDs = [doctorId];
                        perDoctor.tags = tags;
                        expenses.set(perDoctor);
                      }
                    }
                    // If single doctor with new record, the draft itself IS the new record
                    // (already saved above) so skip the draft.set below
                    unawaited(_ensureRecurringEntriesUpToDate());
                    Navigator.pop(dialogContext);
                    return;
                  }

                  expenses.set(draft);
                  unawaited(_ensureRecurringEntriesUpToDate());
                  Navigator.pop(dialogContext);
                },
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _openRecurringExpenseDialog() async {
    await _ensureRecurringEntriesUpToDate();
    final recurringRows = expenses.present.values
        .where(_isRecurringExpense)
        .toList(growable: false)
      ..sort((a, b) => b.date.compareTo(a.date));

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => ContentDialog(
        title: const Text('Recurring Expenses'),
        content: SizedBox(
          width: 680,
          child: recurringRows.isEmpty
              ? const Text(
                  'No recurring expenses yet. Mark an expense as recurring in the expense form.',
                )
              : ListView.separated(
                  shrinkWrap: true,
                  itemCount: recurringRows.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 6),
                  itemBuilder: (_, i) {
                    final row = recurringRows[i];
                    final category = row.items.isEmpty ? '-' : row.items.first;
                    return Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.slate10011,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.violet15010),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              '$category • ₹${NumberFormat('#,##0').format(row.amount)} • ${_paymentMode(row)}',
                              style: const TextStyle(
                                color: AppColors.blue7004,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          AppButton(
                            label: 'Edit',
                            variant: AppButtonVariant.secondary,
                            onPressed: () async {
                              Navigator.pop(dialogContext);
                              await _openExpenseModal(row);
                            },
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
        actions: [
          AppButton(
            label: 'Close',
            variant: AppButtonVariant.secondary,
            onPressed: () => Navigator.pop(dialogContext),
          ),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;

  const _DetailRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          SizedBox(
            width: 84,
            child: Text(
              label,
              style: const TextStyle(
                color: AppColors.textBlueMuted,
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: AppColors.blue7506,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

enum _ExpenseStatus { paid, highValue, toPay }

class _LedgerHeadCell extends StatelessWidget {
  final String label;
  final TextAlign align;

  const _LedgerHeadCell(this.label, {this.align = TextAlign.left});

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      textAlign: align,
      style: const TextStyle(
        color: AppColors.blue65010,
        fontWeight: FontWeight.w800,
        fontSize: 12,
      ),
    );
  }
}

class _ExpenseModeBadge extends StatelessWidget {
  final String mode;

  const _ExpenseModeBadge({required this.mode});

  @override
  Widget build(BuildContext context) {
    final upi = mode.toUpperCase() == 'UPI';
    return Row(
      children: [
        Icon(
          upi ? FluentIcons.mobile_selected : FluentIcons.money,
          size: 12,
          color: upi ? AppColors.brandBlue : AppColors.green5502,
        ),
        const SizedBox(width: 4),
        Text(
          mode,
          style: TextStyle(
            color: upi ? AppColors.brandBlue : AppColors.green5502,
            fontWeight: FontWeight.w700,
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}

class _ExpenseStatusPill extends StatelessWidget {
  final _ExpenseStatus status;

  const _ExpenseStatusPill({required this.status});

  @override
  Widget build(BuildContext context) {
    late final String label;
    late final Color fg;
    late final Color bg;

    switch (status) {
      case _ExpenseStatus.paid:
        label = 'Paid';
        fg = AppColors.green5502;
        bg = AppColors.green1002;
        break;
      case _ExpenseStatus.highValue:
        label = 'High Value';
        fg = AppColors.amber5002;
        bg = AppColors.amber1004;
        break;
      case _ExpenseStatus.toPay:
        label = 'To Pay';
        fg = AppColors.rose550;
        bg = AppColors.amber100;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: TextStyle(
          color: fg,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _SortableHead extends StatelessWidget {
  final String label;
  final bool selected;
  final bool ascending;
  final VoidCallback onTap;

  const _SortableHead({
    required this.label,
    required this.selected,
    required this.ascending,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              color:
                  selected ? AppColors.brandBlueDark : AppColors.blue65010,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(width: 4),
          Icon(
            selected
                ? (ascending
                    ? FluentIcons.chevron_up_small
                    : FluentIcons.chevron_down_small)
                : FluentIcons.switch_user,
            size: 10,
            color: selected ? AppColors.brandBlueDark : AppColors.violet400,
          ),
        ],
      ),
    );
  }
}

class _ExpenseSummaryCardData {
  final String title;
  final double value;
  final Color valueColor;

  const _ExpenseSummaryCardData({
    required this.title,
    required this.value,
    required this.valueColor,
  });
}

class _ModeTab extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _ModeTab({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppColors.brandBlue : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: selected ? AppColors.brandBlue : AppColors.violet1503,
          ),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: selected ? Colors.white : AppColors.textBlueStrong,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}

class _ExpenseActionIconButton extends StatefulWidget {
  final IconData icon;
  final Color color;
  final Color hoverColor;
  final VoidCallback onTap;

  const _ExpenseActionIconButton({
    required this.icon,
    required this.color,
    required this.hoverColor,
    required this.onTap,
  });

  @override
  State<_ExpenseActionIconButton> createState() =>
      _ExpenseActionIconButtonState();
}

class _ExpenseActionIconButtonState extends State<_ExpenseActionIconButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: _hovered ? widget.hoverColor : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Icon(
            widget.icon,
            size: 16,
            color: widget.color,
          ),
        ),
      ),
    );
  }
}
