import 'dart:math' as math;

import 'package:apexo/common_widgets/patients_report_dialog.dart';
import 'package:apexo/core/multi_stream_builder.dart';
import 'package:apexo/features/appointments/appointment_model.dart';
import 'package:apexo/features/appointments/appointments_store.dart';
import 'package:apexo/features/patients/open_patient_panel.dart';
import 'package:apexo/features/patients/patient_model.dart';
import 'package:apexo/features/patients/patients_store.dart';
import 'package:apexo/widget_keys.dart';
import 'package:fluent_ui/fluent_ui.dart';

class PatientsScreenV2 extends StatefulWidget {
  const PatientsScreenV2({super.key});

  @override
  State<PatientsScreenV2> createState() => _PatientsScreenV2State();
}

class _PatientsScreenV2State extends State<PatientsScreenV2> {
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _listSearchController = TextEditingController();

  String _query = '';
  String _listQuery = '';
  String _topRange = '1Week';
  String _outstandingRange = '1Week';
  String _selectedAlphabet = 'A';
  String _sortBy = 'name';
  bool _sortAscending = true;
  int _currentPage = 1;

  static const int _pageSize = 200;

  static const List<String> _topRanges = [
    '1Week',
    '1Month',
    '6Months',
    '1Year',
    'All',
  ];

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() {
        _query = _searchController.text.trim().toLowerCase();
        _currentPage = 1;
      });
    });
    _listSearchController.addListener(() {
      setState(() {
        _listQuery = _listSearchController.text.trim().toLowerCase();
        _currentPage = 1;
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _listSearchController.dispose();
    super.dispose();
  }

  DateTime _dateOnly(DateTime date) {
    return DateTime(date.year, date.month, date.day);
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
    showDialog(
      context: context,
      builder: (_) => Align(
        alignment: Alignment.center,
        child: Container(
          color: Colors.white,
          child: PatientDetailsDialog(
            rows: patient.patientDetails,
            patient: patient,
            hiddenColumns: const [
              'Prescription',
              'P.Mode',
              'Doc Paid',
              'TotalDocPay',
            ],
          ),
        ),
      ),
    );
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
            final today = _dateOnly(now);
            final todaysAppointments = allAppointments
                .where((a) => _dateOnly(a.date) == today)
                .toList(growable: false);

            final todayUniquePatientIds = todaysAppointments
                .map((a) => a.patientID)
                .whereType<String>()
                .toSet();

            int newPatientsToday = 0;
            int returningPatientsToday = 0;
            for (final id in todayUniquePatientIds) {
              final visits = visitsByPatient[id] ?? const <Appointment>[];
              if (visits.isEmpty) continue;
              final isNewToday = _dateOnly(visits.first.date) == today;
              if (isNewToday) {
                newPatientsToday++;
              } else {
                returningPatientsToday++;
              }
            }

            final ageBuckets = _ageBuckets(allPatients);
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

            final preAlphabetPatients = allPatients.where((patient) {
              final name = patient.title.toLowerCase();
              final phone = patient.phone.toLowerCase();

              final topSearchMatches = _query.isEmpty ||
                  name.contains(_query) ||
                  phone.contains(_query);

              final listSearchMatches = _listQuery.isEmpty ||
                  name.contains(_listQuery) ||
                  phone.contains(_listQuery);

              return topSearchMatches && listSearchMatches;
            }).toList(growable: false);

            final filteredPatients = preAlphabetPatients.where((patient) {
              if (_selectedAlphabet == 'All') return true;
              final titleTrimmed = patient.title.trim();
              final firstLetter =
                  titleTrimmed.isEmpty ? '' : titleTrimmed[0].toUpperCase();
              return firstLetter == _selectedAlphabet;
            }).toList(growable: false)
              ..sort((a, b) {
                int value;
                switch (_sortBy) {
                  case 'id':
                    value = a.id.compareTo(b.id);
                    break;
                  case 'phone':
                    value =
                        a.phone.toLowerCase().compareTo(b.phone.toLowerCase());
                    break;
                  case 'age':
                    value = a.age.compareTo(b.age);
                    break;
                  case 'visits':
                    final aVisits =
                        (visitsByPatient[a.id] ?? const <Appointment>[]).length;
                    final bVisits =
                        (visitsByPatient[b.id] ?? const <Appointment>[]).length;
                    value = aVisits.compareTo(bVisits);
                    break;
                  case 'outstanding':
                    value =
                        a.outstandingPayments.compareTo(b.outstandingPayments);
                    break;
                  case 'name':
                  default:
                    value =
                        a.title.toLowerCase().compareTo(b.title.toLowerCase());
                    break;
                }
                return _sortAscending ? value : -value;
              });

            final totalPages =
                math.max(1, (filteredPatients.length / _pageSize).ceil());
            final currentPage = _currentPage.clamp(1, totalPages);
            if (currentPage != _currentPage) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (!mounted) return;
                setState(() {
                  _currentPage = currentPage;
                });
              });
            }

            final start = (currentPage - 1) * _pageSize;
            final end = math.min(start + _pageSize, filteredPatients.length);
            final pagedPatients = filteredPatients.sublist(start, end);

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _TopBar(searchController: _searchController),
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
                    _MetricCard(
                      title: 'New Patients Today',
                      value: '$newPatientsToday',
                      valueColor: const Color(0xFF1A8CC2),
                    ),
                    _MetricCard(
                      title: 'Returning Patients',
                      value: '$returningPatientsToday',
                      valueColor: const Color(0xFF2B5DB8),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final useColumn = constraints.maxWidth < 1260;

                    if (useColumn) {
                      return Column(
                        children: [
                          _AgeDistributionCard(buckets: ageBuckets),
                          const SizedBox(height: 10),
                          _GenderDistributionCard(buckets: genderBuckets),
                          const SizedBox(height: 10),
                          _PaymentModeDistributionCard(
                            buckets: paymentModeBuckets,
                          ),
                          const SizedBox(height: 10),
                          _TopPatientsCard(
                            rows: topPatientsByVisits
                                .take(10)
                                .toList(growable: false),
                            selectedRange: _topRange,
                            ranges: _topRanges,
                            onSelectRange: (v) => setState(() => _topRange = v),
                            onOpenHistory: _openPatientHistoryDialog,
                          ),
                          const SizedBox(height: 10),
                          _TopOutstandingCard(
                            rows:
                                topOutstanding.take(10).toList(growable: false),
                            selectedRange: _outstandingRange,
                            ranges: _topRanges,
                            onSelectRange: (v) =>
                                setState(() => _outstandingRange = v),
                            onOpenHistory: _openPatientHistoryDialog,
                          ),
                          const SizedBox(height: 10),
                          _AllPatientsListCard(
                            patientsList: pagedPatients,
                            visitsByPatient: visitsByPatient,
                            selectedAlphabet: _selectedAlphabet,
                            onSelectAlphabet: (v) => setState(() {
                              _selectedAlphabet = v;
                              _currentPage = 1;
                            }),
                            sortBy: _sortBy,
                            sortAscending: _sortAscending,
                            onSort: _onSort,
                            listSearchController: _listSearchController,
                            onOpenHistory: _openPatientHistoryDialog,
                            totalItems: filteredPatients.length,
                            currentPage: currentPage,
                            totalPages: totalPages,
                            onPageChanged: (page) =>
                                setState(() => _currentPage = page),
                            serialOffset: start,
                          ),
                        ],
                      );
                    }

                    return Column(
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                children: [
                                  _AgeDistributionCard(buckets: ageBuckets),
                                  const SizedBox(height: 10),
                                  _GenderDistributionCard(
                                    buckets: genderBuckets,
                                  ),
                                  const SizedBox(height: 10),
                                  _PaymentModeDistributionCard(
                                    buckets: paymentModeBuckets,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _TopPatientsCard(
                                rows: topPatientsByVisits
                                    .take(10)
                                    .toList(growable: false),
                                selectedRange: _topRange,
                                ranges: _topRanges,
                                onSelectRange: (v) =>
                                    setState(() => _topRange = v),
                                onOpenHistory: _openPatientHistoryDialog,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _TopOutstandingCard(
                                rows: topOutstanding
                                    .take(10)
                                    .toList(growable: false),
                                selectedRange: _outstandingRange,
                                ranges: _topRanges,
                                onSelectRange: (v) =>
                                    setState(() => _outstandingRange = v),
                                onOpenHistory: _openPatientHistoryDialog,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        _AllPatientsListCard(
                          patientsList: pagedPatients,
                          visitsByPatient: visitsByPatient,
                          selectedAlphabet: _selectedAlphabet,
                          onSelectAlphabet: (v) => setState(() {
                            _selectedAlphabet = v;
                            _currentPage = 1;
                          }),
                          sortBy: _sortBy,
                          sortAscending: _sortAscending,
                          onSort: _onSort,
                          listSearchController: _listSearchController,
                          onOpenHistory: _openPatientHistoryDialog,
                          totalItems: filteredPatients.length,
                          currentPage: currentPage,
                          totalPages: totalPages,
                          onPageChanged: (page) =>
                              setState(() => _currentPage = page),
                          serialOffset: start,
                        ),
                      ],
                    );
                  },
                ),
              ],
            );
          },
        ),
      ],
    );
  }

  Map<String, int> _ageBuckets(List<Patient> items) {
    final buckets = <String, int>{
      '0-10': 0,
      '11-20': 0,
      '21-30': 0,
      '31-40': 0,
      '41-50': 0,
      '51-60': 0,
      '61-70': 0,
      '71+': 0,
    };

    for (final p in items) {
      final age = p.age;
      if (age < 0) continue;
      if (age <= 10) {
        buckets['0-10'] = buckets['0-10']! + 1;
      } else if (age <= 20) {
        buckets['11-20'] = buckets['11-20']! + 1;
      } else if (age <= 30) {
        buckets['21-30'] = buckets['21-30']! + 1;
      } else if (age <= 40) {
        buckets['31-40'] = buckets['31-40']! + 1;
      } else if (age <= 50) {
        buckets['41-50'] = buckets['41-50']! + 1;
      } else if (age <= 60) {
        buckets['51-60'] = buckets['51-60']! + 1;
      } else if (age <= 70) {
        buckets['61-70'] = buckets['61-70']! + 1;
      } else {
        buckets['71+'] = buckets['71+']! + 1;
      }
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
      'GPay': 0,
    };

    for (final a in items) {
      final hasCash = (a.paid > 0 && !a.treatmentGpayPaid) ||
          (a.prescriptionPaid > 0 && !a.prescriptionGpayPaid);
      final hasGpay = (a.paid > 0 && a.treatmentGpayPaid) ||
          (a.prescriptionPaid > 0 && a.prescriptionGpayPaid);

      if (!hasCash && !hasGpay) continue;
      if (hasGpay) {
        buckets['GPay'] = buckets['GPay']! + 1;
      } else {
        buckets['Cash'] = buckets['Cash']! + 1;
      }
    }

    return buckets;
  }
}

class _TopBar extends StatelessWidget {
  final TextEditingController searchController;

  const _TopBar({required this.searchController});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Expanded(
          child: Text(
            'Patients',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w700,
              color: Color(0xFF183A67),
            ),
          ),
        ),
        SizedBox(
          width: 280,
          child: TextBox(
            controller: searchController,
            placeholder: 'Search patients',
            prefix: const Padding(
              padding: EdgeInsets.only(left: 8),
              child:
                  Icon(FluentIcons.search, size: 12, color: Color(0xFF6D84A8)),
            ),
            suffix: searchController.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(FluentIcons.clear),
                    onPressed: () => searchController.clear(),
                  )
                : null,
          ),
        ),
      ],
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

class _AgeDistributionCard extends StatelessWidget {
  final Map<String, int> buckets;

  const _AgeDistributionCard({required this.buckets});

  @override
  Widget build(BuildContext context) {
    final maxValue = buckets.values.fold<int>(0, (m, v) => v > m ? v : m);

    return _CardShell(
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
          const SizedBox(height: 10),
          ...buckets.entries.map((entry) {
            final ratio = maxValue == 0 ? 0.0 : (entry.value / maxValue);
            return Padding(
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
                                color: const Color(0xFF2D7BD8),
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
                    width: 26,
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
                    width: 26,
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
            final barColor = entry.key == 'GPay'
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
                    width: 26,
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
  final String selectedRange;
  final List<String> ranges;
  final ValueChanged<String> onSelectRange;
  final ValueChanged<Patient> onOpenHistory;

  const _TopPatientsCard({
    required this.rows,
    required this.selectedRange,
    required this.ranges,
    required this.onSelectRange,
    required this.onOpenHistory,
  });

  @override
  Widget build(BuildContext context) {
    return _CardShell(
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 320),
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
                          boxShadow: selectedRange == range
                              ? const [
                                  BoxShadow(
                                    color: Color(0x332D7BD8),
                                    blurRadius: 8,
                                    offset: Offset(0, 2),
                                  ),
                                ]
                              : const [],
                        ),
                        child: Text(
                          range,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
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
              ...rows.asMap().entries.map(
                    (entry) => _HoverableListRow(
                      isLast: entry.key == rows.length - 1,
                      onTap: () => onOpenHistory(entry.value.key),
                      leading: Text(
                        '${entry.key + 1}.',
                        style: const TextStyle(
                          color: Color(0xFF36557C),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      title: Text(
                        entry.value.key.title,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFF1F446E),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      trailing: Text(
                        '${entry.value.value} visits',
                        style: const TextStyle(
                          color: Color(0xFF1F446E),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
          ],
        ),
      ),
    );
  }
}

class _TopOutstandingCard extends StatelessWidget {
  final List<MapEntry<Patient, double>> rows;
  final String selectedRange;
  final List<String> ranges;
  final ValueChanged<String> onSelectRange;
  final ValueChanged<Patient> onOpenHistory;

  const _TopOutstandingCard({
    required this.rows,
    required this.selectedRange,
    required this.ranges,
    required this.onSelectRange,
    required this.onOpenHistory,
  });

  @override
  Widget build(BuildContext context) {
    return _CardShell(
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 320),
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
                          boxShadow: selectedRange == range
                              ? const [
                                  BoxShadow(
                                    color: Color(0x332D7BD8),
                                    blurRadius: 8,
                                    offset: Offset(0, 2),
                                  ),
                                ]
                              : const [],
                        ),
                        child: Text(
                          range,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
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
              ...rows.asMap().entries.map(
                    (entry) => _HoverableListRow(
                      isLast: entry.key == rows.length - 1,
                      onTap: () => onOpenHistory(entry.value.key),
                      leading: Text(
                        '${entry.key + 1}.',
                        style: const TextStyle(
                          color: Color(0xFF36557C),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      title: Text(
                        entry.value.key.title,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFF1F446E),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      trailing: Text(
                        '₹${entry.value.value.toStringAsFixed(0)}',
                        style: const TextStyle(
                          color: Color(0xFFD6455D),
                        ),
                      ),
                    ),
                  ),
          ],
        ),
      ),
    );
  }
}

class _AllPatientsListCard extends StatelessWidget {
  final List<Patient> patientsList;
  final Map<String, List<Appointment>> visitsByPatient;
  final String selectedAlphabet;
  final ValueChanged<String> onSelectAlphabet;
  final String sortBy;
  final bool sortAscending;
  final ValueChanged<String> onSort;
  final TextEditingController listSearchController;
  final ValueChanged<Patient> onOpenHistory;
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
    required this.sortBy,
    required this.sortAscending,
    required this.onSort,
    required this.listSearchController,
    required this.onOpenHistory,
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
                                  boxShadow: selectedAlphabet == l
                                      ? const [
                                          BoxShadow(
                                            color: Color(0x332D7BD8),
                                            blurRadius: 8,
                                            offset: Offset(0, 2),
                                          ),
                                        ]
                                      : const [],
                                ),
                                child: Text(
                                  l,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
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
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            decoration: const BoxDecoration(
              color: Color(0xFFEFF4FB),
              borderRadius: BorderRadius.vertical(top: Radius.circular(10)),
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
                ),
                _SortableHead(
                  flex: 24,
                  label: 'Patient',
                  keyName: 'name',
                  current: sortBy,
                  ascending: sortAscending,
                  onSort: onSort,
                ),
                _SortableHead(
                  flex: 18,
                  label: 'Phone',
                  keyName: 'phone',
                  current: sortBy,
                  ascending: sortAscending,
                  onSort: onSort,
                ),
                _SortableHead(
                  flex: 10,
                  label: 'Age',
                  keyName: 'age',
                  current: sortBy,
                  ascending: sortAscending,
                  onSort: onSort,
                ),
                _SortableHead(
                  flex: 12,
                  label: 'Visits',
                  keyName: 'visits',
                  current: sortBy,
                  ascending: sortAscending,
                  onSort: onSort,
                ),
                _SortableHead(
                  flex: 16,
                  label: 'Outstanding',
                  keyName: 'outstanding',
                  current: sortBy,
                  ascending: sortAscending,
                  onSort: onSort,
                ),
                const Expanded(
                  flex: 12,
                  child: Text(
                    'Actions',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF2C4468),
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
                      final visits =
                          (visitsByPatient[patient.id] ?? const <Appointment>[])
                              .length;
                      final outstanding = patient.outstandingPayments;

                      return GestureDetector(
                        onTap: () => openPatient(patient, 1),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 10),
                          decoration: const BoxDecoration(
                            border: Border(
                                top: BorderSide(color: Color(0xFFE2ECF8))),
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
                                child: GestureDetector(
                                  onTap: () => onOpenHistory(patient),
                                  child: const Row(
                                    children: [
                                      Icon(
                                        FluentIcons.money,
                                        size: 14,
                                        color: Color(0xFF2D7BD8),
                                      ),
                                      SizedBox(width: 4),
                                      Text(
                                        'History',
                                        style: TextStyle(
                                          color: Color(0xFF2D7BD8),
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ],
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

class _HoverableListRow extends StatefulWidget {
  final Widget leading;
  final Widget title;
  final Widget trailing;
  final VoidCallback onTap;
  final bool isLast;

  const _HoverableListRow({
    required this.leading,
    required this.title,
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
          duration: const Duration(milliseconds: 140),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 11),
          decoration: BoxDecoration(
            color: _hovered ? const Color(0xFFE8F2FF) : Colors.transparent,
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
              Expanded(child: widget.title),
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

  const _SortableHead({
    required this.flex,
    required this.label,
    required this.keyName,
    required this.current,
    required this.ascending,
    required this.onSort,
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
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                color: Color(0xFF2C4468),
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
              color: const Color(0xFF6D84A8),
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
