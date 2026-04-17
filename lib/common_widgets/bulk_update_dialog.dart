import 'package:apexo/features/appointments/appointments_store.dart';
import 'package:apexo/features/patients/patients_store.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/services.dart';

Future<void> showBulkUpdateDialog(BuildContext context) {
  return showDialog<void>(
    context: context,
    builder: (_) => const _BulkUpdateDialog(),
  );
}

class _BulkUpdateDialog extends StatefulWidget {
  const _BulkUpdateDialog();

  @override
  State<_BulkUpdateDialog> createState() => _BulkUpdateDialogState();
}

class _BulkUpdateDialogState extends State<_BulkUpdateDialog> {
  final _currentController = TextEditingController();
  final _replaceController = TextEditingController();
  final _ageValueController = TextEditingController();

  String _updateType = 'Treatment Rename';
  String _matchMode = 'Exact';
  String _ageMode = 'Keep years only (0-130)';
  String _appointmentField = 'Diagnosis';
  bool _caseSensitive = false;
  bool _isApplying = false;
  String? _result;

  @override
  void dispose() {
    _currentController.dispose();
    _replaceController.dispose();
    _ageValueController.dispose();
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

    if (_caseSensitive) {
      return value.replaceAll(current, replacement);
    }

    final pattern = RegExp(RegExp.escape(current), caseSensitive: false);
    return value.replaceAllMapped(pattern, (_) => replacement);
  }

  Future<void> _applyUpdate() async {
    setState(() {
      _isApplying = true;
      _result = null;
    });

    final current = _currentController.text.trim();
    final replacement = _replaceController.text.trim();

    int updatedAppointments = 0;
    int updatedPatients = 0;
    int updatedValues = 0;

    if (_updateType == 'Treatment Rename') {
      if (current.isEmpty) {
        setState(() {
          _isApplying = false;
          _result = 'Current treatment name is required.';
        });
        return;
      }

      for (final appointment in appointments.present.values.toList(growable: false)) {
        var changed = false;

        final nextTreatments = appointment.selectedTreatments.map((item) {
          final replaced = _replaceWithRule(item, current, replacement);
          if (replaced != item) {
            changed = true;
            updatedValues += 1;
          }
          return replaced;
        }).toList(growable: false);

        final nextSubTreatments = appointment.subTreatments.map((item) {
          final replaced = _replaceWithRule(item, current, replacement);
          if (replaced != item) {
            changed = true;
            updatedValues += 1;
          }
          return replaced;
        }).toList(growable: false);

        if (changed) {
          appointment.selectedTreatments = nextTreatments;
          appointment.subTreatments = nextSubTreatments;
          appointments.set(appointment);
          updatedAppointments += 1;
        }
      }
    } else if (_updateType == 'Appointment Text Replace') {
      if (current.isEmpty) {
        setState(() {
          _isApplying = false;
          _result = 'Current text is required.';
        });
        return;
      }

      for (final appointment in appointments.present.values.toList(growable: false)) {
        var changed = false;

        if (_appointmentField == 'Diagnosis') {
          final next = appointment.diagnosis.map((item) {
            final replaced = _replaceWithRule(item, current, replacement);
            if (replaced != item) {
              changed = true;
              updatedValues += 1;
            }
            return replaced;
          }).toList(growable: false);
          if (changed) appointment.diagnosis = next;
        } else if (_appointmentField == 'Pre-op Notes') {
          final next = _replaceWithRule(appointment.preOpNotes, current, replacement);
          if (next != appointment.preOpNotes) {
            appointment.preOpNotes = next;
            changed = true;
            updatedValues += 1;
          }
        } else if (_appointmentField == 'Post-op Notes') {
          final next = _replaceWithRule(appointment.postOpNotes, current, replacement);
          if (next != appointment.postOpNotes) {
            appointment.postOpNotes = next;
            changed = true;
            updatedValues += 1;
          }
        }

        if (changed) {
          appointments.set(appointment);
          updatedAppointments += 1;
        }
      }
    } else {
      final delta = int.tryParse(_ageValueController.text.trim()) ?? 0;

      for (final patient in patients.present.values.toList(growable: false)) {
        final previous = patient.birth;
        var next = previous;

        if (_ageMode == 'Keep years only (0-130)') {
          next = previous.clamp(0, 130);
        } else if (_ageMode == 'Set fixed years') {
          next = delta.clamp(0, 130);
        } else {
          next = (previous + delta).clamp(0, 130);
        }

        if (next != previous) {
          patient.birth = next;
          patients.set(patient);
          updatedPatients += 1;
          updatedValues += 1;
        }
      }
    }

    setState(() {
      _isApplying = false;
      _result =
          'Updated values: $updatedValues | Appointments: $updatedAppointments | Patients: $updatedPatients';
    });
  }

  @override
  Widget build(BuildContext context) {
    final requiresTextFields =
        _updateType == 'Treatment Rename' || _updateType == 'Appointment Text Replace';

    return ContentDialog(
      constraints: const BoxConstraints(maxWidth: 760),
      title: const Text('Bulk Update'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Run mass updates safely across appointments and patients.',
            style: TextStyle(color: Color(0xFF5A7397)),
          ),
          const SizedBox(height: 10),
          const Text('Update Type'),
          const SizedBox(height: 6),
          ComboBox<String>(
            isExpanded: true,
            value: _updateType,
            items: const [
              ComboBoxItem(value: 'Treatment Rename', child: Text('Treatment Rename')),
              ComboBoxItem(
                value: 'Appointment Text Replace',
                child: Text('Appointment Text Replace'),
              ),
              ComboBoxItem(value: 'Age Migration', child: Text('Age Migration')),
            ],
            onChanged: (v) => setState(() => _updateType = v ?? _updateType),
          ),
          const SizedBox(height: 10),
          if (_updateType == 'Age Migration') ...[
            const Text('Migration Rule'),
            const SizedBox(height: 6),
            ComboBox<String>(
              isExpanded: true,
              value: _ageMode,
              items: const [
                ComboBoxItem(
                  value: 'Keep years only (0-130)',
                  child: Text('Keep years only (0-130)'),
                ),
                ComboBoxItem(value: 'Set fixed years', child: Text('Set fixed years')),
                ComboBoxItem(value: 'Add years', child: Text('Add years')),
              ],
              onChanged: (v) => setState(() => _ageMode = v ?? _ageMode),
            ),
            const SizedBox(height: 8),
            TextBox(
              controller: _ageValueController,
              placeholder: _ageMode == 'Add years' ? 'Years to add (use negative to subtract)' : 'Age in years',
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'-?[0-9]*'))],
            ),
          ],
          if (_updateType == 'Appointment Text Replace') ...[
            const Text('Appointment Field'),
            const SizedBox(height: 6),
            ComboBox<String>(
              isExpanded: true,
              value: _appointmentField,
              items: const [
                ComboBoxItem(value: 'Diagnosis', child: Text('Diagnosis')),
                ComboBoxItem(value: 'Pre-op Notes', child: Text('Pre-op Notes')),
                ComboBoxItem(value: 'Post-op Notes', child: Text('Post-op Notes')),
              ],
              onChanged: (v) => setState(() => _appointmentField = v ?? _appointmentField),
            ),
            const SizedBox(height: 10),
          ],
          if (requiresTextFields) ...[
            const Text('Match Mode'),
            const SizedBox(height: 6),
            ComboBox<String>(
              isExpanded: true,
              value: _matchMode,
              items: const [
                ComboBoxItem(value: 'Exact', child: Text('Exact match')),
                ComboBoxItem(value: 'Contains', child: Text('Contains / replace all')), 
              ],
              onChanged: (v) => setState(() => _matchMode = v ?? _matchMode),
            ),
            const SizedBox(height: 8),
            TextBox(
              controller: _currentController,
              placeholder: 'Current text',
            ),
            const SizedBox(height: 8),
            TextBox(
              controller: _replaceController,
              placeholder: 'Replacement text (can be empty)',
            ),
            const SizedBox(height: 8),
            Checkbox(
              checked: _caseSensitive,
              content: const Text('Case sensitive'),
              onChanged: (v) => setState(() => _caseSensitive = v ?? false),
            ),
          ],
          if (_result != null) ...[
            const SizedBox(height: 10),
            Text(
              _result!,
              style: const TextStyle(
                color: Color(0xFF1459AD),
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ],
      ),
      actions: [
        Button(
          onPressed: _isApplying ? null : () => Navigator.pop(context),
          child: const Text('Close'),
        ),
        FilledButton(
          onPressed: _isApplying ? null : _applyUpdate,
          child: Text(_isApplying ? 'Applying...' : 'Apply Update'),
        ),
      ],
    );
  }
}
