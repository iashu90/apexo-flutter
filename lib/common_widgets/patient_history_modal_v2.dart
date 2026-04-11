import 'package:apexo/common_widgets/patient_report.dart';
import 'package:apexo/features/patients/patient_model.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:intl/intl.dart';

Future<void> showPatientHistoryDialogV2({
  required BuildContext context,
  required Patient patient,
  required List<ReportDetailRow> rows,
}) {
  return showDialog<void>(
    context: context,
    builder: (_) => Align(
      alignment: Alignment.center,
      child: PatientHistoryDialogV2(patient: patient, rows: rows),
    ),
  );
}

class _LedgerRowData {
  final String id;
  final DateTime date;
  final String tooth;
  final String treatment;
  final String doctor;
  final double cost;
  final double paid;
  final String mode;
  final String notes;
  final String prescription;

  const _LedgerRowData({
    required this.id,
    required this.date,
    required this.tooth,
    required this.treatment,
    required this.doctor,
    required this.cost,
    required this.paid,
    required this.mode,
    required this.notes,
    required this.prescription,
  });

  double get balance => cost - paid;

  String get status {
    if (paid <= 0 && cost > 0) return 'Due';
    if (paid >= cost) return 'Paid';
    return 'Partial';
  }
}

class PatientHistoryDialogV2 extends StatefulWidget {
  final Patient patient;
  final List<ReportDetailRow> rows;

  const PatientHistoryDialogV2({
    super.key,
    required this.patient,
    required this.rows,
  });

  @override
  State<PatientHistoryDialogV2> createState() => _PatientHistoryDialogV2State();
}

class _PatientHistoryDialogV2State extends State<PatientHistoryDialogV2> {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';
  String _statusFilter = 'All';
  String _modeFilter = 'All';
  String _dateRange = 'Last 30 days';
  String _doctorFilter = 'All Doctors';
  String? _expandedRowId;

  double _toAmount(String source) {
    return double.tryParse(source.replaceAll(RegExp(r'[^0-9.]'), '')) ?? 0;
  }

  List<_LedgerRowData> get _allRows {
    return widget.rows
        .asMap()
        .entries
        .map((entry) {
          final row = entry.value;
          final mode = row.treatmentPaymentMode.trim().isEmpty
              ? (row.preceptionPaymentMode.trim().isEmpty
                  ? 'Cash'
                  : row.preceptionPaymentMode)
              : row.treatmentPaymentMode;
          return _LedgerRowData(
            id: '${row.date.millisecondsSinceEpoch}_${entry.key}',
            date: row.date,
            tooth: row.teeth.trim().isEmpty ? '-' : row.teeth,
            treatment: row.treatment.trim().isEmpty ? '-' : row.treatment,
            doctor: 'Dr Nowfar',
            cost: _toAmount(row.cost),
            paid: _toAmount(row.paid),
            mode: mode,
            notes: row.treatment.trim().isEmpty
                ? 'No additional doctor notes.'
                : 'Follow-up required based on treatment response.',
            prescription: row.prescription.trim().isEmpty
                ? 'No medicines listed.'
                : row.prescription,
          );
        })
        .toList(growable: false)
      ..sort((a, b) => b.date.compareTo(a.date));
  }

  List<_LedgerRowData> get _visibleRows {
    final now = DateTime.now();
    DateTime? startDate;
    if (_dateRange == 'Last 30 days') {
      startDate = now.subtract(const Duration(days: 30));
    }

    return _allRows.where((row) {
      if (startDate != null && row.date.isBefore(startDate)) return false;

      if (_statusFilter != 'All' && row.status != _statusFilter) {
        return false;
      }

      if (_modeFilter != 'All' && row.mode != _modeFilter) {
        return false;
      }

      if (_doctorFilter != 'All Doctors' && row.doctor != _doctorFilter) {
        return false;
      }

      if (_query.isNotEmpty) {
        final haystack = [
          DateFormat('dd MMM yyyy').format(row.date),
          row.tooth,
          row.treatment,
          row.doctor,
          row.mode,
          row.status,
        ].join(' ').toLowerCase();
        if (!haystack.contains(_query)) return false;
      }

      return true;
    }).toList(growable: false);
  }

  Color _statusColor(String status) {
    if (status == 'Paid') return const Color(0xFF16A34A);
    if (status == 'Partial') return const Color(0xFFF59E0B);
    return const Color(0xFFDC2626);
  }

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() => _query = _searchController.text.trim().toLowerCase());
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _openShareOptions() async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => ContentDialog(
        title: const Text('Share Invoice'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Share options'),
            SizedBox(height: 10),
            Text('• WhatsApp'),
            Text('• Email'),
            Text('• SMS'),
            Text('• Copy Link'),
            SizedBox(height: 10),
            Text('Includes treatment details, payment history, logo, and signature.'),
          ],
        ),
        actions: [
          Button(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<void> _openPrintOptions() async {
    String invoiceType = 'Full Invoice';
    bool showBranding = true;
    bool showSignature = true;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setStateDialog) => ContentDialog(
          title: const Text('Print Options'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Invoice Type'),
              const SizedBox(height: 8),
              ComboBox<String>(
                value: invoiceType,
                items: const [
                  ComboBoxItem(value: 'Full Invoice', child: Text('Full Invoice')),
                  ComboBoxItem(value: 'Payment Receipt', child: Text('Payment Receipt')),
                  ComboBoxItem(value: 'Treatment Report', child: Text('Treatment Report')),
                ],
                onChanged: (v) {
                  if (v == null) return;
                  setStateDialog(() => invoiceType = v);
                },
              ),
              const SizedBox(height: 10),
              const Text('Paper: A4'),
              const SizedBox(height: 10),
              Checkbox(
                checked: showBranding,
                content: const Text('Show clinic branding'),
                onChanged: (v) => setStateDialog(() => showBranding = v ?? true),
              ),
              Checkbox(
                checked: showSignature,
                content: const Text('Show signature'),
                onChanged: (v) => setStateDialog(() => showSignature = v ?? true),
              ),
            ],
          ),
          actions: [
            Button(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Close'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screen = MediaQuery.of(context).size;
    final modalWidth = screen.width < 1200 ? screen.width * 0.98 : 1120.0;
    final modalHeight = screen.height * 0.92;

    final totalCost = _allRows.fold<double>(0, (s, r) => s + r.cost);
    final totalPaid = _allRows.fold<double>(0, (s, r) => s + r.paid);
    final totalBalance = totalCost - totalPaid;

    final lastVisit = _allRows.isEmpty
        ? '-'
        : DateFormat('dd MMM yyyy').format(_allRows.first.date);

    final avatarText = widget.patient.title.trim().isEmpty
        ? 'P'
        : widget.patient.title.trim().substring(0, 1).toUpperCase();

    return Container(
      width: modalWidth,
      height: modalHeight,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFDCE6F2)),
      ),
      child: Column(
        children: [
          Container(
            constraints: const BoxConstraints(minHeight: 96),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x120D2F5B),
                  blurRadius: 10,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE3ECFF),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Center(
                    child: Text(
                      avatarText,
                      style: const TextStyle(
                        color: Color(0xFF2563EB),
                        fontWeight: FontWeight.w700,
                        fontSize: 20,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        widget.patient.title.trim().isEmpty
                            ? 'Unnamed Patient'
                            : widget.patient.title,
                        style: const TextStyle(
                          fontSize: 20,
                          color: Color(0xFF1E293B),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Patient ID: ${widget.patient.id}  •  Phone: ${widget.patient.phone.trim().isEmpty ? '-' : widget.patient.phone}  •  Last Visit: $lastVisit  •  Doctor: Dr Nowfar',
                        style: const TextStyle(
                          color: Color(0xFF64748B),
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  alignment: WrapAlignment.end,
                  children: [
                    FilledButton(
                      style: ButtonStyle(
                        backgroundColor:
                            WidgetStateProperty.all(const Color(0xFF2563EB)),
                      ),
                      onPressed: () {},
                      child: const Text('+ Add Treatment'),
                    ),
                    FilledButton(
                      style: ButtonStyle(
                        backgroundColor:
                            WidgetStateProperty.all(const Color(0xFF16A34A)),
                      ),
                      onPressed: () {},
                      child: const Text('Collect Payment'),
                    ),
                    Button(onPressed: _openShareOptions, child: const Text('Share')),
                    Button(onPressed: _openPrintOptions, child: const Text('Print')),
                    Button(onPressed: () {}, child: const Text('Download PDF')),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x120D2F5B),
                  blurRadius: 10,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _summaryCard('Total Treatment Cost', '₹${totalCost.toStringAsFixed(0)}', const Color(0xFF1E293B), const Color(0xFFF1F5FB)),
                _summaryCard('Total Paid', '₹${totalPaid.toStringAsFixed(0)}', const Color(0xFF1E293B), const Color(0xFFF1FBF4)),
                _summaryCard('Outstanding Balance', '₹${totalBalance.toStringAsFixed(0)}', const Color(0xFFDC2626), const Color(0xFFFFF3F3)),
                _summaryCard('Payment Status', totalBalance <= 0 ? 'Paid' : 'Partially Paid', totalBalance <= 0 ? const Color(0xFF16A34A) : const Color(0xFFF59E0B), const Color(0xFFFFF8EF)),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x120D2F5B),
                  blurRadius: 10,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextBox(
                    controller: _searchController,
                    placeholder: 'Search treatments...',
                    prefix: const Padding(
                      padding: EdgeInsets.only(left: 8),
                      child: Icon(FluentIcons.search, size: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                _combo(
                  value: _statusFilter,
                  values: const ['All', 'Paid', 'Due', 'Partial'],
                  onChanged: (v) => setState(() => _statusFilter = v),
                  width: 140,
                ),
                const SizedBox(width: 8),
                _combo(
                  value: _modeFilter,
                  values: const ['All', 'Cash', 'UPI', 'Card', 'GPay'],
                  onChanged: (v) => setState(() => _modeFilter = v),
                  width: 120,
                ),
                const SizedBox(width: 8),
                _combo(
                  value: _dateRange,
                  values: const ['Last 30 days', 'Last 90 days', 'All'],
                  onChanged: (v) => setState(() => _dateRange = v),
                  width: 150,
                ),
                const SizedBox(width: 8),
                _combo(
                  value: _doctorFilter,
                  values: const ['All Doctors', 'Dr Nowfar'],
                  onChanged: (v) => setState(() => _doctorFilter = v),
                  width: 140,
                ),
                const SizedBox(width: 8),
                Button(onPressed: () {}, child: const Text('Export CSV')),
                const SizedBox(width: 6),
                Button(onPressed: () {}, child: const Text('Export PDF')),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x120D2F5B),
                    blurRadius: 10,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                children: [
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    child: Row(
                      children: [
                        Expanded(flex: 12, child: Text('Date', style: TextStyle(fontWeight: FontWeight.w600))),
                        Expanded(flex: 10, child: Text('Tooth', style: TextStyle(fontWeight: FontWeight.w600))),
                        Expanded(flex: 16, child: Text('Treatment', style: TextStyle(fontWeight: FontWeight.w600))),
                        Expanded(flex: 12, child: Text('Doctor', style: TextStyle(fontWeight: FontWeight.w600))),
                        Expanded(flex: 8, child: Text('Cost', style: TextStyle(fontWeight: FontWeight.w600))),
                        Expanded(flex: 8, child: Text('Paid', style: TextStyle(fontWeight: FontWeight.w600))),
                        Expanded(flex: 9, child: Text('Balance', style: TextStyle(fontWeight: FontWeight.w600))),
                        Expanded(flex: 9, child: Text('Status', style: TextStyle(fontWeight: FontWeight.w600))),
                        Expanded(flex: 8, child: Text('Mode', style: TextStyle(fontWeight: FontWeight.w600))),
                        Expanded(flex: 14, child: Text('Actions', style: TextStyle(fontWeight: FontWeight.w600))),
                      ],
                    ),
                  ),
                  const Divider(size: 1),
                  Expanded(
                    child: ListView.builder(
                      itemCount: _visibleRows.length,
                      itemBuilder: (context, index) {
                        final row = _visibleRows[index];
                        final expanded = _expandedRowId == row.id;
                        final statusColor = _statusColor(row.status);

                        return MouseRegion(
                          cursor: SystemMouseCursors.click,
                          child: Column(
                            children: [
                              GestureDetector(
                                onTap: () {
                                  setState(() {
                                    _expandedRowId = expanded ? null : row.id;
                                  });
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                                  color: index.isEven
                                      ? const Color(0xFFF9FBFF)
                                      : Colors.white,
                                  child: Row(
                                    children: [
                                      Expanded(
                                        flex: 12,
                                        child: Text('📅 ${DateFormat('dd MMM yyyy').format(row.date)}'),
                                      ),
                                      Expanded(flex: 10, child: Text('🦷 ${row.tooth}')),
                                      Expanded(flex: 16, child: Text(row.treatment)),
                                      Expanded(flex: 12, child: Text(row.doctor)),
                                      Expanded(
                                        flex: 8,
                                        child: Text('₹${row.cost.toStringAsFixed(0)}'),
                                      ),
                                      Expanded(
                                        flex: 8,
                                        child: Text('₹${row.paid.toStringAsFixed(0)}'),
                                      ),
                                      Expanded(
                                        flex: 9,
                                        child: Text('₹${row.balance.toStringAsFixed(0)}'),
                                      ),
                                      Expanded(
                                        flex: 9,
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                          decoration: BoxDecoration(
                                            color: statusColor.withValues(alpha: 0.15),
                                            borderRadius: BorderRadius.circular(999),
                                            border: Border.all(color: statusColor),
                                          ),
                                          child: Text(
                                            row.status,
                                            textAlign: TextAlign.center,
                                            style: TextStyle(
                                              color: statusColor,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ),
                                      ),
                                      Expanded(flex: 8, child: Text(row.mode)),
                                      Expanded(
                                        flex: 14,
                                        child: Wrap(
                                          spacing: 6,
                                          runSpacing: 6,
                                          children: [
                                            Button(onPressed: () {}, child: const Text('View')),
                                            Button(onPressed: () {}, child: const Text('Edit')),
                                            Button(onPressed: () {}, child: const Text('Print Receipt')),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              if (expanded)
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(12),
                                  color: const Color(0xFFF3F7FC),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Treatment Details',
                                        style: TextStyle(fontWeight: FontWeight.w700),
                                      ),
                                      const SizedBox(height: 6),
                                      Text('Notes by doctor: ${row.notes}'),
                                      const SizedBox(height: 4),
                                      Text('Medicines prescribed: ${row.prescription}'),
                                      const SizedBox(height: 4),
                                      const Text('Lab charges: -'),
                                      const SizedBox(height: 4),
                                      const Text('Attachments: No files attached'),
                                      const SizedBox(height: 10),
                                      const Text(
                                        'Payment Breakdown',
                                        style: TextStyle(fontWeight: FontWeight.w700),
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        '₹${row.paid.toStringAsFixed(0)} — ${row.mode} — ${DateFormat('dd MMM yyyy').format(row.date)}',
                                      ),
                                      const SizedBox(height: 10),
                                      Wrap(
                                        spacing: 8,
                                        runSpacing: 8,
                                        children: [
                                          Button(onPressed: () {}, child: const Text('Add Payment')),
                                          Button(onPressed: () {}, child: const Text('Refund')),
                                          Button(onPressed: () {}, child: const Text('Print Invoice')),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              const Divider(size: 1),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _combo({
    required String value,
    required List<String> values,
    required ValueChanged<String> onChanged,
    required double width,
  }) {
    return SizedBox(
      width: width,
      child: ComboBox<String>(
        value: value,
        items: values
            .map((v) => ComboBoxItem(value: v, child: Text(v)))
            .toList(growable: false),
        onChanged: (v) {
          if (v != null) onChanged(v);
        },
      ),
    );
  }

  Widget _summaryCard(String title, String value, Color valueColor, Color bg) {
    return SizedBox(
      width: 250,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE2E8F2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                color: Color(0xFF334155),
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(
                color: valueColor,
                fontSize: 20,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
