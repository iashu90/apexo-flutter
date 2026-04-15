import 'dart:math' as math;

import 'package:apexo/features/appointments/appointment_model.dart';
import 'package:apexo/features/appointments/appointments_store.dart';
import 'package:apexo/features/patients/patient_model.dart';
import 'package:apexo/features/patients/patients_store.dart';
import 'package:apexo/utils/indian_money.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  Entry point
// ─────────────────────────────────────────────────────────────────────────────

void showOutstandingBalanceModal(BuildContext context) {
  showDialog(
    context: context,
    barrierDismissible: true,
    builder: (_) => const _OutstandingBalanceModal(),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
//  Data model for per-patient outstanding row
// ─────────────────────────────────────────────────────────────────────────────

class _OutstandingRow {
  final Patient patient;
  final double totalCost;
  final double totalPaid;
  final DateTime? lastAppointmentDate;
  final bool hasUpiPayment;
  final List<String> treatments;
  final List<String> teeth;

  const _OutstandingRow({
    required this.patient,
    required this.totalCost,
    required this.totalPaid,
    required this.lastAppointmentDate,
    required this.hasUpiPayment,
    required this.treatments,
    required this.teeth,
  });

  double get due => totalCost - totalPaid;

  int get dueDays =>
      lastAppointmentDate == null
          ? 0
          : DateTime.now().difference(lastAppointmentDate!).inDays;

  bool get isPartial => totalPaid > 0 && totalPaid < totalCost;
  bool get isUnpaid => totalPaid == 0;

  bool get isDueToday {
    if (lastAppointmentDate == null) return false;
    final now = DateTime.now();
    return lastAppointmentDate!.year == now.year &&
        lastAppointmentDate!.month == now.month &&
        lastAppointmentDate!.day == now.day;
  }

  bool get isOverdue => !isDueToday && dueDays > 0;
}

// ─────────────────────────────────────────────────────────────────────────────
//  Computation helper (all in one pass)
// ─────────────────────────────────────────────────────────────────────────────

class _ComputedData {
  final List<_OutstandingRow> rows;
  final double totalOutstanding;
  final double collectedSoFar;
  final double collectedToday;
  final int patientsOver7Days;
  final double collectedLastMonth;

  const _ComputedData({
    required this.rows,
    required this.totalOutstanding,
    required this.collectedSoFar,
    required this.collectedToday,
    required this.patientsOver7Days,
    required this.collectedLastMonth,
  });
}

_ComputedData _computeData() {
  final allAppointments = appointments.present.values;
  final allPatients = patients.present;

  final now = DateTime.now();
  final todayStart = DateTime(now.year, now.month, now.day);

  // Per-patient aggregates
  final Map<String, double> costByPatient = {};
  final Map<String, double> paidByPatient = {};
  final Map<String, DateTime> lastDateByPatient = {};
  final Map<String, bool> hasUpiByPatient = {};
  final Map<String, Set<String>> treatmentsByPatient = {};
  final Map<String, Set<String>> teethByPatient = {};

  double collectedSoFar = 0;
  double collectedToday = 0;

  for (final a in allAppointments) {
    final pid = a.patientID;
    if (pid == null || pid.isEmpty) continue;

    costByPatient[pid] = (costByPatient[pid] ?? 0) + a.price;
    final thisPaid = a.paid + a.prescriptionPaid;
    paidByPatient[pid] = (paidByPatient[pid] ?? 0) + thisPaid;

    collectedSoFar += thisPaid;
    if (!a.date.isBefore(todayStart)) collectedToday += thisPaid;

    final prev = lastDateByPatient[pid];
    if (prev == null || a.date.isAfter(prev)) {
      lastDateByPatient[pid] = a.date;
    }

    if (a.treatmentGpayPaid || a.prescriptionGpayPaid) {
      hasUpiByPatient[pid] = true;
    } else {
      hasUpiByPatient.putIfAbsent(pid, () => false);
    }

    for (final t in a.selectedTreatments) {
      treatmentsByPatient.putIfAbsent(pid, () => {}).add(t);
    }
    for (final tooth in a.selectedTeeth) {
      teethByPatient.putIfAbsent(pid, () => {}).add(tooth);
    }
  }

  double totalOutstanding = 0;
  int patientsOver7Days = 0;
  final rows = <_OutstandingRow>[];

  for (final entry in costByPatient.entries) {
    final pid = entry.key;
    final cost = entry.value;
    final paid = paidByPatient[pid] ?? 0;
    final due = cost - paid;

    if (due <= 0) continue;

    final patient = allPatients[pid];
    if (patient == null) continue;

    totalOutstanding += due;

    final lastDate = lastDateByPatient[pid];
    final dueDays = lastDate == null
        ? 0
        : now.difference(lastDate).inDays;
    if (dueDays > 7) patientsOver7Days++;

    rows.add(_OutstandingRow(
      patient: patient,
      totalCost: cost,
      totalPaid: paid,
      lastAppointmentDate: lastDate,
      hasUpiPayment: hasUpiByPatient[pid] ?? false,
      treatments: (treatmentsByPatient[pid] ?? {}).toList(growable: false),
      teeth: (teethByPatient[pid] ?? {}).toList(growable: false),
    ));
  }

  // Sort by due (desc) by default
  rows.sort((a, b) => b.due.compareTo(a.due));

  // Collected last month for comparison
  final lastMonthStart = DateTime(now.year, now.month - 1, 1);
  final lastMonthEnd = DateTime(now.year, now.month, 0, 23, 59, 59);
  double collectedLastMonth = 0;
  for (final a in allAppointments) {
    if (!a.date.isBefore(lastMonthStart) && !a.date.isAfter(lastMonthEnd)) {
      collectedLastMonth += a.paid + a.prescriptionPaid;
    }
  }

  return _ComputedData(
    rows: rows,
    totalOutstanding: totalOutstanding,
    collectedSoFar: collectedSoFar,
    collectedToday: collectedToday,
    patientsOver7Days: patientsOver7Days,
    collectedLastMonth: collectedLastMonth,
  );
}

// ─────────────────────────────────────────────────────────────────────────────
//  Modal widget
// ─────────────────────────────────────────────────────────────────────────────

const _pageSize = 20;

class _OutstandingBalanceModal extends StatefulWidget {
  const _OutstandingBalanceModal();

  @override
  State<_OutstandingBalanceModal> createState() =>
      _OutstandingBalanceModalState();
}

class _OutstandingBalanceModalState extends State<_OutstandingBalanceModal> {
  final _searchCtrl = TextEditingController();
  String _searchQuery = '';
  String _activeFilter = 'All';
  final Set<String> _checkedIds = {};
  int _visibleCount = _pageSize;

  static const List<String> _filters = [
    'All',
    'Overdue',
    '-Today',
    '>\u20B95000',
    '>\u20B910000',
    '-Cash',
    'UPI',
    'Partial Paid',
    'Unpaid',
  ];

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(() {
      setState(() => _searchQuery = _searchCtrl.text.toLowerCase().trim());
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<_OutstandingRow> _applyFilter(List<_OutstandingRow> rows) {
    List<_OutstandingRow> result = rows;

    // Search
    if (_searchQuery.isNotEmpty) {
      result = result.where((r) {
        final name = r.patient.title.toLowerCase();
        final phone = r.patient.phone.toLowerCase();
        return name.contains(_searchQuery) || phone.contains(_searchQuery);
      }).toList();
    }

    // Active chip filter
    switch (_activeFilter) {
      case 'Overdue':
        result = result.where((r) => r.isOverdue).toList();
      case '-Today':
        result = result.where((r) => r.isDueToday).toList();
      case '>\u20B95000':
        result = result.where((r) => r.due > 5000).toList();
      case '>\u20B910000':
        result = result.where((r) => r.due > 10000).toList();
      case '-Cash':
        result = result.where((r) => !r.hasUpiPayment).toList();
      case 'UPI':
        result = result.where((r) => r.hasUpiPayment).toList();
      case 'Partial Paid':
        result = result.where((r) => r.isPartial).toList();
      case 'Unpaid':
        result = result.where((r) => r.isUnpaid).toList();
    }

    return result;
  }

  @override
  Widget build(BuildContext context) {
    final data = _computeData();
    final filtered = _applyFilter(data.rows);
    final visible = filtered.take(_visibleCount).toList(growable: false);
    final checkedCount =
        _checkedIds.where((id) => filtered.any((r) => r.patient.id == id)).length;

    return ContentDialog(
      constraints: const BoxConstraints(maxWidth: 940, maxHeight: 860),
      title: Row(
        children: [
          const Expanded(
            child: Text(
              'Outstanding Balance',
              style: TextStyle(
                fontWeight: FontWeight.w500,
                fontSize: 20,
                color: Color(0xFF0D2A4E),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(FluentIcons.chrome_close, size: 13),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Metric cards ────────────────────────────────────────────────
          _MetricsRow(data: data),
          const SizedBox(height: 14),

          // ── Search + actions ────────────────────────────────────────────
          _SearchAndActionsBar(searchCtrl: _searchCtrl),
          const SizedBox(height: 10),

          // ── Filter chips ────────────────────────────────────────────────
          _FilterChipsRow(
            filters: _filters,
            active: _activeFilter,
            onSelect: (f) => setState(() {
              _activeFilter = f;
              _visibleCount = _pageSize;
            }),
          ),
          const SizedBox(height: 10),

          // ── List ────────────────────────────────────────────────────────
          Expanded(
            child: visible.isEmpty
                ? const Center(
                    child: Text(
                      'No outstanding patients match the current filter.',
                      style: TextStyle(color: Color(0xFF7C93B1)),
                    ),
                  )
                : ListView.builder(
                    itemCount: visible.length,
                    itemBuilder: (context, index) {
                      final row = visible[index];
                      return _PatientRow(
                        row: row,
                        isChecked: _checkedIds.contains(row.patient.id),
                        onCheckedChanged: (v) {
                          setState(() {
                            if (v == true) {
                              _checkedIds.add(row.patient.id);
                            } else {
                              _checkedIds.remove(row.patient.id);
                            }
                          });
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
      actions: [
        // ── Bottom bar ─────────────────────────────────────────────────
        Row(
          children: [
            Text(
              'Showing ${visible.length} of ${filtered.length} patients',
              style: const TextStyle(
                color: Color(0xFF7C93B1),
                fontSize: 12,
              ),
            ),
            const Spacer(),
            if (checkedCount > 0)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Button(
                  onPressed: () async {
                    final checkedRows = data.rows
                        .where((r) => _checkedIds.contains(r.patient.id))
                        .toList(growable: false);
                    if (checkedRows.isEmpty) return;
                    final StringBuffer msg = StringBuffer();
                    msg.writeln('Dear Patient,');
                    msg.writeln();
                    msg.writeln('This is a reminder about your outstanding balance:');
                    msg.writeln();
                    for (final r in checkedRows) {
                      msg.writeln(
                        '• ${r.patient.title}: ₹${NumberFormat("#,##0.00").format(r.due)} due',
                      );
                    }
                    msg.writeln();
                    msg.writeln('Please contact us at your earliest convenience.');
                    // For bulk: open WhatsApp with first patient phone if single, else generic
                    final phone = checkedRows.length == 1
                        ? checkedRows.first.patient.phone.replaceAll(RegExp(r'[^0-9]'), '')
                        : '';
                    final encoded = Uri.encodeComponent(msg.toString());
                    final uri = phone.isNotEmpty
                        ? Uri.parse('https://wa.me/$phone?text=$encoded')
                        : Uri.parse('https://wa.me/?text=$encoded');
                    await launchUrl(uri, mode: LaunchMode.externalApplication);
                  },
                  style: ButtonStyle(
                    backgroundColor: WidgetStateProperty.all(
                      const Color(0xFF25D366),
                    ),
                    foregroundColor:
                        WidgetStateProperty.all(Colors.white),
                  ),
                  child: Row(
                    children: [
                      const Icon(FluentIcons.chat, size: 14),
                      const SizedBox(width: 6),
                      Text('Send WhatsApp Reminder ($checkedCount)'),
                    ],
                  ),
                ),
              ),
            if (visible.length < filtered.length)
              FilledButton(
                onPressed: () =>
                    setState(() => _visibleCount += _pageSize),
                style: ButtonStyle(
                  backgroundColor: WidgetStateProperty.all(
                    const Color(0xFF1459AD),
                  ),
                ),
                child: const Text('Load More'),
              ),
          ],
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Metric cards row
// ─────────────────────────────────────────────────────────────────────────────

class _MetricsRow extends StatelessWidget {
  final _ComputedData data;

  const _MetricsRow({required this.data});

  @override
  Widget build(BuildContext context) {
    // Growth vs last month (simplified: use collected this month vs last month)
    final now = DateTime.now();
    final monthStart = DateTime(now.year, now.month, 1);
    double collectedThisMonth = 0;
    for (final a in appointments.present.values) {
      if (!a.date.isBefore(monthStart)) {
        collectedThisMonth += a.paid + a.prescriptionPaid;
      }
    }
    final growthPct = data.collectedLastMonth == 0
        ? 0.0
        : ((collectedThisMonth - data.collectedLastMonth) /
                data.collectedLastMonth) *
            100;

    return Row(
      children: [
        Expanded(
          child: _MetricCard(
            color: const Color(0xFFFFF8F8),
            borderColor: const Color(0xFFFFE0E0),
            iconColor: const Color(0xFFD32F2F),
            icon: FluentIcons.money,
            title: 'Outstanding Amount',
            value: formatIndianShortCurrency(data.totalOutstanding, fractionDigits: 0),
            subtitle: growthPct >= 0
                ? '▲ ${growthPct.toStringAsFixed(0)}% vs last month'
                : '▼ ${growthPct.abs().toStringAsFixed(0)}% vs last month',
            subtitleColor: growthPct >= 0
                ? const Color(0xFFD32F2F)
                : const Color(0xFF388E3C),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _MetricCard(
            color: const Color(0xFFF5FFF7),
            borderColor: const Color(0xFFDEF0E0),
            iconColor: const Color(0xFF388E3C),
            icon: FluentIcons.payment_card,
            title: 'Collected So Far',
            value: formatIndianShortCurrency(data.collectedSoFar, fractionDigits: 0),
            subtitle:
                '₹${formatIndianCompactNumber(collectedThisMonth, fractionDigits: 0)} this month',
            subtitleColor: const Color(0xFF388E3C),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _MetricCard(
            color: const Color(0xFFF5F9FF),
            borderColor: const Color(0xFFD8E8F8),
            iconColor: const Color(0xFF1565C0),
            icon: FluentIcons.calendar_day,
            title: 'Collected Today',
            value: formatIndianShortCurrency(data.collectedToday, fractionDigits: 0),
            subtitle: '',
            subtitleColor: Colors.transparent,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _MetricCard(
            color: const Color(0xFFFFFBF0),
            borderColor: const Color(0xFFF5E8C0),
            iconColor: const Color(0xFFF57F17),
            icon: FluentIcons.people,
            title: 'Patients > 7 days due',
            value: '${data.patientsOver7Days}',
            subtitle: '',
            subtitleColor: Colors.transparent,
          ),
        ),
      ],
    );
  }
}

class _MetricCard extends StatelessWidget {
  final Color color;
  final Color borderColor;
  final Color iconColor;
  final IconData icon;
  final String title;
  final String value;
  final String subtitle;
  final Color subtitleColor;

  const _MetricCard({
    required this.color,
    required this.borderColor,
    required this.iconColor,
    required this.icon,
    required this.title,
    required this.value,
    required this.subtitle,
    required this.subtitleColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: iconColor),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 11,
                    color: iconColor.withValues(alpha: 0.85),
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: iconColor.withValues(alpha: 0.85),
            ),
          ),
          if (subtitle.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 11,
                color: subtitleColor,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Search + actions bar
// ─────────────────────────────────────────────────────────────────────────────

class _SearchAndActionsBar extends StatelessWidget {
  final TextEditingController searchCtrl;

  const _SearchAndActionsBar({required this.searchCtrl});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: TextBox(
            controller: searchCtrl,
            placeholder: 'Search patient / phone / treatment',
            prefix: const Padding(
              padding: EdgeInsets.only(left: 8),
              child: Icon(FluentIcons.search, size: 14, color: Color(0xFF7C93B1)),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Button(
          onPressed: () {},
          child: const Row(
            children: [
              Icon(FluentIcons.pdf, size: 14),
              SizedBox(width: 6),
              Text('PDF'),
            ],
          ),
        ),
        const SizedBox(width: 6),
        Button(
          onPressed: () {},
          child: const Row(
            children: [
              Icon(FluentIcons.download, size: 14),
              SizedBox(width: 6),
              Text('CSV'),
            ],
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Filter chips row
// ─────────────────────────────────────────────────────────────────────────────

class _FilterChipsRow extends StatelessWidget {
  final List<String> filters;
  final String active;
  final ValueChanged<String> onSelect;

  const _FilterChipsRow({
    required this.filters,
    required this.active,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: filters.map((f) {
          final isActive = f == active;
          return Padding(
            padding: const EdgeInsets.only(right: 6),
            child: GestureDetector(
              onTap: () => onSelect(f),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: isActive
                      ? const Color(0xFFFFEBEB)
                      : const Color(0xFFF1F6FF),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: isActive
                        ? const Color(0xFFE53E3E)
                        : const Color(0xFFD2E1F2),
                  ),
                ),
                child: Text(
                  f,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isActive
                        ? const Color(0xFFB91C1C)
                        : const Color(0xFF355A84),
                  ),
                ),
              ),
            ),
          );
        }).toList(growable: false),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Patient row
// ─────────────────────────────────────────────────────────────────────────────

class _PatientRow extends StatelessWidget {
  final _OutstandingRow row;
  final bool isChecked;
  final ValueChanged<bool?> onCheckedChanged;

  const _PatientRow({
    required this.row,
    required this.isChecked,
    required this.onCheckedChanged,
  });

  // Generate a consistent avatar color from the name
  Color _avatarColor(String name) {
    final colors = [
      const Color(0xFF1976D2),
      const Color(0xFFE53935),
      const Color(0xFF43A047),
      const Color(0xFFF57C00),
      const Color(0xFF8E24AA),
      const Color(0xFF00ACC1),
      const Color(0xFF6D4C41),
      const Color(0xFF039BE5),
    ];
    if (name.isEmpty) return colors[0];
    final idx = name.codeUnitAt(0) % colors.length;
    return colors[idx];
  }

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return '?';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final due = row.due;
    final avatarColor = _avatarColor(row.patient.title);
    final initials = _initials(row.patient.title);
    final havePaid = row.totalPaid > 0;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFEAF0FB))),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Checkbox
          Checkbox(
            checked: isChecked,
            onChanged: onCheckedChanged,
          ),
          const SizedBox(width: 10),

          // Avatar
          Stack(
            clipBehavior: Clip.none,
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: avatarColor,
                child: Text(
                  initials,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
              ),
              Positioned(
                bottom: -2,
                right: -2,
                child: Container(
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(
                    color: const Color(0xFF25D366),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 1.5),
                  ),
                  child: const Icon(FluentIcons.chat, size: 7, color: Colors.white),
                ),
              ),
            ],
          ),
          const SizedBox(width: 12),

          // Name + phone + age/gender + treatments
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Flexible(
                      child: Text(
                        row.patient.title,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1B3A5C),
                          fontSize: 13,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 5),
                    if (row.patient.birth > 0)
                      Text(
                        '${row.patient.birth}y ${row.patient.gender == 0 ? '♀' : '♂'}',
                        style: const TextStyle(
                          fontSize: 10,
                          color: Color(0xFF8EA8C3),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  row.patient.phone.isEmpty ? '—' : row.patient.phone,
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF607B9F),
                  ),
                ),
                if (row.treatments.isNotEmpty) ...[  
                  const SizedBox(height: 2),
                  Text(
                    row.treatments.take(3).join(', '),
                    style: const TextStyle(
                      fontSize: 10,
                      color: Color(0xFF7BA6CC),
                      fontStyle: FontStyle.italic,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ],
                if (row.teeth.isNotEmpty) ...[  
                  const SizedBox(height: 1),
                  Text(
                    'Teeth: ${row.teeth.take(5).join(', ')}',
                    style: const TextStyle(
                      fontSize: 10,
                      color: Color(0xFFA0B8D0),
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ],
              ],
            ),
          ),

          // Amount badge + paid info
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (row.isDueToday)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE53935),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      'DUE TODAY',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 11,
                      ),
                    ),
                  )
                else if (row.isPartial)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF9EE),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: const Color(0xFFE8D5A0)),
                    ),
                    child: const Text(
                      'PARTIAL',
                      style: TextStyle(
                        color: Color(0xFFA87840),
                        fontWeight: FontWeight.w600,
                        fontSize: 11,
                      ),
                    ),
                  )
                else
                  Text(
                    '₹ ${NumberFormat('#,##0.00').format(due)}',
                    style: const TextStyle(
                      color: Color(0xFFD32F2F),
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                const SizedBox(height: 2),
                Text(
                  havePaid
                      ? 'Paid ₹${NumberFormat('#,##0.00').format(row.totalPaid)} / ${NumberFormat('#,##0.00').format(row.totalCost)}'
                      : 'Paid ₹0.00 / ${NumberFormat('#,##0.00').format(row.totalCost)}',
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF7C93B1),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),

          // Due days
          Expanded(
            flex: 2,
            child: Text(
              'Due: ${row.dueDays} days',
              style: const TextStyle(
                color: Color(0xFF4A6080),
                fontSize: 12,
              ),
              textAlign: TextAlign.center,
            ),
          ),

          // Action button + overflow
          Expanded(
            flex: 3,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                FilledButton(
                  onPressed: () {},
                  style: ButtonStyle(
                    backgroundColor: WidgetStateProperty.all(
                      const Color(0xFF16A34A),
                    ),
                    padding: WidgetStateProperty.all(
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(FluentIcons.receipt_processing,
                          size: 13, color: Colors.white),
                      const SizedBox(width: 5),
                      Text(
                        row.isDueToday ? 'Send Reminder' : 'Collect Payment',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
