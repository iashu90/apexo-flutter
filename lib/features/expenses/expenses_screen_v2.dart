import 'package:apexo/common_widgets/custom_date_range_picker.dart';
import 'package:apexo/common_widgets/delete_confirmation.dart';
import 'package:apexo/features/doctors/doctors_store.dart';
import 'package:apexo/features/expenses/expense_model.dart';
import 'package:apexo/features/expenses/expenses_store.dart';
import 'package:apexo/theme/material_date_picker_theme.dart';
import 'package:apexo/widget_keys.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/material.dart' as material;
import 'package:intl/intl.dart';

class ExpensesScreenV2 extends StatefulWidget {
  const ExpensesScreenV2({super.key});

  @override
  State<ExpensesScreenV2> createState() => _ExpensesScreenV2State();
}

class _ExpensesScreenV2State extends State<ExpensesScreenV2> {
  final TextEditingController _searchCtrl = TextEditingController();

  String _query = '';
  String _categoryFilter = 'all';
  String _paymentFilter = 'all';
  String _rangeFilter = 'all';
  DateTime? _fromDate;
  DateTime? _toDate;
  int _page = 1;
  String _sortBy = 'date';
  bool _sortAscending = false;

  static const int _pageSize = 10;

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
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaffoldPage(
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
          final start = (sorted.isEmpty ? 0 : (_page - 1) * _pageSize)
              .clamp(0, sorted.length);
          final end = (start + _pageSize).clamp(0, sorted.length);
          final paged = sorted.sublist(start, end);

          return Column(
            children: [
              _buildHeader(),
              const SizedBox(height: 10),
              _buildSummaryStrip(cards),
              const SizedBox(height: 10),
              _buildFilters(rows),
              const SizedBox(height: 10),
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
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        const Text(
          'Expenses',
          style: TextStyle(
            color: Color(0xFF233B5F),
            fontSize: 28,
            fontWeight: FontWeight.w700,
          ),
        ),
        const Spacer(),
        FilledButton(
          style: ButtonStyle(
            backgroundColor: WidgetStateProperty.all(const Color(0xFF2D7BD8)),
            foregroundColor: WidgetStateProperty.all(Colors.white),
          ),
          onPressed: () => _openExpenseModal(),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(FluentIcons.add, size: 14),
              SizedBox(width: 6),
              Text('New Expense'),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryStrip(List<_ExpenseSummaryCardData> cards) {
    return SizedBox(
      height: 94,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: cards.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final card = cards[index];
          return Container(
            width: 250,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFD7E3F0)),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x160D2F5B),
                  blurRadius: 10,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  card.title,
                  style: const TextStyle(
                    color: Color(0xFF5A7397),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Spacer(),
                Text(
                  '₹${NumberFormat('#,##0').format(card.value)}',
                  style: TextStyle(
                    color: card.valueColor,
                    fontWeight: FontWeight.w800,
                    fontSize: 24,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildFilters(List<Expense> allRows) {
    final categories = [
      'all',
      ...expenses.allItems.toSet().where((e) => e.trim().isNotEmpty)
    ]..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          SizedBox(
            width: 280,
            child: TextBox(
              controller: _searchCtrl,
              placeholder: 'Search expenses...',
              prefix: const Padding(
                padding: EdgeInsets.only(left: 10),
                child: Icon(FluentIcons.search, size: 12),
              ),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 180,
            child: ComboBox<String>(
              value: _categoryFilter,
              items: categories
                  .map(
                    (v) => ComboBoxItem<String>(
                      value: v,
                      child: Text(v == 'all' ? 'Category' : v),
                    ),
                  )
                  .toList(growable: false),
              onChanged: (v) {
                if (v == null) return;
                setState(() {
                  _categoryFilter = v;
                  _page = 1;
                });
              },
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 140,
            child: ComboBox<String>(
              value: _paymentFilter,
              items: const [
                ComboBoxItem<String>(value: 'all', child: Text('All Payments')),
                ComboBoxItem<String>(value: 'upi', child: Text('UPI Payments')),
                ComboBoxItem<String>(
                    value: 'cash', child: Text('Cash Payments')),
              ],
              onChanged: (v) {
                if (v == null) return;
                setState(() {
                  _paymentFilter = v;
                  _page = 1;
                });
              },
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 160,
            child: ComboBox<String>(
              value: _rangeFilter,
              items: const [
                ComboBoxItem<String>(value: 'all', child: Text('All Dates')),
                ComboBoxItem<String>(value: 'today', child: Text('Today')),
                ComboBoxItem<String>(value: 'week', child: Text('This Week')),
                ComboBoxItem<String>(value: 'month', child: Text('This Month')),
                ComboBoxItem<String>(
                    value: 'custom', child: Text('Custom Date')),
              ],
              onChanged: (v) async {
                if (v == null) return;
                if (v == 'custom') {
                  await _pickCustomRange();
                  return;
                }
                setState(() {
                  _rangeFilter = v;
                  _fromDate = null;
                  _toDate = null;
                  _page = 1;
                });
              },
            ),
          ),
          if (_rangeFilter == 'custom' &&
              (_fromDate != null || _toDate != null))
            Padding(
              padding: const EdgeInsets.only(left: 8),
              child: Text(
                '${DateFormat('dd MMM').format(_fromDate ?? _toDate!)} - ${DateFormat('dd MMM').format(_toDate ?? _fromDate!)}',
                style: const TextStyle(
                  color: Color(0xFF2D4A70),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          const SizedBox(width: 8),
          Button(
            child: const Text('Reset'),
            onPressed: () {
              setState(() {
                _query = '';
                _searchCtrl.text = '';
                _categoryFilter = 'all';
                _paymentFilter = 'all';
                _rangeFilter = 'all';
                _fromDate = null;
                _toDate = null;
                _sortBy = 'date';
                _sortAscending = false;
                _page = 1;
              });
            },
          ),
          const SizedBox(width: 8),
          Text(
            'Total Records: ${allRows.length}',
            style: const TextStyle(
              color: Color(0xFF5A7397),
              fontWeight: FontWeight.w600,
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
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFDCE6F2)),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: const BoxDecoration(
              color: Color(0xFFF7FBFF),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(10),
                topRight: Radius.circular(10),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  flex: 12,
                  child: _SortableHead(
                    label: 'Date',
                    selected: _sortBy == 'date',
                    ascending: _sortAscending,
                    onTap: () => _onSort('date'),
                  ),
                ),
                Expanded(
                  flex: 14,
                  child: _SortableHead(
                    label: 'Category',
                    selected: _sortBy == 'category',
                    ascending: _sortAscending,
                    onTap: () => _onSort('category'),
                  ),
                ),
                Expanded(
                  flex: 16,
                  child: _SortableHead(
                    label: 'Doctor',
                    selected: _sortBy == 'doctor',
                    ascending: _sortAscending,
                    onTap: () => _onSort('doctor'),
                  ),
                ),
                Expanded(
                  flex: 22,
                  child: _SortableHead(
                    label: 'Note',
                    selected: _sortBy == 'note',
                    ascending: _sortAscending,
                    onTap: () => _onSort('note'),
                  ),
                ),
                Expanded(
                  flex: 12,
                  child: _SortableHead(
                    label: 'Amount',
                    selected: _sortBy == 'amount',
                    ascending: _sortAscending,
                    onTap: () => _onSort('amount'),
                  ),
                ),
                const Expanded(
                  flex: 12,
                  child: _Head('To Pay'),
                ),
                Expanded(
                  flex: 10,
                  child: _SortableHead(
                    label: 'Mode',
                    selected: _sortBy == 'mode',
                    ascending: _sortAscending,
                    onTap: () => _onSort('mode'),
                  ),
                ),
                const Expanded(flex: 8, child: _Head('Actions')),
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
                : ListView.builder(
                    itemCount: rows.length,
                    itemBuilder: (context, index) {
                      final e = rows[index];
                      final category = e.items.isEmpty ? '-' : e.items.first;
                      final paymentMode = _paymentMode(e);

                      return Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10),
                        decoration: const BoxDecoration(
                          border: Border(
                            top: BorderSide(color: Color(0xFFE8EFF7)),
                          ),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              flex: 12,
                              child: Text(
                                DateFormat('dd MMM yyyy').format(e.date),
                                style:
                                    const TextStyle(color: Color(0xFF36557C)),
                              ),
                            ),
                            Expanded(
                              flex: 14,
                              child: Text(
                                category,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Color(0xFF2D476D),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            Expanded(
                              flex: 16,
                              child: Text(
                                _doctorDetails(e),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style:
                                    const TextStyle(color: Color(0xFF4B6488)),
                              ),
                            ),
                            Expanded(
                              flex: 22,
                              child: Text(
                                e.note.trim().isEmpty ? '-' : e.note.trim(),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style:
                                    const TextStyle(color: Color(0xFF4B6488)),
                              ),
                            ),
                            Expanded(
                              flex: 12,
                              child: Text(
                                '₹${NumberFormat('#,##0').format(e.amount)}',
                                style: const TextStyle(
                                  color: Color(0xFFD6455D),
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            Expanded(
                              flex: 12,
                              child: Builder(builder: (_) {
                                if (category != 'Consultant' ||
                                    e.operators.isEmpty) {
                                  return const SizedBox.shrink();
                                }
                                final outstanding = _doctorOutstanding(e);
                                if (outstanding <= 0) {
                                  return const SizedBox.shrink();
                                }
                                return Text(
                                  '₹${NumberFormat('#,##0').format(outstanding)}',
                                  style: const TextStyle(
                                    color: Color(0xFFE09C31),
                                    fontWeight: FontWeight.w700,
                                  ),
                                );
                              }),
                            ),
                            Expanded(
                              flex: 10,
                              child: Align(
                                alignment: Alignment.centerLeft,
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    paymentMode == 'UPI'
                                        ? Image.asset(
                                            'assets/gpay.png',
                                            width: 14,
                                            height: 14,
                                            fit: BoxFit.cover,
                                            errorBuilder: (_, __, ___) =>
                                                const Icon(
                                              FluentIcons.receipt_processing,
                                              size: 12,
                                              color: Color(0xFF2D7BD8),
                                            ),
                                          )
                                        : const Icon(
                                            FluentIcons.money,
                                            size: 12,
                                            color: Color(0xFF3B9A42),
                                          ),
                                    const SizedBox(width: 5),
                                    Text(
                                      paymentMode,
                                      style: const TextStyle(
                                        color: Color(0xFF2D476D),
                                        fontWeight: FontWeight.w600,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            Expanded(
                              flex: 8,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  _ExpenseActionIconButton(
                                    icon: FluentIcons.edit,
                                    color: const Color(0xFF8267D6),
                                    hoverColor: const Color(0xFFF1EDFB),
                                    onTap: () => _openExpenseModal(e),
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
                          ],
                        ),
                      );
                    },
                  ),
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
                IconButton(
                  icon: const Icon(FluentIcons.chevron_left_small),
                  onPressed:
                      page <= 1 ? null : () => setState(() => _page = page - 1),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEAF2FF),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: const Color(0xFFD2E1F6)),
                  ),
                  child: Text(
                    '$page / $totalPages',
                    style: const TextStyle(
                      color: Color(0xFF1459AD),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(FluentIcons.chevron_right_small),
                  onPressed: page >= totalPages
                      ? null
                      : () => setState(() => _page = page + 1),
                ),
              ],
            ),
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
      _fromDate = DateTime(range.start.year, range.start.month, range.start.day);
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
      from = DateTime(today.year, today.month, 1);
      to = DateTime(today.year, today.month + 1, 0);
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
    double totalSpent = 0;
    double weeklySpent = 0;
    double monthlySpent = 0;

    for (final e in rows) {
      final dateOnly = DateTime(e.date.year, e.date.month, e.date.day);
      totalSpent += e.amount;
      if (dateOnly == today) {
        todaySpent += e.amount;
      }
      if (!dateOnly.isBefore(weekStart) && !dateOnly.isAfter(weekEnd)) {
        weeklySpent += e.amount;
      }
      if (!dateOnly.isBefore(monthStart) && !dateOnly.isAfter(monthEnd)) {
        monthlySpent += e.amount;
      }
    }

    return [
      _ExpenseSummaryCardData(
        title: 'TODAY',
        value: todaySpent,
        valueColor: const Color(0xFF2D476D),
      ),
      _ExpenseSummaryCardData(
        title: 'TOTAL SPENT',
        value: totalSpent,
        valueColor: const Color(0xFFD6455D),
      ),
      _ExpenseSummaryCardData(
        title: 'WEEKLY SPENT',
        value: weeklySpent,
        valueColor: const Color(0xFFD6455D),
      ),
      _ExpenseSummaryCardData(
        title: 'MONTHLY SPENT',
        value: monthlySpent,
        valueColor: const Color(0xFFD6455D),
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
      final isConsultant = e.items.any(
          (item) => item.trim().toLowerCase() == 'consultant');
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
    final date = DateFormat('dd MMM yyyy').format(expense.date);
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
    double amount = draft.amount;
    final noteController = TextEditingController(text: draft.note);
    final customCategoryController = TextEditingController();
    final selectedDoctors = draft.operatorsIDs.toSet();
    String? amountError;
    String? categoryError;

    final availableCategories = expenses.allItems
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toSet()
      ..add('Consultant')
      ..add('Medication')
      ..add('Labwork')
      ..add('Utilities')
      ..add('Doctor 1')
      ..add('Doctor 2')
      ..add('Sister 1')
      ..add('Sister 2')
      ..add('Maid')
      ..add('Electricity')
      ..add('Service Charges');

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setStateDialog) {
          final categoryOptions = [
            ...availableCategories.toList(growable: false)..sort(),
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
                        child: Button(
                          style: ButtonStyle(
                            padding: WidgetStateProperty.all(
                              const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 9),
                            ),
                            backgroundColor: WidgetStateProperty.all(
                                const Color(0xFFF8FAFE)),
                          ),
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
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  DateFormat('dd/MM/yyyy').format(selectedDate),
                                  style: const TextStyle(
                                    color: Color(0xFF1F2A3A),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              const Icon(FluentIcons.calendar, size: 14),
                            ],
                          ),
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
                                    if (categoryError != null)
                                      categoryError = null;
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
              Button(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Cancel'),
              ),
              FilledButton(
                style: ButtonStyle(
                  backgroundColor:
                      WidgetStateProperty.all(const Color(0xFF2D7BD8)),
                ),
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
                    return lower != 'upi' && lower != 'cash';
                  }).toList(growable: true);
                  tags.add(selectedMode == 'upi' ? 'UPI' : 'Cash');
                  draft.tags = tags;

                  expenses.set(draft);
                  Navigator.pop(dialogContext);
                },
                child:
                    Text(editing == null ? 'Save Expense' : 'Update Expense'),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _Head extends StatelessWidget {
  final String label;

  const _Head(this.label);

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: const TextStyle(
        color: Color(0xFF3F577B),
        fontWeight: FontWeight.w700,
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
