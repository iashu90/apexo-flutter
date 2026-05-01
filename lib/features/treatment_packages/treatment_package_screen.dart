import 'package:apexo/core/theme/app_colors.dart';
import 'package:apexo/core/ui/components/app_button.dart';
import 'package:apexo/features/doctors/doctor_model.dart';
import 'package:apexo/features/doctors/doctors_store.dart';
import 'package:apexo/features/patients/patient_model.dart';
import 'package:apexo/features/patients/patients_store.dart';
import 'package:apexo/utils/uuid.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/material.dart' as material;

enum TreatmentPlanStatus { active, completed, cancelled }

extension _TreatmentPlanStatusLabel on TreatmentPlanStatus {
  String get label {
    switch (this) {
      case TreatmentPlanStatus.active:
        return 'Active';
      case TreatmentPlanStatus.completed:
        return 'Completed';
      case TreatmentPlanStatus.cancelled:
        return 'Cancelled';
    }
  }
}

class TreatmentSittingDraft {
  final String id;
  double plannedAmount;
  double paidAmount;
  DateTime dueDate;
  String? doctorId;
  String notes;
  bool completed;

  TreatmentSittingDraft({
    required this.id,
    required this.plannedAmount,
    required this.paidAmount,
    required this.dueDate,
    this.doctorId,
    this.notes = '',
    this.completed = false,
  });
}

class TreatmentPlanDraft {
  String? patientId;
  String planName;
  String templateName;
  double totalPackageCost;
  int estimatedSittings;
  TreatmentPlanStatus status;
  String notes;
  List<TreatmentSittingDraft> sittings;

  TreatmentPlanDraft({
    this.patientId,
    required this.planName,
    this.templateName = 'Custom',
    required this.totalPackageCost,
    required this.estimatedSittings,
    required this.status,
    required this.notes,
    required this.sittings,
  });

  int get completedSittings => sittings.where((s) => s.completed).length;

  double get totalPaid =>
      sittings.fold<double>(0, (sum, sitting) => sum + sitting.paidAmount);

  double get remainingDue => totalPackageCost - totalPaid;

  double get plannedSum =>
      sittings.fold<double>(0, (sum, sitting) => sum + sitting.plannedAmount);
}

class _TreatmentPackageRepository {
  static final _TreatmentPackageRepository instance =
      _TreatmentPackageRepository._();

  _TreatmentPackageRepository._();

  final List<TreatmentPlanDraft> plans = <TreatmentPlanDraft>[];

  void save(TreatmentPlanDraft plan) {
    plans.add(plan);
  }
}

class _PackageTemplate {
  final String name;
  final int sittings;
  final double totalCost;
  final List<String> defaultNotes;

  const _PackageTemplate({
    required this.name,
    required this.sittings,
    required this.totalCost,
    this.defaultNotes = const <String>[],
  });
}

const List<_PackageTemplate> _packageTemplates = [
  _PackageTemplate(
    name: 'Custom',
    sittings: 1,
    totalCost: 0,
  ),
  _PackageTemplate(
    name: 'RCT Package',
    sittings: 3,
    totalCost: 12000,
    defaultNotes: ['Consultation', 'Canal prep', 'Obturation'],
  ),
  _PackageTemplate(
    name: 'Scaling Package',
    sittings: 2,
    totalCost: 4000,
    defaultNotes: ['Full mouth scaling', 'Review'],
  ),
  _PackageTemplate(
    name: 'Ortho Starter',
    sittings: 6,
    totalCost: 30000,
    defaultNotes: ['Imaging', 'Bonding', 'Monthly follow-up'],
  ),
  _PackageTemplate(
    name: 'Extraction + Review',
    sittings: 2,
    totalCost: 7000,
    defaultNotes: ['Extraction', 'Post-op review'],
  ),
];

Future<void> showTreatmentPackageManagerDialog({
  required BuildContext context,
}) async {
  await showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) {
      final size = MediaQuery.of(dialogContext).size;
      final width = (size.width - 36).clamp(360.0, 1240.0);
      final height = (size.height - 32).clamp(520.0, 860.0);
      return ContentDialog(
        constraints: BoxConstraints(
          maxWidth: width,
          maxHeight: height,
        ),
        content: SizedBox(
          width: width,
          height: height,
          child: const _TreatmentPackageManagerScreen(),
        ),
      );
    },
  );
}

class _TreatmentPackageManagerScreen extends StatefulWidget {
  const _TreatmentPackageManagerScreen();

  @override
  State<_TreatmentPackageManagerScreen> createState() =>
      _TreatmentPackageManagerScreenState();
}

class _TreatmentPackageManagerScreenState
    extends State<_TreatmentPackageManagerScreen> {
  final TextEditingController _planNameCtrl = TextEditingController();
  final TextEditingController _totalCostCtrl = TextEditingController(text: '0');
  final TextEditingController _estimatedSittingsCtrl =
      TextEditingController(text: '1');
  final TextEditingController _notesCtrl = TextEditingController();
  final Map<String, TextEditingController> _plannedControllers = {};
  final Map<String, TextEditingController> _paidControllers = {};
  final Map<String, TextEditingController> _notesControllers = {};

  TreatmentPlanStatus _status = TreatmentPlanStatus.active;
  String? _selectedPatientId;
  String _selectedTemplate = 'Custom';
  final List<TreatmentSittingDraft> _sittings = <TreatmentSittingDraft>[];

  @override
  void initState() {
    super.initState();
    _addSitting();
  }

  @override
  void dispose() {
    _planNameCtrl.dispose();
    _totalCostCtrl.dispose();
    _estimatedSittingsCtrl.dispose();
    _notesCtrl.dispose();
    for (final controller in _plannedControllers.values) {
      controller.dispose();
    }
    for (final controller in _paidControllers.values) {
      controller.dispose();
    }
    for (final controller in _notesControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  double _parseCurrency(String raw) {
    return double.tryParse(raw.trim()) ?? 0;
  }

  int _parseInt(String raw) {
    return int.tryParse(raw.trim()) ?? 0;
  }

  double get _totalPackageCost => _parseCurrency(_totalCostCtrl.text);

  double get _plannedSum =>
      _sittings.fold<double>(0, (sum, row) => sum + row.plannedAmount);

  double get _totalPaid =>
      _sittings.fold<double>(0, (sum, row) => sum + row.paidAmount);

  int get _completedSittings => _sittings.where((row) => row.completed).length;

  int get _estimatedSittings => _parseInt(_estimatedSittingsCtrl.text);

  double get _remainingDue => _totalPackageCost - _totalPaid;

  bool get _plannedMismatch => (_plannedSum - _totalPackageCost).abs() > 0.01;

  TextEditingController _plannedControllerFor(TreatmentSittingDraft row) {
    return _plannedControllers.putIfAbsent(
      row.id,
      () => TextEditingController(
        text: row.plannedAmount == 0 ? '' : row.plannedAmount.toStringAsFixed(2),
      ),
    );
  }

  TextEditingController _paidControllerFor(TreatmentSittingDraft row) {
    return _paidControllers.putIfAbsent(
      row.id,
      () => TextEditingController(
        text: row.paidAmount == 0 ? '' : row.paidAmount.toStringAsFixed(2),
      ),
    );
  }

  TextEditingController _noteControllerFor(TreatmentSittingDraft row) {
    return _notesControllers.putIfAbsent(
      row.id,
      () => TextEditingController(text: row.notes),
    );
  }

  void _syncRowControllers(TreatmentSittingDraft row) {
    final planned = _plannedControllers[row.id];
    final paid = _paidControllers[row.id];
    final note = _notesControllers[row.id];
    final plannedText = row.plannedAmount == 0 ? '' : row.plannedAmount.toStringAsFixed(2);
    final paidText = row.paidAmount == 0 ? '' : row.paidAmount.toStringAsFixed(2);
    if (planned != null && planned.text != plannedText) {
      planned.text = plannedText;
    }
    if (paid != null && paid.text != paidText) {
      paid.text = paidText;
    }
    if (note != null && note.text != row.notes) {
      note.text = row.notes;
    }
  }

  void _removeRowControllers(String rowId) {
    _plannedControllers.remove(rowId)?.dispose();
    _paidControllers.remove(rowId)?.dispose();
    _notesControllers.remove(rowId)?.dispose();
  }

  void _applyEstimatedSittings(int count) {
    final safeCount = count < 1 ? 1 : count;
    setState(() {
      if (_sittings.length > safeCount) {
        final removed = _sittings.sublist(safeCount).map((s) => s.id).toList(growable: false);
        _sittings.removeRange(safeCount, _sittings.length);
        for (final rowId in removed) {
          _removeRowControllers(rowId);
        }
      } else {
        while (_sittings.length < safeCount) {
          _sittings.add(
            TreatmentSittingDraft(
              id: uuid(),
              plannedAmount: 0,
              paidAmount: 0,
              dueDate: DateTime.now().add(Duration(days: 7 * (_sittings.length + 1))),
            ),
          );
        }
      }
      _estimatedSittingsCtrl.text = safeCount.toString();
    });
  }

  void _applyTemplateByName(String templateName) {
    final template = _packageTemplates.firstWhere(
      (item) => item.name == templateName,
      orElse: () => _packageTemplates.first,
    );
    setState(() {
      _selectedTemplate = template.name;
      if (template.name != 'Custom') {
        _planNameCtrl.text = template.name;
        _totalCostCtrl.text = template.totalCost.toStringAsFixed(0);
        _notesCtrl.text = template.defaultNotes.join(', ');
      }
    });
    _applyEstimatedSittings(template.sittings);
    if (template.totalCost > 0) {
      final split = template.totalCost / template.sittings;
      setState(() {
        for (final row in _sittings) {
          row.plannedAmount = split;
          _syncRowControllers(row);
        }
      });
    }
  }

  void _addSitting() {
    setState(() {
      _sittings.add(
        TreatmentSittingDraft(
          id: uuid(),
          plannedAmount: 0,
          paidAmount: 0,
          dueDate: DateTime.now().add(Duration(days: 7 * (_sittings.length + 1))),
        ),
      );
      _estimatedSittingsCtrl.text = _sittings.length.toString();
    });
  }

  void _removeSitting(String id) {
    setState(() {
      _sittings.removeWhere((s) => s.id == id);
      _removeRowControllers(id);
      if (_sittings.isEmpty) {
        _addSitting();
      } else {
        _estimatedSittingsCtrl.text = _sittings.length.toString();
      }
    });
  }

  Future<void> _pickDueDate(int index) async {
    final initial = _sittings[index].dueDate;
    final picked = await material.showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime.now().subtract(const Duration(days: 3650)),
      lastDate: DateTime.now().add(const Duration(days: 3650)),
    );
    if (picked == null) return;
    setState(() {
      _sittings[index].dueDate = DateTime(picked.year, picked.month, picked.day);
    });
  }

  Future<void> _handleTotalCostChanged() async {
    if (_sittings.isEmpty) return;

    final total = _totalPackageCost;
    final action = await showDialog<String>(
      context: context,
      builder: (dialogContext) => ContentDialog(
        title: const Text('Package Cost Changed'),
        content: const Text(
          'You changed the total package cost. Auto-distribute across sittings or keep manual amounts?',
        ),
        actions: [
          AppButton(
            label: 'Manual Adjust',
            variant: AppButtonVariant.secondary,
            onPressed: () => Navigator.pop(dialogContext, 'manual'),
          ),
          AppButton(
            label: 'Auto-Distribute',
            onPressed: () => Navigator.pop(dialogContext, 'auto'),
          ),
        ],
      ),
    );

    if (action != 'auto') return;

    final count = _sittings.length;
    if (count == 0) return;
    final double split = count == 0 ? 0.0 : total / count;
    setState(() {
      for (var i = 0; i < _sittings.length; i++) {
        _sittings[i].plannedAmount = split;
        _syncRowControllers(_sittings[i]);
      }
    });
  }

  void _savePlan() {
    final name = _planNameCtrl.text.trim();
    if (name.isEmpty) {
      _showError('Plan name is required.');
      return;
    }
    if (_sittings.isEmpty) {
      _showError('Add at least one sitting.');
      return;
    }

    final draft = TreatmentPlanDraft(
      patientId: _selectedPatientId,
      planName: name,
      templateName: _selectedTemplate,
      totalPackageCost: _totalPackageCost,
      estimatedSittings: _estimatedSittings,
      status: _status,
      notes: _notesCtrl.text.trim(),
      sittings: _sittings
          .map(
            (s) => TreatmentSittingDraft(
              id: s.id,
              plannedAmount: s.plannedAmount,
              paidAmount: s.paidAmount,
              dueDate: s.dueDate,
              doctorId: s.doctorId,
              notes: s.notes,
              completed: s.completed,
            ),
          )
          .toList(growable: false),
    );

    _TreatmentPackageRepository.instance.save(draft);
    if (!mounted) return;
    Navigator.pop(context);
  }

  void _showError(String message) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => ContentDialog(
        title: const Text('Validation'),
        content: Text(message),
        actions: [
          AppButton(
            label: 'OK',
            onPressed: () => Navigator.pop(dialogContext),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final doctorItems = doctors.present.values.toList(growable: false)
      ..sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
    final patientItems = patients.present.values.toList(growable: false)
      ..sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Treatment Package Management',
          style: TextStyle(
            color: AppColors.blue750,
            fontSize: 22,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'Create package plans with sittings, doctor assignment, and financial tracking.',
          style: TextStyle(
            color: AppColors.textBlueMuted,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 10),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final stacked = constraints.maxWidth < 900;
              final detailsCard = _buildPlanDetailsCard(patientItems);
              final summaryCard = _buildSummaryCard();

              return Column(
                children: [
                  if (stacked)
                    Column(
                      children: [
                        detailsCard,
                        const SizedBox(height: 8),
                        summaryCard,
                      ],
                    )
                  else
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(flex: 7, child: detailsCard),
                        const SizedBox(width: 8),
                        Expanded(flex: 5, child: summaryCard),
                      ],
                    ),
                  const SizedBox(height: 10),
                  Expanded(child: _buildSittingsTable(doctorItems)),
                ],
              );
            },
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            AppButton(
              label: 'Cancel',
              variant: AppButtonVariant.secondary,
              onPressed: () => Navigator.pop(context),
            ),
            const SizedBox(width: 8),
            AppButton(
              label: '+ Add Sitting',
              variant: AppButtonVariant.secondary,
              onPressed: _addSitting,
            ),
            const Spacer(),
            AppButton(
              label: 'Save Plan',
              onPressed: _savePlan,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildPlanDetailsCard(List<Patient> patientItems) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.violet1506),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Plan Details',
            style: TextStyle(
              color: AppColors.blue700,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: ComboBox<String>(
                  isExpanded: true,
                  value: _selectedPatientId,
                  placeholder: const Text('Assign Patient'),
                  items: patientItems
                      .map(
                        (patient) => ComboBoxItem<String>(
                          value: patient.id,
                          child: Text(
                            patient.title.trim().isEmpty
                                ? 'Unnamed patient'
                                : patient.title.trim(),
                          ),
                        ),
                      )
                      .toList(growable: false),
                  onChanged: (value) {
                    setState(() => _selectedPatientId = value);
                  },
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 220,
                child: ComboBox<String>(
                  isExpanded: true,
                  value: _selectedTemplate,
                  items: _packageTemplates
                      .map(
                        (template) => ComboBoxItem<String>(
                          value: template.name,
                          child: Text(template.name),
                        ),
                      )
                      .toList(growable: false),
                  onChanged: (value) {
                    if (value == null) return;
                    _applyTemplateByName(value);
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextBox(
                  controller: _planNameCtrl,
                  placeholder: 'Plan name (e.g. Invisalign Package)',
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 180,
                child: TextBox(
                  controller: _totalCostCtrl,
                  placeholder: 'Total Cost',
                  onSubmitted: (_) => _handleTotalCostChanged(),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              SizedBox(
                width: 180,
                child: TextBox(
                  controller: _estimatedSittingsCtrl,
                  placeholder: 'Estimated Sittings',
                  onSubmitted: (value) {
                    _applyEstimatedSittings(_parseInt(value));
                  },
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 180,
                child: ComboBox<TreatmentPlanStatus>(
                  isExpanded: true,
                  value: _status,
                  items: TreatmentPlanStatus.values
                      .map(
                        (status) => ComboBoxItem<TreatmentPlanStatus>(
                          value: status,
                          child: Text(status.label),
                        ),
                      )
                      .toList(growable: false),
                  onChanged: (value) {
                    if (value == null) return;
                    setState(() => _status = value);
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          TextBox(
            controller: _notesCtrl,
            maxLines: 3,
            placeholder: 'Internal notes',
          ),
          if (_plannedMismatch) ...[
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.amber1002,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.amber200),
              ),
              child: Text(
                'Warning: Planned sum (${_plannedSum.toStringAsFixed(2)}) does not match total package cost (${_totalPackageCost.toStringAsFixed(2)}).',
                style: const TextStyle(
                  color: AppColors.amber500,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSummaryCard() {
    final target = _estimatedSittings <= 0 ? _sittings.length : _estimatedSittings;
    final double progress =
        target == 0 ? 0.0 : (_completedSittings / target).clamp(0.0, 1.0).toDouble();

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.violet1506),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Plan Summary',
            style: TextStyle(
              color: AppColors.blue700,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Progress: $_completedSittings / $target Completed',
            style: const TextStyle(
              color: AppColors.blue7002,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          ProgressBar(value: progress),
          const SizedBox(height: 10),
          _summaryLine('Total Package Cost', _totalPackageCost.toStringAsFixed(2)),
          _summaryLine('Planned Sum', _plannedSum.toStringAsFixed(2)),
          _summaryLine('Total Paid', _totalPaid.toStringAsFixed(2)),
          _summaryLine('Remaining Due', _remainingDue.toStringAsFixed(2)),
        ],
      ),
    );
  }

  Widget _summaryLine(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                color: AppColors.textBlueMuted,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              color: AppColors.blue700,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSittingsTable(List<Doctor> doctorItems) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.violet1506),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Sittings',
            style: TextStyle(
              color: AppColors.blue700,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          _buildTableHeader(),
          const SizedBox(height: 6),
          Expanded(
            child: ReorderableListView.builder(
              buildDefaultDragHandles: false,
              itemCount: _sittings.length,
              onReorder: (oldIndex, newIndex) {
                setState(() {
                  if (newIndex > oldIndex) newIndex -= 1;
                  final item = _sittings.removeAt(oldIndex);
                  _sittings.insert(newIndex, item);
                });
              },
              itemBuilder: (context, index) {
                final row = _sittings[index];
                return _buildSittingRow(
                  key: ValueKey(row.id),
                  index: index,
                  row: row,
                  doctorItems: doctorItems,
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTableHeader() {
    Widget header(String value, {int flex = 1}) {
      return Expanded(
        flex: flex,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Text(
            value,
            style: const TextStyle(
              color: AppColors.blue6007,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.surfaceBlueSoft,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          const SizedBox(width: 28),
          header('#', flex: 1),
          header('Planned', flex: 2),
          header('Due Date', flex: 2),
          header('Doctor', flex: 2),
          header('Paid', flex: 2),
          header('Notes', flex: 4),
          header('Link', flex: 2),
          const SizedBox(width: 34),
        ],
      ),
    );
  }

  Widget _buildSittingRow({
    required Key key,
    required int index,
    required TreatmentSittingDraft row,
    required List<Doctor> doctorItems,
  }) {
    final plannedCtrl = _plannedControllerFor(row);
    final paidCtrl = _paidControllerFor(row);
    final notesCtrl = _noteControllerFor(row);

    Widget expanded({required int flex, required Widget child}) {
      return Expanded(
        flex: flex,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: child,
        ),
      );
    }

    return Container(
      key: key,
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.violet1508),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 28,
            child: ReorderableDragStartListener(
              index: index,
              child: const Icon(FluentIcons.more_vertical, size: 14),
            ),
          ),
          expanded(
            flex: 1,
            child: Text(
              '${index + 1}',
              style: const TextStyle(
                color: AppColors.blue7002,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          expanded(
            flex: 2,
            child: TextBox(
              controller: plannedCtrl,
              placeholder: '0.00',
              onChanged: (value) {
                setState(() {
                  row.plannedAmount = _parseCurrency(value);
                });
              },
            ),
          ),
          expanded(
            flex: 2,
            child: AppButton(
              label: material.MaterialLocalizations.of(context)
                  .formatShortDate(row.dueDate),
              variant: AppButtonVariant.secondary,
              onPressed: () => _pickDueDate(index),
            ),
          ),
          expanded(
            flex: 2,
            child: ComboBox<String>(
              isExpanded: true,
              value: row.doctorId,
              placeholder: const Text('Unassigned'),
              items: doctorItems
                  .map(
                    (doctor) => ComboBoxItem<String>(
                      value: doctor.id,
                      child: Text(
                        doctor.title.trim().isEmpty
                            ? 'Unnamed doctor'
                            : doctor.title.trim(),
                      ),
                    ),
                  )
                  .toList(growable: false),
              onChanged: (value) => setState(() => row.doctorId = value),
            ),
          ),
          expanded(
            flex: 2,
            child: TextBox(
              controller: paidCtrl,
              placeholder: '0.00',
              onChanged: (value) {
                setState(() {
                  row.paidAmount = _parseCurrency(value);
                });
              },
            ),
          ),
          expanded(
            flex: 4,
            child: TextBox(
              controller: notesCtrl,
              placeholder: 'Clinical goals/notes',
              onChanged: (value) {
                row.notes = value;
              },
            ),
          ),
          expanded(
            flex: 2,
            child: AppButton(
              label: 'Link',
              variant: AppButtonVariant.secondary,
              onPressed: () {
                showDialog<void>(
                  context: context,
                  builder: (dialogContext) => ContentDialog(
                    title: const Text('Link to Appointment'),
                    content: const Text(
                      'Appointment linking will be wired to calendar in the next phase.',
                    ),
                    actions: [
                      AppButton(
                        label: 'OK',
                        onPressed: () => Navigator.pop(dialogContext),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          SizedBox(
            width: 34,
            child: Tooltip(
              message: 'Remove sitting',
              child: IconButton(
                icon: const Icon(FluentIcons.delete, size: 14),
                onPressed: () => _removeSitting(row.id),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
