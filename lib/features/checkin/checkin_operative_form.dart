part of 'checkin_screen.dart';

class _CheckinOperativeForm extends StatefulWidget {
  final Appointment appointment;
  final List<Appointment> allAppointmentsForPatient;
  final bool showInlineBottomActions;
  final String? forcedStage;
  final VoidCallback? onDraftChanged;

  const _CheckinOperativeForm({
    required this.appointment,
    required this.allAppointmentsForPatient,
    this.showInlineBottomActions = false,
    this.forcedStage,
    this.onDraftChanged,
  });

  @override
  State<_CheckinOperativeForm> createState() => _CheckinOperativeFormState();
}

class _CheckinOperativeFormState extends State<_CheckinOperativeForm> {
  late final TextEditingController _postOpController;
  late final TextEditingController _priceController;
  late final TextEditingController _paidController;
  late final TextEditingController _discountController;
  Timer? _draftChangedDebounce;
  bool _discountEnabled = false;
  bool _loadingTopTreatments = true;
  Set<String> _selectedTreatments = {};
  Set<String> _selectedConsultationTypes = {};
  Set<String> _selectedChiefComplaints = {};
  List<String> _patientTopTreatments = const [];
  List<String> _clinicTopTreatments = const [];
  String _visitType = 'Consultation Only';
  String? _selectedPostOpParent;
  Set<String> _selectedTeeth = {};
  Map<String, ToothState> _teethStates = {};
  static const int _maxAppointmentsForClinicSuggestionScan = 600;

  static const List<String> _consultationSubTypes = [
    'General',
    'RCT',
    'Extraction',
    'Ortho',
    'Pulpectomy',
    'Food Lodgment',
    'Sinusits',
    'Gum Disease',
    'Implant',
    'TMJ',
    'Crown & Bridge',
    'Clear Aligner',
    'Denture Evaluation',
    'Others',
  ];

  static const List<String> _rctSubTypes = [
    'AO & BMP',
    'Obturation',
    'PCS',
  ];

  static const List<String> _visitTypes = [
    'Consultation Only',
    'New Problem / New Treatment',
    'Follow-up Visit',
  ];

  static const List<String> _chiefComplaintSuggestions = [
    'Toothache',
    'Sensitivity',
    'Swelling',
    'Bleeding',
    'Cavity',
    'Abscess',
    'Gingivitis',
    'Halitosis',
    'Malocclusion',
    'Impacted',
    'Discoloration',
    'Xerostomia',
    'Bruxism',
    'Orthodontics',
    'Prophylaxis',
    'Extraction',
    'Restoration',
    'Trauma',
    'Periodontitis',
    'Pulpitis',
  ];

  static const Map<String, List<String>> _postOpSuggestions = {
    'Post Tooth Extraction': [
      'Bite on the gauze for 30-45 minutes.',
      'Do not spit, rinse, or use a straw for 24 hours.',
      'Eat soft foods and drink cool liquids.',
      'Avoid hot food, smoking, and alcohol.',
      'Take medicines as prescribed.',
      'Apply ice pack outside cheek for swelling (10 minutes on, 10 minutes off).',
      'Rest today and avoid heavy work.',
      'Brush gently, avoid extraction area.',
    ],
    'Bleeding Control': [
      'Bite on gauze for 30-45 mins',
      'Minor oozing is normal for 24h',
      'Do not spit',
      'Apply tea bag if bleeding persists',
    ],
    'Pain Management': [
      'Take first dose before numbness wears off',
      'Ibuprofen 400-600mg every 6h',
      'Alternate Tylenol/Advil',
      'Avoid Aspirin',
    ],
    'Swelling & Inflammation': [
      'Ice pack: 20 mins on / 20 mins off',
      'Keep head elevated while sleeping',
      'Swelling peaks at 48-72 hours',
      'Warm compress after 48 hours',
    ],
    'Activity Restrictions': [
      'Rest for the remainder of the day',
      'No heavy lifting/exercise for 48h',
      'Avoid bending over',
    ],
    'Diet & Nutrition': [
      'Soft foods only (Yogurt, Soup, Mashed Potatoes)',
      'Cold/Room temp foods only for 24h',
      'Chew on the opposite side',
      'High protein/Hydrate well',
    ],
    'Oral Hygiene': [
      'No rinsing for the first 24h',
      'Gentle warm salt water rinse (Day 2)',
      'Brush other teeth carefully',
      'Do not disturb the surgical site',
    ],
    'Habits to Avoid': [
      'No Straws',
      'No Smoking for 72h',
      'No Alcohol',
      'No Vaping',
    ],
    'Suture (Stitch) Care': [
      'Dissolvable: will fall out in 5-10 days',
      'Non-dissolvable: return in 1 week for removal',
      'Do not pull on loose ends',
    ],
    'Medicated Rinses/Antibiotics': [
      'Chlorhexidine rinse 2x daily',
      'Finish the full course of antibiotics',
      'Apply prescribed topical gel with Q-tip',
    ],
    'Warning Signs': [
      'Uncontrolled bleeding',
      'Severe pain not relieved by meds',
      'Fever or chills',
      'Persistent numbness after 6 hours',
    ],
  };

  static const List<String> _allToothIds = [
    '18',
    '17',
    '16',
    '15',
    '14',
    '13',
    '12',
    '11',
    '21',
    '22',
    '23',
    '24',
    '25',
    '26',
    '27',
    '28',
    '48',
    '47',
    '46',
    '45',
    '44',
    '43',
    '42',
    '41',
    '31',
    '32',
    '33',
    '34',
    '35',
    '36',
    '37',
    '38',
  ];

  @override
  void initState() {
    super.initState();
    final a = widget.appointment;
    _postOpController = TextEditingController(text: a.postOpNotes);
    _priceController = TextEditingController(
        text: a.price == 0 ? '' : a.price.toStringAsFixed(0));
    _paidController = TextEditingController(
        text: a.paid == 0 ? '' : a.paid.toStringAsFixed(0));
    _discountController = TextEditingController(
        text: a.discount == 0 ? '' : a.discount.toStringAsFixed(0));
    _discountEnabled = a.discount > 0;
    _selectedTreatments = a.selectedTreatments.toSet();
    _selectedChiefComplaints = a.chiefComplaints.toSet();
    _selectedConsultationTypes =
        a.subTreatments.where((e) => e.trim().isNotEmpty).toSet();
    if (_selectedConsultationTypes.contains('Access opening') ||
        _selectedConsultationTypes.contains('BMP')) {
      _selectedConsultationTypes
        ..remove('Access opening')
        ..remove('BMP')
        ..add('AO & BMP');
      a.subTreatments = _selectedConsultationTypes.toList(growable: false);
    }
    _visitType =
        _visitTypes.contains(a.visitType) ? a.visitType : 'Follow-up Visit';
    _selectedTeeth = a.selectedTeeth.toSet();
    _teethStates = {
      for (final id in _allToothIds) id: ToothState(toothId: id),
    };
    for (final id in _selectedTeeth) {
      if (!_teethStates.containsKey(id)) {
        _teethStates[id] = ToothState(toothId: id);
      }
      _teethStates[id]!.surfaces[ToothSurface.occlusal] = TreatmentType.filling;
    }

    // Defer clinic-wide aggregation until after first paint to reduce initial UI jank.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _refreshTopTreatmentSuggestions();
    });
  }

  @override
  void didUpdateWidget(covariant _CheckinOperativeForm oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.appointment.id != widget.appointment.id ||
        oldWidget.allAppointmentsForPatient.length !=
            widget.allAppointmentsForPatient.length) {
      _refreshTopTreatmentSuggestions();
    }
  }

  bool _hasConsultationSelected() {
    return _selectedTreatments
        .any((t) => t.trim().toLowerCase() == 'consultation');
  }

  bool _hasRctSelected() {
    return _selectedTreatments.any((t) => t.trim().toLowerCase() == 'rct');
  }

  void _scheduleAutosave({bool immediate = false}) {
    if (immediate) {
      _draftChangedDebounce?.cancel();
      widget.onDraftChanged?.call();
      return;
    }

    _draftChangedDebounce?.cancel();
    _draftChangedDebounce = Timer(const Duration(milliseconds: 220), () {
      if (!mounted) return;
      widget.onDraftChanged?.call();
    });
  }

  @override
  void dispose() {
    _draftChangedDebounce?.cancel();
    _postOpController.dispose();
    _priceController.dispose();
    _paidController.dispose();
    _discountController.dispose();
    super.dispose();
  }

  List<String> _topTreatmentsForPatient() {
    final counts = <String, int>{};
    for (final appointment in widget.allAppointmentsForPatient) {
      for (final treatment in appointment.selectedTreatments) {
        final key = treatment.trim();
        if (key.isEmpty) continue;
        counts[key] = (counts[key] ?? 0) + 1;
      }
    }
    final rows = counts.entries.toList(growable: false)
      ..sort((a, b) => b.value.compareTo(a.value));
    return rows.take(10).map((e) => e.key).toList(growable: false);
  }

  List<String> _topTreatmentsAcrossClinic() {
    final counts = <String, int>{};
    var scanned = 0;
    for (final appointment in appointments.present.values) {
      if (scanned >= _maxAppointmentsForClinicSuggestionScan) break;
      scanned++;
      for (final treatment in appointment.selectedTreatments) {
        final key = treatment.trim();
        if (key.isEmpty) continue;
        counts[key] = (counts[key] ?? 0) + 1;
      }
    }
    final rows = counts.entries.toList(growable: false)
      ..sort((a, b) => b.value.compareTo(a.value));
    return rows.take(10).map((e) => e.key).toList(growable: false);
  }

  Future<void> _refreshTopTreatmentSuggestions() async {
    final patientTop = _topTreatmentsForPatient();
    final clinicTop = _topTreatmentsAcrossClinic();
    if (!mounted) return;
    setState(() {
      _patientTopTreatments = patientTop;
      _clinicTopTreatments = clinicTop;
      _loadingTopTreatments = false;
    });
  }

  // ignore: unused_element
  Future<void> _confirmDoneToggle() async {
    final a = widget.appointment;
    if (a.isDone) {
      a.checkinStage = 'checkout';
      a.completedTime = null;
      setState(() => a.isDone = false);
      _scheduleAutosave(immediate: true);
      return;
    }

    final shouldComplete = await _confirmMoveToCompleted(
      context,
      a,
      paidOverride: a.paid,
    );

    if (!shouldComplete) return;
    a.checkinStage = 'completed';
    a.completedTime = DateTime.now();
    setState(() => a.isDone = true);
    _scheduleAutosave(immediate: true);
    await _openNextAppointmentPrompt(a);
  }

  Future<void> _openNextAppointmentPrompt(Appointment appointment) async {
    await _showNextAppointmentPromptDialog(context, appointment);
  }

  Future<void> _moveBackToWaiting() async {
    final patientName = _patientDisplayName(widget.appointment);
    final shouldMove = await showDialog<bool>(
      context: context,
      builder: (context) => ContentDialog(
        title: Text('Move "$patientName" back to Waiting?'),
        content: Text(
          '$patientName will be moved back to Waiting and doctor assignment will be removed.',
        ),
        actions: [
          AppButton(
            label: 'Cancel',
            variant: AppButtonVariant.secondary,
            onPressed: () => Navigator.pop(context, false),
          ),
          AppButton(
            label: 'Move to Waiting',
            variant: AppButtonVariant.danger,
            onPressed: () => Navigator.pop(context, true),
          ),
        ],
      ),
    );
    if (shouldMove != true) return;
    final a = widget.appointment;
    a.operatorsIDs = [];
    a.checkinStage = 'waiting';
    a.completedTime = null;
    a.isDone = false;
    _scheduleAutosave(immediate: true);
  }

  // ignore: unused_element
  Future<void> _moveBackToWithDoctor() async {
    final patientName = _patientDisplayName(widget.appointment);
    final shouldMove = await showDialog<bool>(
      context: context,
      builder: (context) => ContentDialog(
        title: Text('Move "$patientName" back to Treatment?'),
        content: Text(
            'This patient will be moved back to Treatment stage for $patientName.'),
        actions: [
          AppButton(
            label: 'Cancel',
            variant: AppButtonVariant.secondary,
            onPressed: () => Navigator.pop(context, false),
          ),
          AppButton(
            label: 'Move to Treatment',
            variant: AppButtonVariant.danger,
            onPressed: () => Navigator.pop(context, true),
          ),
        ],
      ),
    );
    if (shouldMove != true) return;
    final a = widget.appointment;
    a.checkinStage = 'with_doctor';
    a.completedTime = null;
    a.isDone = false;
    _scheduleAutosave(immediate: true);
  }

  @override
  Widget build(BuildContext context) {
    final a = widget.appointment;
    final effectiveStage = widget.forcedStage ?? a.checkinStage;
    final isWithDoctor = effectiveStage == 'with_doctor';
    final isCheckout = effectiveStage == 'checkout';

    if (isCheckout) {
      return _CheckoutPaymentCard(
        appointment: a,
        priceController: _priceController,
        paidController: _paidController,
        discountController: _discountController,
        discountEnabled: _discountEnabled,
        onToggleDiscount: (value) => setState(() => _discountEnabled = value),
        onCollectFullBalance: () {
          final discount = a.discount;
          final discountedTotal = (a.discountType == 'percent'
                  ? (a.price - (a.price * discount / 100))
                      .clamp(0, double.infinity)
                  : (a.price - discount).clamp(0, double.infinity))
              .toDouble();
          _paidController.text = discountedTotal.toStringAsFixed(0);
          a.paid = discountedTotal;
          _scheduleAutosave(immediate: true);
          setState(() {});
        },
      );
    }

    final topTreatments = _patientTopTreatments;
    final globalTopTreatments = _clinicTopTreatments;
    final mergedTopTreatments = <String>{
      ...topTreatments,
      ...globalTopTreatments,
    }.take(10).toList(growable: false);

    const sectionTitleStyle = TextStyle(
      color: Color(0xFF2C4E76),
      fontWeight: FontWeight.w800,
      fontSize: 15,
    );

    return SizedBox(
      width: double.infinity,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isWithDoctor)
            const Text(
              'Treatment',
              style: TextStyle(
                color: Color(0xFF2C4E76),
                fontWeight: FontWeight.w800,
                fontSize: 18,
              ),
            ),
          if (isWithDoctor) const SizedBox(height: 8),
          // Doctor display / edit row
          GestureDetector(
            onTap: () async {
              final picked = await pickDoctorDialog(
                context,
                initialSelected: a.operatorsIDs,
                title: 'Assign Doctor(s)',
              );
              if (picked == null) return;
              a.operatorsIDs = picked;
              _scheduleAutosave(immediate: true);
              if (mounted) setState(() {});
            },
            child: Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFF0F7FF),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFBDD4F2)),
              ),
              child: Row(
                children: [
                  const Icon(FluentIcons.medical, size: 14, color: Color(0xFF2D6EC2)),
                  const SizedBox(width: 8),
                  const Text(
                    'Doctor: ',
                    style: TextStyle(
                      color: Color(0xFF4B6488),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      a.operators.isEmpty
                          ? 'Unassigned'
                          : a.operators.map((d) => d.title).join(', '),
                      style: const TextStyle(
                        color: Color(0xFF1F3C5E),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const Icon(FluentIcons.edit, size: 12, color: Color(0xFF5A7FAD)),
                  const SizedBox(width: 4),
                  const Text(
                    'Change',
                    style: TextStyle(
                      color: Color(0xFF2D7BD8),
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ),
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              _medicalHistorySummaryText(a.patient),
              style: const TextStyle(
                color: Color(0xFFC63A4D),
                fontWeight: FontWeight.w700,
                fontSize: 14,
              ),
            ),
          ),
          if (isWithDoctor)
            LayoutBuilder(
              builder: (context, constraints) {
                final firstColumn = Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Visit Type', style: sectionTitleStyle),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: _visitTypes.map((type) {
                        final selected = _visitType == type;
                        final icon = type == 'Follow-up Visit'
                            ? FluentIcons.calendar
                            : type == 'New Problem / New Treatment'
                                ? FluentIcons.health
                                : FluentIcons.chat;
                        final note = type == 'Follow-up Visit'
                            ? 'Patient is returning for a review'
                            : type == 'New Problem / New Treatment'
                                ? 'New concern or additional treatment'
                                : 'Advice or opinion only';

                        return GestureDetector(
                          onTap: () {
                            setState(() {
                              _visitType = type;
                              a.visitType = type;
                              _scheduleAutosave();
                            });
                          },
                          child: Container(
                            width: 250,
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: selected
                                  ? const Color(0xFFEAF6FF)
                                  : const Color(0xFFF4F6FA),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: selected
                                    ? const Color(0xFF4DB6C6)
                                    : const Color(0xFFDDE5F0),
                              ),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  width: 28,
                                  height: 28,
                                  decoration: BoxDecoration(
                                    color: selected
                                        ? const Color(0xFFBEE9EF)
                                        : const Color(0xFFE9EDF5),
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  alignment: Alignment.center,
                                  child: Icon(icon,
                                      size: 12, color: const Color(0xFF2E5C85)),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        type,
                                        style: const TextStyle(
                                          color: Color(0xFF254870),
                                          fontWeight: FontWeight.w700,
                                          fontSize: 12,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        note,
                                        style: const TextStyle(
                                          color: Color(0xFF5B7394),
                                          fontWeight: FontWeight.w600,
                                          fontSize: 11,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }).toList(growable: false),
                    ),
                    const SizedBox(height: 12),
                    const Text('Chief Complaint', style: sectionTitleStyle),
                    const SizedBox(height: 6),
                    _CheckinSearchableTagInput(
                      initialValues:
                          _selectedChiefComplaints.toList(growable: false),
                      suggestions: _chiefComplaintSuggestions,
                      placeholder: 'Add chief complaint...',
                      onChanged: (values) {
                        setState(() {
                          _selectedChiefComplaints = values.toSet();
                          a.chiefComplaints = values;
                          _scheduleAutosave();
                        });
                      },
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: _chiefComplaintSuggestions
                          .map(
                            (complaint) => _quickChip(
                              label: complaint,
                              selected:
                                  _selectedChiefComplaints.contains(complaint),
                              onTap: () {
                                setState(() {
                                  if (_selectedChiefComplaints
                                      .contains(complaint)) {
                                    _selectedChiefComplaints.remove(complaint);
                                  } else {
                                    _selectedChiefComplaints.add(complaint);
                                  }
                                  a.chiefComplaints = _selectedChiefComplaints
                                      .toList(growable: false);
                                  _scheduleAutosave();
                                });
                              },
                            ),
                          )
                          .toList(growable: false),
                    ),
                    const SizedBox(height: 12),
                    InfoLabel(
                      label: 'Teeth:',
                      child: TeethPicker(
                        selectedTeeth: _selectedTeeth,
                        isAdult: (a.patient?.age ?? 0) >= 13,
                        onChanged: (teeth) {
                          setState(() {
                            _selectedTeeth = teeth;
                            for (final id in teeth) {
                              _teethStates.putIfAbsent(
                                id,
                                () => ToothState(toothId: id),
                              );
                            }
                            a.selectedTeeth = teeth.toList(growable: false);
                            _scheduleAutosave();
                          });
                        },
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Text('Diagnosis', style: sectionTitleStyle),
                    const SizedBox(height: 6),
                    _CheckinSearchableTagInput(
                      initialValues: a.diagnosis,
                      suggestions: allDiagnosis,
                      placeholder: 'Add diagnosis...',
                      onChanged: (values) {
                        setState(() {
                          a.diagnosis = values;
                          _scheduleAutosave();
                        });
                      },
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: allDiagnosis
                          .take(16)
                          .map(
                            (diagnosis) => _quickChip(
                              label: diagnosis,
                              selected: a.diagnosis.contains(diagnosis),
                              onTap: () {
                                setState(() {
                                  final updated =
                                      a.diagnosis.toList(growable: true);
                                  if (updated.contains(diagnosis)) {
                                    updated.remove(diagnosis);
                                  } else {
                                    updated.add(diagnosis);
                                  }
                                  a.diagnosis = updated;
                                  _scheduleAutosave();
                                });
                              },
                            ),
                          )
                          .toList(growable: false),
                    ),
                    const SizedBox(height: 16),
                    const Text('Treatment', style: sectionTitleStyle),
                    const SizedBox(height: 6),
                    _CheckinSearchableTagInput(
                      initialValues:
                          _selectedTreatments.toList(growable: false),
                      suggestions: allTreatments
                          .map((t) => t.name)
                          .toList(growable: false),
                      placeholder: 'Add treatment...',
                      onChanged: (values) {
                        _selectedTreatments = values.toSet();
                        a.selectedTreatments = values;
                        if (!_hasConsultationSelected() && !_hasRctSelected()) {
                          _selectedConsultationTypes.clear();
                          a.subTreatments = [];
                        } else {
                          a.subTreatments = _selectedConsultationTypes.toList(
                              growable: false);
                        }
                        _scheduleAutosave();
                        setState(() {});
                      },
                    ),
                    if (_loadingTopTreatments) ...[
                      const SizedBox(height: 8),
                      const ProgressRing(strokeWidth: 2.2),
                    ] else if (mergedTopTreatments.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Text(
                        topTreatments.isNotEmpty
                            ? 'Top 10 treatments (includes patient history):'
                            : 'Top 10 provided treatments:',
                        style: const TextStyle(
                          color: Color(0xFF5A7397),
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: mergedTopTreatments
                            .map(
                              (t) => _quickChip(
                                label: t,
                                selected: _selectedTreatments.contains(t),
                                onTap: () {
                                  setState(() {
                                    if (_selectedTreatments.contains(t)) {
                                      _selectedTreatments.remove(t);
                                    } else {
                                      _selectedTreatments.add(t);
                                    }
                                    a.selectedTreatments = _selectedTreatments
                                        .toList(growable: false);
                                    if (!_hasConsultationSelected() &&
                                        !_hasRctSelected()) {
                                      _selectedConsultationTypes.clear();
                                      a.subTreatments = [];
                                    } else {
                                      a.subTreatments =
                                          _selectedConsultationTypes.toList(
                                        growable: false,
                                      );
                                    }
                                    _scheduleAutosave();
                                  });
                                },
                              ),
                            )
                            .toList(growable: false),
                      ),
                    ],
                    if (_hasConsultationSelected()) ...[
                      const SizedBox(height: 10),
                      const Text(
                        'Consultation Type Suggestions:',
                        style: TextStyle(
                          color: Color(0xFF5A7397),
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: _consultationSubTypes
                            .map(
                              (type) => _hierarchyChip(
                                label: type,
                                selected:
                                    _selectedConsultationTypes.contains(type),
                                onTap: () {
                                  setState(() {
                                    if (_selectedConsultationTypes
                                        .contains(type)) {
                                      _selectedConsultationTypes.remove(type);
                                    } else {
                                      _selectedConsultationTypes.add(type);
                                    }
                                    a.subTreatments =
                                        _selectedConsultationTypes.toList(
                                      growable: false,
                                    );
                                    _scheduleAutosave();
                                  });
                                },
                              ),
                            )
                            .toList(growable: false),
                      ),
                    ],
                    if (_hasRctSelected()) ...[
                      const SizedBox(height: 10),
                      const Text(
                        'RCT Stage Selection:',
                        style: TextStyle(
                          color: Color(0xFF5A7397),
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: _rctSubTypes
                            .map(
                              (type) => _hierarchyChip(
                                label: type,
                                selected:
                                    _selectedConsultationTypes.contains(type),
                                onTap: () {
                                  setState(() {
                                    if (_selectedConsultationTypes
                                        .contains(type)) {
                                      _selectedConsultationTypes.remove(type);
                                    } else {
                                      _selectedConsultationTypes.add(type);
                                    }
                                    a.subTreatments =
                                        _selectedConsultationTypes.toList(
                                      growable: false,
                                    );
                                    _scheduleAutosave();
                                  });
                                },
                              ),
                            )
                            .toList(growable: false),
                      ),
                    ],
                    const SizedBox(height: 10),
                    const Text('Treatment Price', style: sectionTitleStyle),
                    const SizedBox(height: 6),
                    CupertinoTextField(
                      controller: _priceController,
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                      ],
                      prefix: const Padding(
                        padding: EdgeInsets.only(left: 10),
                        child: Text('₹',
                            style: TextStyle(color: Color(0xFF355279))),
                      ),
                      placeholder: 'Treatment price',
                      onChanged: (value) {
                        a.price = double.tryParse(value) ?? 0;
                        _scheduleAutosave();
                      },
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [100, 200, 500, 1000, 2000, 2500]
                          .map(
                            (v) => AppButton(
                              label: '₹$v',
                              compact: false,
                              variant: AppButtonVariant.secondary,
                              onPressed: () {
                                _priceController.text = '$v';
                                a.price = v.toDouble();
                                _scheduleAutosave();
                                setState(() {});
                              },
                            ),
                          )
                          .toList(growable: false),
                    ),
                  ],
                );

                final secondColumn = Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Post-operative Notes',
                        style: sectionTitleStyle),
                    const SizedBox(height: 6),
                    CupertinoTextField(
                      controller: _postOpController,
                      minLines: 4,
                      maxLines: 8,
                      onChanged: (value) {
                        a.postOpNotes = value;
                        _scheduleAutosave();
                      },
                      placeholder: 'Post-operative notes',
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: _postOpSuggestions.keys
                          .map(
                            (parent) => AppButton(
                              label: parent,
                              compact: false,
                              variant: _selectedPostOpParent == parent
                                  ? AppButtonVariant.primary
                                  : AppButtonVariant.secondary,
                              onPressed: () {
                                setState(() => _selectedPostOpParent = parent);
                              },
                            ),
                          )
                          .toList(growable: false),
                    ),
                    if (_selectedPostOpParent != null &&
                        _postOpSuggestions[_selectedPostOpParent!] != null) ...[
                      const SizedBox(height: 14),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _postOpSuggestions[_selectedPostOpParent!]!
                            .map(
                              (child) => _hierarchyChip(
                                label: child,
                                selected: false,
                                onTap: () {
                                  final parent = _selectedPostOpParent;
                                  if (parent == null) return;
                                  final parentLine = '- $parent';
                                  final childLine = '  - $child';
                                  final current = _postOpController.text.trim();
                                  if (current.contains(
                                          '$parentLine\n$childLine') ||
                                      current.contains('\n$childLine')) {
                                    return;
                                  }
                                  _postOpController.text = current
                                          .contains(parentLine)
                                      ? '$current\n$childLine'
                                      : (current.isEmpty
                                          ? '$parentLine\n$childLine'
                                          : '$current\n$parentLine\n$childLine');
                                  setState(() {});
                                  a.postOpNotes = _postOpController.text;
                                  _scheduleAutosave();
                                },
                              ),
                            )
                            .toList(growable: false),
                      ),
                    ],
                    if (widget.showInlineBottomActions) ...[
                      const SizedBox(height: 18),
                      Row(
                        children: [
                          Expanded(
                            child: AppButton(
                              label: 'Proceed to Billing',
                              onPressed: () async {
                                final navigator = Navigator.of(context);
                                final patientName = _patientDisplayName(a);
                                final confirmed = await showDialog<bool>(
                                  context: context,
                                  builder: (dialogContext) => ContentDialog(
                                    title: Text(
                                      'Move "$patientName" to Billing?',
                                    ),
                                    content: Text(
                                      'This appointment will be moved to Billing stage for $patientName.',
                                    ),
                                    actions: [
                                      AppButton(
                                        label: 'Cancel',
                                        variant: AppButtonVariant.secondary,
                                        onPressed: () =>
                                            Navigator.pop(dialogContext, false),
                                      ),
                                      AppButton(
                                        label: 'Proceed',
                                        onPressed: () =>
                                            Navigator.pop(dialogContext, true),
                                      ),
                                    ],
                                  ),
                                );
                                if (confirmed != true) return;
                                a.checkinStage = 'checkout';
                                a.isDone = false;
                                _scheduleAutosave(immediate: true);
                                if (!mounted) return;
                                navigator.maybePop();
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: AppButton(
                              label: 'Move Back to Waiting',
                              variant: AppButtonVariant.danger,
                              onPressed: _moveBackToWaiting,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                );

                final scheduler = _InlineNextAppointmentCard(
                  appointment: a,
                  includeCancelledSection: true,
                );
                final todaySummary = _buildTodaySummaryCard(a);

                if (constraints.maxWidth >= 1180) {
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(flex: 42, child: firstColumn),
                      const SizedBox(width: 12),
                      Expanded(flex: 42, child: secondColumn),
                      const SizedBox(width: 12),
                      SizedBox(
                        width: 260,
                        child: Column(
                          children: [
                            scheduler,
                            const SizedBox(height: 10),
                            todaySummary,
                          ],
                        ),
                      ),
                    ],
                  );
                }

                return Column(
                  children: [
                    firstColumn,
                    const SizedBox(height: 16),
                    secondColumn,
                    const SizedBox(height: 16),
                    scheduler,
                    const SizedBox(height: 10),
                    todaySummary,
                  ],
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _quickChip({
    required String label,
    bool selected = false,
    AppButtonVariant selectedVariant = AppButtonVariant.primary,
    AppButtonVariant normalVariant = AppButtonVariant.secondary,
    required VoidCallback onTap,
  }) {
    return AppButton(
      label: label,
      compact: false,
      variant: selected ? selectedVariant : normalVariant,
      onPressed: onTap,
    );
  }

  Widget _hierarchyChip({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFE6F7EC) : const Color(0xFFF4FBF6),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected ? const Color(0xFF9FD9B1) : const Color(0xFFCDEBD7),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? const Color(0xFF1E8B66) : const Color(0xFF2F7A57),
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  Widget _buildTodaySummaryCard(Appointment a) {
    final treatedTeeth = _selectedTeeth.toList(growable: false)
      ..sort((x, y) => x.compareTo(y));
    final diagnosisLabel =
        a.diagnosis.where((d) => d.trim().isNotEmpty).join(', ').trim().isEmpty
            ? '-'
            : a.diagnosis.where((d) => d.trim().isNotEmpty).join(', ');
    final chiefComplaintLabel = a.chiefComplaints
            .where((d) => d.trim().isNotEmpty)
            .join(', ')
            .trim()
            .isEmpty
        ? '-'
        : a.chiefComplaints.where((d) => d.trim().isNotEmpty).join(', ');
    final selectedTreatments =
        a.selectedTreatments.where((t) => t.trim().isNotEmpty).toList();
    final selectedSubTreatments =
        a.subTreatments.where((t) => t.trim().isNotEmpty).toList();
    final treatmentLabel = selectedTreatments.isEmpty
        ? 'Consultation'
        : selectedSubTreatments.isEmpty
            ? selectedTreatments.join(', ')
            : '${selectedTreatments.join(', ')} - ${selectedSubTreatments.join(', ')}';

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF4F7FC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFD7E0EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Today Summary',
            style: TextStyle(
              color: Color(0xFF223B5E),
              fontWeight: FontWeight.w800,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 12),
          _summaryLine('Teeth treated',
              treatedTeeth.isEmpty ? '-' : treatedTeeth.join(', ')),
          _summaryLine('Diagnosis', diagnosisLabel),
          _summaryLine('Chief complaint', chiefComplaintLabel),
          _summaryLine('Treatment', treatmentLabel),
          _summaryLine('Cost', '₹${a.price.toStringAsFixed(0)}',
              valueColor: const Color(0xFF203A61)),
          const SizedBox(height: 10),
          const Divider(size: 1),
        ],
      ),
    );
  }

  Widget _summaryLine(String label, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Expanded(
            child: Text(
              '$label:',
              style: const TextStyle(
                color: Color(0xFF5A6B7F),
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(
                color: valueColor ?? const Color(0xFF2A3F5E),
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
