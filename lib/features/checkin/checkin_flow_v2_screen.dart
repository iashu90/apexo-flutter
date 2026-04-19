import 'package:apexo/features/appointments/appointment_model.dart';
import 'package:apexo/features/appointments/appointments_store.dart';
import 'package:apexo/common_widgets/pick_doctor_dialog.dart';
import 'package:apexo/theme/apexo_theme.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:intl/intl.dart';

class CheckinFlowV2Screen extends StatefulWidget {
  final Appointment appointment;
  final VoidCallback? onClose;

  const CheckinFlowV2Screen({
    super.key,
    required this.appointment,
    this.onClose,
  });

  @override
  State<CheckinFlowV2Screen> createState() => _CheckinFlowV2ScreenState();
}

class _CheckinFlowV2ScreenState extends State<CheckinFlowV2Screen> {
  int _activeTab = 0;

  Appointment get _appointment => widget.appointment;

  String get _patientName {
    final value = _appointment.title.trim();
    return value.isEmpty ? 'Unnamed patient' : value;
  }

  String get _patientPhone {
    final value = _appointment.patient?.phone.trim() ?? '';
    return value.isEmpty ? '-' : value;
  }

  String get _patientAge {
    return '${_appointment.patient?.age ?? 0}';
  }

  String get _patientGender {
    final gender = _appointment.patient?.gender;
    if (gender == 1) return 'Male';
    if (gender == 0) return 'Female';
    return '-';
  }

  String get _doctorNames {
    final names = _appointment.operators
        .map((d) => d.title.trim())
        .where((name) => name.isNotEmpty)
        .toList(growable: false);
    if (names.isEmpty) return 'Unassigned';
    return names.join(', ');
  }

  double get _discountedTotal {
    final discount = _appointment.discount;
    if (_appointment.discountType == 'percent') {
      return (_appointment.price - (_appointment.price * discount / 100))
          .clamp(0, double.infinity);
    }
    return (_appointment.price - discount).clamp(0, double.infinity);
  }

  double get _balance {
    return (_discountedTotal - _appointment.paid).clamp(0, double.infinity);
  }

  List<Appointment> get _previousVisits {
    final patient = _appointment.patient;
    if (patient == null) return const [];
    final visits = patient.allAppointments
        .where((row) => row.id != _appointment.id)
        .toList(growable: false)
      ..sort((a, b) => b.date.compareTo(a.date));
    return visits;
  }

  Future<void> _handleCheckInPressed() async {
    final pickedDoctorIds = await pickDoctorDialog(
      context,
      initialSelected: _appointment.operatorsIDs,
      subtitle: '$_patientName • $_patientAge y • $_patientGender',
    );
    if (pickedDoctorIds == null || pickedDoctorIds.isEmpty) return;

    setState(() {
      _appointment.operatorsIDs = pickedDoctorIds;
      _appointment.checkinStage = 'waiting';
      _appointment.isCheckedIn = true;
      appointments.set(_appointment);
    });
  }

  void _setStage(String stage) {
    setState(() {
      _appointment.checkinStage = stage;
      _appointment.isCheckedIn = stage != 'scheduled' && stage != 'pending';
      if (stage == 'completed') {
        _appointment.isDone = true;
      }
      appointments.set(_appointment);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFF3F7FC),
      child: Column(
        children: [
          _buildHeader(context),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final compact = constraints.maxWidth < 1080;
                  if (compact) {
                    return SingleChildScrollView(
                      child: Column(
                        children: [
                          _buildLeftPane(),
                          const SizedBox(height: 10),
                          _buildCenterPane(),
                          const SizedBox(height: 10),
                          _buildRightPane(),
                        ],
                      ),
                    );
                  }

                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(width: 280, child: _buildLeftPane()),
                      const SizedBox(width: 10),
                      Expanded(child: _buildCenterPane()),
                      const SizedBox(width: 10),
                      SizedBox(width: 280, child: _buildRightPane()),
                    ],
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [Color(0xFF2D7BD8), Color(0xFF3E68DF)],
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$_patientName • ${_appointment.patientID ?? '-'}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 26,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Appointment: ${DateFormat('dd MMM yyyy • h:mm a').format(_appointment.date)} • $_doctorNames',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.9),
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          if (widget.onClose != null)
            IconButton(
              icon: const Icon(FluentIcons.chrome_close),
              style: ButtonStyle(
                foregroundColor: WidgetStateProperty.all(Colors.white),
              ),
              onPressed: widget.onClose,
            ),
        ],
      ),
    );
  }

  Widget _buildLeftPane() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _card(
          title: 'Check-in Details',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _kv('Arrival time', DateFormat('h:mm a').format(_appointment.date)),
              _kv('Doctor assignee', _doctorNames),
              _kv('Reason for visit', _appointment.preOpNotes.trim().isEmpty ? '-' : _appointment.preOpNotes),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _handleCheckInPressed,
                  child: const Text('Check-in'),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        _card(
          title: 'Treatment History',
          child: _buildTreatmentHistoryFlow(),
        ),
      ],
    );
  }

  Widget _buildTreatmentHistoryFlow() {
    final rows = _previousVisits
        .where((row) => row.selectedTreatments.isNotEmpty)
        .toList(growable: false);

    if (rows.isEmpty) {
      return const Text(
        'No previous treatment history.',
        style: TextStyle(color: Color(0xFF5E6B7A)),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: rows.take(8).map((row) {
        final treatments = row.selectedTreatments
            .where((t) => t.trim().isNotEmpty)
            .toList(growable: false);
        return Container(
          width: double.infinity,
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFD),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                DateFormat('dd MMM yyyy').format(row.date),
                style: const TextStyle(
                  color: Color(0xFF355279),
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: treatments
                    .map((item) => _grayChip(item))
                    .toList(growable: false),
              ),
            ],
          ),
        );
      }).toList(growable: false),
    );
  }

  Widget _buildCenterPane() {
    final tabs = ['Treatment', 'Billing', 'Summary'];

    return _card(
      title: 'Visit Workspace',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: const Color(0xFFF2F4F8),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              children: List.generate(
                tabs.length,
                (index) => Expanded(
                  child: Button(
                    style: ButtonStyle(
                      backgroundColor: WidgetStateProperty.all(
                        _activeTab == index
                            ? ApexoThemeColors.navActiveTab
                            : Colors.transparent,
                      ),
                      foregroundColor: WidgetStateProperty.all(
                        _activeTab == index
                            ? Colors.white
                            : const Color(0xFF2D3D55),
                      ),
                    ),
                    onPressed: () => setState(() => _activeTab = index),
                    child: Text(tabs[index]),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          _buildActiveTabBody(),
        ],
      ),
    );
  }

  Widget _buildActiveTabBody() {
    switch (_activeTab) {
      case 1:
        return _buildBillingTab();
      case 2:
        return _buildSummaryTab();
      default:
        return _buildTreatmentTab();
    }
  }

  Widget _buildTreatmentTab() {
    final rows = _previousVisits
        .where((row) => row.selectedTreatments.isNotEmpty)
        .take(4)
        .toList(growable: false);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeading('Selected Teeth'),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: _appointment.selectedTeeth.isEmpty
              ? const [Text('-', style: TextStyle(color: Color(0xFF5E6B7A)))]
              : _appointment.selectedTeeth
                  .map((tooth) => _blueChip(tooth))
                  .toList(growable: false),
        ),
        const SizedBox(height: 10),
        _sectionHeading('Diagnosis'),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: _appointment.diagnosis.isEmpty
              ? const [Text('-', style: TextStyle(color: Color(0xFF5E6B7A)))]
              : _appointment.diagnosis
                  .map((item) => _grayChip(item))
                  .toList(growable: false),
        ),
        const SizedBox(height: 10),
        _sectionHeading('Previous Treatment Taken'),
        if (rows.isEmpty)
          const Text('-', style: TextStyle(color: Color(0xFF5E6B7A)))
        else
          ...rows.map((row) {
            final treatment = row.selectedTreatments
                .where((t) => t.trim().isNotEmpty)
                .join(', ');
            return Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 6),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFD),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Text(
                '${DateFormat('dd MMM yyyy').format(row.date)} • ${treatment.isEmpty ? '-' : treatment}',
                style: const TextStyle(
                  color: Color(0xFF2D3D55),
                  fontWeight: FontWeight.w600,
                ),
              ),
            );
          }),
        const SizedBox(height: 8),
        _sectionHeading('Procedures & Treatment Cart'),
        ..._appointment.selectedTreatments.map(
          (treatment) => Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              children: [
                Expanded(child: Text(treatment.trim().isEmpty ? '-' : treatment)),
                Text('Rs ${_appointment.price.toStringAsFixed(0)}'),
              ],
            ),
          ),
        ),
        if (_appointment.selectedTreatments.isEmpty)
          const Text('-', style: TextStyle(color: Color(0xFF5E6B7A))),
      ],
    );
  }

  Widget _buildBillingTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeading('Payment Summary'),
        _kv('Net Total', 'Rs ${_discountedTotal.toStringAsFixed(0)}'),
        _kv('Total Paid', 'Rs ${_appointment.paid.toStringAsFixed(0)}'),
        _kv('Balance', 'Rs ${_balance.toStringAsFixed(0)}'),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: FilledButton(
                onPressed: () => _setStage('checkout'),
                child: const Text('Collect Payment'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Button(
                onPressed: () => _setStage('completed'),
                child: const Text('Mark Completed'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSummaryTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeading('Visit Summary'),
        _kv('Teeth', _appointment.selectedTeeth.isEmpty ? '-' : _appointment.selectedTeeth.join(', ')),
        _kv('Procedures', _appointment.selectedTreatments.isEmpty ? '-' : _appointment.selectedTreatments.join(', ')),
        _kv('Doctor', _doctorNames),
        _kv('Status', _statusLabel(_appointment)),
        const SizedBox(height: 8),
        FilledButton(
          onPressed: () => _setStage('completed'),
          child: const Text('Complete Visit'),
        ),
      ],
    );
  }

  Widget _sectionHeading(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        title,
        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
      ),
    );
  }

  Widget _blueChip(String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFFEAF2FF),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        value,
        style: const TextStyle(
          color: Color(0xFF1F4B8F),
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _grayChip(String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFFEEF2F7),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(value),
    );
  }

  Widget _buildRightPane() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _card(
          title: 'Patient Summary',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _patientName,
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 6),
              Text('Patient ID: ${_appointment.patientID ?? '-'}'),
              Text('Age: $_patientAge'),
              Text('Gender: $_patientGender'),
              Text('Phone: $_patientPhone'),
              const SizedBox(height: 10),
              _kv('Total', 'Rs ${_discountedTotal.toStringAsFixed(0)}'),
              _kv('Total Paid', 'Rs ${_appointment.paid.toStringAsFixed(0)}'),
              _kv('Balance', 'Rs ${_balance.toStringAsFixed(0)}'),
              const Divider(size: 16),
              _kv('Status', _statusLabel(_appointment)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _card({
    required String title,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFD7E5F6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: Color(0xFF243A54),
            ),
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }

  Widget _kv(String key, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Expanded(
            child: Text(
              key,
              style: const TextStyle(
                color: Color(0xFF5A6B80),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              color: Color(0xFF2B3F58),
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  String _statusLabel(Appointment appointment) {
    if (appointment.isDone || appointment.checkinStage == 'completed') {
      return 'Completed';
    }
    if (appointment.checkinStage == 'checkout' ||
        appointment.checkinStage == 'billing') {
      return 'Billing';
    }
    if (appointment.checkinStage == 'with_doctor' ||
        appointment.checkinStage == 'treatment') {
      return 'In chair';
    }
    if (appointment.checkinStage == 'waiting' ||
        appointment.checkinStage == 'pending' ||
        appointment.checkinStage == 'scheduled') {
      return 'Waiting';
    }
    return appointment.checkinStage;
  }
}
