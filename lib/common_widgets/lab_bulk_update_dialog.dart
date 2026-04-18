import 'package:apexo/common_widgets/password_guard_dialog.dart';
import 'package:apexo/features/labwork/labwork_model.dart';
import 'package:apexo/features/labwork/labworks_store.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:intl/intl.dart';

Future<void> showLabBulkUpdateDialog(BuildContext context) async {
  await runPasswordProtectedAction(
    context,
    title: 'Lab Bulk Update Access',
    message: 'Enter password to settle due lab payments in bulk.',
    onAuthorized: () async {
      await showDialog<void>(
        context: context,
        builder: (_) => const _LabBulkUpdateDialog(),
      );
    },
  );
}

class _LabBulkMatch {
  final String id;
  final String patientLabel;
  final String labLabel;
  final DateTime date;
  final double dueAmount;

  const _LabBulkMatch({
    required this.id,
    required this.patientLabel,
    required this.labLabel,
    required this.date,
    required this.dueAmount,
  });
}

class _LabBulkUpdateDialog extends StatefulWidget {
  const _LabBulkUpdateDialog();

  @override
  State<_LabBulkUpdateDialog> createState() => _LabBulkUpdateDialogState();
}

class _LabBulkUpdateDialogState extends State<_LabBulkUpdateDialog> {
  String _labFilter = 'all';
  final TextEditingController _labNameCtrl = TextEditingController();
  String _labNameQuery = '';
  DateTime _monthAnchor = DateTime(DateTime.now().year, DateTime.now().month, 1);

  bool _finding = false;
  bool _updating = false;
  String? _result;
  int _progressDone = 0;
  int _progressTotal = 0;

  List<_LabBulkMatch> _matches = const [];

  List<DateTime> get _monthOptions {
    final months = <DateTime>{
      for (final item in labworks.present.values) DateTime(item.date.year, item.date.month, 1),
      DateTime(DateTime.now().year, DateTime.now().month, 1),
    }.toList(growable: false)
      ..sort((a, b) => b.compareTo(a));
    return months;
  }

  List<String> get _labOptions {
    final labs = <String>{
      for (final item in labworks.present.values)
        if (item.lab.trim().isNotEmpty) item.lab.trim(),
    }.toList(growable: false)
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return ['all', ...labs];
  }

  bool _isInSelectedMonth(Labwork item) {
    return item.date.year == _monthAnchor.year && item.date.month == _monthAnchor.month;
  }

  bool _isMatchingLab(Labwork item) {
    final lab = item.lab.trim();
    if (_labFilter != 'all' && lab != _labFilter) return false;
    if (_labNameQuery.isEmpty) return true;
    return lab.toLowerCase().contains(_labNameQuery);
  }

  @override
  void initState() {
    super.initState();
    _labNameCtrl.addListener(() {
      setState(() {
        _labNameQuery = _labNameCtrl.text.trim().toLowerCase();
        _matches = const [];
        _result = null;
      });
    });
  }

  @override
  void dispose() {
    _labNameCtrl.dispose();
    super.dispose();
  }

  bool _isDue(Labwork item) {
    return !item.paid && item.price > 0;
  }

  Future<void> _findMatches() async {
    setState(() {
      _finding = true;
      _result = null;
      _matches = const [];
      _progressDone = 0;
      _progressTotal = 0;
    });

    final found = <_LabBulkMatch>[];
    for (final item in labworks.present.values) {
      if (!_isInSelectedMonth(item) || !_isMatchingLab(item) || !_isDue(item)) {
        continue;
      }
      found.add(
        _LabBulkMatch(
          id: item.id,
          patientLabel: item.patient?.title.trim().isNotEmpty == true
              ? item.patient!.title
              : 'Unnamed patient',
          labLabel: item.lab.trim().isEmpty ? 'Unassigned Lab' : item.lab.trim(),
          date: item.date,
          dueAmount: item.price,
        ),
      );
    }

    found.sort((a, b) => b.date.compareTo(a.date));

    setState(() {
      _finding = false;
      _matches = found;
      final total = found.fold<double>(0, (sum, m) => sum + m.dueAmount);
      _result = '${found.length} due record(s) found • Total due ₹${NumberFormat('#,##0').format(total)}';
    });
  }

  Future<void> _markAllPaid() async {
    if (_matches.isEmpty) return;

    setState(() {
      _updating = true;
      _result = null;
      _progressDone = 0;
      _progressTotal = _matches.length;
    });

    var updated = 0;
    for (final match in _matches) {
      final item = labworks.get(match.id);
      if (item == null) continue;
      if (!item.paid) {
        item.paid = true;
        labworks.set(item);
      }
      updated += 1;
      if (mounted) {
        setState(() => _progressDone = updated);
      }
    }

    await _findMatches();

    if (!mounted) return;
    setState(() {
      _updating = false;
      _result = 'Marked $updated record(s) as paid.';
      _progressDone = _progressTotal;
    });
  }

  @override
  Widget build(BuildContext context) {
    final monthOptions = _monthOptions;
    if (!monthOptions.any((m) => m.year == _monthAnchor.year && m.month == _monthAnchor.month)) {
      _monthAnchor = monthOptions.first;
    }

    final totalDue = _matches.fold<double>(0, (sum, m) => sum + m.dueAmount);

    return ContentDialog(
      constraints: const BoxConstraints(maxWidth: 860),
      title: const Text('Lab Bulk Update'),
      content: SizedBox(
        width: 820,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Mark all due labwork records as paid at month-end.',
              style: TextStyle(color: Color(0xFF5A7397)),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: ComboBox<DateTime>(
                    value: _monthAnchor,
                    isExpanded: true,
                    items: monthOptions
                        .map(
                          (month) => ComboBoxItem<DateTime>(
                            value: month,
                            child: Text(DateFormat('MMMM yyyy').format(month)),
                          ),
                        )
                        .toList(growable: false),
                    onChanged: (value) {
                      if (value == null) return;
                      setState(() {
                        _monthAnchor = value;
                        _matches = const [];
                        _result = null;
                      });
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ComboBox<String>(
                    value: _labFilter,
                    isExpanded: true,
                    items: _labOptions
                        .map(
                          (lab) => ComboBoxItem<String>(
                            value: lab,
                            child: Text(lab == 'all' ? 'All Labs' : lab),
                          ),
                        )
                        .toList(growable: false),
                    onChanged: (value) {
                      if (value == null) return;
                      setState(() {
                        _labFilter = value;
                        _matches = const [];
                        _result = null;
                      });
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            TextBox(
              controller: _labNameCtrl,
              placeholder: 'Lab name contains... (optional)',
              prefix: const Padding(
                padding: EdgeInsets.only(left: 10),
                child: Icon(
                  FluentIcons.filter,
                  size: 12,
                  color: Color(0xFF6D84A8),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                FilledButton(
                  onPressed: _finding || _updating ? null : _findMatches,
                  child: Text(_finding ? 'Finding...' : 'Find Due Records'),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: _updating || _matches.isEmpty ? null : _markAllPaid,
                  child: Text(_updating ? 'Updating...' : 'Mark All As Paid'),
                ),
              ],
            ),
            if (_updating && _progressTotal > 0) ...[
              const SizedBox(height: 8),
              ProgressBar(value: _progressDone / _progressTotal),
              const SizedBox(height: 6),
              Text(
                'Updating $_progressDone of $_progressTotal',
                style: const TextStyle(
                  color: Color(0xFF36557C),
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              ),
            ],
            if (_result != null) ...[
              const SizedBox(height: 8),
              Text(
                _result!,
                style: const TextStyle(
                  color: Color(0xFF1459AD),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
            const SizedBox(height: 10),
            if (_matches.isNotEmpty)
              Text(
                'Selected due total: ₹${NumberFormat('#,##0').format(totalDue)}',
                style: const TextStyle(
                  color: Color(0xFFD6455D),
                  fontWeight: FontWeight.w700,
                ),
              ),
            const SizedBox(height: 8),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 320),
              child: _matches.isEmpty
                  ? const Center(
                      child: Text(
                        'No due labwork records found for current selection.',
                        style: TextStyle(color: Color(0xFF6D84A8)),
                      ),
                    )
                  : ListView.separated(
                      itemCount: _matches.length,
                      separatorBuilder: (_, __) => const Divider(size: 1),
                      itemBuilder: (context, index) {
                        final item = _matches[index];
                        return ListTile.selectable(
                          title: Text(item.patientLabel),
                          subtitle: Text(
                            '${DateFormat('dd MMM yyyy').format(item.date)} • ${item.labLabel} • Due ₹${item.dueAmount.toStringAsFixed(0)}',
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      actions: [
        Button(
          onPressed: _finding || _updating ? null : () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    );
  }
}
