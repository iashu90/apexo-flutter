import 'package:apexo/common_widgets/date_time_picker.dart';
import 'package:apexo/common_widgets/patient_picker.dart';
import 'package:apexo/common_widgets/teeth_picker.dart';
import 'package:apexo/core/theme/app_colors.dart';
import 'package:apexo/core/ui/components/app_button.dart';
import 'package:apexo/core/ui/components/app_dropdown_menu.dart';
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
    builder: (_) => _LabworkDialog(item: editingCopy),
  );
}

class _LabworkDialog extends StatefulWidget {
  final Labwork item;

  const _LabworkDialog({required this.item});

  @override
  State<_LabworkDialog> createState() => _LabworkDialogState();
}

class _LabworkDialogState extends State<_LabworkDialog> {
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
          const Icon(
            FluentIcons.test_beaker_solid,
            size: 20,
            color: AppColors.brandBlue,
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                labworks.get(widget.item.id) == null
                    ? 'New Labwork'
                    : 'Edit Labwork',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 2),
              const Text(
                'Create a new lab request with patient and case details',
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.textBlueMuted,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const Spacer(),
          IconButton(
            icon: const Icon(FluentIcons.chrome_close, size: 16),
            onPressed: _saving ? null : () => Navigator.pop(context),
          ),
        ],
      ),
      content: Container(
        color: AppColors.bgCard,
        child: SingleChildScrollView(
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
                  child: AppDropdownMenu<String>(
                    width: double.infinity,
                    value: selectedDoctorId ?? '__none__',
                    items: [
                      const AppDropdownItem<String>(
                        value: '__none__',
                        label: 'Select doctor',
                      ),
                      ...doctorsList.map(
                        (doctor) => AppDropdownItem<String>(
                          value: doctor.id,
                          label: doctor.title.trim().isEmpty
                              ? 'Unnamed doctor'
                              : doctor.title,
                        ),
                      ),
                    ],
                    onChanged: (id) {
                      setState(() {
                        widget.item.operatorsIDs =
                            id == '__none__' ? <String>[] : <String>[id];
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
                  child: AppDropdownMenu<String>(
                    width: double.infinity,
                    value: widget.item.lab.trim().isEmpty
                        ? '__none__'
                        : widget.item.lab,
                    items: [
                      const AppDropdownItem<String>(
                        value: '__none__',
                        label: 'Select laboratory',
                      ),
                      ...labOptions.map(
                        (lab) => AppDropdownItem<String>(
                          value: lab,
                          label: lab,
                        ),
                      ),
                    ],
                    onChanged: (lab) {
                      setState(() {
                        widget.item.lab = lab == '__none__' ? '' : lab;
                      });
                    },
                  ),
                ),
                _fieldBox(
                  width: isWide ? 330 : 460,
                  label: '${txt('typeOfWork')}:',
                  child: AppDropdownMenu<String>(
                    width: double.infinity,
                    value: widget.item.typeOfWork.isEmpty
                        ? '__none__'
                        : widget.item.typeOfWork,
                    items: const [
                      AppDropdownItem<String>(
                        value: '__none__',
                        label: 'Select type of work',
                      ),
                      AppDropdownItem<String>(
                          value: 'Zirconia Premium', label: 'Zirconia Premium'),
                      AppDropdownItem<String>(value: 'Zirconia', label: 'Zirconia'),
                      AppDropdownItem<String>(value: 'PFM', label: 'PFM'),
                      AppDropdownItem<String>(value: 'DMLS', label: 'DMLS'),
                      AppDropdownItem<String>(value: 'Full Metal', label: 'Full Metal'),
                      AppDropdownItem<String>(value: 'PMMA', label: 'PMMA'),
                      AppDropdownItem<String>(value: 'RPD', label: 'RPD'),
                      AppDropdownItem<String>(value: 'Denture', label: 'Denture'),
                      AppDropdownItem<String>(value: 'Implant', label: 'Implant'),
                      AppDropdownItem<String>(value: 'ESSIX', label: 'ESSIX'),
                      AppDropdownItem<String>(value: 'Other', label: 'Other'),
                    ],
                    onChanged: (v) => setState(
                      () => widget.item.typeOfWork = v == '__none__' ? '' : v,
                    ),
                  ),
                ),
                _fieldBox(
                  width: isWide ? 330 : 460,
                  label: '${txt('shade')}:',
                  child: AppDropdownMenu<String>(
                    width: double.infinity,
                    value: widget.item.shade.isEmpty ? '__none__' : widget.item.shade,
                    items: const [
                      AppDropdownItem<String>(
                        value: '__none__',
                        label: 'Select shade',
                      ),
                      AppDropdownItem<String>(value: '0M1', label: '0M1'),
                      AppDropdownItem<String>(value: '0M2', label: '0M2'),
                      AppDropdownItem<String>(value: '0M3', label: '0M3'),
                      AppDropdownItem<String>(value: '1M1', label: '1M1'),
                      AppDropdownItem<String>(value: '1M2', label: '1M2'),
                      AppDropdownItem<String>(value: '2L1.5', label: '2L1.5'),
                      AppDropdownItem<String>(value: '2L2.5', label: '2L2.5'),
                      AppDropdownItem<String>(value: '2M1', label: '2M1'),
                      AppDropdownItem<String>(value: '2M2', label: '2M2'),
                      AppDropdownItem<String>(value: '2M3', label: '2M3'),
                      AppDropdownItem<String>(value: '2R1.5', label: '2R1.5'),
                      AppDropdownItem<String>(value: '2R2.5', label: '2R2.5'),
                      AppDropdownItem<String>(value: '3L1.5', label: '3L1.5'),
                      AppDropdownItem<String>(value: '3L2.5', label: '3L2.5'),
                      AppDropdownItem<String>(value: '3M1', label: '3M1'),
                      AppDropdownItem<String>(value: '3M2', label: '3M2'),
                      AppDropdownItem<String>(value: '3M3', label: '3M3'),
                      AppDropdownItem<String>(value: '3R1.5', label: '3R1.5'),
                      AppDropdownItem<String>(value: '3R2.5', label: '3R2.5'),
                    ],
                    onChanged: (v) =>
                        setState(() => widget.item.shade = v == '__none__' ? '' : v),
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
          color: selected ? AppColors.brandBlue : AppColors.slate1004,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected ? AppColors.brandBlue : AppColors.violet1506,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : AppColors.textBlueStrong,
            fontWeight: FontWeight.w700,
            fontSize: 12,
          ),
        ),
      ),
    );
  }
}
