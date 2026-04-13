import 'package:apexo/features/labwork/labwork_model.dart';
import 'package:apexo/features/labwork/labworks_store.dart';
import 'package:apexo/features/labwork/open_labwork_panel.dart';
import 'package:apexo/widget_keys.dart';
import 'package:fluent_ui/fluent_ui.dart';
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
  String _rangeFilter = 'all';

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
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
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
                            onOpen: openLabwork,
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [Color(0xFF2A5FAF), Color(0xFF4B8CD8)],
        ),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          const Icon(FluentIcons.fabric_open_folder_horizontal, color: Colors.white),
          const SizedBox(width: 8),
          const Text(
            'New Labwork',
            style: TextStyle(
              color: Colors.white,
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
            onPressed: openLabwork,
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
      ),
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
      _StatCardData('N. LAB', '$inLab', 'cases', const Color(0xFFF0F8FF), FluentIcons.test_beaker),
      _StatCardData('READY', '$ready', 'ready', const Color(0xFFFFF8EA), FluentIcons.status_circle_checkmark),
      _StatCardData('DELIVERED', '$delivered', 'done', const Color(0xFFF3F8FF), FluentIcons.cube_shape),
      _StatCardData('PAYMENT DUE', '₹${NumberFormat('#,##0').format(paymentDue)}', '', const Color(0xFFF4FCF7), FluentIcons.money),
      _StatCardData('DUES', '${dues.length} dues', '', const Color(0xFFFFF2F2), FluentIcons.warning),
    ];

    return SizedBox(
      height: 84,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemBuilder: (context, i) => _StatCard(data: cards[i]),
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemCount: cards.length,
      ),
    );
  }

  Widget _buildSearchAndDateFilters() {
    return Row(
      children: [
        Expanded(
          child: TextBox(
            controller: _searchCtrl,
            placeholder: 'Search patient / phone / teeth / doctor',
            prefix: const Padding(
              padding: EdgeInsets.only(left: 10),
              child: Icon(FluentIcons.search, size: 12, color: Color(0xFF6B778C)),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            border: Border.all(color: const Color(0xFFD7DCE6)),
            borderRadius: BorderRadius.circular(8),
            color: Colors.white,
          ),
          child: ComboBox<String>(
            value: _rangeFilter,
            items: const [
              ComboBoxItem(value: 'today', child: Text('Today')),
              ComboBoxItem(value: 'week', child: Text('This Week')),
              ComboBoxItem(value: 'month', child: Text('This Month')),
              ComboBoxItem(value: 'all', child: Text('Custom Date')),
            ],
            onChanged: (v) {
              if (v == null) return;
              setState(() => _rangeFilter = v);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildStatusFilters() {
    return Row(
      children: [
        _FilterChip(
          label: 'All',
          selected: _statusFilter == 'all',
          onTap: () => setState(() => _statusFilter = 'all'),
          bg: const Color(0xFFFFC94D),
        ),
        const SizedBox(width: 8),
        _FilterChip(
          label: 'In Lab',
          selected: _statusFilter == 'in_lab',
          onTap: () => setState(() => _statusFilter = 'in_lab'),
          bg: const Color(0xFFEDE8D6),
        ),
        const SizedBox(width: 8),
        _FilterChip(
          label: 'Doctor',
          selected: _statusFilter == 'ready',
          onTap: () => setState(() => _statusFilter = 'ready'),
          bg: const Color(0xFFF3E8C7),
        ),
        const SizedBox(width: 8),
        _FilterChip(
          label: 'Completed',
          selected: _statusFilter == 'done',
          onTap: () => setState(() => _statusFilter = 'done'),
          bg: const Color(0xFFE3EEF9),
        ),
        const Spacer(),
        _FilterChip(
          label: 'All',
          selected: _paymentFilter == 'all',
          onTap: () => setState(() => _paymentFilter = 'all'),
          bg: const Color(0xFFE9F7F1),
        ),
        const SizedBox(width: 8),
        _FilterChip(
          label: 'Paid',
          selected: _paymentFilter == 'paid',
          onTap: () => setState(() => _paymentFilter = 'paid'),
          bg: const Color(0xFFE4F4EA),
        ),
        const SizedBox(width: 8),
        _FilterChip(
          label: 'Due',
          selected: _paymentFilter == 'due',
          onTap: () => setState(() => _paymentFilter = 'due'),
          bg: const Color(0xFFFCEAEA),
        ),
      ],
    );
  }

  List<Labwork> _applyFilters(List<Labwork> input) {
    final now = DateTime.now();

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

      if (_rangeFilter == 'today' && !_isSameDay(l.date, now)) return false;
      if (_rangeFilter == 'week') {
        final start = now.subtract(Duration(days: now.weekday - 1));
        final s = DateTime(start.year, start.month, start.day);
        final e = s.add(const Duration(days: 7));
        if (l.date.isBefore(s) || !l.date.isBefore(e)) return false;
      }
      if (_rangeFilter == 'month' && (l.date.year != now.year || l.date.month != now.month)) {
        return false;
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
      _rangeFilter = 'all';
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
      width: 190,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: data.color,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFDCE3EF)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(data.icon, size: 14, color: const Color(0xFF5F6E85)),
              const SizedBox(width: 6),
              Text(
                data.title,
                style: const TextStyle(
                  fontSize: 11,
                  color: Color(0xFF6B778C),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            data.value,
            style: const TextStyle(
              fontSize: 32,
              height: 0.9,
              color: Color(0xFF172B4D),
              fontWeight: FontWeight.w700,
            ),
          ),
          if (data.subtitle.isNotEmpty)
            Text(
              data.subtitle,
              style: const TextStyle(
                fontSize: 12,
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
  final Color bg;

  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
    required this.bg,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? bg : const Color(0xFFF5F7FB),
          borderRadius: BorderRadius.circular(7),
          border: Border.all(
            color: selected ? const Color(0xFFCFD8E8) : const Color(0xFFE4E9F2),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? const Color(0xFF2E3A4E) : const Color(0xFF73819A),
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
  final void Function([Labwork?]) onOpen;

  const _DateSection({
    required this.title,
    required this.items,
    required this.onOpen,
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
                fontSize: 23,
                letterSpacing: 0.8,
                fontWeight: FontWeight.w700,
                color: Color(0xFF4A5A74),
              ),
            ),
          ),
          ...items.map((item) => _LabworkRow(item: item, onOpen: onOpen)),
        ],
      ),
    );
  }
}

class _LabworkRow extends StatelessWidget {
  final Labwork item;
  final void Function([Labwork?]) onOpen;

  const _LabworkRow({
    required this.item,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    final dueColor = item.paid ? const Color(0xFF2A8AD9) : const Color(0xFFD54A4A);
    final dueBg = item.paid ? const Color(0xFFE7F2FC) : const Color(0xFFFDECEC);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFDDE5F1)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 68,
            child: Text(
              DateFormat('dd MMM').format(item.date),
              style: const TextStyle(
                color: Color(0xFF4C5C77),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Container(width: 1, height: 40, color: const Color(0xFFE7ECF5)),
          const SizedBox(width: 10),
          Container(
            width: 30,
            height: 30,
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
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.patient?.title.trim().isNotEmpty == true
                      ? item.patient!.title
                      : 'Unknown patient',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1F2B40),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                Text(
                  item.patient?.phone ?? '-',
                  style: const TextStyle(
                    color: Color(0xFF6E7A90),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          _Tag(text: item.typeOfWork.isEmpty ? 'Type N/A' : item.typeOfWork),
          const SizedBox(width: 8),
          _Tag(text: item.shade.isEmpty ? 'Shade -' : 'Shade ${item.shade}'),
          const SizedBox(width: 8),
          _Tag(
            text: item.noOfUnits > 0 ? '${item.noOfUnits} Unit' : '0 Unit',
            bg: const Color(0xFFE8F2FD),
          ),
          const SizedBox(width: 8),
          _Tag(
            text: item.lab.trim().isEmpty ? 'Lab -' : item.lab,
            bg: const Color(0xFFEAF5EC),
          ),
          const SizedBox(width: 12),
          Container(
            constraints: const BoxConstraints(minWidth: 120),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
                fontSize: 28,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(FluentIcons.edit),
            onPressed: () => onOpen(item),
          ),
        ],
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
