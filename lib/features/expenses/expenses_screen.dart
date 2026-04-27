import 'package:apexo/common_widgets/custom_date_range_picker.dart';
import 'package:apexo/common_widgets/delete_confirmation.dart';
import 'package:apexo/common_widgets/export_file_action_button.dart';
import 'package:apexo/core/theme/app_theme.dart';
import 'package:apexo/core/ui/components/app_button.dart';
import 'package:apexo/core/ui/components/app_dropdown_menu.dart';
import 'package:apexo/core/ui/components/app_pagination.dart';
import 'package:apexo/core/ui/components/app_search_field.dart';
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
  OverlayEntry? _expenseDetailsOverlay;

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
  }

  @override
  void dispose() {
    _hideExpenseOverlay();
    _searchCtrl.dispose();
    super.dispose();
  }

  bool _isRecurringExpense(Expense expense) {
    return expense.tags.any((tag) => tag.toLowerCase().startsWith('recurring:'));
  }

  void _hideExpenseOverlay() {
    _expenseDetailsOverlay?.remove();
    _expenseDetailsOverlay = null;
  }

  void _showExpenseOverlay(Expense expense) {
    _hideExpenseOverlay();
    final overlay = Overlay.of(context, rootOverlay: true);

    _expenseDetailsOverlay = OverlayEntry(
      builder: (overlayContext) => Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              onTap: _hideExpenseOverlay,
              child: Container(color: const Color(0x66000000)),
            ),
          ),
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520, maxHeight: 620),
              child: Container(
                margin: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFDCE6F2)),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x22000F2A),
                      blurRadius: 24,
                      offset: Offset(0, 10),
                    ),
                  ],
                ),
                child: _buildDetailsPane(
                  expense,
                  onClose: _hideExpenseOverlay,
                ),
              ),
            ),
          ),
        ],
      ),
    );

    overlay.insert(_expenseDetailsOverlay!);
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
                  const SizedBox(height: 12),
                  _buildSummaryStrip(cards),
                  const SizedBox(height: 12),
                  _buildExpenseOverviewCard(sorted),
                  const SizedBox(height: 12),
                  _buildFilters(rows),
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
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        gradient: const LinearGradient(
          colors: [Color(0xFFF6FAFF), Color(0xFFEAF3FF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: const Color(0xFFD5E4F8)),
      ),
      child: Row(
        children: [
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Expenses',
                  style: TextStyle(
                    color: Color(0xFF1F3554),
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Track and manage your clinic expenses',
                  style: TextStyle(
                    color: Color(0xFF4D678D),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          ExportFileActionButton(
            type: ExportFileType.csv,
            busy: _isExportingCsv,
            onPressed:
                (_isExportingCsv || rows.isEmpty) ? null : () => _exportCsv(rows),
          ),
          const SizedBox(width: 8),
          ExportFileActionButton(
            type: ExportFileType.pdf,
            busy: _isExportingPdf,
            onPressed:
                (_isExportingPdf || rows.isEmpty) ? null : () => _exportPdf(rows),
          ),
          const SizedBox(width: 8),
          AppButton(
            onPressed: _openRecurringExpenseDialog,
            label: 'Recurring Expenses',
            variant: AppButtonVariant.secondary,
            leading: const Icon(FluentIcons.repeat_all, size: 13),
          ),
          const SizedBox(width: 8),
          AppButton(
            onPressed: () => _openExpenseModal(),
            label: 'New Expense',
            leading: const Icon(FluentIcons.add, size: 14),
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
      Color(0xFF2D7BD8),
      Color(0xFFD6455D),
      Color(0xFFCE7A1A),
      Color(0xFF377D4C),
      Color(0xFF7B4FA8),
      Color(0xFF1B9988),
      Color(0xFFB55E11),
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
        border: Border.all(color: const Color(0xFFDCE6F2)),
        boxShadow: const [
          BoxShadow(color: Color(0x0F0D2E59), blurRadius: 10, offset: Offset(0, 3)),
        ],
      ),
      child: total <= 0
          ? const Row(
              children: [
                Icon(FluentIcons.pie_single, size: 16, color: Color(0xFF2D6EC2)),
                SizedBox(width: 8),
                Text(
                  'Expense Overview',
                  style: TextStyle(color: Color(0xFF214162), fontWeight: FontWeight.w800),
                ),
                SizedBox(width: 12),
                Text('No records', style: TextStyle(color: Color(0xFF7A8FAF), fontWeight: FontWeight.w600)),
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
                          const Icon(FluentIcons.pie_single, size: 16, color: Color(0xFF2D6EC2)),
                          const SizedBox(width: 8),
                          const Text(
                            'Expense Overview',
                            style: TextStyle(color: Color(0xFF214162), fontWeight: FontWeight.w800, fontSize: 14),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            'Total ₹${NumberFormat('#,##0').format(total)}',
                            style: const TextStyle(color: Color(0xFF5A7397), fontWeight: FontWeight.w700, fontSize: 12),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      ...display.asMap().entries.map((entry) {
                        final idx = entry.key;
                        final item = entry.value;
                        final pct = total > 0 ? (item.value / total * 100) : 0.0;
                        final color = pieColors[idx % pieColors.length];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Row(
                            children: [
                              Container(
                                width: 12,
                                height: 12,
                                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  item.key,
                                  style: const TextStyle(color: Color(0xFF243F60), fontWeight: FontWeight.w600, fontSize: 13),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Text(
                                '${pct.toStringAsFixed(0)}%',
                                style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 13),
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
                        final pct = total > 0 ? (item.value / total * 100) : 0.0;
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
      const Color(0xFF2D7BD8),
      const Color(0xFFD6455D),
      const Color(0xFFCE7A1A),
      const Color(0xFF377D4C),
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
              border: Border.all(color: const Color(0xFFDDE8F6)),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x120D2E59),
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
                          color: Color(0xFF547196),
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
                padding: EdgeInsets.only(right: i == children.length - 1 ? 0 : 8),
                child: children[i],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildFilters(List<Expense> allRows) {
    final categories = [
      'all',
      ..._orderedExpenseCategories(),
    ];
    final quickCategories = _orderedExpenseCategories().take(6).toList(growable: false);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFDDE8F6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildQuickFilterChip(label: 'All', value: 'all'),
              ...quickCategories.map(
                (category) => _buildQuickFilterChip(
                  label: category,
                  value: category,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              AppSearchField(
                hint: 'Search notes, category, doctor...',
                controller: _searchCtrl,
                width: 280,
                onClear: () {
                  _searchCtrl.clear();
                  setState(() {
                    _query = '';
                    _page = 1;
                  });
                },
              ),
              AppDropdownMenu<String>(
                width: 170,
                value: _categoryFilter,
                items: categories
                    .map(
                      (v) => AppDropdownItem<String>(
                        value: v,
                        label: v == 'all' ? 'Category' : v,
                      ),
                    )
                    .toList(growable: false),
                onChanged: (v) {
                  setState(() {
                    _categoryFilter = v;
                    _page = 1;
                  });
                },
              ),
              AppDropdownMenu<String>(
                width: 150,
                value: _paymentFilter,
                items: const [
                  AppDropdownItem<String>(value: 'all', label: 'All Payments'),
                  AppDropdownItem<String>(value: 'upi', label: 'UPI Payments'),
                  AppDropdownItem<String>(value: 'cash', label: 'Cash Payments'),
                ],
                onChanged: (v) {
                  setState(() {
                    _paymentFilter = v;
                    _page = 1;
                  });
                },
              ),
              AppDropdownMenu<String>(
                width: 150,
                value: _statusFilter,
                items: const [
                  AppDropdownItem<String>(value: 'all', label: 'All Status'),
                  AppDropdownItem<String>(value: 'paid', label: 'Paid'),
                  AppDropdownItem<String>(value: 'pending', label: 'Pending'),
                  AppDropdownItem<String>(value: 'high', label: 'High Value'),
                ],
                onChanged: (v) {
                  setState(() {
                    _statusFilter = v;
                    _page = 1;
                  });
                },
              ),
              GestureDetector(
                onTap: () => setState(() {
                  _recurringOnly = !_recurringOnly;
                  _page = 1;
                }),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 120),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: _recurringOnly
                        ? const Color(0xFF2D7BD8)
                        : const Color(0xFFEFF4FB),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: _recurringOnly
                          ? const Color(0xFF2D7BD8)
                          : const Color(0xFFD6E2F0),
                    ),
                  ),
                  child: Text(
                    'Recurring',
                    style: TextStyle(
                      color: _recurringOnly ? Colors.white : const Color(0xFF355279),
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
              AppDropdownMenu<String>(
                width: 160,
                value: _rangeFilter,
                items: const [
                  AppDropdownItem<String>(value: 'all', label: 'All Dates'),
                  AppDropdownItem<String>(value: 'today', label: 'Today'),
                  AppDropdownItem<String>(value: 'week', label: 'This Week'),
                  AppDropdownItem<String>(value: 'month', label: 'Monthly'),
                  AppDropdownItem<String>(value: 'last_month', label: 'Last Month'),
                  AppDropdownItem<String>(value: 'custom', label: 'Custom Date'),
                ],
                onChanged: (v) async {
                  if (v == 'custom') {
                    await _pickCustomRange();
                    return;
                  }
                  setState(() {
                    _rangeFilter = v;
                    if (v == 'month') {
                      _monthAnchor =
                          DateTime(DateTime.now().year, DateTime.now().month, 1);
                    }
                    _fromDate = null;
                    _toDate = null;
                    _page = 1;
                  });
                },
              ),
              if (_rangeFilter == 'month') _buildMonthSelector(),
              AppButton(
                label: 'Reset',
                variant: AppButtonVariant.secondary,
                onPressed: () {
                  setState(() {
                    _query = '';
                    _searchCtrl.text = '';
                    _categoryFilter = 'all';
                    _paymentFilter = 'all';
                    _statusFilter = 'all';
                    _recurringOnly = false;
                    _rangeFilter = 'month';
                    _monthAnchor =
                        DateTime(DateTime.now().year, DateTime.now().month, 1);
                    _fromDate = null;
                    _toDate = null;
                    _sortBy = 'date';
                    _sortAscending = false;
                    _page = 1;
                  });
                },
              ),
              Text(
                'Total Records: ${allRows.length}',
                style: const TextStyle(
                  color: Color(0xFF5A7397),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          if (_rangeFilter == 'custom' && (_fromDate != null || _toDate != null))
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                '${formatClinicDate(_fromDate ?? _toDate!, pattern: 'dd MMM')} - ${formatClinicDate(_toDate ?? _fromDate!, pattern: 'dd MMM')}',
                style: const TextStyle(
                  color: Color(0xFF2D4A70),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildQuickFilterChip({required String label, required String value}) {
    final selected = _categoryFilter.toLowerCase() == value.toLowerCase();
    return GestureDetector(
      onTap: () {
        setState(() {
          _categoryFilter = value;
          _page = 1;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF2D7BD8) : const Color(0xFFF3F8FF),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected ? const Color(0xFF2D7BD8) : const Color(0xFFD9E6F8),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : const Color(0xFF36557D),
            fontWeight: FontWeight.w700,
            fontSize: 12,
          ),
        ),
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
                  _page = 1;
                });
              },
            ),
          ),
          const SizedBox(width: 6),
          Text(
            formatClinicDate(_monthAnchor, pattern: 'MMMM yyyy'),
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
        border: Border.all(color: const Color(0xFFDCE6F2)),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: const BoxDecoration(
              color: Color(0xFFF4F9FF),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: Row(
              children: [
                const Icon(
                  FluentIcons.bulleted_list,
                  size: 16,
                  color: Color(0xFF2D6EC2),
                ),
                const SizedBox(width: 8),
                const Text(
                  'Expense Ledger',
                  style: TextStyle(
                    color: Color(0xFF234466),
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
          Expanded(
            child: rows.isEmpty
                ? const Center(
                    child: Text(
                      'No expenses found for selected filters.',
                      style: TextStyle(color: Color(0xFF6B7F9C)),
                    ),
                  )
                : _buildGroupedLedger(rows),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: Color(0xFFE8EFF7))),
            ),
            child: Row(
              children: [
                Text(
                  total == 0
                      ? 'Showing 0 of 0'
                      : 'Showing $start-$end of $total',
                  style: const TextStyle(color: Color(0xFF5A7397)),
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

  Widget _buildGroupedLedger(List<Expense> rows) {
    final grouped = <String, List<Expense>>{};
    for (final expense in rows) {
      final key = formatClinicDate(expense.date, pattern: 'yyyy-MM-dd');
      grouped.putIfAbsent(key, () => <Expense>[]).add(expense);
    }
    final keys = grouped.keys.toList(growable: false)
      ..sort((a, b) => b.compareTo(a));

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      itemCount: keys.length,
      itemBuilder: (context, index) {
        final key = keys[index];
        final dayRows = grouped[key]!;
        final dailyTotal = dayRows.fold<double>(0, (sum, e) => sum + e.amount);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 8, bottom: 8),
              child: Row(
                children: [
                  Text(
                    formatClinicDate(dayRows.first.date, pattern: 'dd MMM yyyy'),
                    style: const TextStyle(
                      color: Color(0xFF2B486D),
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEAF3FF),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      '₹${NumberFormat('#,##0').format(dailyTotal)}',
                      style: const TextStyle(
                        color: Color(0xFF2D6EC2),
                        fontWeight: FontWeight.w700,
                        fontSize: 11,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            ...dayRows.map((e) {
              final category = e.items.isEmpty ? '-' : e.items.first;
              final paymentMode = _paymentMode(e);

              return GestureDetector(
                onTap: () => _showExpenseOverlay(e),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 120),
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: const Color(0xFFE5EEF9),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 3,
                        height: 42,
                        decoration: BoxDecoration(
                          color: paymentMode == 'UPI'
                              ? const Color(0xFF2D7BD8)
                              : const Color(0xFF3C9A56),
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        flex: 24,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              category,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Color(0xFF213E61),
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              e.note.trim().isEmpty ? 'No note added' : e.note.trim(),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Color(0xFF607A9D),
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        flex: 14,
                        child: Text(
                          _doctorDetails(e),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Color(0xFF4B6488),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 9,
                        child: Text(
                          paymentMode,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: paymentMode == 'UPI'
                                ? const Color(0xFF2D7BD8)
                                : const Color(0xFF2D8A4E),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 10,
                        child: Text(
                          '₹${NumberFormat('#,##0').format(e.amount)}',
                          textAlign: TextAlign.end,
                          style: const TextStyle(
                            color: Color(0xFFD6455D),
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      _ExpenseActionIconButton(
                        icon: FluentIcons.edit,
                        color: const Color(0xFF8267D6),
                        hoverColor: const Color(0xFFF1EDFB),
                        onTap: () => _showExpenseOverlay(e),
                      ),
                      const SizedBox(width: 8),
                      _ExpenseActionIconButton(
                        icon: FluentIcons.delete,
                        color: const Color(0xFFD6455D),
                        hoverColor: const Color(0xFFFFECEF),
                        onTap: () => _deleteExpense(e),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ],
        );
      },
    );
  }

  Widget _buildDetailsPane(Expense? selected, {VoidCallback? onClose}) {
    final category = selected == null || selected.items.isEmpty
        ? '-'
        : selected.items.first;
    final paymentMode = selected == null ? '-' : _paymentMode(selected);
    final outstanding = selected == null ? 0 : _doctorOutstanding(selected);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFDCE6F2)),
      ),
      padding: const EdgeInsets.all(14),
      child: selected == null
          ? const Center(
              child: Text(
                'Select an expense to inspect details.',
                style: TextStyle(
                  color: Color(0xFF6B7F9C),
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
                    color: Color(0xFF1F3C5E),
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
                _DetailRow(label: 'Date', value: formatClinicDate(selected.date, pattern: 'dd MMM yyyy')),
                _DetailRow(label: 'Category', value: category),
                _DetailRow(label: 'Amount', value: '₹${NumberFormat('#,##0').format(selected.amount)}'),
                _DetailRow(label: 'Payment', value: paymentMode),
                _DetailRow(label: 'Doctor', value: _doctorDetails(selected)),
                const SizedBox(height: 10),
                const Text(
                  'Note',
                  style: TextStyle(
                    color: Color(0xFF4B6488),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF5F9FF),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFE1ECFA)),
                  ),
                  child: Text(
                    selected.note.trim().isEmpty ? 'No note provided.' : selected.note.trim(),
                    style: const TextStyle(
                      color: Color(0xFF35557D),
                      height: 1.35,
                    ),
                  ),
                ),
                if (outstanding > 0) ...[
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF6E8),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFF0D9A8)),
                    ),
                    child: Text(
                      'Consultant outstanding: ₹${NumberFormat('#,##0').format(outstanding)}',
                      style: const TextStyle(
                        color: Color(0xFF94620E),
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
    final avgDaily = weekDays <= 0 ? 0.0 : rows
            .where((e) {
              final d = DateTime(e.date.year, e.date.month, e.date.day);
              return !d.isBefore(weekStart) && !d.isAfter(weekEnd);
            })
            .fold<double>(0, (sum, e) => sum + e.amount) /
        weekDays;

    return [
      _ExpenseSummaryCardData(
        title: 'Today Spent',
        value: todaySpent,
        valueColor: const Color(0xFF2D476D),
      ),
      _ExpenseSummaryCardData(
        title: 'This Month',
        value: monthlySpent,
        valueColor: const Color(0xFFD6455D),
      ),
      _ExpenseSummaryCardData(
        title: 'Pending Payments',
        value: pendingSpent,
        valueColor: const Color(0xFFCE7A1A),
      ),
      _ExpenseSummaryCardData(
        title: 'Avg Daily Spend',
        value: avgDaily,
        valueColor: const Color(0xFF377D4C),
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
                      color: Color(0xFF1F2A3A),
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
                                      color: const Color(0xFFD4E2F3)),
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
                                color: Color(0xFFD6455D), fontSize: 11),
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
                                color: Color(0xFFD6455D), fontSize: 11),
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
                                        ? const Color(0xFF2D7BD8)
                                        : const Color(0xFFEFF4FB),
                                    borderRadius: BorderRadius.circular(999),
                                    border: Border.all(
                                      color: selected
                                          ? const Color(0xFF2D7BD8)
                                          : const Color(0xFFD4E2F3),
                                    ),
                                  ),
                                  child: Text(
                                    doctor.title.trim().isEmpty
                                        ? 'Doctor'
                                        : doctor.title,
                                    style: TextStyle(
                                      color: selected
                                          ? Colors.white
                                          : const Color(0xFF345982),
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
                        if (e.items.isEmpty || e.items.first.toLowerCase() != 'consultant') return false;
                        if (!e.operatorsIDs.contains(doctorId)) return false;
                        return e.date.year == selectedDate.year && e.date.month == selectedDate.month;
                      });
                      if (existing.isNotEmpty) {
                        final toUpdate = existing.first;
                        toUpdate.amount = amount;
                        expenses.set(toUpdate);
                        continue;
                      }
                      // No existing record - will create new via draft below (only for first doctor)
                    }
                    // If multiple doctors, create separate records for each
                    if (selectedDoctors.length > 1) {
                      for (final doctorId in selectedDoctors) {
                        final existing = expenses.present.values.where((e) {
                          if (e.id == draft.id) return false;
                          if (e.items.isEmpty || e.items.first.toLowerCase() != 'consultant') return false;
                          if (!e.operatorsIDs.contains(doctorId)) return false;
                          return e.date.year == selectedDate.year && e.date.month == selectedDate.month;
                        });
                        if (existing.isEmpty) {
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
                      Navigator.pop(dialogContext);
                      return;
                    }
                  }

                  expenses.set(draft);
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
                        color: const Color(0xFFF4F8FF),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFD8E5F8)),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              '$category • ₹${NumberFormat('#,##0').format(row.amount)} • ${_paymentMode(row)}',
                              style: const TextStyle(
                                color: Color(0xFF2B4A6E),
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
                color: Color(0xFF5C779B),
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: Color(0xFF213E61),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
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
                  selected ? const Color(0xFF1459AD) : const Color(0xFF3F577B),
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
            color: selected ? const Color(0xFF1459AD) : const Color(0xFF89A0BF),
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
          color: selected ? const Color(0xFF2D7BD8) : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: selected ? const Color(0xFF2D7BD8) : const Color(0xFFD4E2F3),
          ),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: selected ? Colors.white : const Color(0xFF355A82),
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
