import 'package:apexo/core/theme/app_colors.dart';
import 'package:apexo/core/ui/components/app_button.dart';
import 'package:apexo/features/doctors/doctor_model.dart';
import 'package:apexo/features/doctors/doctors_store.dart';
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
  String planName;
  double totalPackageCost;
  int estimatedSittings;
  TreatmentPlanStatus status;
  String notes;
  List<TreatmentSittingDraft> sittings;

  TreatmentPlanDraft({
    required this.planName,
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

  TreatmentPlanStatus _status = TreatmentPlanStatus.active;
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
      planName: name,
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
              final detailsCard = _buildPlanDetailsCard();
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

  Widget _buildPlanDetailsCard() {
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
    final plannedCtrl = TextEditingController(
      text: row.plannedAmount == 0 ? '' : row.plannedAmount.toStringAsFixed(2),
    );
    final paidCtrl = TextEditingController(
      text: row.paidAmount == 0 ? '' : row.paidAmount.toStringAsFixed(2),
    );
    final notesCtrl = TextEditingController(text: row.notes);

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
                setState(() => row.plannedAmount = _parseCurrency(value));
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
                setState(() => row.paidAmount = _parseCurrency(value));
              },
            ),
          ),
          expanded(
            flex: 4,
            child: TextBox(
              controller: notesCtrl,
              placeholder: 'Clinical goals/notes',
              onChanged: (value) => row.notes = value,
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
