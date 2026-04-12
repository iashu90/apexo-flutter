import 'dart:math' as math;

import 'package:apexo/common_widgets/patient_history_modal_v2.dart';
import 'package:apexo/core/multi_stream_builder.dart';
import 'package:apexo/features/appointments/appointment_model.dart';
import 'package:apexo/features/appointments/appointments_store.dart';
import 'package:apexo/features/patients/open_patient_panel.dart';
import 'package:apexo/features/patients/patient_model.dart';
import 'package:apexo/features/patients/patients_store.dart';
import 'package:apexo/widget_keys.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:intl/intl.dart';

class PatientsScreenV2 extends StatefulWidget {
  const PatientsScreenV2({super.key});

  @override
  State<PatientsScreenV2> createState() => _PatientsScreenV2State();
}

class _PatientsScreenV2State extends State<PatientsScreenV2> {
  final TextEditingController _listSearchController = TextEditingController();

  String _listQuery = '';
  String _topRange = '6Months';
  String _outstandingRange = '6Months';
  String _procedureTab = 'RCT';
  String _selectedAlphabet = 'All';
  String _listBehaviorFilter = 'all';
  String _sortBy = 'name';
  bool _sortAscending = true;
  double _highValueThreshold = 10000;
  int _topPatientsVisibleCount = 10;
  int _topOutstandingVisibleCount = 10;
  int _topProcedureVisibleCount = 10;
  int _currentPage = 1;

  static const int _pageSize = 200;

  static const List<String> _topRanges = [
    '1Month',
    '6Months',
    '1Year',
    'All',
  ];

  @override
  void initState() {
    super.initState();
    _listSearchController.addListener(() {
      setState(() {
        _listQuery = _listSearchController.text.trim().toLowerCase();
        _currentPage = 1;
      });
    });
  }

  @override
  void dispose() {
    _listSearchController.dispose();
    super.dispose();
  }

  DateTime? _rangeStart(String range, DateTime now) {
    switch (range) {
      case '1Week':
        return now.subtract(const Duration(days: 7));
      case '1Month':
        return now.subtract(const Duration(days: 30));
      case '1Year':
        return now.subtract(const Duration(days: 365));
      case '6Months':
        return now.subtract(const Duration(days: 182));
      case 'All':
      default:
        return null;
    }
  }

  void _onSort(String key) {
    setState(() {
      if (_sortBy == key) {
        _sortAscending = !_sortAscending;
      } else {
        _sortBy = key;
        _sortAscending = true;
      }
      _currentPage = 1;
    });
  }

  void _openPatientHistoryDialog(Patient patient) {
    showPatientHistoryDialogV2(
      context: context,
      patient: patient,
      rows: patient.patientDetails,
    );
  }

  Future<void> _confirmDeletePatient(Patient patient) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => ContentDialog(
        title: const Text('Delete patient?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Name: ${patient.title.trim().isEmpty ? 'Unnamed patient' : patient.title}',
            ),
            Text('Patient ID: ${patient.id}'),
            Text('Phone: ${patient.phone.trim().isEmpty ? '-' : patient.phone}'),
            Text('Age: ${patient.age}'),
            const SizedBox(height: 8),
            const Text('This action is permanent and cannot be undone.'),
          ],
        ),
        actions: [
          Button(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: ButtonStyle(
              backgroundColor:
                  WidgetStateProperty.all(const Color(0xFFD6455D)),
            ),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    await patients.hardDelete(patient.id);
  }

  @override
  Widget build(BuildContext context) {
    return ScaffoldPage.scrollable(
      key: WK.patientsScreenV2,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
      children: [
        MStreamBuilder(
          streams: [
            patients.observableMap.stream,
            appointments.observableMap.stream,
          ],
          builder: (context, _) {
            final allPatients = patients.present.values.toList(growable: false);
            final uniquePatientCount = allPatients
                .map((p) => p.id)
                .where((id) => id.trim().isNotEmpty)
                .toSet()
                .length;
            final allAppointments =
                appointments.present.values.toList(growable: false);

            final visitsByPatient = <String, List<Appointment>>{};
            for (final a in allAppointments) {
              final id = a.patientID;
              if (id == null || id.isEmpty) continue;
              (visitsByPatient[id] ??= []).add(a);
            }
            for (final list in visitsByPatient.values) {
              list.sort((a, b) => a.date.compareTo(b.date));
            }

            final now = DateTime.now();

            final spentByPatient = <String, double>{};
            for (final appointment in allAppointments) {
              final pid = appointment.patientID;
              if (pid == null || pid.isEmpty) continue;
              spentByPatient[pid] = (spentByPatient[pid] ?? 0) +
                  appointment.paid +
                  appointment.prescriptionPaid;
            }

            final ageBuckets = _ageGenderBuckets(allPatients);
            final genderBuckets = _genderBuckets(allPatients);
            final paymentModeBuckets = _paymentModeBuckets(allAppointments);

            final rangeStart = _rangeStart(_topRange, now);
            final topPatientsByVisits = allPatients
                .map((p) {
                  final visits = visitsByPatient[p.id] ?? const <Appointment>[];
                  final count = rangeStart == null
                      ? visits.length
                      : visits
                          .where((a) => !a.date.isBefore(rangeStart))
                          .length;
                  return MapEntry(p, count);
                })
                .where((entry) => entry.value > 0)
                .toList(growable: false)
              ..sort((a, b) => b.value.compareTo(a.value));

            final outstandingRangeStart = _rangeStart(_outstandingRange, now);
            final topOutstanding = allPatients
                .where((p) {
                  if (outstandingRangeStart == null) return true;
                  final visits = visitsByPatient[p.id] ?? const <Appointment>[];
                  return visits
                      .any((a) => !a.date.isBefore(outstandingRangeStart));
                })
                .map((p) => MapEntry(p, p.outstandingPayments))
                .where((entry) => entry.value > 0)
                .toList(growable: false)
              ..sort((a, b) => b.value.compareTo(a.value));

            final topProcedurePatients = _topPatientsByProcedure(
              allPatients: allPatients,
              allAppointments: allAppointments,
              procedureTab: _procedureTab,
            );

            final journeyMetrics = _treatmentJourneyMetrics(
              allPatients: allPatients,
              visitsByPatient: visitsByPatient,
              now: now,
            );

            final monthlyGrowth = _monthlyPatientGrowth(
              allAppointments: allAppointments,
              anchor: now,
            );

            final preAlphabetPatients = allPatients.where((patient) {
              if (_listQuery.isEmpty) return true;
              final name = patient.title.toLowerCase();
              final phone = patient.phone.toLowerCase();
              final id = patient.id.toLowerCase();
              final address = patient.address.toLowerCase();
              return name.contains(_listQuery) ||
                  phone.contains(_listQuery) ||
                  id.contains(_listQuery) ||
                  address.contains(_listQuery);
            }).toList(growable: false);

            final filteredPatients = preAlphabetPatients.where((patient) {
              if (_selectedAlphabet == 'All') return true;
              final titleTrimmed = patient.title.trim();
              final firstLetter =
                  titleTrimmed.isEmpty ? '' : titleTrimmed[0].toUpperCase();
              return firstLetter == _selectedAlphabet;
            }).where((patient) {
              if (_listBehaviorFilter == 'all') return true;
              final visits = visitsByPatient[patient.id] ?? const <Appointment>[];
              final totalSpent = spentByPatient[patient.id] ?? 0;
              final daysSinceLast =
                  visits.isEmpty ? 99999 : now.difference(visits.last.date).inDays;
              final daysSinceFirst =
                  visits.isEmpty ? 99999 : now.difference(visits.first.date).inDays;

              switch (_listBehaviorFilter) {
                case 'highValue':
                  return totalSpent >= _highValueThreshold;
                case 'frequent':
                  return visits.length >= 5;
                case 'inactive':
                  return visits.isNotEmpty && daysSinceLast > 180;
                case 'new':
                  return visits.isNotEmpty && daysSinceFirst <= 30;
                case 'oneTimer':
                  return visits.length == 1;
                case 'invalidPhone':
                  final digits =
                      patient.phone.replaceAll(RegExp(r'[^0-9]'), '');
                  return digits.length != 10;
                case 'noVisit':
                  return visits.isEmpty;
                case 'todayVisited':
                  return visits.any((a) =>
                      a.date.year == now.year &&
                      a.date.month == now.month &&
                      a.date.day == now.day);
                default:
                  return true;
              }
            }).toList(growable: false);

            filteredPatients.sort((a, b) {
              switch (_sortBy) {
                case 'id':
                  return a.id.toLowerCase().compareTo(b.id.toLowerCase());
                case 'phone':
                  return a.phone.toLowerCase().compareTo(b.phone.toLowerCase());
                case 'age':
                  return a.age.compareTo(b.age);
                case 'lastVisit':
                  final aRows = visitsByPatient[a.id] ?? const <Appointment>[];
                  final bRows = visitsByPatient[b.id] ?? const <Appointment>[];
                  final aLast = aRows.isEmpty
                      ? DateTime.fromMillisecondsSinceEpoch(0)
                      : aRows.last.date;
                  final bLast = bRows.isEmpty
                      ? DateTime.fromMillisecondsSinceEpoch(0)
                      : bRows.last.date;
                  return aLast.compareTo(bLast);
                case 'paidSoFar':
                  final aPaid = spentByPatient[a.id] ?? 0;
                  final bPaid = spentByPatient[b.id] ?? 0;
                  return aPaid.compareTo(bPaid);
                case 'visits':
                  final aVisits =
                      (visitsByPatient[a.id] ?? const <Appointment>[]).length;
                  final bVisits =
                      (visitsByPatient[b.id] ?? const <Appointment>[]).length;
                  return aVisits.compareTo(bVisits);
                case 'outstanding':
                  return a.outstandingPayments.compareTo(b.outstandingPayments);
                case 'name':
                default:
                  return a.title.toLowerCase().compareTo(b.title.toLowerCase());
              }
            });

            final sortedPatients = _sortAscending
                ? filteredPatients
                : filteredPatients.reversed.toList(growable: false);

            final totalPages =
                math.max(1, (sortedPatients.length / _pageSize).ceil());
            final currentPage = _currentPage.clamp(1, totalPages);
            final start = (currentPage - 1) * _pageSize;
            final end = math.min(start + _pageSize, sortedPatients.length);
            final pagedPatients = sortedPatients.sublist(start, end);
            final screenWidth = MediaQuery.of(context).size.width;
            final isMobile = screenWidth < 820;
            final isTablet = screenWidth >= 820 && screenWidth < 1180;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (isMobile)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const _TopBar(),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          onPressed: () => openPatient(),
                          style: ButtonStyle(
                            backgroundColor: WidgetStateProperty.all(
                              const Color(0xFF2D7BD8),
                            ),
                            foregroundColor: WidgetStateProperty.all(Colors.white),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(FluentIcons.add, size: 12),
                              SizedBox(width: 6),
                              Text('Add Patient'),
                            ],
                          ),
                        ),
                      ),
                    ],
                  )
                else
                  Row(
                    children: [
                      const Expanded(child: _TopBar()),
                      SizedBox(
                        width: isTablet ? 160 : 180,
                        child: FilledButton(
                          onPressed: () => openPatient(),
                          style: ButtonStyle(
                            backgroundColor: WidgetStateProperty.all(
                              const Color(0xFF2D7BD8),
                            ),
                            foregroundColor: WidgetStateProperty.all(Colors.white),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(FluentIcons.add, size: 12),
                              SizedBox(width: 6),
                              Text('Add Patient'),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    _MetricCard(
                      title: 'Total Patients (Unique IDs)',
                      value: '$uniquePatientCount',
                      valueColor: const Color(0xFF1D3E67),
                    ),
                    SizedBox(
                      width: 280,
                      height: 160,
                      child: _PatientGrowthMonthlyCard(rows: monthlyGrowth),
                    ),
                    SizedBox(
                      width: 280,
                      height: 160,
                      child: _TreatmentJourneyTimelineCard(
                        metrics: journeyMetrics,
                      ),
                    ),
                    _DonutMetricCard(
                      title: 'Payment Mode',
                      centerValue:
                          '${paymentModeBuckets.values.fold<int>(0, (s, v) => s + v)}',
                      segments: [
                        _DonutSegment(
                          label: 'Cash',
                          value: paymentModeBuckets['Cash'] ?? 0,
                          color: const Color(0xFF7D8FA7),
                        ),
                        _DonutSegment(
                          label: 'UPI',
                          value: paymentModeBuckets['UPI'] ?? 0,
                          color: const Color(0xFF2D7BD8),
                        ),
                      ],
                    ),
                    _DonutMetricCard(
                      title: 'Gender Distribution',
                      centerValue:
                          '${genderBuckets.values.fold<int>(0, (s, v) => s + v)}',
                      segments: [
                        _DonutSegment(
                          label: 'Male',
                          value: genderBuckets['Male'] ?? 0,
                          color: const Color(0xFF2D7BD8),
                        ),
                        _DonutSegment(
                          label: 'Female',
                          value: genderBuckets['Female'] ?? 0,
                          color: const Color(0xFF2BA58D),
                        ),
                      ],
                    ),
                    SizedBox(
                      width: 280,
                      height: 160,
                      child: _CompactAgeDistributionCard(buckets: ageBuckets),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final useHorizontalStrip = constraints.maxWidth >= 1240;
                    final cardWidth = useHorizontalStrip
                        ? 460.0
                        : constraints.maxWidth;

                    final cards = [
                      SizedBox(
                        width: cardWidth,
                        child: _TopPatientsCard(
                            rows: topPatientsByVisits,
                            visitsByPatient: visitsByPatient,
                            selectedRange: _topRange,
                            ranges: _topRanges,
                            onSelectRange: (v) => setState(() {
                              _topRange = v;
                              _topPatientsVisibleCount = 10;
                            }),
                            onOpenHistory: _openPatientHistoryDialog,
                            visibleCount: _topPatientsVisibleCount,
                            onViewMore: () => setState(() {
                              if (_topPatientsVisibleCount >=
                                  topPatientsByVisits.length) {
                                _topPatientsVisibleCount = 10;
                              } else {
                                _topPatientsVisibleCount = math.min(
                                  _topPatientsVisibleCount + 10,
                                  topPatientsByVisits.length,
                                );
                              }
                            }),
                        ),
                      ),
                      SizedBox(
                        width: cardWidth,
                        child: _TopOutstandingCard(
                            rows: topOutstanding,
                            visitsByPatient: visitsByPatient,
                            selectedRange: _outstandingRange,
                            ranges: _topRanges,
                            onSelectRange: (v) => setState(() {
                              _outstandingRange = v;
                              _topOutstandingVisibleCount = 10;
                            }),
                            onOpenHistory: _openPatientHistoryDialog,
                            visibleCount: _topOutstandingVisibleCount,
                            onViewMore: () => setState(() {
                              if (_topOutstandingVisibleCount >=
                                  topOutstanding.length) {
                                _topOutstandingVisibleCount = 10;
                              } else {
                                _topOutstandingVisibleCount = math.min(
                                  _topOutstandingVisibleCount + 10,
                                  topOutstanding.length,
                                );
                              }
                            }),
                        ),
                      ),
                      SizedBox(
                        width: cardWidth,
                        child: _TopProcedurePatientsCard(
                            selectedTab: _procedureTab,
                            rows: topProcedurePatients.toList(growable: false),
                            visitsByPatient: visitsByPatient,
                            onSelectTab: (tab) => setState(() {
                              _procedureTab = tab;
                              _topProcedureVisibleCount = 10;
                            }),
                            onOpenHistory: _openPatientHistoryDialog,
                            visibleCount: _topProcedureVisibleCount,
                            onViewMore: () => setState(() {
                              if (_topProcedureVisibleCount >=
                                  topProcedurePatients.length) {
                                _topProcedureVisibleCount = 10;
                              } else {
                                _topProcedureVisibleCount = math.min(
                                  _topProcedureVisibleCount + 10,
                                  topProcedurePatients.length,
                                );
                              }
                            }),
                        ),
                      ),
                    ];

                    if (useHorizontalStrip) {
                      return SizedBox(
                        height: 420,
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              cards[0],
                              const SizedBox(width: 10),
                              cards[1],
                              const SizedBox(width: 10),
                              cards[2],
                            ],
                          ),
                        ),
                      );
                    }

                    return Column(
                      children: [
                        cards[0],
                        const SizedBox(height: 10),
                        cards[1],
                        const SizedBox(height: 10),
                        cards[2],
                      ],
                    );
                  },
                ),
                const SizedBox(height: 10),
                _AllPatientsListCard(
                  patientsList: pagedPatients,
                  visitsByPatient: visitsByPatient,
                  selectedAlphabet: _selectedAlphabet,
                  onSelectAlphabet: (v) => setState(() {
                    _selectedAlphabet = _selectedAlphabet == v ? 'All' : v;
                    _currentPage = 1;
                  }),
                  behaviorFilter: _listBehaviorFilter,
                  onBehaviorFilterChanged: (v) => setState(() {
                    _listBehaviorFilter = v;
                    _currentPage = 1;
                  }),
                  highValueThreshold: _highValueThreshold,
                  onHighValueThresholdChanged: (v) => setState(() {
                    _highValueThreshold = v;
                    _currentPage = 1;
                  }),
                  sortBy: _sortBy,
                  sortAscending: _sortAscending,
                  onSort: _onSort,
                  listSearchController: _listSearchController,
                  onOpenHistory: _openPatientHistoryDialog,
                  onDeletePatient: _confirmDeletePatient,
                  totalItems: sortedPatients.length,
                  currentPage: currentPage,
                  totalPages: totalPages,
                  onPageChanged: (page) => setState(() => _currentPage = page),
                  serialOffset: start,
                ),
              ],
            );
          },
        ),
      ],
    );
  }

  List<({String label, int count})> _monthlyPatientGrowth({
    required List<Appointment> allAppointments,
    required DateTime anchor,
  }) {
    final buckets = <DateTime, Set<String>>{};
    for (int i = 23; i >= 0; i--) {
      final month = DateTime(anchor.year, anchor.month - i, 1);
      buckets[month] = <String>{};
    }

    for (final appointment in allAppointments) {
      final pid = appointment.patientID;
      if (pid == null || pid.isEmpty) continue;
      final month = DateTime(appointment.date.year, appointment.date.month, 1);
      final set = buckets[month];
      if (set != null) set.add(pid);
    }

    return buckets.entries
        .map((entry) {
          return (
            label: DateFormat('MMM').format(entry.key),
            count: entry.value.length,
          );
        })
        .toList(growable: false);
  }

  Map<String, Map<String, int>> _ageGenderBuckets(List<Patient> items) {
    final buckets = <String, Map<String, int>>{
      '0-10': {'Male': 0, 'Female': 0},
      '11-20': {'Male': 0, 'Female': 0},
      '21-30': {'Male': 0, 'Female': 0},
      '31-40': {'Male': 0, 'Female': 0},
      '41-49': {'Male': 0, 'Female': 0},
      '50+': {'Male': 0, 'Female': 0},
    };

    for (final p in items) {
      final age = p.age;
      if (age < 0) continue;
      final gender = p.gender == 1 ? 'Male' : 'Female';
      final String bucket;
      if (age <= 10) {
        bucket = '0-10';
      } else if (age <= 20) {
        bucket = '11-20';
      } else if (age <= 30) {
        bucket = '21-30';
      } else if (age <= 40) {
        bucket = '31-40';
      } else if (age <= 49) {
        bucket = '41-49';
      } else {
        bucket = '50+';
      }
      buckets[bucket]![gender] = buckets[bucket]![gender]! + 1;
    }

    return buckets;
  }

  Map<String, int> _genderBuckets(List<Patient> items) {
    final buckets = <String, int>{
      'Male': 0,
      'Female': 0,
    };

    for (final p in items) {
      if (p.gender == 1) {
        buckets['Male'] = buckets['Male']! + 1;
      } else {
        buckets['Female'] = buckets['Female']! + 1;
      }
    }

    return buckets;
  }

  Map<String, int> _paymentModeBuckets(List<Appointment> items) {
    final buckets = <String, int>{
      'Cash': 0,
      'UPI': 0,
    };

    for (final a in items) {
      final hasCash = (a.paid > 0 && !a.treatmentGpayPaid) ||
          (a.prescriptionPaid > 0 && !a.prescriptionGpayPaid);
      final hasGpay = (a.paid > 0 && a.treatmentGpayPaid) ||
          (a.prescriptionPaid > 0 && a.prescriptionGpayPaid);

      if (!hasCash && !hasGpay) continue;
      if (hasCash) {
        buckets['Cash'] = buckets['Cash']! + 1;
      }
      if (hasGpay) {
        buckets['UPI'] = buckets['UPI']! + 1;
      }
    }

    return buckets;
  }

  List<MapEntry<Patient, int>> _topPatientsByProcedure({
    required List<Patient> allPatients,
    required List<Appointment> allAppointments,
    required String procedureTab,
  }) {
    final patientById = <String, Patient>{
      for (final p in allPatients)
        if (p.id.trim().isNotEmpty) p.id: p,
    };

    final counts = <String, int>{};
    final key = procedureTab.toLowerCase();

    for (final appointment in allAppointments) {
      final patientId = appointment.patientID;
      if (patientId == null || patientId.isEmpty) continue;

      final hasProcedure = appointment.selectedTreatments.any((treatment) {
        final normalized = treatment.toLowerCase();
        if (key == 'rct') return normalized.contains('rct');
        return normalized.contains('ortho');
      });

      if (!hasProcedure) continue;
      counts[patientId] = (counts[patientId] ?? 0) + 1;
    }

    final rows = counts.entries
        .map((entry) {
          final patient = patientById[entry.key];
          if (patient == null) return null;
          return MapEntry(patient, entry.value);
        })
        .whereType<MapEntry<Patient, int>>()
        .toList(growable: false)
      ..sort((a, b) => b.value.compareTo(a.value));

    return rows;
  }

  _TreatmentJourneyMetrics _treatmentJourneyMetrics({
    required List<Patient> allPatients,
    required Map<String, List<Appointment>> visitsByPatient,
    required DateTime now,
  }) {
    int newlyAdded = 0;
    int active = 0;
    int followUpDue = 0;
    int inactive = 0;

    for (final patient in allPatients) {
      final visits = visitsByPatient[patient.id] ?? const <Appointment>[];
      if (visits.isEmpty) continue;

      final daysSinceLast = now.difference(visits.last.date).inDays;
      if (visits.length == 1) {
        newlyAdded++;
      } else if (daysSinceLast <= 60) {
        active++;
      } else if (daysSinceLast <= 180) {
        followUpDue++;
      } else {
        inactive++;
      }
    }

    return _TreatmentJourneyMetrics(
      newlyAdded: newlyAdded,
      active: active,
      followUpDue: followUpDue,
      inactive: inactive,
    );
  }
}

class _TreatmentJourneyMetrics {
  final int newlyAdded;
  final int active;
  final int followUpDue;
  final int inactive;

  const _TreatmentJourneyMetrics({
    required this.newlyAdded,
    required this.active,
    required this.followUpDue,
    required this.inactive,
  });
}

class _TreatmentJourneyTimelineCard extends StatelessWidget {
  final _TreatmentJourneyMetrics metrics;

  const _TreatmentJourneyTimelineCard({required this.metrics});

  @override
  Widget build(BuildContext context) {
    final values = [
      metrics.newlyAdded,
      metrics.active,
      metrics.followUpDue,
      metrics.inactive,
    ];
    final maxValue = values.fold<int>(1, (m, v) => v > m ? v : m);

    Widget bar(String label, int value, Color color) {
      return Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    label,
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFF36557C),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Text(
                  '$value',
                  style: const TextStyle(
                    color: Color(0xFF1F446E),
                    fontWeight: FontWeight.w700,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 3),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: Container(
                height: 8,
                color: const Color(0xFFEAF2FC),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: FractionallySizedBox(
                    widthFactor: maxValue == 0 ? 0 : value / maxValue,
                    child: Container(color: color),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return _CardShell(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'Treatment Journey',
                style: TextStyle(
                  fontSize: 13,
                  color: Color(0xFF3C5E87),
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              IconButton(
                icon: Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE8F2FF),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: const Color(0xFFC7DCF7)),
                  ),
                  child: const Icon(
                    FluentIcons.info,
                    size: 11,
                    color: Color(0xFF2D7BD8),
                  ),
                ),
                onPressed: () => showDialog(
                  context: context,
                  builder: (context) => ContentDialog(
                    title: const Text('Treatment Journey Legend'),
                    content: const Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('New: first visit only'),
                        SizedBox(height: 4),
                        Text('Active: last visit <= 60 days'),
                        SizedBox(height: 4),
                        Text('Follow-up: last visit between 61 and 180 days'),
                        SizedBox(height: 4),
                        Text('Inactive: last visit > 180 days'),
                      ],
                    ),
                    actions: [
                      Button(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('Close'),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              bar('New', metrics.newlyAdded, const Color(0xFF2D7BD8)),
              const SizedBox(width: 6),
              bar('Active', metrics.active, const Color(0xFF2BA58D)),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              bar('Follow-up', metrics.followUpDue, const Color(0xFFE09C31)),
              const SizedBox(width: 6),
              bar('Inactive', metrics.inactive, const Color(0xFF7D8FA7)),
            ],
          ),
        ],
      ),
    );
  }
}

class _InsightRow extends StatelessWidget {
  final String label;
  final String value;

  const _InsightRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                color: Color(0xFF36557C),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              color: Color(0xFF1F446E),
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar();

  @override
  Widget build(BuildContext context) {
    return const Text(
      'Patients',
      style: TextStyle(
        fontSize: 28,
        fontWeight: FontWeight.w600,
        color: Color(0xFF112E54),
        letterSpacing: 0.1,
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  final String title;
  final String value;
  final Color valueColor;

  const _MetricCard({
    required this.title,
    required this.value,
    required this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 280,
      height: 160,
      child: _CardShell(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 13,
                color: Color(0xFF3C5E87),
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              value,
              style: TextStyle(
                fontSize: 38,
                fontWeight: FontWeight.w700,
                color: valueColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PatientGrowthMonthlyCard extends StatefulWidget {
  final List<({String label, int count})> rows;

  const _PatientGrowthMonthlyCard({required this.rows});

  @override
  State<_PatientGrowthMonthlyCard> createState() =>
      _PatientGrowthMonthlyCardState();
}

class _PatientGrowthMonthlyCardState extends State<_PatientGrowthMonthlyCard> {
  static const int _windowSize = 6;
  int _windowEnd = 0;

  @override
  void initState() {
    super.initState();
    _windowEnd = widget.rows.length;
  }

  @override
  void didUpdateWidget(covariant _PatientGrowthMonthlyCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.rows.length != widget.rows.length) {
      _windowEnd = widget.rows.length;
    }
  }

  @override
  Widget build(BuildContext context) {
    final safeWindowEnd = _windowEnd.clamp(0, widget.rows.length).toInt();
    final safeWindowStart =
      (safeWindowEnd - _windowSize).clamp(0, safeWindowEnd).toInt();
    final visibleRows = widget.rows.sublist(safeWindowStart, safeWindowEnd);
    final peak = visibleRows.fold<int>(1, (m, e) => e.count > m ? e.count : m);
    final hasGrowth = widget.rows.length >= 2 &&
        widget.rows.last.count >= widget.rows[widget.rows.length - 2].count;
    final trendColor = hasGrowth ? const Color(0xFF2BA58D) : const Color(0xFFD6455D);
    final canGoBack = safeWindowStart > 0;
    final canGoForward = safeWindowEnd < widget.rows.length;

    return _CardShell(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'Patient Growth (Monthly)',
                style: TextStyle(
                  fontSize: 13,
                  color: Color(0xFF3C5E87),
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 6),
              _MiniNavArrow(
                icon: FluentIcons.chevron_left,
                enabled: canGoBack,
                onTap: () {
                  if (!canGoBack) return;
                  setState(() => _windowEnd = safeWindowEnd - _windowSize);
                },
              ),
              const SizedBox(width: 4),
              _MiniNavArrow(
                icon: FluentIcons.chevron_right,
                enabled: canGoForward,
                onTap: () {
                  if (!canGoForward) return;
                  setState(() => _windowEnd = safeWindowEnd + _windowSize);
                },
              ),
              const Spacer(),
              Icon(
                hasGrowth ? FluentIcons.up : FluentIcons.down,
                size: 10,
                color: trendColor,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: visibleRows.map((row) {
                final ratio = peak == 0 ? 0.0 : row.count / peak;
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text(
                          '${row.count}',
                          style: const TextStyle(
                            color: Color(0xFF1F446E),
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          height: 64 * ratio.clamp(0.0, 1.0),
                          decoration: BoxDecoration(
                            color: const Color(0xFF2D7BD8),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          row.label,
                          style: const TextStyle(
                            color: Color(0xFF5B789F),
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(growable: false),
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniNavArrow extends StatelessWidget {
  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;

  const _MiniNavArrow({
    required this.icon,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        width: 16,
        height: 16,
        decoration: BoxDecoration(
          color: enabled ? const Color(0xFFEAF2FC) : const Color(0xFFF4F8FD),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
            color: enabled ? const Color(0xFFBED4F1) : const Color(0xFFE2ECF8),
          ),
        ),
        child: Icon(
          icon,
          size: 9,
          color: enabled ? const Color(0xFF2D7BD8) : const Color(0xFF9FB4CF),
        ),
      ),
    );
  }
}

class _DonutSegment {
  final String label;
  final int value;
  final Color color;

  const _DonutSegment({
    required this.label,
    required this.value,
    required this.color,
  });
}

class _DonutMetricCard extends StatelessWidget {
  final String title;
  final String centerValue;
  final List<_DonutSegment> segments;

  const _DonutMetricCard({
    required this.title,
    required this.centerValue,
    required this.segments,
  });

  @override
  Widget build(BuildContext context) {
    final total = segments.fold<int>(0, (sum, s) => sum + s.value);

    return SizedBox(
      width: 280,
      height: 160,
      child: _CardShell(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 13,
                color: Color(0xFF3C5E87),
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                SizedBox(
                  width: 86,
                  height: 86,
                  child: CustomPaint(
                    painter: _DonutPainter(segments: segments),
                    child: Center(
                      child: Text(
                        centerValue,
                        style: const TextStyle(
                          color: Color(0xFF1D3E67),
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: segments
                        .map(
                          (s) => Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: Row(
                              children: [
                                Container(
                                  width: 10,
                                  height: 10,
                                  decoration: BoxDecoration(
                                    color: s.color,
                                    borderRadius: BorderRadius.circular(2),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    '${s.label} (${s.value})',
                                    style: const TextStyle(
                                      color: Color(0xFF36557C),
                                      fontWeight: FontWeight.w600,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                                Text(
                                  total == 0
                                      ? '0%'
                                      : '${((s.value / total) * 100).round()}%',
                                  style: const TextStyle(
                                    color: Color(0xFF1F446E),
                                    fontWeight: FontWeight.w700,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                        .toList(growable: false),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _DonutPainter extends CustomPainter {
  final List<_DonutSegment> segments;

  const _DonutPainter({required this.segments});

  @override
  void paint(Canvas canvas, Size size) {
    final total = segments.fold<int>(0, (sum, s) => sum + s.value);
    final stroke = size.width * 0.18;
    final rect = Offset.zero & size;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;

    if (total == 0) {
      paint.color = const Color(0xFFD8E6F5);
      canvas.drawArc(
          rect.deflate(stroke / 2), -math.pi / 2, math.pi * 2, false, paint);
      return;
    }

    double start = -math.pi / 2;
    final gap = 0.04;
    for (final segment in segments) {
      if (segment.value <= 0) continue;
      final sweep = (segment.value / total) * math.pi * 2;
      paint.color = segment.color;
      final adjustedSweep = math.max(0, sweep - gap);
      canvas.drawArc(
        rect.deflate(stroke / 2),
        start,
        adjustedSweep.toDouble(),
        false,
        paint,
      );
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant _DonutPainter oldDelegate) {
    return oldDelegate.segments != segments;
  }
}

class _CompactAgeDistributionCard extends StatefulWidget {
  final Map<String, Map<String, int>> buckets;

  const _CompactAgeDistributionCard({required this.buckets});

  @override
  State<_CompactAgeDistributionCard> createState() =>
      _CompactAgeDistributionCardState();
}

class _CompactAgeDistributionCardState
    extends State<_CompactAgeDistributionCard> {
  @override
  Widget build(BuildContext context) {
    final rows = widget.buckets.entries.map((entry) {
      final male = entry.value['Male'] ?? 0;
      final female = entry.value['Female'] ?? 0;
      return (label: entry.key, male: male, female: female);
    }).toList(growable: false);
    final totalPatients =
        rows.fold<int>(0, (sum, row) => sum + row.male + row.female);

    final maxValue = rows.fold<int>(1, (m, e) {
      final total = e.male + e.female;
      return total > m ? total : m;
    });

    return _CardShell(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'Age Distribution',
                style: TextStyle(
                  fontSize: 13,
                  color: Color(0xFF3C5E87),
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'Total: $totalPatients',
                style: const TextStyle(
                  color: Color(0xFF5A7397),
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: const Color(0xFF2D7BD8),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 3),
              const Text(
                'M',
                style: TextStyle(
                  color: Color(0xFF4E678B),
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: const Color(0xFF2BA58D),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 3),
              const Text(
                'F',
                style: TextStyle(
                  color: Color(0xFF4E678B),
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: rows
                    .map(
                      (row) => Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Row(
                          children: [
                            SizedBox(
                              width: 42,
                              child: Text(
                                row.label,
                                style: const TextStyle(
                                  color: Color(0xFF36557C),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            Expanded(
                              child: LayoutBuilder(
                                builder: (context, inner) {
                                  final total = row.male + row.female;
                                  final totalWidth = maxValue == 0
                                      ? 0.0
                                      : inner.maxWidth * (total / maxValue);
                                  final maleWidth = total == 0
                                      ? 0.0
                                      : totalWidth * (row.male / total);
                                  final femaleWidth = totalWidth - maleWidth;

                                  return ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: Stack(
                                      children: [
                                        Container(
                                          height: 8,
                                          color: const Color(0xFFEAF2FC),
                                        ),
                                        Row(
                                          children: [
                                            if (maleWidth > 0)
                                              Container(
                                                height: 8,
                                                width: maleWidth,
                                                color: const Color(0xFF2D7BD8),
                                              ),
                                            if (femaleWidth > 0)
                                              Container(
                                                height: 8,
                                                width: femaleWidth,
                                                color: const Color(0xFF2BA58D),
                                              ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                            ),
                            const SizedBox(width: 8),
                            SizedBox(
                              width: 118,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  Container(
                                    width: 6,
                                    height: 6,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF2D7BD8),
                                      borderRadius: BorderRadius.circular(999),
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    '${row.male}',
                                    style: const TextStyle(
                                      color: Color(0xFF1F446E),
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    width: 6,
                                    height: 6,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF2BA58D),
                                      borderRadius: BorderRadius.circular(999),
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    '${row.female}',
                                    style: const TextStyle(
                                      color: Color(0xFF1F446E),
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'T:${row.male + row.female}',
                                    style: const TextStyle(
                                      color: Color(0xFF5A7397),
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                    .toList(growable: false),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AgeDistributionCard extends StatefulWidget {
  final Map<String, Map<String, int>> buckets;

  const _AgeDistributionCard({required this.buckets});

  @override
  State<_AgeDistributionCard> createState() => _AgeDistributionCardState();
}

class _AgeDistributionCardState extends State<_AgeDistributionCard> {
  String? _hoveredKey;

  @override
  Widget build(BuildContext context) {
    final maxValue = widget.buckets.values
        .map((m) => (m['Male'] ?? 0) + (m['Female'] ?? 0))
        .fold<int>(0, (m, v) => v > m ? v : m);
    final sorted = widget.buckets.entries.toList(growable: false)
      ..sort((a, b) {
        final aTotal = (a.value['Male'] ?? 0) + (a.value['Female'] ?? 0);
        final bTotal = (b.value['Male'] ?? 0) + (b.value['Female'] ?? 0);
        return bTotal.compareTo(aTotal);
      });

    return _CardShell(
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 320, maxHeight: 420),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Patient Age Distribution',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Color(0xFF183A67),
              ),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: const Color(0xFF2D7BD8),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 4),
                const Text('Male',
                    style: TextStyle(fontSize: 11, color: Color(0xFF36557C))),
                const SizedBox(width: 10),
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: const Color(0xFF2BA58D),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 4),
                const Text('Female',
                    style: TextStyle(fontSize: 11, color: Color(0xFF36557C))),
              ],
            ),
            const SizedBox(height: 8),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: sorted.map((entry) {
                    final male = entry.value['Male'] ?? 0;
                    final female = entry.value['Female'] ?? 0;
                    final total = male + female;
                    final totalRatio = maxValue == 0 ? 0.0 : total / maxValue;
                    final maleRatio =
                        total == 0 ? 0.0 : male / total.toDouble();
                    final isHovered = _hoveredKey == entry.key;

                    return MouseRegion(
                      onEnter: (_) => setState(() => _hoveredKey = entry.key),
                      onExit: (_) => setState(() => _hoveredKey = null),
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          children: [
                            SizedBox(
                              width: 46,
                              child: Text(
                                entry.key,
                                style: const TextStyle(
                                  color: Color(0xFF36557C),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            Expanded(
                              child: LayoutBuilder(
                                builder: (context, constraints) {
                                  final barWidth =
                                      constraints.maxWidth * totalRatio;
                                  final maleWidth = barWidth * maleRatio;
                                  final femaleWidth =
                                      barWidth * (1.0 - maleRatio);
                                  return Stack(
                                    children: [
                                      Container(
                                        height: 10,
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFE9F1FC),
                                          borderRadius:
                                              BorderRadius.circular(8),
                                        ),
                                      ),
                                      if (maleWidth > 0)
                                        Positioned(
                                          left: 0,
                                          child: Container(
                                            height: 10,
                                            width: maleWidth,
                                            decoration: BoxDecoration(
                                              color: const Color(0xFF2D7BD8),
                                              borderRadius: BorderRadius.only(
                                                topLeft:
                                                    const Radius.circular(8),
                                                bottomLeft:
                                                    const Radius.circular(8),
                                                topRight: femaleWidth > 0
                                                    ? Radius.zero
                                                    : const Radius.circular(8),
                                                bottomRight: femaleWidth > 0
                                                    ? Radius.zero
                                                    : const Radius.circular(8),
                                              ),
                                            ),
                                          ),
                                        ),
                                      if (femaleWidth > 0)
                                        Positioned(
                                          left: maleWidth,
                                          child: Container(
                                            height: 10,
                                            width: femaleWidth,
                                            decoration: BoxDecoration(
                                              color: const Color(0xFF2BA58D),
                                              borderRadius: BorderRadius.only(
                                                topLeft: maleWidth > 0
                                                    ? Radius.zero
                                                    : const Radius.circular(8),
                                                bottomLeft: maleWidth > 0
                                                    ? Radius.zero
                                                    : const Radius.circular(8),
                                                topRight:
                                                    const Radius.circular(8),
                                                bottomRight:
                                                    const Radius.circular(8),
                                              ),
                                            ),
                                          ),
                                        ),
                                    ],
                                  );
                                },
                              ),
                            ),
                            const SizedBox(width: 8),
                            SizedBox(
                              width: 64,
                              child: Text(
                                isHovered ? 'M:$male F:$female' : '$total',
                                textAlign: TextAlign.right,
                                style: TextStyle(
                                  color: isHovered
                                      ? const Color(0xFF1A5CA3)
                                      : const Color(0xFF1F446E),
                                  fontWeight: FontWeight.w700,
                                  fontSize: isHovered ? 11 : 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(growable: false),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GenderDistributionCard extends StatelessWidget {
  final Map<String, int> buckets;

  const _GenderDistributionCard({required this.buckets});

  @override
  Widget build(BuildContext context) {
    final maxValue = buckets.values.fold<int>(0, (m, v) => v > m ? v : m);

    return _CardShell(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Gender Distribution',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Color(0xFF183A67),
            ),
          ),
          const SizedBox(height: 10),
          ...buckets.entries.map((entry) {
            final ratio = maxValue == 0 ? 0.0 : (entry.value / maxValue);
            final barColor = entry.key == 'Male'
                ? const Color(0xFF2D7BD8)
                : const Color(0xFF2BA58D);
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  SizedBox(
                    width: 56,
                    child: Text(
                      entry.key,
                      style: const TextStyle(
                        color: Color(0xFF36557C),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Expanded(
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        return Stack(
                          children: [
                            Container(
                              height: 10,
                              decoration: BoxDecoration(
                                color: const Color(0xFFE9F1FC),
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            Container(
                              height: 10,
                              width: constraints.maxWidth * ratio,
                              decoration: BoxDecoration(
                                color: barColor,
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 40,
                    child: Text(
                      '${entry.value}',
                      textAlign: TextAlign.right,
                      style: const TextStyle(
                        color: Color(0xFF1F446E),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _PaymentModeDistributionCard extends StatelessWidget {
  final Map<String, int> buckets;

  const _PaymentModeDistributionCard({required this.buckets});

  @override
  Widget build(BuildContext context) {
    final maxValue = buckets.values.fold<int>(0, (m, v) => v > m ? v : m);

    return _CardShell(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Payment Mode Distribution',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Color(0xFF183A67),
            ),
          ),
          const SizedBox(height: 10),
          ...buckets.entries.map((entry) {
            final ratio = maxValue == 0 ? 0.0 : (entry.value / maxValue);
            final barColor = entry.key == 'UPI'
                ? const Color(0xFF2D7BD8)
                : const Color(0xFF7D8FA7);
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  SizedBox(
                    width: 56,
                    child: Text(
                      entry.key,
                      style: const TextStyle(
                        color: Color(0xFF36557C),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Expanded(
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        return Stack(
                          children: [
                            Container(
                              height: 10,
                              decoration: BoxDecoration(
                                color: const Color(0xFFE9F1FC),
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            Container(
                              height: 10,
                              width: constraints.maxWidth * ratio,
                              decoration: BoxDecoration(
                                color: barColor,
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 40,
                    child: Text(
                      '${entry.value}',
                      textAlign: TextAlign.right,
                      style: const TextStyle(
                        color: Color(0xFF1F446E),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _TopPatientsCard extends StatelessWidget {
  final List<MapEntry<Patient, int>> rows;
  final Map<String, List<Appointment>> visitsByPatient;
  final String selectedRange;
  final List<String> ranges;
  final ValueChanged<String> onSelectRange;
  final ValueChanged<Patient> onOpenHistory;
  final int visibleCount;
  final VoidCallback onViewMore;

  const _TopPatientsCard({
    required this.rows,
    required this.visitsByPatient,
    required this.selectedRange,
    required this.ranges,
    required this.onSelectRange,
    required this.onOpenHistory,
    required this.visibleCount,
    required this.onViewMore,
  });

  @override
  Widget build(BuildContext context) {
    final visibleRows = rows.take(visibleCount).toList(growable: false);
    final hasMore = visibleCount < rows.length;

    return _CardShell(
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 320, maxHeight: 420),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Top Patients by Visits',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Color(0xFF183A67),
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: ranges
                  .map(
                    (range) => GestureDetector(
                      onTap: () => onSelectRange(range),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 7,
                        ),
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: selectedRange == range
                                ? const Color(0xFF2D7BD8)
                                : const Color(0xFFD4E2F3),
                          ),
                          color: selectedRange == range
                              ? const Color(0xFF2D7BD8)
                              : const Color(0xFFEFF4FB),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          range,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: selectedRange == range
                                ? Colors.white
                                : const Color(0xFF345982),
                          ),
                        ),
                      ),
                    ),
                  )
                  .toList(growable: false),
            ),
            const SizedBox(height: 14),
            if (rows.isEmpty)
              const Text(
                'No visits in this range.',
                style: TextStyle(color: Color(0xFF607B9F)),
              )
            else
              Expanded(
                child: Column(
                  children: [
                    Expanded(
                      child: Scrollbar(
                        child: ListView(
                          primary: false,
                          padding: EdgeInsets.zero,
                          physics: const ClampingScrollPhysics(),
                          children: visibleRows
                              .asMap()
                              .entries
                              .map(
                                (entry) => _HoverableListRow(
                                  isLast: entry.key == visibleRows.length - 1,
                                  onTap: () => onOpenHistory(entry.value.key),
                                  leading: Text(
                                    '${entry.key + 1}.',
                                    style: const TextStyle(
                                      color: Color(0xFF36557C),
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  title: Text(
                                    entry.value.key.title.trim().isEmpty
                                        ? 'Unnamed patient'
                                        : entry.value.key.title,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: Color(0xFF1F446E),
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  subtitle: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '${entry.value.key.phone} • ${entry.value.key.age}y',
                                        style: const TextStyle(
                                          color: Color(0xFF7C93B1),
                                          fontSize: 11,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Wrap(
                                        spacing: 4,
                                        runSpacing: 4,
                                        children: _treatmentChips(
                                          visitsByPatient,
                                          entry.value.key,
                                        ),
                                      ),
                                    ],
                                  ),
                                  trailing: Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        '${entry.value.value} visits',
                                        style: const TextStyle(
                                          color: Color(0xFF1F446E),
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        'Last: ${_lastVisited(visitsByPatient, entry.value.key)}',
                                        style: const TextStyle(
                                          color: Color(0xFF7C93B1),
                                          fontSize: 11,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              )
                              .toList(growable: false),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (rows.length > 10)
                      FilledButton(
                        onPressed: onViewMore,
                        style: ButtonStyle(
                          backgroundColor: WidgetStateProperty.all(
                            const Color(0xFF2D7BD8),
                          ),
                        ),
                        child: Text(hasMore ? 'View More (+10)' : 'Show Less'),
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _lastVisited(
    Map<String, List<Appointment>> visitsByPatient,
    Patient patient,
  ) {
    final visits = visitsByPatient[patient.id] ?? const <Appointment>[];
    if (visits.isEmpty) return '-';
    return DateFormat('dd MMM').format(visits.last.date);
  }

  List<Widget> _treatmentChips(
    Map<String, List<Appointment>> visitsByPatient,
    Patient patient,
  ) {
    final visits = visitsByPatient[patient.id] ?? const <Appointment>[];
    final unique = <String>{};
    for (final appointment in visits) {
      for (final treatment in appointment.selectedTreatments) {
        final value = treatment.trim();
        if (value.isNotEmpty) unique.add(value);
      }
    }
    final rows = unique.toList(growable: false)..sort();
    if (rows.isEmpty) {
      return const [
        Text(
          'No treatments',
          style: TextStyle(color: Color(0xFF8AA0BC), fontSize: 10),
        ),
      ];
    }
    final visible = rows.take(3).toList(growable: false);
    return visible
        .map(
          (row) => Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: const Color(0xFFEAF2FC),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: const Color(0xFFD5E5F7)),
            ),
            child: Text(
              row,
              style: const TextStyle(
                color: Color(0xFF2F5B88),
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        )
        .toList(growable: false);
  }
}

class _TopOutstandingCard extends StatelessWidget {
  final List<MapEntry<Patient, double>> rows;
  final Map<String, List<Appointment>> visitsByPatient;
  final String selectedRange;
  final List<String> ranges;
  final ValueChanged<String> onSelectRange;
  final ValueChanged<Patient> onOpenHistory;
  final int visibleCount;
  final VoidCallback onViewMore;

  const _TopOutstandingCard({
    required this.rows,
    required this.visitsByPatient,
    required this.selectedRange,
    required this.ranges,
    required this.onSelectRange,
    required this.onOpenHistory,
    required this.visibleCount,
    required this.onViewMore,
  });

  @override
  Widget build(BuildContext context) {
    final visibleRows = rows.take(visibleCount).toList(growable: false);
    final hasMore = visibleCount < rows.length;

    return _CardShell(
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 320, maxHeight: 420),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Top Outstanding Patients',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Color(0xFF183A67),
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: ranges
                  .map(
                    (range) => GestureDetector(
                      onTap: () => onSelectRange(range),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 7,
                        ),
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: selectedRange == range
                                ? const Color(0xFF2D7BD8)
                                : const Color(0xFFD4E2F3),
                          ),
                          color: selectedRange == range
                              ? const Color(0xFF2D7BD8)
                              : const Color(0xFFEFF4FB),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          range,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: selectedRange == range
                                ? Colors.white
                                : const Color(0xFF345982),
                          ),
                        ),
                      ),
                    ),
                  )
                  .toList(growable: false),
            ),
            const SizedBox(height: 14),
            if (rows.isEmpty)
              const Text(
                'No outstanding balances.',
                style: TextStyle(color: Color(0xFF607B9F)),
              )
            else
              Expanded(
                child: Column(
                  children: [
                    Expanded(
                      child: Scrollbar(
                        child: ListView(
                          primary: false,
                          padding: EdgeInsets.zero,
                          physics: const ClampingScrollPhysics(),
                          children: visibleRows
                              .asMap()
                              .entries
                              .map(
                                (entry) => _HoverableListRow(
                                  isLast: entry.key == visibleRows.length - 1,
                                  onTap: () => onOpenHistory(entry.value.key),
                                  leading: Text(
                                    '${entry.key + 1}.',
                                    style: const TextStyle(
                                      color: Color(0xFF36557C),
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  title: Text(
                                    entry.value.key.title.trim().isEmpty
                                        ? 'Unnamed patient'
                                        : entry.value.key.title,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: Color(0xFF1F446E),
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  subtitle: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '${entry.value.key.phone} • ${entry.value.key.age}y',
                                        style: const TextStyle(
                                          color: Color(0xFF7C93B1),
                                          fontSize: 11,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Wrap(
                                        spacing: 4,
                                        runSpacing: 4,
                                        children: _treatmentChips(
                                          visitsByPatient,
                                          entry.value.key,
                                        ),
                                      ),
                                    ],
                                  ),
                                  trailing: Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        '₹${entry.value.value.toStringAsFixed(0)}',
                                        style: const TextStyle(
                                          color: Color(0xFFD6455D),
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        'Last: ${_lastVisited(visitsByPatient, entry.value.key)}',
                                        style: const TextStyle(
                                          color: Color(0xFF7C93B1),
                                          fontSize: 11,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              )
                              .toList(growable: false),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (rows.length > 10)
                      FilledButton(
                        onPressed: onViewMore,
                        style: ButtonStyle(
                          backgroundColor: WidgetStateProperty.all(
                            const Color(0xFF2D7BD8),
                          ),
                        ),
                        child: Text(hasMore ? 'View More (+10)' : 'Show Less'),
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _lastVisited(
    Map<String, List<Appointment>> visitsByPatient,
    Patient patient,
  ) {
    final visits = visitsByPatient[patient.id] ?? const <Appointment>[];
    if (visits.isEmpty) return '-';
    return DateFormat('dd MMM').format(visits.last.date);
  }

  List<Widget> _treatmentChips(
    Map<String, List<Appointment>> visitsByPatient,
    Patient patient,
  ) {
    final visits = visitsByPatient[patient.id] ?? const <Appointment>[];
    final unique = <String>{};
    for (final appointment in visits) {
      for (final treatment in appointment.selectedTreatments) {
        final value = treatment.trim();
        if (value.isNotEmpty) unique.add(value);
      }
    }
    final rows = unique.toList(growable: false)..sort();
    if (rows.isEmpty) {
      return const [
        Text(
          'No treatments',
          style: TextStyle(color: Color(0xFF8AA0BC), fontSize: 10),
        ),
      ];
    }
    final visible = rows.take(3).toList(growable: false);
    return visible
        .map(
          (row) => Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: const Color(0xFFEAF2FC),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: const Color(0xFFD5E5F7)),
            ),
            child: Text(
              row,
              style: const TextStyle(
                color: Color(0xFF2F5B88),
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        )
        .toList(growable: false);
  }
}

class _TopProcedurePatientsCard extends StatelessWidget {
  final String selectedTab;
  final List<MapEntry<Patient, int>> rows;
  final Map<String, List<Appointment>> visitsByPatient;
  final ValueChanged<String> onSelectTab;
  final ValueChanged<Patient> onOpenHistory;
  final int visibleCount;
  final VoidCallback onViewMore;

  const _TopProcedurePatientsCard({
    required this.selectedTab,
    required this.rows,
    required this.visitsByPatient,
    required this.onSelectTab,
    required this.onOpenHistory,
    required this.visibleCount,
    required this.onViewMore,
  });

  @override
  Widget build(BuildContext context) {
    final visibleRows = rows.take(visibleCount).toList(growable: false);
    final hasMore = visibleCount < rows.length;

    Widget tabChip(String label) {
      final selected = selectedTab == label;
      return GestureDetector(
        onTap: () => onSelectTab(label),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            border: Border.all(
              color:
                  selected ? const Color(0xFF2D7BD8) : const Color(0xFFD4E2F3),
            ),
            color: selected ? const Color(0xFF2D7BD8) : const Color(0xFFEFF4FB),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: selected ? Colors.white : const Color(0xFF345982),
            ),
          ),
        ),
      );
    }

    return _CardShell(
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 320, maxHeight: 420),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Procedure Focus Patients',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Color(0xFF183A67),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                tabChip('RCT'),
                const SizedBox(width: 6),
                tabChip('ORTHO'),
              ],
            ),
            const SizedBox(height: 14),
            if (rows.isEmpty)
              Text(
                'No patients found for $selectedTab treatments.',
                style: const TextStyle(color: Color(0xFF607B9F)),
              )
            else
              Expanded(
                child: Column(
                  children: [
                    Expanded(
                      child: Scrollbar(
                        child: ListView(
                          primary: false,
                          padding: EdgeInsets.zero,
                          physics: const ClampingScrollPhysics(),
                          children: visibleRows
                              .asMap()
                              .entries
                              .map(
                                (entry) => _HoverableListRow(
                                  isLast: entry.key == visibleRows.length - 1,
                                  onTap: () => onOpenHistory(entry.value.key),
                                  leading: Text(
                                    '${entry.key + 1}.',
                                    style: const TextStyle(
                                      color: Color(0xFF36557C),
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  title: Text(
                                    entry.value.key.title.trim().isEmpty
                                        ? 'Unnamed patient'
                                        : entry.value.key.title,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: Color(0xFF1F446E),
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  subtitle: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '${entry.value.key.phone} • ${entry.value.key.age}y',
                                        style: const TextStyle(
                                          color: Color(0xFF7C93B1),
                                          fontSize: 11,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Wrap(
                                        spacing: 4,
                                        runSpacing: 4,
                                        children: _uniqueTreatmentChips(
                                          visitsByPatient,
                                          entry.value.key,
                                        ),
                                      ),
                                    ],
                                  ),
                                  trailing: Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        '${entry.value.value} sessions',
                                        style: const TextStyle(
                                          color: Color(0xFF1F446E),
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        'Last: ${_lastVisited(visitsByPatient, entry.value.key)}',
                                        style: const TextStyle(
                                          color: Color(0xFF7C93B1),
                                          fontSize: 11,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              )
                              .toList(growable: false),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (rows.length > 10)
                      FilledButton(
                        onPressed: onViewMore,
                        style: ButtonStyle(
                          backgroundColor: WidgetStateProperty.all(
                            const Color(0xFF2D7BD8),
                          ),
                        ),
                        child: Text(hasMore ? 'View More (+10)' : 'Show Less'),
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _lastVisited(
    Map<String, List<Appointment>> visitsByPatient,
    Patient patient,
  ) {
    final visits = visitsByPatient[patient.id] ?? const <Appointment>[];
    if (visits.isEmpty) return '-';
    return DateFormat('dd MMM').format(visits.last.date);
  }

  List<Widget> _uniqueTreatmentChips(
    Map<String, List<Appointment>> visitsByPatient,
    Patient patient,
  ) {
    final visits = visitsByPatient[patient.id] ?? const <Appointment>[];
    final unique = <String>{};
    for (final appointment in visits) {
      for (final treatment in appointment.selectedTreatments) {
        final value = treatment.trim();
        if (value.isNotEmpty) {
          unique.add(value);
        }
      }
    }

    final list = unique.toList(growable: false)..sort();
    if (list.isEmpty) {
      return const [
        Text(
          'No treatments',
          style: TextStyle(
            color: Color(0xFF8AA0BC),
            fontSize: 10,
          ),
        ),
      ];
    }

    final visible = list.take(4).toList(growable: false);
    final chips = visible
        .map(
          (t) => Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: const Color(0xFFEAF2FC),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: const Color(0xFFD5E5F7)),
            ),
            child: Text(
              t,
              style: const TextStyle(
                color: Color(0xFF2F5B88),
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        )
        .toList();

    if (list.length > visible.length) {
      chips.add(
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: const Color(0xFFEAF2FC),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: const Color(0xFFD5E5F7)),
          ),
          child: Text(
            '+${list.length - visible.length}',
            style: const TextStyle(
              color: Color(0xFF5F789B),
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      );
    }

    return chips;
  }
}

class _AllPatientsListCard extends StatelessWidget {
  final List<Patient> patientsList;
  final Map<String, List<Appointment>> visitsByPatient;
  final String selectedAlphabet;
  final ValueChanged<String> onSelectAlphabet;
  final String behaviorFilter;
  final ValueChanged<String> onBehaviorFilterChanged;
  final double highValueThreshold;
  final ValueChanged<double> onHighValueThresholdChanged;
  final String sortBy;
  final bool sortAscending;
  final ValueChanged<String> onSort;
  final TextEditingController listSearchController;
  final ValueChanged<Patient> onOpenHistory;
  final ValueChanged<Patient> onDeletePatient;
  final int totalItems;
  final int currentPage;
  final int totalPages;
  final ValueChanged<int> onPageChanged;
  final int serialOffset;

  const _AllPatientsListCard({
    required this.patientsList,
    required this.visitsByPatient,
    required this.selectedAlphabet,
    required this.onSelectAlphabet,
    required this.behaviorFilter,
    required this.onBehaviorFilterChanged,
    required this.highValueThreshold,
    required this.onHighValueThresholdChanged,
    required this.sortBy,
    required this.sortAscending,
    required this.onSort,
    required this.listSearchController,
    required this.onOpenHistory,
    required this.onDeletePatient,
    required this.totalItems,
    required this.currentPage,
    required this.totalPages,
    required this.onPageChanged,
    required this.serialOffset,
  });

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final searchWidth = screenWidth < 900 ? 190.0 : 280.0;
    final isHeaderHighlighted =
        selectedAlphabet != 'All' || behaviorFilter != 'all';

    const letters = [
      'All',
      'A',
      'B',
      'C',
      'D',
      'E',
      'F',
      'G',
      'H',
      'I',
      'J',
      'K',
      'L',
      'M',
      'N',
      'O',
      'P',
      'Q',
      'R',
      'S',
      'T',
      'U',
      'V',
      'W',
      'X',
      'Y',
      'Z',
    ];

    Widget behaviorChip(String key, String label) {
      final selected = behaviorFilter == key;
      return GestureDetector(
        onTap: () => onBehaviorFilterChanged(key),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: BoxDecoration(
            color: selected ? const Color(0xFF2D7BD8) : const Color(0xFFEFF4FB),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: selected ? const Color(0xFF2D7BD8) : const Color(0xFFD2E1F2),
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: selected ? Colors.white : const Color(0xFF355A84),
            ),
          ),
        ),
      );
    }

    return _CardShell(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'All Patients',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: Color(0xFF183A67),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '$totalItems matching patients',
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xFF5A7397),
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: letters
                        .map(
                          (l) => Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: GestureDetector(
                              onTap: () => onSelectAlphabet(l),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: selectedAlphabet == l
                                      ? const Color(0xFF2D7BD8)
                                      : const Color(0xFFEFF4FB),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: selectedAlphabet == l
                                        ? const Color(0xFF2D7BD8)
                                        : const Color(0xFFD2E1F2),
                                  ),
                                ),
                                child: Text(
                                  l,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: selectedAlphabet == l
                                        ? Colors.white
                                        : const Color(0xFF355A84),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        )
                        .toList(growable: false),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: searchWidth,
                child: TextBox(
                  controller: listSearchController,
                  placeholder: 'Search by name or phone',
                  prefix: const Padding(
                    padding: EdgeInsets.only(left: 8),
                    child: Icon(
                      FluentIcons.search,
                      size: 12,
                      color: Color(0xFF6D84A8),
                    ),
                  ),
                  suffix: listSearchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(FluentIcons.clear),
                          onPressed: () => listSearchController.clear(),
                        )
                      : null,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              behaviorChip('all', 'All'),
              behaviorChip('highValue', 'High value patients'),
              behaviorChip('frequent', 'Frequent visitors'),
              behaviorChip('inactive', 'Inactive patients'),
              behaviorChip('new', 'New patients'),
              behaviorChip('oneTimer', 'One timer'),
              behaviorChip('invalidPhone', 'Invalid Phone Number'),
              behaviorChip('noVisit', 'No Visit'),
              behaviorChip('todayVisited', "Today's"),
              if (behaviorFilter == 'highValue')
                SizedBox(
                  width: 180,
                  child: NumberBox(
                    value: highValueThreshold,
                    mode: SpinButtonPlacementMode.none,
                    clearButton: false,
                    min: 0,
                    smallChange: 500,
                    placeholder: 'Threshold',
                    onChanged: (v) => onHighValueThresholdChanged(v ?? highValueThreshold),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            decoration: BoxDecoration(
              color: isHeaderHighlighted
                  ? const Color(0xFF1A74DB)
                  : const Color(0xFFEFF4FB),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(10)),
            ),
            child: Row(
              children: [
                _SortableHead(
                  flex: 8,
                  label: 'ID',
                  keyName: 'id',
                  current: sortBy,
                  ascending: sortAscending,
                  onSort: onSort,
                  onDark: isHeaderHighlighted,
                ),
                _SortableHead(
                  flex: 24,
                  label: 'Patient',
                  keyName: 'name',
                  current: sortBy,
                  ascending: sortAscending,
                  onSort: onSort,
                  onDark: isHeaderHighlighted,
                ),
                _SortableHead(
                  flex: 18,
                  label: 'Phone',
                  keyName: 'phone',
                  current: sortBy,
                  ascending: sortAscending,
                  onSort: onSort,
                  onDark: isHeaderHighlighted,
                ),
                _SortableHead(
                  flex: 10,
                  label: 'Age',
                  keyName: 'age',
                  current: sortBy,
                  ascending: sortAscending,
                  onSort: onSort,
                  onDark: isHeaderHighlighted,
                ),
                _SortableHead(
                  flex: 12,
                  label: 'Visits',
                  keyName: 'visits',
                  current: sortBy,
                  ascending: sortAscending,
                  onSort: onSort,
                  onDark: isHeaderHighlighted,
                ),
                Expanded(
                  flex: 16,
                  child: _SortableHead(
                    flex: 16,
                    label: 'Last Visit',
                    keyName: 'lastVisit',
                    current: sortBy,
                    ascending: sortAscending,
                    onSort: onSort,
                    onDark: isHeaderHighlighted,
                  ),
                ),
                Expanded(
                  flex: 16,
                  child: _SortableHead(
                    flex: 16,
                    label: 'Paid So Far',
                    keyName: 'paidSoFar',
                    current: sortBy,
                    ascending: sortAscending,
                    onSort: onSort,
                    onDark: isHeaderHighlighted,
                  ),
                ),
                _SortableHead(
                  flex: 16,
                  label: 'Outstanding',
                  keyName: 'outstanding',
                  current: sortBy,
                  ascending: sortAscending,
                  onSort: onSort,
                  onDark: isHeaderHighlighted,
                ),
                Expanded(
                  flex: 12,
                  child: Text(
                    'Actions',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: isHeaderHighlighted
                          ? Colors.white
                          : const Color(0xFF2C4468),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Container(
            decoration: BoxDecoration(
              border: Border.all(color: const Color(0xFFD6E2F0)),
              borderRadius:
                  const BorderRadius.vertical(bottom: Radius.circular(10)),
            ),
            child: patientsList.isEmpty
                ? const Padding(
                    padding: EdgeInsets.all(16),
                    child: Text(
                      'No matching patients',
                      style: TextStyle(color: Color(0xFF607B9F)),
                    ),
                  )
                : Column(
                    children:
                        patientsList.toList().asMap().entries.map((entry) {
                      final patient = entry.value;
                      final serial = serialOffset + entry.key + 1;
                        final patientVisits =
                          (visitsByPatient[patient.id] ?? const <Appointment>[]);
                        final visits = patientVisits.length;
                        final lastVisit = patientVisits.isEmpty
                          ? '-'
                          : DateFormat('dd MMM yyyy').format(patientVisits.last.date);
                        final paidSoFar = patientVisits.fold<double>(
                        0,
                        (sum, visit) => sum + visit.paid + visit.prescriptionPaid,
                        );
                      final outstanding = patient.outstandingPayments;

                      return Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 10),
                        decoration: const BoxDecoration(
                          border:
                              Border(top: BorderSide(color: Color(0xFFE2ECF8))),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              flex: 8,
                              child: Text(
                                '$serial',
                                style: const TextStyle(
                                  color: Color(0xFF2D476D),
                                ),
                              ),
                            ),
                            Expanded(
                              flex: 24,
                              child: GestureDetector(
                                onTap: () => openPatient(patient, 1),
                                child: Text(
                                  patient.title.trim().isEmpty
                                      ? 'Unnamed patient'
                                      : patient.title,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Color(0xFF1459AD),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                            Expanded(
                              flex: 18,
                              child: Text(
                                patient.phone,
                                overflow: TextOverflow.ellipsis,
                                style:
                                    const TextStyle(color: Color(0xFF2D476D)),
                              ),
                            ),
                            Expanded(
                              flex: 10,
                              child: Text(
                                '${patient.age}',
                                style:
                                    const TextStyle(color: Color(0xFF2D476D)),
                              ),
                            ),
                            Expanded(
                              flex: 12,
                              child: Text(
                                '$visits',
                                style: const TextStyle(
                                  color: Color(0xFF2D476D),
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            Expanded(
                              flex: 16,
                              child: Text(
                                lastVisit,
                                style: const TextStyle(
                                  color: Color(0xFF2D476D),
                                  fontSize: 12,
                                ),
                              ),
                            ),
                            Expanded(
                              flex: 16,
                              child: Text(
                                '₹${paidSoFar.toStringAsFixed(0)}',
                                style: const TextStyle(
                                  color: Color(0xFF1459AD),
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            Expanded(
                              flex: 16,
                              child: Text(
                                '₹${outstanding.toStringAsFixed(0)}',
                                style: TextStyle(
                                  color: outstanding > 0
                                      ? const Color(0xFFD6455D)
                                      : const Color(0xFF2D476D),
                                ),
                              ),
                            ),
                            Expanded(
                              flex: 12,
                              child: Wrap(
                                spacing: 6,
                                runSpacing: 6,
                                children: [
                                  _HoverActionItem(
                                    icon: FluentIcons.history,
                                    label: 'History',
                                    onTap: () => onOpenHistory(patient),
                                  ),
                                  _HoverActionItem(
                                    icon: FluentIcons.delete,
                                    label: 'Delete',
                                    iconColor: const Color(0xFFD6455D),
                                    hoverColor: const Color(0xFFFFECEF),
                                    hoverBorderColor: const Color(0xFFF6C8CF),
                                    onTap: () => onDeletePatient(patient),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(growable: false),
                  ),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Showing ${patientsList.length} of $totalItems patients',
                style: const TextStyle(
                  color: Color(0xFF5B789F),
                  fontWeight: FontWeight.w600,
                ),
              ),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  _PageButton(
                    label: '<',
                    enabled: currentPage > 1,
                    selected: false,
                    onTap: () => onPageChanged(currentPage - 1),
                  ),
                  ..._pageNumbers(currentPage, totalPages).map(
                    (page) {
                      if (page == null) {
                        return const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 6),
                          child: Text('...'),
                        );
                      }
                      return _PageButton(
                        label: '$page',
                        enabled: true,
                        selected: page == currentPage,
                        onTap: () => onPageChanged(page),
                      );
                    },
                  ),
                  _PageButton(
                    label: '>',
                    enabled: currentPage < totalPages,
                    selected: false,
                    onTap: () => onPageChanged(currentPage + 1),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  List<int?> _pageNumbers(int current, int total) {
    if (total <= 7) {
      return List<int?>.generate(total, (i) => i + 1);
    }

    final pages = <int?>[1];
    final start = math.max(2, current - 1);
    final end = math.min(total - 1, current + 1);

    if (start > 2) pages.add(null);
    for (int p = start; p <= end; p++) {
      pages.add(p);
    }
    if (end < total - 1) pages.add(null);
    pages.add(total);

    return pages;
  }
}

class _PageButton extends StatelessWidget {
  final String label;
  final bool enabled;
  final bool selected;
  final VoidCallback onTap;

  const _PageButton({
    required this.label,
    required this.enabled,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        constraints: const BoxConstraints(minWidth: 28),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF2D7BD8) : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selected ? const Color(0xFF2D7BD8) : const Color(0xFFD0DEEF),
          ),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: !enabled
                ? const Color(0xFF9EB2CB)
                : selected
                    ? Colors.white
                    : const Color(0xFF2D4A70),
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _HoverActionItem extends StatefulWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color iconColor;
  final Color hoverColor;
  final Color hoverBorderColor;

  const _HoverActionItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.iconColor = const Color(0xFF2D7BD8),
    this.hoverColor = const Color(0xFFE7F1FF),
    this.hoverBorderColor = const Color(0xFFBFD8F8),
  });

  @override
  State<_HoverActionItem> createState() => _HoverActionItemState();
}

class _HoverActionItemState extends State<_HoverActionItem> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: Tooltip(
        message: widget.label,
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 140),
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: _hovered ? widget.hoverColor : Colors.transparent,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: _hovered ? widget.hoverBorderColor : Colors.transparent,
              ),
            ),
            child: Icon(
              widget.icon,
              size: 14,
              color: widget.iconColor,
            ),
          ),
        ),
      ),
    );
  }
}

class _HoverableListRow extends StatefulWidget {
  final Widget leading;
  final Widget title;
  final Widget? subtitle;
  final Widget trailing;
  final VoidCallback onTap;
  final bool isLast;

  const _HoverableListRow({
    required this.leading,
    required this.title,
    this.subtitle,
    required this.trailing,
    required this.onTap,
    required this.isLast,
  });

  @override
  State<_HoverableListRow> createState() => _HoverableListRowState();
}

class _HoverableListRowState extends State<_HoverableListRow> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 90),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 11),
          decoration: BoxDecoration(
            color: _hovered ? const Color(0xFFE8F2FF) : Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border(
              bottom: widget.isLast
                  ? BorderSide.none
                  : const BorderSide(color: Color(0xFFE4EAF2), width: 1),
            ),
          ),
          child: Row(
            children: [
              widget.leading,
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    widget.title,
                    if (widget.subtitle != null) ...[
                      const SizedBox(height: 1),
                      widget.subtitle!,
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              widget.trailing,
            ],
          ),
        ),
      ),
    );
  }
}

class _SortableHead extends StatelessWidget {
  final int flex;
  final String label;
  final String keyName;
  final String current;
  final bool ascending;
  final ValueChanged<String> onSort;
  final bool onDark;

  const _SortableHead({
    required this.flex,
    required this.label,
    required this.keyName,
    required this.current,
    required this.ascending,
    required this.onSort,
    this.onDark = false,
  });

  @override
  Widget build(BuildContext context) {
    final active = current == keyName;
    return Expanded(
      flex: flex,
      child: GestureDetector(
        onTap: () => onSort(keyName),
        child: Row(
          children: [
            Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: onDark ? Colors.white : const Color(0xFF2C4468),
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              active
                  ? (ascending
                      ? FluentIcons.chevron_up
                      : FluentIcons.chevron_down)
                  : FluentIcons.switch_user,
              size: 10,
              color: onDark ? Colors.white : const Color(0xFF6D84A8),
            ),
          ],
        ),
      ),
    );
  }
}

class _CardShell extends StatelessWidget {
  final Widget child;

  const _CardShell({required this.child});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFD7E3F0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x160D2F5B),
            blurRadius: 10,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: child,
      ),
    );
  }
}
