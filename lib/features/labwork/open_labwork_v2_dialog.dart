import 'package:apexo/common_widgets/date_time_picker.dart';
import 'package:apexo/common_widgets/patient_picker.dart';
import 'package:apexo/common_widgets/teeth_picker.dart';
import 'package:apexo/core/ui/components/app_button.dart';
import 'package:apexo/features/doctors/doctors_store.dart';
import 'package:apexo/features/labwork/labwork_model.dart';
import 'package:apexo/features/labwork/labworks_store.dart';
import 'package:apexo/features/settings/settings_stores.dart';
import 'package:apexo/services/localization/locale.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/services.dart';

Future<void> openLabworkDialog(BuildContext context, [Labwork? labwork]) {
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
  Set<String> _selectedTeeth = {};
  double _pricePerUnit = 0;
  bool _saving = false;
  String _deliveryState = 'in_lab';

  @override
  void initState() {
    super.initState();
    _notesCtrl = TextEditingController(text: widget.item.note);
    _selectedTeeth = Set<String>.from(widget.item.selectedTeeth);
    if (widget.item.noOfUnits > 0) {
      _pricePerUnit = widget.item.price / widget.item.noOfUnits;
    }
    _deliveryState = widget.item.deliveredToPatient
        ? 'delivery'
        : widget.item.deliveredToDoctor
            ? 'ready'
            : 'in_lab';
  }

  @override
  void dispose() {
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    widget.item.note = _notesCtrl.text.trim();
    widget.item.selectedTeeth = _selectedTeeth.toList();
    labworks.set(widget.item);
    if (mounted) Navigator.pop(context);
  }

  void _setDeliveryState(String state) {
    setState(() {
      _deliveryState = state;
      if (state == 'in_lab') {
        widget.item.deliveredToDoctor = false;
        widget.item.deliveredToPatient = false;
      } else if (state == 'ready') {
        widget.item.deliveredToDoctor = true;
        widget.item.deliveredToPatient = false;
      } else {
        widget.item.deliveredToDoctor = true;
        widget.item.deliveredToPatient = true;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final isWide = width > 1150;
    final doctorsList = doctors.present.values.toList(growable: false)
      ..sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
    final selectedDoctorId =
        widget.item.operatorsIDs.isEmpty ? null : widget.item.operatorsIDs.first;

    final labOptions = <String>{
      ...labworks.predefinedLabs,
      if (widget.item.lab.trim().isNotEmpty) widget.item.lab.trim(),
    }.toList(growable: false)
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

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
                  child: ComboBox<String>(
                    isExpanded: true,
                    value: selectedDoctorId,
                    items: doctorsList
                        .map(
                          (doctor) => ComboBoxItem<String>(
                            value: doctor.id,
                            child: Text(
                              doctor.title.trim().isEmpty
                                  ? 'Unnamed doctor'
                                  : doctor.title,
                            ),
                          ),
                        )
                        .toList(growable: false),
                    placeholder: const Text('Select doctor'),
                    onChanged: (id) {
                      setState(() {
                        widget.item.operatorsIDs =
                            id == null ? <String>[] : <String>[id];
                      });
                    },
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
                  child: ComboBox<String>(
                    isExpanded: true,
                    value: widget.item.lab.trim().isEmpty ? null : widget.item.lab,
                    items: labOptions
                        .map(
                          (lab) => ComboBoxItem<String>(
                            value: lab,
                            child: Text(lab),
                          ),
                        )
                        .toList(growable: false),
                    placeholder: const Text('Select laboratory'),
                    onChanged: (lab) {
                      setState(() {
                        widget.item.lab = lab ?? '';
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
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _toggleChoice(
                        label: 'UNPAID',
                        selected: !widget.item.paid,
                        onTap: () => setState(() => widget.item.paid = false),
                      ),
                      _toggleChoice(
                        label: 'PAID',
                        selected: widget.item.paid,
                        onTap: () => setState(() => widget.item.paid = true),
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
            InfoLabel(
              label: 'Labwork Status:',
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _toggleChoice(
                    label: 'In Lab',
                    selected: _deliveryState == 'in_lab',
                    onTap: () => _setDeliveryState('in_lab'),
                  ),
                  _toggleChoice(
                    label: 'Ready',
                    selected: _deliveryState == 'ready',
                    onTap: () => _setDeliveryState('ready'),
                  ),
                  _toggleChoice(
                    label: 'Delivered',
                    selected: _deliveryState == 'delivery',
                    onTap: () => _setDeliveryState('delivery'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
          AppButton(
          onPressed: _saving ? null : () => Navigator.pop(context),
            label: 'Cancel',
            variant: AppButtonVariant.secondary,
        ),
          AppButton(
          onPressed: _saving ? null : _save,
            label: _saving ? 'Saving...' : 'Save',
            variant: AppButtonVariant.primary,
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

  Widget _toggleChoice({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF2D7BD8) : const Color(0xFFEFF4FB),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color:
                selected ? const Color(0xFF2D7BD8) : const Color(0xFFD6E2F0),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : const Color(0xFF355279),
            fontWeight: FontWeight.w700,
            fontSize: 12,
          ),
        ),
      ),
    );
  }
}
