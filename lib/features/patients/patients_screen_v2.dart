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

  static const List<String> _topRanges = ['1Week', '1Month', '1Year', 'All'];

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() {
        _query = _searchController.text.trim().toLowerCase();
      });
    });
    _listSearchController.addListener(() {
      setState(() {
        _listQuery = _listSearchController.text.trim().toLowerCase();
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

            final filteredPatients = allPatients.where((patient) {
              final name = patient.title.toLowerCase();
              final phone = patient.phone.toLowerCase();

              final topSearchMatches = _query.isEmpty ||
                  name.contains(_query) ||
                  phone.contains(_query);

              final listSearchMatches = _listQuery.isEmpty ||
                  name.contains(_listQuery) ||
                  phone.contains(_listQuery);

              final titleTrimmed = patient.title.trim();
              final firstLetter =
                  titleTrimmed.isEmpty ? '' : titleTrimmed[0].toUpperCase();
              final alphabetMatches = firstLetter == _selectedAlphabet;

              return topSearchMatches && listSearchMatches && alphabetMatches;
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
                      title: 'Total Patients',
                      value: '${allPatients.length}',
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
                            patientsList: filteredPatients,
                            visitsByPatient: visitsByPatient,
                            selectedAlphabet: _selectedAlphabet,
                            onSelectAlphabet: (v) =>
                                setState(() => _selectedAlphabet = v),
                            sortBy: _sortBy,
                            sortAscending: _sortAscending,
                            onSort: _onSort,
                            listSearchController: _listSearchController,
                            onOpenHistory: _openPatientHistoryDialog,
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
                                child:
                                    _AgeDistributionCard(buckets: ageBuckets)),
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
                          patientsList: filteredPatients,
                          visitsByPatient: visitsByPatient,
                          selectedAlphabet: _selectedAlphabet,
                          onSelectAlphabet: (v) =>
                              setState(() => _selectedAlphabet = v),
                          sortBy: _sortBy,
                          sortAscending: _sortAscending,
                          onSort: _onSort,
                          listSearchController: _listSearchController,
                          onOpenHistory: _openPatientHistoryDialog,
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
      '0-18': 0,
      '19-35': 0,
      '36-60': 0,
      '60+': 0,
    };

    for (final p in items) {
      final age = p.age;
      if (age < 0) continue;
      if (age <= 18) {
        buckets['0-18'] = buckets['0-18']! + 1;
      } else if (age <= 35) {
        buckets['19-35'] = buckets['19-35']! + 1;
      } else if (age <= 60) {
        buckets['36-60'] = buckets['36-60']! + 1;
      } else {
        buckets['60+'] = buckets['60+']! + 1;
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
          const SizedBox(height: 10),
          if (rows.isEmpty)
            const Text(
              'No visits in this range.',
              style: TextStyle(color: Color(0xFF607B9F)),
            )
          else
            ...rows.asMap().entries.map(
                  (entry) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: GestureDetector(
                      onTap: () => onOpenHistory(entry.value.key),
                      child: Row(
                        children: [
                          Text(
                            '${entry.key + 1}.',
                            style: const TextStyle(
                              color: Color(0xFF36557C),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              entry.value.key.title,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Color(0xFF1F446E),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          Text(
                            '${entry.value.value} visits',
                            style: const TextStyle(
                              color: Color(0xFF1F446E),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
        ],
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
          const SizedBox(height: 10),
          if (rows.isEmpty)
            const Text(
              'No outstanding balances.',
              style: TextStyle(color: Color(0xFF607B9F)),
            )
          else
            ...rows.asMap().entries.map(
                  (entry) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: GestureDetector(
                      onTap: () => onOpenHistory(entry.value.key),
                      child: Row(
                        children: [
                          Text(
                            '${entry.key + 1}.',
                            style: const TextStyle(
                              color: Color(0xFF36557C),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              entry.value.key.title,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Color(0xFF1F446E),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          Text(
                            '₹${entry.value.value.toStringAsFixed(0)}',
                            style: const TextStyle(
                              color: Color(0xFFBE7E88),
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
        ],
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
  });

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final searchWidth = screenWidth < 900 ? 190.0 : 280.0;

    const letters = [
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
                    children: patientsList
                        .take(200)
                        .toList()
                        .asMap()
                        .entries
                        .map((entry) {
                      final patient = entry.value;
                      final serial = entry.key + 1;
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
                                    fontWeight: FontWeight.w700,
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
                                        ? const Color(0xFFBE7E88)
                                        : const Color(0xFF2D476D),
                                    fontWeight: FontWeight.w700,
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
        ],
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
