import 'package:apexo/common_widgets/date_time_picker.dart';
import 'package:apexo/common_widgets/operators_picker.dart';
import 'package:apexo/common_widgets/patient_picker.dart';
import 'package:apexo/common_widgets/teeth_picker.dart';
import 'package:apexo/features/labwork/labwork_model.dart';
import 'package:apexo/features/labwork/labworks_store.dart';
import 'package:apexo/features/labwork/open_labwork_panel.dart';
import 'package:apexo/features/settings/settings_stores.dart';
import 'package:apexo/services/localization/locale.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/services.dart';

Future<void> openLabworkV2Dialog(BuildContext context, [Labwork? labwork]) {
  final editingCopy = Labwork.fromJson(labwork?.toJson() ?? {});
  return showDialog<void>(
    context: context,
    builder: (_) => _LabworkV2Dialog(item: editingCopy),
  );
}

class _LabworkV2Dialog extends StatefulWidget {
  final Labwork item;

  const _LabworkV2Dialog({required this.item});

  @override
  State<_LabworkV2Dialog> createState() => _LabworkV2DialogState();
}

class _LabworkV2DialogState extends State<_LabworkV2Dialog> {
  late final TextEditingController _notesCtrl;
  late final TextEditingController _labCtrl;
  final FocusNode _labFocusNode = FocusNode();
  Set<String> _selectedTeeth = {};
  double _pricePerUnit = 0;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _notesCtrl = TextEditingController(text: widget.item.note);
    _labCtrl = TextEditingController(text: widget.item.lab);
    _selectedTeeth = Set<String>.from(widget.item.selectedTeeth);
    if (widget.item.noOfUnits > 0) {
      _pricePerUnit = widget.item.price / widget.item.noOfUnits;
    }
  }

  @override
  void dispose() {
    _notesCtrl.dispose();
    _labCtrl.dispose();
    _labFocusNode.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    widget.item.note = _notesCtrl.text.trim();
    // The TagInputWidget clears the controller after a selection, so we only
    // override widget.item.lab from the controller when it still has text
    // (free-typed value). When a suggestion is picked, widget.item.lab is
    // already updated via onChanged.
    final typedLab = _labCtrl.text.trim();
    if (typedLab.isNotEmpty) widget.item.lab = typedLab;
    widget.item.selectedTeeth = _selectedTeeth.toList();
    labworks.set(widget.item);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final isWide = width > 1150;

    return ContentDialog(
      constraints: const BoxConstraints(maxWidth: 1140, maxHeight: 760),
      title: Row(
        children: [
          Text(labworks.get(widget.item.id) == null
              ? 'New Labwork'
              : 'Edit Labwork'),
          const Spacer(),
          IconButton(
            icon: const Icon(FluentIcons.chrome_close, size: 16),
            onPressed: _saving ? null : () => Navigator.pop(context),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _fieldBox(
                  width: isWide ? 330 : 460,
                  label: '${txt('date')}:',
                  child: DateTimePicker(
                    initValue: widget.item.date,
                    onChange: (d) => widget.item.date = d,
                    buttonText: txt('changeDate'),
                  ),
                ),
                _fieldBox(
                  width: isWide ? 330 : 460,
                  label: '${txt('patient')}:',
                  child: PatientPicker(
                    value: widget.item.patientID,
                    onChanged: (id) => widget.item.patientID = id,
                  ),
                ),
                _fieldBox(
                  width: isWide ? 330 : 460,
                  label: '${txt('doctors')}:',
                  child: OperatorsPicker(
                    value: widget.item.operatorsIDs,
                    onChanged: (ids) => widget.item.operatorsIDs = ids,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _fieldBox(
                  width: isWide ? 330 : 460,
                  label: '${txt('laboratory')}:',
                  child: LaboratoryPicker(
                    value: widget.item.lab,
                    controller: _labCtrl,
                    focusNode: _labFocusNode,
                    onChanged: (lab) {
                      if (lab == null) return;
                      setState(() {
                        _labCtrl.text = lab;
                        widget.item.lab = lab;
                      });
                    },
                  ),
                ),
                _fieldBox(
                  width: isWide ? 330 : 460,
                  label: '${txt('typeOfWork')}:',
                  child: ComboBox<String>(
                    value: widget.item.typeOfWork.isEmpty
                        ? null
                        : widget.item.typeOfWork,
                    items: const [
                      'Zirconia Premium',
                      'Zirconia',
                      'PFM',
                      'DMLS',
                      'Full Metal',
                      'PMMA',
                      'RPD',
                      'Denture',
                      'Implant',
                      'ESSIX',
                      'Other',
                    ]
                        .map((v) =>
                            ComboBoxItem<String>(value: v, child: Text(v)))
                        .toList(growable: false),
                    placeholder: const Text('Select type of work'),
                    onChanged: (v) =>
                        setState(() => widget.item.typeOfWork = v ?? ''),
                  ),
                ),
                _fieldBox(
                  width: isWide ? 330 : 460,
                  label: '${txt('shade')}:',
                  child: ComboBox<String>(
                    value: widget.item.shade.isEmpty ? null : widget.item.shade,
                    items: const [
                      '0M1',
                      '0M2',
                      '0M3',
                      '1M1',
                      '1M2',
                      '2L1.5',
                      '2L2.5',
                      '2M1',
                      '2M2',
                      '2M3',
                      '2R1.5',
                      '2R2.5',
                      '3L1.5',
                      '3L2.5',
                      '3M1',
                      '3M2',
                      '3M3',
                      '3R1.5',
                      '3R2.5',
                    ]
                        .map((v) =>
                            ComboBoxItem<String>(value: v, child: Text(v)))
                        .toList(growable: false),
                    placeholder: const Text('Select shade'),
                    onChanged: (v) =>
                        setState(() => widget.item.shade = v ?? ''),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            TeethPicker(
              selectedTeeth: _selectedTeeth,
              isAdult: _selectedTeeth.every(
                (t) =>
                    t.startsWith('1') ||
                    t.startsWith('2') ||
                    t.startsWith('3') ||
                    t.startsWith('4'),
              ),
              onChanged: (teeth) {
                setState(() {
                  _selectedTeeth = teeth;
                  widget.item.selectedTeeth = teeth.toList();
                });
              },
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _fieldBox(
                  width: isWide ? 220 : 460,
                  label: '${txt('noOfUnits')}:',
                  child: NumberBox(
                    clearButton: false,
                    mode: SpinButtonPlacementMode.inline,
                    value: widget.item.noOfUnits.toDouble(),
                    min: 0,
                    onChanged: (n) {
                      setState(() {
                        widget.item.noOfUnits = n?.toInt() ?? 0;
                        widget.item.price =
                            _pricePerUnit * widget.item.noOfUnits;
                      });
                    },
                  ),
                ),
                _fieldBox(
                  width: isWide ? 220 : 460,
                  label: 'Price per Unit:',
                  child: NumberBox(
                    clearButton: false,
                    value: _pricePerUnit,
                    min: 0,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    onChanged: (n) {
                      setState(() {
                        _pricePerUnit = n ?? 0;
                        widget.item.price =
                            _pricePerUnit * widget.item.noOfUnits;
                      });
                    },
                  ),
                ),
                _fieldBox(
                  width: isWide ? 260 : 460,
                  label:
                      '${txt('priceIn')} ${globalSettings.get('currency_______').value}:',
                  child: NumberBox(
                    clearButton: false,
                    value: widget.item.price,
                    min: 0,
                    onChanged: (n) {
                      setState(() {
                        widget.item.price = n ?? 0;
                        if (widget.item.noOfUnits > 0) {
                          _pricePerUnit =
                              widget.item.price / widget.item.noOfUnits;
                        }
                      });
                    },
                  ),
                ),
                _fieldBox(
                  width: isWide ? 330 : 460,
                  label: 'Payment Status:',
                  child: Row(
                    children: [
                      Checkbox(
                        checked: widget.item.paid,
                        onChanged: (v) =>
                            setState(() => widget.item.paid = v ?? false),
                        content: Text(
                            widget.item.paid ? txt('paid') : txt('unpaid')),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextBox(
              controller: _notesCtrl,
              placeholder: '${txt('orderNotes')}...',
              minLines: 1,
              maxLines: 3,
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 18,
              runSpacing: 8,
              children: [
                Checkbox(
                  checked: widget.item.deliveredToDoctor,
                  onChanged: (v) => setState(
                      () => widget.item.deliveredToDoctor = v ?? false),
                  content: const Text('Ready (Delivered to Doctor)'),
                ),
                Checkbox(
                  checked: widget.item.deliveredToPatient,
                  onChanged: (v) => setState(
                      () => widget.item.deliveredToPatient = v ?? false),
                  content: const Text('Delivered (to Patient)'),
                ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        Button(
          onPressed: _saving ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          style: ButtonStyle(
            backgroundColor: WidgetStateProperty.all(const Color(0xFF2D7BD8)),
          ),
          onPressed: _saving ? null : _save,
          child: Text(_saving ? 'Saving...' : 'Save'),
        ),
      ],
    );
  }

  Widget _fieldBox({
    required double width,
    required String label,
    required Widget child,
  }) {
    return SizedBox(
      width: width,
      child: InfoLabel(
        label: label,
        child: child,
      ),
    );
  }
}
