import 'package:apexo/common_widgets/delete_confirmation.dart';
import 'package:apexo/features/expenses/expense_model.dart';
import 'package:apexo/features/expenses/expenses_store.dart';
import 'package:apexo/features/expenses/open_expense_panel.dart';
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
  String _rangeFilter = 'month';
  DateTime? _fromDate;
  DateTime? _toDate;
  int _page = 1;

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
          final cards = _summaryCards(filtered);

          final totalPages = filtered.isEmpty
              ? 1
              : ((filtered.length + _pageSize - 1) / _pageSize).ceil();
          if (_page > totalPages) {
            _page = totalPages;
          }
          final start = (filtered.isEmpty ? 0 : (_page - 1) * _pageSize)
              .clamp(0, filtered.length);
          final end = (start + _pageSize).clamp(0, filtered.length);
          final paged = filtered.sublist(start, end);

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
                  total: filtered.length,
                  start: filtered.isEmpty ? 0 : start + 1,
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
          'New Expenses',
          style: TextStyle(
            color: Color(0xFF233B5F),
            fontSize: 28,
            fontWeight: FontWeight.w700,
          ),
        ),
        const Spacer(),
        FilledButton(
          style: ButtonStyle(
            backgroundColor: WidgetStateProperty.all(const Color(0xFF2BA58D)),
            foregroundColor: WidgetStateProperty.all(Colors.white),
          ),
          onPressed: () => openExpense(),
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
      height: 90,
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
              color: card.background,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: card.border),
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
                    fontSize: 26,
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
    final categories = ['all', ...expenses.allItems.toSet().where((e) => e.trim().isNotEmpty)]
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

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
                ComboBoxItem<String>(value: 'cash', child: Text('Cash Payments')),
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
            width: 150,
            child: ComboBox<String>(
              value: _rangeFilter,
              items: const [
                ComboBoxItem<String>(value: 'all', child: Text('All Dates')),
                ComboBoxItem<String>(value: 'today', child: Text('Today')),
                ComboBoxItem<String>(value: 'month', child: Text('This Month')),
                ComboBoxItem<String>(value: 'custom', child: Text('Custom Date')),
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
          if (_rangeFilter == 'custom' && (_fromDate != null || _toDate != null))
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
                _rangeFilter = 'month';
                _fromDate = null;
                _toDate = null;
                _page = 1;
              });
            },
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
            child: const Row(
              children: [
                Expanded(flex: 12, child: _Head('Date')),
                Expanded(flex: 14, child: _Head('Category')),
                Expanded(flex: 28, child: _Head('Payee / Note')),
                Expanded(flex: 14, child: _Head('Amount Paid')),
                Expanded(flex: 14, child: _Head('Payment Mode')),
                Expanded(flex: 8, child: _Head('Actions')),
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
                      final modeBg = paymentMode == 'UPI'
                          ? const Color(0xFFDCFCE7)
                          : const Color(0xFFFFF3CD);
                      final modeFg = paymentMode == 'UPI'
                          ? const Color(0xFF1E7C58)
                          : const Color(0xFF9A6B00);

                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
                                DateFormat('dd MMM').format(e.date),
                                style: const TextStyle(color: Color(0xFF36557C)),
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
                              flex: 28,
                              child: Text(
                                _payeeAndNote(e),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(color: Color(0xFF4B6488)),
                              ),
                            ),
                            Expanded(
                              flex: 14,
                              child: Text(
                                '₹${NumberFormat('#,##0').format(e.amount)}',
                                style: const TextStyle(
                                  color: Color(0xFF2D476D),
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            Expanded(
                              flex: 14,
                              child: Align(
                                alignment: Alignment.centerLeft,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: modeBg,
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: Text(
                                    paymentMode,
                                    style: TextStyle(
                                      color: modeFg,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 11,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            Expanded(
                              flex: 8,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  IconButton(
                                    icon: const Icon(FluentIcons.edit, size: 14),
                                    onPressed: () => openExpense(e),
                                  ),
                                  IconButton(
                                    icon: const Icon(
                                      FluentIcons.delete,
                                      size: 14,
                                      color: Color(0xFFD6455D),
                                    ),
                                    onPressed: () => _deleteExpense(e),
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
                  total == 0 ? 'Showing 0 of 0' : 'Showing $start-$end of $total',
                  style: const TextStyle(color: Color(0xFF5A7397)),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(FluentIcons.chevron_left_small),
                  onPressed: page <= 1
                      ? null
                      : () => setState(() => _page = page - 1),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
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

  Future<void> _pickCustomRange() async {
    final now = DateTime.now();
    final from = await material.showDatePicker(
      context: context,
      initialDate: _fromDate ?? now,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      builder: apexoDatePickerBuilder(context),
    );
    if (from == null || !mounted) return;

    final to = await material.showDatePicker(
      context: context,
      initialDate: _toDate ?? from,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      builder: apexoDatePickerBuilder(context),
    );
    if (!mounted) return;

    setState(() {
      _rangeFilter = 'custom';
      _fromDate = DateTime(from.year, from.month, from.day);
      if (to == null) {
        _toDate = _fromDate;
      } else {
        _toDate = DateTime(to.year, to.month, to.day);
        if (_toDate!.isBefore(_fromDate!)) {
          final temp = _fromDate;
          _fromDate = _toDate;
          _toDate = temp;
        }
      }
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
          e.issuer,
          e.note,
          e.phoneNumber,
          e.items.join(' '),
          e.tags.join(' '),
        ].join(' ').toLowerCase();
        if (!hay.contains(_query)) return false;
      }

      if (_categoryFilter != 'all') {
        final hasCategory =
            e.items.any((item) => item.trim().toLowerCase() == _categoryFilter.toLowerCase());
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

    double todaySpent = 0;
    double totalSpent = 0;
    double upiPayments = 0;
    double cashPayments = 0;

    for (final e in rows) {
      totalSpent += e.amount;
      if (DateTime(e.date.year, e.date.month, e.date.day) == today) {
        todaySpent += e.amount;
      }
      if (_paymentMode(e) == 'UPI') {
        upiPayments += e.amount;
      } else {
        cashPayments += e.amount;
      }
    }

    return [
      const _ExpenseSummaryCardData(
        title: 'TODAY',
        background: Color(0xFFF2F8FF),
        border: Color(0xFFD8E8FA),
        valueColor: Color(0xFF2D476D),
        value: 0,
      ).copyWith(value: todaySpent),
      const _ExpenseSummaryCardData(
        title: 'TOTAL SPENT',
        background: Color(0xFFFFF8E9),
        border: Color(0xFFF0E3BF),
        valueColor: Color(0xFF2D476D),
        value: 0,
      ).copyWith(value: totalSpent),
      const _ExpenseSummaryCardData(
        title: 'UPI PAYMENTS',
        background: Color(0xFFF0FBF7),
        border: Color(0xFFD3EFE4),
        valueColor: Color(0xFF2D476D),
        value: 0,
      ).copyWith(value: upiPayments),
      const _ExpenseSummaryCardData(
        title: 'CASH PAYMENTS',
        background: Color(0xFFFDF6EA),
        border: Color(0xFFF1E1BE),
        valueColor: Color(0xFF2D476D),
        value: 0,
      ).copyWith(value: cashPayments),
    ];
  }

  String _paymentMode(Expense expense) {
    final hay =
        '${expense.tags.join(' ')} ${expense.note} ${expense.items.join(' ')}'.toLowerCase();
    if (hay.contains('upi') || hay.contains('gpay') || hay.contains('qr')) {
      return 'UPI';
    }
    return 'Cash';
  }

  String _payeeAndNote(Expense expense) {
    final issuer = expense.issuer.trim();
    final note = expense.note.trim();
    if (issuer.isEmpty && note.isEmpty) return '-';
    if (issuer.isEmpty) return note;
    if (note.isEmpty) return issuer;
    return '$issuer - $note';
  }

  Future<void> _deleteExpense(Expense expense) async {
    final confirmed = await showConfirmDeleteDialog(
      context,
      message: 'Delete this expense?',
      customDetails: '${expense.title} (${expense.issuer})',
    );
    if (confirmed != true) return;
    await expenses.hardDelete(expense.id);
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

class _ExpenseSummaryCardData {
  final String title;
  final double value;
  final Color background;
  final Color border;
  final Color valueColor;

  const _ExpenseSummaryCardData({
    required this.title,
    required this.value,
    required this.background,
    required this.border,
    required this.valueColor,
  });

  _ExpenseSummaryCardData copyWith({double? value}) {
    return _ExpenseSummaryCardData(
      title: title,
      value: value ?? this.value,
      background: background,
      border: border,
      valueColor: valueColor,
    );
  }
}
