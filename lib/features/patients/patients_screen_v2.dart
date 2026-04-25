// ignore_for_file: unused_import, unused_element, unused_field, unused_local_variable

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'dart:math' as math;

import 'package:apexo/common_widgets/export_file_action_button.dart';
import 'package:apexo/common_widgets/export_progress_dialog.dart';
import 'package:apexo/common_widgets/patient_history_modal_v2.dart';
import 'package:apexo/common_widgets/report_table_modal_v2.dart';
import 'package:apexo/core/theme/app_colors.dart';
import 'package:apexo/core/ui/components/app_button.dart';
import 'package:apexo/core/ui/components/app_pagination.dart';
import 'package:apexo/core/multi_stream_builder.dart';
import 'package:apexo/features/appointments/appointment_model.dart';
import 'package:apexo/features/appointments/appointments_store.dart';
import 'package:apexo/features/labwork/labwork_model.dart';
import 'package:apexo/features/labwork/open_labwork_v2_dialog.dart';
import 'package:apexo/features/patients/open_add_patient_popup.dart';
import 'package:apexo/features/patients/patient_history_suggestions.dart';
import 'package:apexo/features/patients/patient_model.dart';
import 'package:apexo/features/patients/patients_store.dart';
import 'package:apexo/utils/clinic_time.dart';
import 'package:apexo/utils/pdf_export_utility.dart';
import 'package:file_picker/file_picker.dart';
import 'package:apexo/widget_keys.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:intl/intl.dart';

String _toTitleCasePatientName(String input) {
  final cleaned = input.trim();
  if (cleaned.isEmpty) return cleaned;
  return cleaned.split(RegExp(r'\s+')).map((word) {
    if (word.isEmpty) return word;
    final first = word.substring(0, 1).toUpperCase();
    final rest = word.length > 1 ? word.substring(1).toLowerCase() : '';
    return '$first$rest';
  }).join(' ');
}

String _patientDisplayName(Patient patient) {
  return patient.title.trim().isEmpty
      ? 'Unnamed patient'
      : _toTitleCasePatientName(patient.title);
}

class PatientsScreen extends StatefulWidget {
  const PatientsScreen({super.key});

  @override
  State<PatientsScreen> createState() => _PatientsScreenState();
}

class _PatientsScreenState extends State<PatientsScreen> {
  final TextEditingController _listSearchController = TextEditingController();

  String _listQuery = '';
  final String _topRange = 'All';
  final String _outstandingRange = 'All';
  final String _procedureRange = 'All';
  final String _procedureTab = 'RCT';
  String _selectedAlphabet = 'All';
  String _listBehaviorFilter = 'all';
  String _sortBy = 'name';
  bool _sortAscending = true;
  double _highValueThreshold = 10000;
  final int _topPatientsVisibleCount = 10;
  final int _topOutstandingVisibleCount = 10;
  final int _topProcedureVisibleCount = 10;
  int _currentPage = 1;
  bool _isExportingPatientsCsv = false;
  bool _isExportingPatientsPdf = false;

  static const int _pageSize = 20;

  static const List<String> _focusRanges = [
    '1W',
    '1M',
    '3M',
    '6M',
    'YTD',
    'Year',
    'All',
  ];
  static const List<String> _procedureRanges = ['All'];

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
      case '1W':
        return now.subtract(const Duration(days: 7));
      case '1M':
        return now.subtract(const Duration(days: 30));
      case '3M':
        return now.subtract(const Duration(days: 90));
      case '6M':
        return now.subtract(const Duration(days: 182));
      case 'YTD':
        return DateTime(now.year, 1, 1);
      case 'Year':
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
      _currentPage = 1;
    });
  }

  void _openPatientHistoryDialog(Patient patient) {
    showPatientHistoryDialog(
      context: context,
      patient: patient,
      rows: patient.patientDetails,
    );
  }

  void _openLabworkForPatient(Patient patient) {
    final draft = Labwork.fromJson({
      'patientID': patient.id,
      'phoneNumber': patient.phone,
      'date':
          (DateTime.now().millisecondsSinceEpoch / (60 * 60 * 1000)).round(),
    });
    openLabworkDialog(context, draft);
  }

  void _showTopPatientsDialog({
    required String title,
    required List<MapEntry<Patient, int>> rows,
    required String metricLabel,
    required Map<String, List<Appointment>> visitsByPatient,
  }) {
    final extraPatients =
        rows.skip(10).map((entry) => entry.key).toSet().toList(growable: false);
    final detailRows = extraPatients
        .expand((patient) => patient.patientDetails)
        .toList(growable: false)
      ..sort((a, b) => b.date.compareTo(a.date));

    if (detailRows.isEmpty) {
      showDialog<void>(
        context: context,
        builder: (_) => ContentDialog(
          title: Text('$title (${rows.length})'),
          content: Text(
            'No additional $metricLabel rows to show.',
            style: const TextStyle(color: Color(0xFF5B789F)),
          ),
          actions: [
            AppButton(
              label: 'Close',
              variant: AppButtonVariant.secondary,
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        ),
      );
      return;
    }

    showReportTableModal(
      context: context,
      title: '$title (${rows.length})',
      rows: detailRows,
      hiddenColumns: const [
        'Doc Paid',
        'TotalDocPay',
      ],
    );
  }

  String _csvCell(String value) {
    final escaped = value.replaceAll('"', '""');
    return '"$escaped"';
  }

  String _patientsFileStem() {
    final stamp = DateFormat('dd_MMM_yyyy_HH_mm').format(DateTime.now());
    return 'patients_filtered_$stamp';
  }

  String _normalizeSavePath(String rawPath, String extension) {
    final trimmed = rawPath.trim();
    final normalized = trimmed.startsWith('file://')
        ? Uri.parse(trimmed).toFilePath(windows: Platform.isWindows)
        : trimmed;
    return normalized.toLowerCase().endsWith(extension)
        ? normalized
        : '$normalized$extension';
  }

  Future<void> _exportPatientsCsv({
    required List<Patient> rows,
    required Map<String, List<Appointment>> visitsByPatient,
  }) async {
    if (_isExportingPatientsCsv || _isExportingPatientsPdf || rows.isEmpty) {
      return;
    }

    setState(() => _isExportingPatientsCsv = true);
    try {
      await runWithExportProgressDialog<void>(
        context: context,
        title: 'Exporting CSV',
        task: (progress) async {
          progress.setProgress(0.1);
          if (progress.isCancelled) {
            return;
          }

          final buffer = StringBuffer();
          buffer.writeln(
              'ID,Patient,Phone,Age,Visits,Last Visit,Paid,Outstanding');

          for (int i = 0; i < rows.length; i++) {
            if (progress.isCancelled) return;
            final patient = rows[i];
            final visits = visitsByPatient[patient.id] ?? const <Appointment>[];
            final paid = visits.fold<double>(
              0,
              (sum, visit) => sum + visit.paid + visit.prescriptionPaid,
            );
            final lastVisit = visits.isEmpty
                ? '-'
              : formatClinicDate(visits.last.date, pattern: 'dd MMM yyyy');
            buffer.writeln(
              [
                _csvCell(patient.id),
                _csvCell(_patientDisplayName(patient)),
                _csvCell(patient.phone),
                patient.age,
                visits.length,
                _csvCell(lastVisit),
                paid.toStringAsFixed(0),
                patient.outstandingPayments.toStringAsFixed(0),
              ].join(','),
            );
            if (i % 20 == 0) {
              progress.setProgress(0.1 + (0.55 * ((i + 1) / rows.length)));
            }
          }

          progress.setProgress(0.7);
          final savePath = await FilePicker.platform.saveFile(
            dialogTitle: 'Save CSV',
            fileName: '${_patientsFileStem()}.csv',
          );
          if (savePath == null ||
              savePath.trim().isEmpty ||
              progress.isCancelled) {
            return;
          }

          final target = _normalizeSavePath(savePath, '.csv');
          await File(target).parent.create(recursive: true);
          progress.setProgress(0.85);

          await File(target).writeAsString(
            buffer.toString(),
            encoding: utf8,
            flush: true,
          );
          progress.setProgress(1);
        },
      );
    } catch (error) {
      if (mounted) {
        displayInfoBar(
          context,
          builder: (ctx, close) => InfoBar(
            title: const Text('CSV export failed'),
            content: Text('$error'),
            severity: InfoBarSeverity.error,
            action: IconButton(
              icon: const Icon(FluentIcons.clear),
              onPressed: close,
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isExportingPatientsCsv = false);
      }
    }
  }

  Future<void> _exportPatientsPdf({
    required List<Patient> rows,
    required Map<String, List<Appointment>> visitsByPatient,
  }) async {
    if (_isExportingPatientsCsv || _isExportingPatientsPdf || rows.isEmpty) {
      return;
    }

    setState(() => _isExportingPatientsPdf = true);
    try {
      await runWithExportProgressDialog<void>(
        context: context,
        title: 'Exporting PDF',
        task: (progress) async {
          progress.setProgress(0.2);
          final tableRows = <List<String>>[
            const [
              'ID',
              'Patient',
              'Phone',
              'Age',
              'Visits',
              'Last Visit',
              'Paid',
              'Outstanding',
            ],
          ];

          for (int i = 0; i < rows.length; i++) {
            final patient = rows[i];
            final visits = visitsByPatient[patient.id] ?? const <Appointment>[];
            final paid = visits.fold<double>(
              0,
              (sum, visit) => sum + visit.paid + visit.prescriptionPaid,
            );
            final lastVisit = visits.isEmpty
                ? '-'
              : formatClinicDate(visits.last.date, pattern: 'dd MMM yyyy');
            tableRows.add([
              patient.id,
              _patientDisplayName(patient),
              patient.phone,
              '${patient.age}',
              '${visits.length}',
              lastVisit,
              paid.toStringAsFixed(0),
              patient.outstandingPayments.toStringAsFixed(0),
            ]);
            if (i % 20 == 0) {
              progress.setProgress(0.2 + (0.4 * ((i + 1) / rows.length)));
            }
          }

          progress.setProgress(0.75);
          final bytes = await generateTablePdf(
            title: 'Filtered Patients Export',
            rows: tableRows,
          );
          if (progress.isCancelled) return;

          final savePath = await FilePicker.platform.saveFile(
            dialogTitle: 'Save PDF',
            fileName: '${_patientsFileStem()}.pdf',
          );
          if (savePath == null ||
              savePath.trim().isEmpty ||
              progress.isCancelled) {
            return;
          }

          final target = _normalizeSavePath(savePath, '.pdf');
          await File(target).parent.create(recursive: true);
          progress.setProgress(0.9);
          await File(target).writeAsBytes(bytes, flush: true);
          progress.setProgress(1);
        },
      );
    } catch (error) {
      if (mounted) {
        displayInfoBar(
          context,
          builder: (ctx, close) => InfoBar(
            title: const Text('PDF export failed'),
            content: Text('$error'),
            severity: InfoBarSeverity.error,
            action: IconButton(
              icon: const Icon(FluentIcons.clear),
              onPressed: close,
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isExportingPatientsPdf = false);
      }
    }
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
              'Name: ${_patientDisplayName(patient)}',
            ),
            Text('Patient ID: ${patient.id}'),
            Text(
                'Phone: ${patient.phone.trim().isEmpty ? '-' : patient.phone}'),
            Text('Age: ${patient.age}'),
            const SizedBox(height: 8),
            const Text('This action is permanent and cannot be undone.'),
          ],
        ),
        actions: [
          AppButton(
            label: 'Cancel',
            variant: AppButtonVariant.secondary,
            onPressed: () => Navigator.pop(dialogContext, false),
          ),
          AppButton(
            label: 'Delete',
            variant: AppButtonVariant.danger,
            onPressed: () => Navigator.pop(dialogContext, true),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    try {
      await patients.hardDelete(patient.id);
    } catch (e) {
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => ContentDialog(
          title: const Text('Cannot delete patient'),
          content: Text(
            '$e\n\nDelete or reassign linked appointments/labworks first.',
          ),
          actions: [
            AppButton(
              label: 'OK',
              variant: AppButtonVariant.secondary,
              onPressed: () => Navigator.pop(dialogContext),
            ),
          ],
        ),
      );
    }
  }

  Future<void> _openEditPatientPopup(Patient patient) async {
    await openAddPatientPopup(
      context: context,
      existingPatient: patient,
    );
  }

  Future<void> _openAddPatientPopup() async {
    await openAddPatientPopup(
      context: context,
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

            final patientAnalytics = <String,
                ({
              int visits,
              DateTime? firstVisit,
              DateTime? lastVisit,
              double totalSpent,
              bool hasProcedureFocus,
              bool visitedToday,
              bool visitedThisMonth,
            })>{};
            for (final patient in allPatients) {
              final rows = visitsByPatient[patient.id] ?? const <Appointment>[];
              final firstVisit = rows.isEmpty ? null : rows.first.date;
              final lastVisit = rows.isEmpty ? null : rows.last.date;
              final totalSpent = rows.fold<double>(
                0,
                (sum, visit) => sum + visit.paid + visit.prescriptionPaid,
              );
              final hasProcedureFocus = rows.any((appointment) {
                return appointment.selectedTreatments.any((treatment) {
                  final normalized = treatment.toLowerCase();
                  return normalized.contains('rct') ||
                      normalized.contains('ortho') ||
                      normalized.contains('crown');
                });
              });
              final visitedToday = rows.any((a) =>
                  a.date.year == now.year &&
                  a.date.month == now.month &&
                  a.date.day == now.day);
              final visitedThisMonth = rows.any(
                  (a) => a.date.year == now.year && a.date.month == now.month);
              patientAnalytics[patient.id] = (
                visits: rows.length,
                firstVisit: firstVisit,
                lastVisit: lastVisit,
                totalSpent: totalSpent,
                hasProcedureFocus: hasProcedureFocus,
                visitedToday: visitedToday,
                visitedThisMonth: visitedThisMonth,
              );
            }

            final ageBuckets = _ageGenderBuckets(allPatients);
            final genderBuckets = _genderBuckets(allPatients);
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
              rangeStart: _rangeStart(_procedureRange, now),
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
              final analytics = patientAnalytics[patient.id];
              final visits = analytics?.visits ?? 0;
              final totalSpent = analytics?.totalSpent ?? 0;
              final lastVisit = analytics?.lastVisit;
              final firstVisit = analytics?.firstVisit;
              final daysSinceLast =
                  lastVisit == null ? 99999 : now.difference(lastVisit).inDays;
              final hasProcedureFocus = analytics?.hasProcedureFocus ?? false;

              switch (_listBehaviorFilter) {
                case 'highValue':
                  return totalSpent >= _highValueThreshold;
                case 'frequent':
                  return visits >= 5;
                case 'inactive':
                  return visits > 0 && daysSinceLast > 180;
                case 'new':
                  return firstVisit != null &&
                      firstVisit.year == now.year &&
                      firstVisit.month == now.month &&
                      firstVisit.day == now.day;
                case 'focused':
                  return visits > 0 && daysSinceLast <= 90;
                case 'outstandingOnly':
                  return patient.outstandingPayments > 0;
                case 'procedureFocus':
                  return hasProcedureFocus;
                case 'visitedThisMonth':
                  return analytics?.visitedThisMonth ?? false;
                case 'oneTimer':
                  return visits == 1;
                case 'invalidPhone':
                  final digits =
                      patient.phone.replaceAll(RegExp(r'[^0-9]'), '');
                  return digits.length != 10;
                case 'noVisit':
                  return visits == 0;
                case 'todayVisited':
                  return analytics?.visitedToday ?? false;
                default:
                  return true;
              }
            }).toList(growable: false);

            if (_listBehaviorFilter == 'focused') {
              filteredPatients.sort((a, b) {
                final aLast = patientAnalytics[a.id]?.lastVisit ??
                    DateTime.fromMillisecondsSinceEpoch(0);
                final bLast = patientAnalytics[b.id]?.lastVisit ??
                    DateTime.fromMillisecondsSinceEpoch(0);
                return bLast.compareTo(aLast);
              });
            } else {
              filteredPatients.sort((a, b) {
                switch (_sortBy) {
                  case 'id':
                    return a.id.toLowerCase().compareTo(b.id.toLowerCase());
                  case 'phone':
                    return a.phone
                        .toLowerCase()
                        .compareTo(b.phone.toLowerCase());
                  case 'age':
                    return a.age.compareTo(b.age);
                  case 'lastVisit':
                    final aLast = patientAnalytics[a.id]?.lastVisit ??
                        DateTime.fromMillisecondsSinceEpoch(0);
                    final bLast = patientAnalytics[b.id]?.lastVisit ??
                        DateTime.fromMillisecondsSinceEpoch(0);
                    return aLast.compareTo(bLast);
                  case 'paidSoFar':
                    final aPaid = patientAnalytics[a.id]?.totalSpent ?? 0;
                    final bPaid = patientAnalytics[b.id]?.totalSpent ?? 0;
                    return aPaid.compareTo(bPaid);
                  case 'visits':
                    final aVisits = patientAnalytics[a.id]?.visits ?? 0;
                    final bVisits = patientAnalytics[b.id]?.visits ?? 0;
                    return aVisits.compareTo(bVisits);
                  case 'outstanding':
                    return a.outstandingPayments
                        .compareTo(b.outstandingPayments);
                  case 'name':
                  default:
                    return a.title
                        .toLowerCase()
                        .compareTo(b.title.toLowerCase());
                }
              });
            }

            final sortedPatients = _listBehaviorFilter == 'focused'
                ? filteredPatients
                : (_sortAscending
                    ? filteredPatients
                    : filteredPatients.reversed.toList(growable: false));

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
                        child: AppButton(
                          onPressed: _openAddPatientPopup,
                          label: 'Add Patient',
                          leading: const Icon(FluentIcons.add, size: 12),
                          expanded: true,
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
                        child: AppButton(
                          onPressed: _openAddPatientPopup,
                          label: 'Add Patient',
                          leading: const Icon(FluentIcons.add, size: 12),
                          expanded: true,
                        ),
                      ),
                    ],
                  ),
                const SizedBox(height: 10),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final metricWidth = constraints.maxWidth < 920
                        ? constraints.maxWidth
                        : 280.0;

                    return Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        SizedBox(
                          width: metricWidth,
                          child: _MetricCard(
                            title: 'Total Patients (Unique IDs)',
                            value: '$uniquePatientCount',
                            valueColor: const Color(0xFF1D3E67),
                          ),
                        ),
                        SizedBox(
                          width: metricWidth,
                          height: 160,
                          child: _PatientGrowthMonthlyCard(rows: monthlyGrowth),
                        ),
                        SizedBox(
                          width: metricWidth,
                          height: 160,
                          child: _TreatmentJourneyTimelineCard(
                            metrics: journeyMetrics,
                          ),
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 10),
                const SizedBox(height: 2),
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
                    final previousFilter = _listBehaviorFilter;
                    _listBehaviorFilter = v;
                    if (v == 'focused') {
                      _sortBy = 'lastVisit';
                      _sortAscending = false;
                    } else if (v == 'outstandingOnly') {
                      _sortBy = 'outstanding';
                      _sortAscending = false;
                    } else if (previousFilter == 'outstandingOnly') {
                      _sortBy = 'name';
                      _sortAscending = true;
                    }
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
                  onEditPatient: _openEditPatientPopup,
                  onOpenLabwork: _openLabworkForPatient,
                  onExportCsv: () => _exportPatientsCsv(
                    rows: sortedPatients,
                    visitsByPatient: visitsByPatient,
                  ),
                  onExportPdf: () => _exportPatientsPdf(
                    rows: sortedPatients,
                    visitsByPatient: visitsByPatient,
                  ),
                  isExportingCsv: _isExportingPatientsCsv,
                  isExportingPdf: _isExportingPatientsPdf,
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

    return buckets.entries.map((entry) {
      return (
        label: formatClinicDate(entry.key, pattern: 'MMM'),
        count: entry.value.length,
      );
    }).toList(growable: false);
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
    required DateTime? rangeStart,
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
      if (rangeStart != null && appointment.date.isBefore(rangeStart)) {
        continue;
      }

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
                      AppButton(
                        label: 'Close',
                        variant: AppButtonVariant.secondary,
                        onPressed: () => Navigator.of(context).pop(),
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
    final trendColor =
        hasGrowth ? const Color(0xFF2BA58D) : const Color(0xFFD6455D);
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
    const gap = 0.04;
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

    return _CardShell(
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 320, maxHeight: 420),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Top Patients by Visits',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF183A67),
                    ),
                  ),
                ),
                if (rows.length > 10)
                  IconButton(
                    onPressed: onViewMore,
                    icon: const Icon(
                      FluentIcons.forward,
                      size: 14,
                      color: Color(0xFF2D7BD8),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            if (ranges.length > 1) ...[
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
            ],
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
                                    _patientDisplayName(entry.value.key),
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
                    if (rows.length > 10) const SizedBox.shrink(),
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
    return formatClinicDate(visits.last.date, pattern: 'dd MMM');
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

    return _CardShell(
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 320, maxHeight: 420),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Top Outstanding Patients',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF183A67),
                    ),
                  ),
                ),
                if (rows.length > 10)
                  IconButton(
                    onPressed: onViewMore,
                    icon: const Icon(
                      FluentIcons.forward,
                      size: 14,
                      color: Color(0xFF2D7BD8),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            if (ranges.length > 1)
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
            if (ranges.length > 1) const SizedBox(height: 14),
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
                                    _patientDisplayName(entry.value.key),
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
                    if (rows.length > 10) const SizedBox.shrink(),
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
    return formatClinicDate(visits.last.date, pattern: 'dd MMM');
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
  final String selectedRange;
  final List<String> ranges;
  final ValueChanged<String> onSelectRange;
  final ValueChanged<String> onSelectTab;
  final ValueChanged<Patient> onOpenHistory;
  final int visibleCount;
  final VoidCallback onViewMore;

  const _TopProcedurePatientsCard({
    required this.selectedTab,
    required this.rows,
    required this.visitsByPatient,
    required this.selectedRange,
    required this.ranges,
    required this.onSelectRange,
    required this.onSelectTab,
    required this.onOpenHistory,
    required this.visibleCount,
    required this.onViewMore,
  });

  @override
  Widget build(BuildContext context) {
    final visibleRows = rows.take(visibleCount).toList(growable: false);

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
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Procedure Focus Patients',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF183A67),
                    ),
                  ),
                ),
                if (rows.length > 10)
                  IconButton(
                    onPressed: onViewMore,
                    icon: const Icon(
                      FluentIcons.forward,
                      size: 14,
                      color: Color(0xFF2BA58D),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                tabChip('RCT'),
                const SizedBox(width: 6),
                tabChip('ORTHO'),
              ],
            ),
            if (ranges.length > 1) const SizedBox(height: 8),
            if (ranges.length > 1)
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
                                    _patientDisplayName(entry.value.key),
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
                    if (rows.length > 10) const SizedBox.shrink(),
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
    return formatClinicDate(visits.last.date, pattern: 'dd MMM');
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
  final ValueChanged<Patient> onEditPatient;
  final ValueChanged<Patient> onOpenHistory;
  final ValueChanged<Patient> onOpenLabwork;
  final ValueChanged<Patient> onDeletePatient;
  final VoidCallback onExportCsv;
  final VoidCallback onExportPdf;
  final bool isExportingCsv;
  final bool isExportingPdf;
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
    required this.onEditPatient,
    required this.onOpenHistory,
    required this.onOpenLabwork,
    required this.onDeletePatient,
    required this.onExportCsv,
    required this.onExportPdf,
    required this.isExportingCsv,
    required this.isExportingPdf,
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
    final compactHeader = screenWidth < 980;
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
      return AppButton(
        label: label,
        variant:
            selected ? AppButtonVariant.primary : AppButtonVariant.secondary,
        onPressed: () => onBehaviorFilterChanged(key),
      );
    }

    return _CardShell(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'All Patients',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              ExportFileActionButton(
                type: ExportFileType.csv,
                busy: isExportingCsv,
                onPressed: (totalItems == 0 || isExportingCsv || isExportingPdf)
                    ? null
                    : onExportCsv,
              ),
              const SizedBox(width: 6),
              ExportFileActionButton(
                type: ExportFileType.pdf,
                busy: isExportingPdf,
                onPressed: (totalItems == 0 || isExportingCsv || isExportingPdf)
                    ? null
                    : onExportPdf,
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '$totalItems matching patients',
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          if (compactHeader)
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  width: searchWidth,
                  child: TextBox(
                    controller: listSearchController,
                    placeholder: 'Search by name or phone',
                  ),
                ),
                const SizedBox(height: 8),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: letters
                        .map(
                          (l) => Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: AppButton(
                              label: l,
                              compact: true,
                              variant: selectedAlphabet == l
                                  ? AppButtonVariant.primary
                                  : AppButtonVariant.secondary,
                              onPressed: () => onSelectAlphabet(l),
                            ),
                          ),
                        )
                        .toList(growable: false),
                  ),
                ),
              ],
            )
          else
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
                              child: AppButton(
                                label: l,
                                compact: true,
                                variant: selectedAlphabet == l
                                    ? AppButtonVariant.primary
                                    : AppButtonVariant.secondary,
                                onPressed: () => onSelectAlphabet(l),
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
              behaviorChip('new', "Today's new"),
              behaviorChip('oneTimer', 'One timer'),
              behaviorChip('outstandingOnly', 'Outstanding'),
              behaviorChip('procedureFocus', 'Procedure focus'),
              behaviorChip('visitedThisMonth', 'Visited this month'),
              behaviorChip('invalidPhone', 'Invalid Phone Number'),
              behaviorChip('noVisit', 'No Visit'),
              behaviorChip('todayVisited', "Today's patients"),
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
                    onChanged: (v) =>
                        onHighValueThresholdChanged(v ?? highValueThreshold),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SizedBox(
              width: math.max(1100, screenWidth - 70),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 10),
                    decoration: BoxDecoration(
                      color: isHeaderHighlighted
                          ? AppColors.primary600
                          : AppColors.primary50,
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
                          label: 'Patient Details',
                          keyName: 'name',
                          current: sortBy,
                          ascending: sortAscending,
                          onSort: onSort,
                          onDark: isHeaderHighlighted,
                        ),
                        _SortableHead(
                          flex: 10,
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
                          flex: 18,
                          child: Text(
                            'Treatments',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: isHeaderHighlighted
                                  ? Colors.white
                                  : AppColors.textSecondary,
                            ),
                          ),
                        ),
                        Expanded(
                          flex: 16,
                          child: _SortableHead(
                            flex: 16,
                            label: 'Paid',
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
                          flex: 20,
                          child: Text(
                            'Actions',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: isHeaderHighlighted
                                  ? Colors.white
                                  : AppColors.textSecondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: AppColors.borderSoft),
                      borderRadius: const BorderRadius.vertical(
                          bottom: Radius.circular(10)),
                    ),
                    child: patientsList.isEmpty
                        ? const Padding(
                            padding: EdgeInsets.all(16),
                            child: Text(
                              'No matching patients',
                              style: TextStyle(color: AppColors.textSecondary),
                            ),
                          )
                        : Column(
                            children: patientsList
                                .toList()
                                .asMap()
                                .entries
                                .map((entry) {
                              final patient = entry.value;
                              final serial = serialOffset + entry.key + 1;
                              final patientVisits =
                                  (visitsByPatient[patient.id] ??
                                      const <Appointment>[]);
                              final visits = patientVisits.length;
                              final lastVisit = patientVisits.isEmpty
                                  ? '-'
                                  : formatClinicDate(patientVisits.last.date,
                                    pattern: 'dd MMM yyyy');
                              final paidSoFar = patientVisits.fold<double>(
                                0,
                                (sum, visit) =>
                                    sum + visit.paid + visit.prescriptionPaid,
                              );
                              final treatments = patientVisits
                                  .expand((visit) => visit.selectedTreatments)
                                  .map((t) => t.trim())
                                  .where((t) => t.isNotEmpty)
                                  .toSet()
                                  .toList(growable: false);
                              final treatmentSummary = treatments.isEmpty
                                  ? 'No treatments'
                                  : treatments.take(3).join(', ');
                              final outstanding = patient.outstandingPayments;

                              return Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 6),
                                decoration: const BoxDecoration(
                                  border: Border(
                                      top:
                                          BorderSide(color: Color(0xFFE2ECF8))),
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      flex: 8,
                                      child: Text(
                                        '$serial',
                                        style: const TextStyle(
                                          color: AppColors.textPrimary,
                                        ),
                                      ),
                                    ),
                                    Expanded(
                                      flex: 24,
                                      child: GestureDetector(
                                        onTap: () => onEditPatient(patient),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              _patientDisplayName(patient),
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                color: AppColors.textActive,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              '${patient.phone} • ${patient.age}y',
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                color: AppColors.textSecondary,
                                                fontSize: 11,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                    Expanded(
                                      flex: 10,
                                      child: Text(
                                        '$visits',
                                        style: const TextStyle(
                                          color: AppColors.textPrimary,
                                        ),
                                      ),
                                    ),
                                    Expanded(
                                      flex: 16,
                                      child: Text(
                                        lastVisit,
                                        style: const TextStyle(
                                          color: AppColors.textPrimary,
                                        ),
                                      ),
                                    ),
                                    Expanded(
                                      flex: 16,
                                      child: Tooltip(
                                        message: treatments.isEmpty
                                            ? 'No treatments'
                                            : treatments.join(', '),
                                        child: Text(
                                          treatments.length > 3
                                              ? '$treatmentSummary +${treatments.length - 3}'
                                              : treatmentSummary,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            color: AppColors.textPrimary,
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    ),
                                    Expanded(
                                      flex: 16,
                                      child: Text(
                                        '₹${paidSoFar.toStringAsFixed(0)}',
                                        style: const TextStyle(
                                          color: AppColors.textActive,
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
                                              ? AppColors.error
                                              : AppColors.textPrimary,
                                        ),
                                      ),
                                    ),
                                    Expanded(
                                      flex: 20,
                                      child: Align(
                                        alignment: Alignment.center,
                                        child: Wrap(
                                          spacing: 6,
                                          runSpacing: 6,
                                          alignment: WrapAlignment.center,
                                          children: [
                                            _HoverActionItem(
                                              icon: FluentIcons.history,
                                              label: 'History',
                                              onTap: () =>
                                                  onOpenHistory(patient),
                                            ),
                                            _HoverActionItem(
                                              icon: FluentIcons.test_beaker,
                                              label: 'Lab',
                                              iconColor:
                                                  const Color(0xFF2BA58D),
                                              hoverColor:
                                                  const Color(0xFFEAF8F1),
                                              hoverBorderColor:
                                                  const Color(0xFFBFEAD8),
                                              onTap: () =>
                                                  onOpenLabwork(patient),
                                            ),
                                            _HoverActionItem(
                                              icon: FluentIcons.delete,
                                              label: 'Delete',
                                              iconColor:
                                                  const Color(0xFFD6455D),
                                              hoverColor:
                                                  const Color(0xFFFCEDEF),
                                              hoverBorderColor:
                                                  const Color(0xFFF7CDD4),
                                              onTap: () =>
                                                  onDeletePatient(patient),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }).toList(growable: false),
                          ),
                  ),
                ],
              ),
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
              Expanded(
                child: Align(
                  alignment: Alignment.centerRight,
                  child: AppPagination(
                    currentPage: currentPage,
                    totalPages: totalPages,
                    onPageChanged: onPageChanged,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HoverActionItem extends StatefulWidget {
  final IconData icon;
  final String label;
  final Color iconColor;
  final Color hoverColor;
  final Color hoverBorderColor;
  final VoidCallback onTap;

  const _HoverActionItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.iconColor = const Color(0xFF2D4A70),
    this.hoverColor = const Color(0xFFEAF1FB),
    this.hoverBorderColor = const Color(0xFFD4E1F2),
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
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
          decoration: BoxDecoration(
            color: _hovered ? widget.hoverColor : Colors.white,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color:
                  _hovered ? widget.hoverBorderColor : const Color(0xFFD6E2F0),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(widget.icon, size: 12, color: widget.iconColor),
              const SizedBox(width: 4),
              Text(
                widget.label,
                style: TextStyle(
                  color: widget.iconColor,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
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
