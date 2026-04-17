import 'package:apexo/common_widgets/password_guard_dialog.dart';
import 'package:apexo/features/labwork/labwork_model.dart';
import 'package:apexo/features/labwork/labworks_store.dart';
import 'package:fluent_ui/fluent_ui.dart';

Future<void> showLabBulkUpdateDialog(BuildContext context) async {
  await runPasswordProtectedAction(
    context,
    title: 'Lab Bulk Update Access',
    message: 'Enter password to edit labwork names in bulk.',
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
  final String oldValue;
  final String newValue;

  const _LabBulkMatch({
    required this.id,
    required this.patientLabel,
    required this.oldValue,
    required this.newValue,
  });
}

class _LabBulkUpdateDialog extends StatefulWidget {
  const _LabBulkUpdateDialog();

  @override
  State<_LabBulkUpdateDialog> createState() => _LabBulkUpdateDialogState();
}

class _LabBulkUpdateDialogState extends State<_LabBulkUpdateDialog> {
  final _currentController = TextEditingController();
  final _replaceController = TextEditingController();

  String _targetField = 'Type Of Work';
  String _matchMode = 'Exact';
  bool _caseSensitive = false;
  bool _finding = false;
  bool _updating = false;
  String? _result;
  int _progressDone = 0;
  int _progressTotal = 0;

  List<_LabBulkMatch> _matches = const [];

  @override
  void dispose() {
    _currentController.dispose();
    _replaceController.dispose();
    super.dispose();
  }

  String _normalized(String value) {
    return _caseSensitive ? value : value.toLowerCase();
  }

  String _sourceFieldValue(Labwork item) {
    if (_targetField == 'Lab Name') return item.lab;
    return item.typeOfWork;
  }

  String _replaceText(String value, String findText, String replaceText) {
    if (findText.isEmpty) return value;
    if (_matchMode == 'Exact') {
      return _normalized(value.trim()) == _normalized(findText.trim())
          ? replaceText
          : value;
    }

    final pattern = RegExp(
      RegExp.escape(findText),
      caseSensitive: _caseSensitive,
    );
    return value.replaceAll(pattern, replaceText);
  }

  bool _matchesRule(Labwork item, String findText, String replaceText) {
    final current = _sourceFieldValue(item);
    final next = _replaceText(current, findText, replaceText);
    return next != current;
  }

  void _applyUpdate(Labwork item, String findText, String replaceText) {
    if (_targetField == 'Lab Name') {
      item.lab = _replaceText(item.lab, findText, replaceText);
    } else {
      item.typeOfWork = _replaceText(item.typeOfWork, findText, replaceText);
    }
    labworks.set(item);
  }

  Future<void> _findMatches() async {
    final findText = _currentController.text.trim();
    final replaceText = _replaceController.text.trim();

    setState(() {
      _finding = true;
      _result = null;
      _matches = const [];
      _progressDone = 0;
      _progressTotal = 0;
    });

    if (findText.isEmpty) {
      setState(() {
        _finding = false;
        _result = 'Find text is required.';
      });
      return;
    }

    final found = <_LabBulkMatch>[];
    for (final item in labworks.present.values) {
      if (!_matchesRule(item, findText, replaceText)) continue;
      final oldValue = _sourceFieldValue(item);
      found.add(
        _LabBulkMatch(
          id: item.id,
          patientLabel: item.patient?.title.trim().isNotEmpty == true
              ? item.patient!.title
              : 'Unnamed patient',
          oldValue: oldValue,
          newValue: _replaceText(oldValue, findText, replaceText),
        ),
      );
    }

    setState(() {
      _finding = false;
      _matches = found;
      _result = '${found.length} matching labwork record(s) found.';
    });
  }

  Future<void> _updateAll() async {
    if (_matches.isEmpty) return;

    setState(() {
      _updating = true;
      _result = null;
      _progressDone = 0;
      _progressTotal = _matches.length;
    });

    final findText = _currentController.text.trim();
    final replaceText = _replaceController.text.trim();
    var updated = 0;

    for (final match in _matches) {
      final item = labworks.get(match.id);
      if (item == null) continue;
      _applyUpdate(item, findText, replaceText);
      updated += 1;
      if (mounted) {
        setState(() => _progressDone = updated);
      }
    }

    await _findMatches();

    if (!mounted) return;
    setState(() {
      _updating = false;
      _result = 'Updated $updated labwork record(s).';
      _progressDone = _progressTotal;
    });
  }

  @override
  Widget build(BuildContext context) {
    final targetLabel = _targetField == 'Lab Name' ? 'Lab Name' : 'Type Of Work';

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
              'Replace labwork names in one click after previewing all affected records.',
              style: TextStyle(color: Color(0xFF5A7397)),
            ),
            const SizedBox(height: 10),
            ComboBox<String>(
              value: _targetField,
              isExpanded: true,
              items: const [
                ComboBoxItem(value: 'Type Of Work', child: Text('Type Of Work')),
                ComboBoxItem(value: 'Lab Name', child: Text('Lab Name')),
              ],
              onChanged: (value) {
                if (value == null) return;
                setState(() {
                  _targetField = value;
                  _matches = const [];
                  _result = null;
                });
              },
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextBox(
                    controller: _currentController,
                    placeholder: 'Find $targetLabel',
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextBox(
                    controller: _replaceController,
                    placeholder: 'Replace with',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: ComboBox<String>(
                    value: _matchMode,
                    isExpanded: true,
                    items: const [
                      ComboBoxItem(value: 'Exact', child: Text('Exact match')),
                      ComboBoxItem(
                        value: 'Contains',
                        child: Text('Contains / replace all'),
                      ),
                    ],
                    onChanged: (value) {
                      if (value == null) return;
                      setState(() => _matchMode = value);
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Checkbox(
                    checked: _caseSensitive,
                    content: const Text('Case sensitive'),
                    onChanged: (value) =>
                        setState(() => _caseSensitive = value ?? false),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                FilledButton(
                  onPressed: _finding || _updating ? null : _findMatches,
                  child: Text(_finding ? 'Finding...' : 'Find'),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: _updating || _matches.isEmpty ? null : _updateAll,
                  child: Text(_updating ? 'Updating...' : 'Update All'),
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
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 320),
              child: _matches.isEmpty
                  ? const Center(
                      child: Text(
                        'No matching labwork records found yet.',
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
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Current: ${item.oldValue}'),
                              Text('New: ${item.newValue}'),
                            ],
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
