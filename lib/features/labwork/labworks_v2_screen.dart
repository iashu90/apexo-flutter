import 'package:apexo/common_widgets/patient_history_modal_v2.dart';
import 'package:apexo/features/labwork/labwork_model.dart';
import 'package:apexo/features/labwork/labworks_store.dart';
import 'package:apexo/features/labwork/open_labwork_v2_dialog.dart';
import 'package:apexo/theme/material_date_picker_theme.dart';
import 'package:apexo/widget_keys.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/material.dart' show showDatePicker;
import 'package:intl/intl.dart';

class LabworksV2Screen extends StatefulWidget {
  const LabworksV2Screen({super.key});

  @override
  State<LabworksV2Screen> createState() => _LabworksV2ScreenState();
}

class _LabworksV2ScreenState extends State<LabworksV2Screen> {
  final TextEditingController _searchCtrl = TextEditingController();

  String _query = '';
  String _statusFilter = 'all';
  String _paymentFilter = 'all';
  String _rangeFilter = 'today';
  DateTime? _fromDate;
  DateTime? _toDate;

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
    return ScaffoldPage(
      key: WK.labworksScreenV2,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      content: StreamBuilder(
        stream: labworks.observableMap.stream,
        builder: (context, _) {
          final all = labworks.present.values.toList(growable: false)
            ..sort((a, b) => b.date.compareTo(a.date));

          final filtered = _applyFilters(all);
          final grouped = _groupByDate(filtered);

          return Column(
            children: [
              _buildHeader(),
              const SizedBox(height: 10),
              _buildStatStrip(all),
              const SizedBox(height: 10),
              _buildSearchAndDateFilters(),
              const SizedBox(height: 8),
              _buildStatusFilters(),
              const SizedBox(height: 10),
              Expanded(
                child: grouped.isEmpty
                    ? _EmptyState(onClear: _clearFilters)
                    : ListView.builder(
                        itemCount: grouped.length,
                        itemBuilder: (context, index) {
                          final entry = grouped[index];
                          return _DateSection(
                            title: entry.$1,
                            items: entry.$2,
                            onOpen: (item) => openLabworkV2Dialog(context, item),
                            onHistory: (item) {
                              final patient = item.patient;
                              if (patient == null) return;
                              showPatientHistoryDialogV2(
                                context: context,
                                patient: patient,
                                rows: patient.patientDetails,
                              );
                            },
                          );
                        },
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
        const Icon(FluentIcons.manufacturing, color: Color(0xFF2D4B78), size: 16),
        const SizedBox(width: 8),
        const Text(
          'Labworks',
          style: TextStyle(
            color: Color(0xFF233B5F),
            fontSize: 22,
            fontWeight: FontWeight.w700,
          ),
        ),
        const Spacer(),
        FilledButton(
          style: ButtonStyle(
            backgroundColor: WidgetStateProperty.all(const Color(0xFF2AB673)),
            foregroundColor: WidgetStateProperty.all(Colors.white),
          ),
          onPressed: () => openLabworkV2Dialog(context),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(FluentIcons.add, size: 14),
              SizedBox(width: 6),
              Text('New Labwork'),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStatStrip(List<Labwork> all) {
    final today = DateTime.now();
    final todayItems = all.where((l) => _isSameDay(l.date, today)).toList(growable: false);
    final inLab = all.where((l) => !l.deliveredToDoctor).length;
    final ready = all.where((l) => l.deliveredToDoctor && !l.deliveredToPatient).length;
    final delivered = all.where((l) => l.deliveredToPatient).length;
    final dues = all.where((l) => !l.paid).toList(growable: false);
    final paymentDue = dues.fold<double>(0, (sum, l) => sum + l.price);

    final cards = [
      _StatCardData('TODAY', '${todayItems.length}', 'orders', const Color(0xFFF8FBFF), FluentIcons.calendar),
      _StatCardData('IN LAB', '$inLab', 'cases', const Color(0xFFF0F8FF), FluentIcons.test_beaker),
      _StatCardData('READY', '$ready', 'ready', const Color(0xFFEFF6FF), FluentIcons.status_circle_checkmark),
      _StatCardData('DELIVERED', '$delivered', 'done', const Color(0xFFF3F8FF), FluentIcons.cube_shape),
      _StatCardData(
        'PAYMENT DUE',
        paymentDue <= 0 ? '' : '₹${NumberFormat('#,##0').format(paymentDue)}',
        paymentDue <= 0 ? '' : 'dues',
        const Color(0xFFF4FCF7),
        FluentIcons.money,
      ),
      _StatCardData('DUES', dues.isEmpty ? '' : '${dues.length} dues', '', const Color(0xFFFFF2F2), FluentIcons.warning),
    ];

    return SizedBox(
      height: 92,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemBuilder: (context, i) => _StatCard(data: cards[i]),
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemCount: cards.length,
      ),
    );
  }

  Widget _buildSearchAndDateFilters() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        SizedBox(
          width: 420,
          child: TextBox(
            controller: _searchCtrl,
            placeholder: 'Search patient / phone / teeth / doctor',
            prefix: const Padding(
              padding: EdgeInsets.only(left: 10),
              child: Icon(FluentIcons.search, size: 12, color: Color(0xFF6B778C)),
            ),
          ),
        ),
        _dateQuickFilter('Today', 'today'),
        _dateQuickFilter('This Week', 'week'),
        _dateQuickFilter('This Month', 'month'),
        _dateQuickFilter('Custom Date', 'custom'),
        SizedBox(
          width: 132,
          child: Button(
            onPressed: () => _pickDate(true),
            child: Text(_fromDate == null ? 'From' : DateFormat('dd MMM').format(_fromDate!)),
          ),
        ),
        SizedBox(
          width: 132,
          child: Button(
            onPressed: () => _pickDate(false),
            child: Text(_toDate == null ? 'To' : DateFormat('dd MMM').format(_toDate!)),
          ),
        ),
        if (_fromDate != null || _toDate != null)
          IconButton(
            icon: const Icon(FluentIcons.clear),
            onPressed: () {
              setState(() {
                _fromDate = null;
                _toDate = null;
                if (_rangeFilter == 'custom') _rangeFilter = 'today';
              });
            },
          ),
      ],
    );
  }

  Widget _dateQuickFilter(String label, String value) {
    final selected = _rangeFilter == value;
    return GestureDetector(
      onTap: () => setState(() => _rangeFilter = value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF2563B5) : const Color(0xFFF5F8FD),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: selected ? const Color(0xFF2563B5) : const Color(0xFFDCE4F1)),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : const Color(0xFF5C6A84),
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _buildStatusFilters() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        _FilterChip(
          label: 'All',
          selected: _statusFilter == 'all',
          onTap: () => setState(() => _statusFilter = 'all'),
        ),
        _FilterChip(
          label: 'In Lab',
          selected: _statusFilter == 'in_lab',
          onTap: () => setState(() => _statusFilter = 'in_lab'),
        ),
        _FilterChip(
          label: 'Doctors',
          selected: _statusFilter == 'ready',
          onTap: () => setState(() => _statusFilter = 'ready'),
        ),
        _FilterChip(
          label: 'Completed',
          selected: _statusFilter == 'done',
          onTap: () => setState(() => _statusFilter = 'done'),
        ),
        const SizedBox(width: 12),
        _FilterChip(
          label: 'All Payment',
          selected: _paymentFilter == 'all',
          onTap: () => setState(() => _paymentFilter = 'all'),
        ),
        _FilterChip(
          label: 'Paid',
          selected: _paymentFilter == 'paid',
          onTap: () => setState(() => _paymentFilter = 'paid'),
        ),
        _FilterChip(
          label: 'Due',
          selected: _paymentFilter == 'due',
          onTap: () => setState(() => _paymentFilter = 'due'),
        ),
      ],
    );
  }

  Future<void> _pickDate(bool from) async {
    final now = DateTime.now();
    final initial = from
        ? (_fromDate ?? now)
        : (_toDate ?? _fromDate ?? now);

    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      builder: apexoDatePickerBuilder(context),
    );
    if (picked == null) return;

    setState(() {
      _rangeFilter = 'custom';
      if (from) {
        _fromDate = DateTime(picked.year, picked.month, picked.day);
        if (_toDate != null && _fromDate!.isAfter(_toDate!)) {
          _toDate = null;
        }
      } else {
        _toDate = DateTime(picked.year, picked.month, picked.day);
        if (_fromDate != null && _toDate!.isBefore(_fromDate!)) {
          _fromDate = null;
        }
      }
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
    } else if (_rangeFilter == 'month') {
      from = DateTime(today.year, today.month, 1);
      to = DateTime(today.year, today.month + 1, 0);
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

      if (_statusFilter == 'in_lab' && l.deliveredToDoctor) return false;
      if (_statusFilter == 'ready' && (!l.deliveredToDoctor || l.deliveredToPatient)) {
        return false;
      }
      if (_statusFilter == 'done' && !l.deliveredToPatient) return false;

      if (_paymentFilter == 'paid' && !l.paid) return false;
      if (_paymentFilter == 'due' && l.paid) return false;

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
      final d = DateTime(labwork.date.year, labwork.date.month, labwork.date.day);
      final label = d == today
          ? 'TODAY'
          : d == yesterday
              ? 'YESTERDAY'
              : DateFormat('MMM yyyy').format(d).toUpperCase();
      grouped.putIfAbsent(label, () => []).add(labwork);
    }

    return grouped.entries.map((e) => (e.key, e.value)).toList(growable: false);
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  void _clearFilters() {
    setState(() {
      _query = '';
      _searchCtrl.text = '';
      _statusFilter = 'all';
      _paymentFilter = 'all';
      _rangeFilter = 'today';
      _fromDate = null;
      _toDate = null;
    });
  }
}

class _StatCardData {
  final String title;
  final String value;
  final String subtitle;
  final Color color;
  final IconData icon;

  const _StatCardData(this.title, this.value, this.subtitle, this.color, this.icon);
}

class _StatCard extends StatelessWidget {
  final _StatCardData data;

  const _StatCard({required this.data});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 176,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: data.color,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFDCE3EF)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(data.icon, size: 13, color: const Color(0xFF5F6E85)),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  data.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF6B778C),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            data.value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 26,
              height: 1,
              color: Color(0xFF172B4D),
              fontWeight: FontWeight.w700,
            ),
          ),
          if (data.subtitle.isNotEmpty)
            Text(
              data.subtitle,
              style: const TextStyle(
                fontSize: 11,
                color: Color(0xFF6B778C),
              ),
            ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFE7F0FD) : const Color(0xFFF5F8FD),
          borderRadius: BorderRadius.circular(7),
          border: Border.all(
            color: selected ? const Color(0xFF86AEEA) : const Color(0xFFDCE4F1),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? const Color(0xFF2059B5) : const Color(0xFF5C6A84),
            fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class _DateSection extends StatelessWidget {
  final String title;
  final List<Labwork> items;
  final void Function(Labwork?) onOpen;
  final void Function(Labwork) onHistory;

  const _DateSection({
    required this.title,
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
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 20,
                letterSpacing: 0.5,
                fontWeight: FontWeight.w700,
                color: Color(0xFF4A5A74),
              ),
            ),
          ),
          ...items.map((item) => _LabworkRow(item: item, onOpen: onOpen, onHistory: onHistory)),
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
    final dueColor = item.paid ? const Color(0xFF2A8AD9) : const Color(0xFFD54A4A);
    final dueBg = item.paid ? const Color(0xFFE7F2FC) : const Color(0xFFFDECEC);
    final hasDueLabel = item.paid || item.price > 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFDDE5F1)),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 980;

          final head = Row(
            children: [
              SizedBox(
                width: compact ? 62 : 68,
                child: Text(
                  DateFormat('dd MMM').format(item.date),
                  style: const TextStyle(
                    color: Color(0xFF4C5C77),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Container(width: 1, height: 34, color: const Color(0xFFE7ECF5)),
              const SizedBox(width: 10),
              Container(
                width: 28,
                height: 28,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Color(0xFFD8E5F8),
                ),
                child: Text(
                  _initials(item.patient?.title ?? ''),
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF32537F),
                    fontSize: 11,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.patient?.title.trim().isNotEmpty == true
                          ? item.patient!.title
                          : 'Unknown patient',
                      style: const TextStyle(
                        fontSize: 18,
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
                  ],
                ),
              ),
              if (hasDueLabel)
                Container(
                  constraints: const BoxConstraints(minWidth: 108),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                  decoration: BoxDecoration(
                    color: dueBg,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    item.paid
                        ? '₹${NumberFormat('#,##0').format(item.price)} Paid'
                        : '₹${NumberFormat('#,##0').format(item.price)} Due',
                    style: TextStyle(
                      color: dueColor,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              const SizedBox(width: 4),
              IconButton(
                icon: const Icon(FluentIcons.history, size: 15),
                onPressed: item.patient == null ? null : () => onHistory(item),
              ),
              IconButton(
                icon: const Icon(FluentIcons.edit, size: 15),
                onPressed: () => onOpen(item),
              ),
            ],
          );

          final meta = Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _Tag(text: item.typeOfWork.isEmpty ? 'Type N/A' : item.typeOfWork),
              _Tag(text: item.shade.isEmpty ? 'Shade -' : 'Shade ${item.shade}'),
              _Tag(
                text: item.noOfUnits > 0 ? '${item.noOfUnits} Unit' : '0 Unit',
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
              _Tag(
                text: item.deliveredToDoctor ? 'Delivered to Doctor' : 'Pending Doctor',
                bg: item.deliveredToDoctor ? const Color(0xFFE7F6EC) : const Color(0xFFFAF1E7),
              ),
              _Tag(
                text: item.deliveredToPatient ? 'Delivered to Patient' : 'Pending Patient',
                bg: item.deliveredToPatient ? const Color(0xFFE7F6EC) : const Color(0xFFFAF1E7),
              ),
            ],
          );

          if (compact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [head, const SizedBox(height: 8), meta],
            );
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [head, const SizedBox(height: 8), meta],
          );
        },
      ),
    );
  }

  String _initials(String name) {
    final t = name.trim();
    if (t.isEmpty) return 'U';
    final parts = t.split(RegExp(r'\s+')).where((e) => e.isNotEmpty).toList(growable: false);
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
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
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
            const Icon(FluentIcons.search_issue, size: 28, color: Color(0xFF5E7396)),
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
            Button(onPressed: onClear, child: const Text('Clear filters')),
          ],
        ),
      ),
    );
  }
}
