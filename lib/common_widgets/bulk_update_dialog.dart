import 'package:apexo/features/appointments/appointment_model.dart';
import 'package:apexo/features/appointments/appointments_store.dart';
import 'package:apexo/features/patients/patients_store.dart';
import 'package:fluent_ui/fluent_ui.dart';

Future<void> showBulkUpdateDialog(BuildContext context) async {
  final passwordController = TextEditingController();
  String? error;

  final unlocked = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (context, setStateDialog) => ContentDialog(
        title: const Text('Bulk Update Access'),
        content: SizedBox(
          width: 360,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Enter password to continue.'),
              const SizedBox(height: 8),
              TextBox(
                controller: passwordController,
                placeholder: 'Password',
                obscureText: true,
                onChanged: (_) {
                  if (error != null) setStateDialog(() => error = null);
                },
              ),
              if (error != null) ...[
                const SizedBox(height: 6),
                Text(
                  error!,
                  style: const TextStyle(
                    color: Color(0xFFD6455D),
                    fontSize: 12,
                  ),
                ),
              ],
            ],
          ),
        ),
        actions: [
          Button(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (passwordController.text.trim() != '0001') {
                setStateDialog(() => error = 'Invalid password.');
                return;
              }
              Navigator.pop(dialogContext, true);
            },
            child: const Text('Continue'),
          ),
        ],
      ),
    ),
  );

  if (unlocked != true || !context.mounted) return;

  await showDialog<void>(
    context: context,
    builder: (_) => const _BulkUpdateDialog(),
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

  String _updateType = 'Treatment Rename';
  String _matchMode = 'Exact';
  bool _caseSensitive = false;

  bool _finding = false;
  bool _updating = false;
  String? _result;

  List<_BulkMatch> _matches = const [];

  @override
  void dispose() {
    _currentController.dispose();
    _replaceController.dispose();
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
      final nextTreatments =
          a.selectedTreatments.map((e) => _replaceWithRule(e, current, replacement));
      final nextSub = a.subTreatments.map((e) => _replaceWithRule(e, current, replacement));
      return !_listEquals(a.selectedTreatments, nextTreatments.toList(growable: false)) ||
          !_listEquals(a.subTreatments, nextSub.toList(growable: false));
    }

    final nextDiagnosis =
        a.diagnosis.map((e) => _replaceWithRule(e, current, replacement)).toList(growable: false);
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

  void _applyAppointmentUpdate(Appointment a, String current, String replacement) {
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

    a.diagnosis =
        a.diagnosis.map((e) => _replaceWithRule(e, current, replacement)).toList(growable: false);
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
      }
    } else {
      for (final m in _matches) {
        final a = appointments.get(m.id);
        if (a == null) continue;
        _applyAppointmentUpdate(a, current, replacement);
        updated += 1;
      }
    }

    await _findMatches();

    if (!mounted) return;
    setState(() {
      _updating = false;
      _result = 'Updated $updated record(s).';
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
                ComboBoxItem(value: 'Treatment Rename', child: Text('Treatment Rename')),
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
                        ComboBoxItem(value: 'Exact', child: Text('Exact match')),
                        ComboBoxItem(value: 'Contains', child: Text('Contains / replace all')),
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
                      onChanged: (v) => setState(() => _caseSensitive = v ?? false),
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
                FilledButton(
                  onPressed: _finding || _updating ? null : _findMatches,
                  child: Text(_finding ? 'Finding...' : 'Find'),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  style: ButtonStyle(
                    backgroundColor: WidgetStateProperty.resolveWith((states) {
                      if (states.contains(WidgetState.disabled)) {
                        return const Color(0xFFD0D5DD);
                      }
                      return const Color(0xFF2D7BD8);
                    }),
                  ),
                  onPressed: _updating || _matches.isEmpty ? null : _updateAll,
                  child: Text(_updating ? 'Updating...' : 'Update All'),
                ),
              ],
            ),
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
                        'No matching records found yet.',
                        style: TextStyle(color: Color(0xFF6D84A8)),
                      ),
                    )
                  : ListView.separated(
                      itemCount: _matches.length,
                      separatorBuilder: (_, __) => const Divider(size: 1),
                      itemBuilder: (context, index) {
                        final m = _matches[index];
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
                          trailing: Button(
                            onPressed: _updating || _finding
                                ? null
                                : () => _updateOne(m),
                            child: const Text('Update'),
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
