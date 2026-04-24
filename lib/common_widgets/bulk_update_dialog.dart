import 'package:apexo/common_widgets/password_guard_dialog.dart';
import 'package:apexo/core/ui/components/app_button.dart';
import 'package:apexo/features/appointments/appointment_model.dart';
import 'package:apexo/features/appointments/appointments_store.dart';
import 'package:apexo/features/patients/patients_store.dart';
import 'package:fluent_ui/fluent_ui.dart';

Future<void> showBulkUpdateDialog(BuildContext context) async {
  await runPasswordProtectedAction(
    context,
    title: 'Bulk Update Access',
    message: 'Enter password to continue.',
    onAuthorized: () async {
      await showDialog<void>(
        context: context,
        builder: (_) => const _BulkUpdateDialog(),
      );
    },
  );
}

class _BulkMatch {
  final String id;
  final String title;
  final String subtitle;
  final String oldValue;
  final String newValue;

  const _BulkMatch({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.oldValue,
    required this.newValue,
  });
}

class _BulkUpdateDialog extends StatefulWidget {
  const _BulkUpdateDialog();

  @override
  State<_BulkUpdateDialog> createState() => _BulkUpdateDialogState();
}

class _BulkUpdateDialogState extends State<_BulkUpdateDialog> {
  final _currentController = TextEditingController();
  final _replaceController = TextEditingController();
  final _matchSearchController = TextEditingController();

  String _updateType = 'Treatment Rename';
  String _matchMode = 'Exact';
  bool _caseSensitive = false;

  bool _finding = false;
  bool _updating = false;
  String? _result;
  int _progressDone = 0;
  int _progressTotal = 0;
  String _progressLabel = '';

  List<_BulkMatch> _matches = const [];

  List<_BulkMatch> get _visibleMatches {
    final query = _matchSearchController.text.trim().toLowerCase();
    if (query.isEmpty) return _matches;
    return _matches.where((m) {
      return m.title.toLowerCase().contains(query) ||
          m.subtitle.toLowerCase().contains(query) ||
          m.oldValue.toLowerCase().contains(query) ||
          m.newValue.toLowerCase().contains(query);
    }).toList(growable: false);
  }

  @override
  void dispose() {
    _currentController.dispose();
    _replaceController.dispose();
    _matchSearchController.dispose();
    super.dispose();
  }

  String _normalize(String value) {
    return _caseSensitive ? value : value.toLowerCase();
  }

  String _replaceWithRule(String value, String current, String replacement) {
    if (current.isEmpty) return value;

    if (_matchMode == 'Exact') {
      if (_normalize(value.trim()) == _normalize(current.trim())) {
        return replacement;
      }
      return value;
    }

    final source = _caseSensitive ? value : value.toLowerCase();
    final needle = _caseSensitive ? current : current.toLowerCase();
    if (!source.contains(needle)) return value;

    if (_caseSensitive) return value.replaceAll(current, replacement);
    final pattern = RegExp(RegExp.escape(current), caseSensitive: false);
    return value.replaceAllMapped(pattern, (_) => replacement);
  }

  bool _appointmentMatches(Appointment a, String current, String replacement) {
    if (_updateType == 'Treatment Rename') {
      final nextTreatments = a.selectedTreatments
          .map((e) => _replaceWithRule(e, current, replacement))
          .toList(growable: false);
      final nextSub = a.subTreatments
          .map((e) => _replaceWithRule(e, current, replacement))
          .toList(growable: false);
      return !_listEquals(a.selectedTreatments, nextTreatments) ||
          !_listEquals(a.subTreatments, nextSub);
    }

    final nextDiagnosis = a.diagnosis
        .map((e) => _replaceWithRule(e, current, replacement))
        .toList(growable: false);
    final nextPre = _replaceWithRule(a.preOpNotes, current, replacement);
    final nextPost = _replaceWithRule(a.postOpNotes, current, replacement);
    return !_listEquals(a.diagnosis, nextDiagnosis) ||
        nextPre != a.preOpNotes ||
        nextPost != a.postOpNotes;
  }

  bool _listEquals(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  void _applyAppointmentUpdate(
    Appointment a,
    String current,
    String replacement,
  ) {
    if (_updateType == 'Treatment Rename') {
      a.selectedTreatments = a.selectedTreatments
          .map((e) => _replaceWithRule(e, current, replacement))
          .toList(growable: false);
      a.subTreatments = a.subTreatments
          .map((e) => _replaceWithRule(e, current, replacement))
          .toList(growable: false);
      appointments.set(a);
      return;
    }

    a.diagnosis = a.diagnosis
        .map((e) => _replaceWithRule(e, current, replacement))
        .toList(growable: false);
    a.preOpNotes = _replaceWithRule(a.preOpNotes, current, replacement);
    a.postOpNotes = _replaceWithRule(a.postOpNotes, current, replacement);
    appointments.set(a);
  }

  Future<void> _findMatches() async {
    final current = _currentController.text.trim();
    final replacement = _replaceController.text.trim();

    setState(() {
      _finding = true;
      _result = null;
      _matches = const [];
      _progressDone = 0;
      _progressTotal = 0;
      _progressLabel = '';
    });

    if (_updateType != 'Age -> Year Of Birth' && current.isEmpty) {
      setState(() {
        _finding = false;
        _result = 'Find text is required.';
      });
      return;
    }

    final found = <_BulkMatch>[];

    if (_updateType == 'Age -> Year Of Birth') {
      final now = DateTime.now();
      for (final p in patients.present.values) {
        if (p.birth <= 0 || p.birth > 130) continue;
        final yearOfBirth = now.year - p.birth;
        found.add(
          _BulkMatch(
            id: p.id,
            title: p.title.trim().isEmpty ? 'Unnamed patient' : p.title,
            subtitle: 'Patient',
            oldValue: 'Age: ${p.birth}',
            newValue: 'Year of birth: $yearOfBirth',
          ),
        );
      }
    } else {
      for (final a in appointments.present.values) {
        if (!_appointmentMatches(a, current, replacement)) continue;
        found.add(
          _BulkMatch(
            id: a.id,
            title: a.title.trim().isEmpty ? 'Unnamed patient' : a.title,
            subtitle: 'Appointment ${a.id}',
            oldValue: _updateType == 'Treatment Rename'
                ? a.selectedTreatments.join(', ')
                : 'Diagnosis: ${a.diagnosis.join(', ')} | Pre: ${a.preOpNotes} | Post: ${a.postOpNotes}',
            newValue: _updateType == 'Treatment Rename'
                ? a.selectedTreatments
                    .map((e) => _replaceWithRule(e, current, replacement))
                    .join(', ')
                : 'Diagnosis: ${a.diagnosis.map((e) => _replaceWithRule(e, current, replacement)).join(', ')} | Pre: ${_replaceWithRule(a.preOpNotes, current, replacement)} | Post: ${_replaceWithRule(a.postOpNotes, current, replacement)}',
          ),
        );
      }
    }

    setState(() {
      _finding = false;
      _matches = found;
      _result = '${found.length} matching record(s) found.';
    });
  }

  Future<void> _updateOne(_BulkMatch match) async {
    final current = _currentController.text.trim();
    final replacement = _replaceController.text.trim();

    if (_updateType == 'Age -> Year Of Birth') {
      final p = patients.get(match.id);
      if (p == null || p.birth <= 0 || p.birth > 130) return;
      p.birth = DateTime.now().year - p.birth;
      patients.set(p);
    } else {
      final a = appointments.get(match.id);
      if (a == null) return;
      _applyAppointmentUpdate(a, current, replacement);
    }

    await _findMatches();
  }

  Future<void> _updateAll() async {
    if (_matches.isEmpty) return;

    setState(() {
      _updating = true;
      _result = null;
      _progressDone = 0;
      _progressTotal = _matches.length;
      _progressLabel = 'Updating 0 of ${_matches.length}';
    });

    final current = _currentController.text.trim();
    final replacement = _replaceController.text.trim();
    var updated = 0;

    if (_updateType == 'Age -> Year Of Birth') {
      for (final m in _matches) {
        final p = patients.get(m.id);
        if (p == null || p.birth <= 0 || p.birth > 130) continue;
        p.birth = DateTime.now().year - p.birth;
        patients.set(p);
        updated += 1;
        if (mounted) {
          setState(() {
            _progressDone = updated;
            _progressLabel = 'Updating $updated of $_progressTotal';
          });
        }
      }
    } else {
      for (final m in _matches) {
        final a = appointments.get(m.id);
        if (a == null) continue;
        _applyAppointmentUpdate(a, current, replacement);
        updated += 1;
        if (mounted) {
          setState(() {
            _progressDone = updated;
            _progressLabel = 'Updating $updated of $_progressTotal';
          });
        }
      }
    }

    await _findMatches();

    if (!mounted) return;
    setState(() {
      _updating = false;
      _result = 'Updated $updated record(s).';
      _progressDone = _progressTotal;
      _progressLabel = 'Completed $updated update(s).';
    });
  }

  @override
  Widget build(BuildContext context) {
    final isAgeMode = _updateType == 'Age -> Year Of Birth';

    return ContentDialog(
      constraints: const BoxConstraints(maxWidth: 920),
      title: const Text('Bulk Update'),
      content: SizedBox(
        width: 860,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Find matching records first, then update one-by-one or update all.',
              style: TextStyle(color: Color(0xFF5A7397)),
            ),
            const SizedBox(height: 10),
            ComboBox<String>(
              isExpanded: true,
              value: _updateType,
              items: const [
                ComboBoxItem(
                  value: 'Treatment Rename',
                  child: Text('Treatment Rename'),
                ),
                ComboBoxItem(
                  value: 'Appointment Text Replace',
                  child: Text('Appointment Text Replace'),
                ),
                ComboBoxItem(
                  value: 'Age -> Year Of Birth',
                  child: Text('Age -> Year Of Birth'),
                ),
              ],
              onChanged: (v) {
                if (v == null) return;
                setState(() {
                  _updateType = v;
                  _matches = const [];
                  _result = null;
                  _matchSearchController.clear();
                });
              },
            ),
            const SizedBox(height: 8),
            if (!isAgeMode) ...[
              Row(
                children: [
                  Expanded(
                    child: TextBox(
                      controller: _currentController,
                      placeholder: 'Find text',
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextBox(
                      controller: _replaceController,
                      placeholder: 'Replace text',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: ComboBox<String>(
                      isExpanded: true,
                      value: _matchMode,
                      items: const [
                        ComboBoxItem(
                          value: 'Exact',
                          child: Text('Exact match'),
                        ),
                        ComboBoxItem(
                          value: 'Contains',
                          child: Text('Contains / replace all'),
                        ),
                      ],
                      onChanged: (v) {
                        if (v == null) return;
                        setState(() => _matchMode = v);
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Checkbox(
                      checked: _caseSensitive,
                      content: const Text('Case sensitive'),
                      onChanged: (v) =>
                          setState(() => _caseSensitive = v ?? false),
                    ),
                  ),
                ],
              ),
            ] else ...[
              const Text(
                'This migration converts stored age values (0-130) into year of birth automatically.',
                style: TextStyle(
                  color: Color(0xFF355279),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
            const SizedBox(height: 8),
            Row(
              children: [
                AppButton(
                  onPressed: _finding || _updating ? null : _findMatches,
                  label: _finding ? 'Finding...' : 'Find',
                  variant: AppButtonVariant.secondary,
                ),
                const SizedBox(width: 8),
                AppButton(
                  onPressed: _updating || _matches.isEmpty ? null : _updateAll,
                  label: _updating ? 'Updating...' : 'Update All',
                ),
              ],
            ),
            if (_updating && _progressTotal > 0) ...[
              const SizedBox(height: 8),
              ProgressBar(value: _progressDone / _progressTotal),
              const SizedBox(height: 6),
              Text(
                _progressLabel,
                style: const TextStyle(
                  color: Color(0xFF355279),
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
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: TextBox(
                  controller: _matchSearchController,
                  placeholder: 'Search in results',
                  prefix: const Padding(
                    padding: EdgeInsets.only(left: 8),
                    child: Icon(
                      FluentIcons.search,
                      size: 12,
                      color: Color(0xFF6D84A8),
                    ),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 320),
              child: _matches.isEmpty
                  ? const Center(
                      child: Text(
                        'No matching records found yet.',
                        style: TextStyle(color: Color(0xFF6D84A8)),
                      ),
                    )
                  : _visibleMatches.isEmpty
                      ? const Center(
                          child: Text(
                            'No results match this search.',
                            style: TextStyle(color: Color(0xFF6D84A8)),
                          ),
                        )
                      : ListView.separated(
                          itemCount: _visibleMatches.length,
                          separatorBuilder: (_, __) => const Divider(size: 1),
                          itemBuilder: (context, index) {
                            final m = _visibleMatches[index];
                            return ListTile.selectable(
                              title: Text(m.title),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(m.subtitle),
                                  const SizedBox(height: 3),
                                  Text('Current: ${m.oldValue}'),
                                  Text('New: ${m.newValue}'),
                                ],
                              ),
                              trailing: AppButton(
                                onPressed:
                                    _updating || _finding ? null : () => _updateOne(m),
                                label: 'Update',
                                compact: true,
                              ),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
      actions: [
        AppButton(
          onPressed:
              _finding || _updating ? null : () => Navigator.pop(context),
          label: 'Close',
          variant: AppButtonVariant.secondary,
        ),
      ],
    );
  }
}
