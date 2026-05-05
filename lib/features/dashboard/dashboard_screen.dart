// ignore_for_file: unused_element, unused_field, unused_local_variable, unused_import

import 'dart:async';
import 'dart:math' as math;

import 'package:apexo/common_widgets/app_screen_title.dart';
import 'package:apexo/common_widgets/date_navigator_bar.dart';
import 'package:apexo/common_widgets/patient_checkin_lookup_dialog.dart';
import 'package:apexo/core/theme/app_colors.dart';
import 'package:apexo/core/theme/app_theme.dart';
import 'package:apexo/core/ui/components/app_button.dart';
import 'package:apexo/features/appointments/appointment_model.dart';
import 'package:apexo/features/appointments/appointment_financials.dart';
import 'package:apexo/features/appointments/appointments_store.dart';
import 'package:apexo/features/checkin/checkin_stage_modals.dart';
import 'package:apexo/features/checkin/checkin_screen.dart';
import 'package:apexo/features/dashboard/dashboard_controller.dart';
import 'package:apexo/features/dashboard/dashboard_insight_cards.dart';
import 'package:apexo/features/dashboard/overall_due_helper.dart';
import 'package:apexo/features/doctors/doctors_store.dart';
import 'package:apexo/features/labwork/labwork_model.dart';
import 'package:apexo/features/labwork/open_labwork_dialog.dart';
import 'package:apexo/features/network_actions/network_actions_controller.dart';
import 'package:apexo/features/patients/open_add_patient_popup.dart';
import 'package:apexo/features/patients/patients_store.dart';
import 'package:apexo/utils/indian_money.dart';
import 'package:apexo/utils/clinic_time.dart';
import 'package:apexo/common_widgets/patient_history_modal.dart';
import 'package:apexo/common_widgets/report_table_modal.dart';
import 'package:apexo/theme/material_date_picker_theme.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/material.dart' as material;
import 'package:intl/intl.dart';
import 'package:apexo/features/dashboard/outstanding_balance_modal.dart';

DateTime dashboardPersistedDate = DateTime.now();
bool _dashboardInitialAppointmentsSyncSettled = false;
const String dashboardDoctorFilterAll = '__all__';
const String dashboardDoctorFilterUnassigned = '__unassigned__';
const String dashboardTreatmentFilterAll = '__all_treatments__';

String _toTitleCase(String text) {
  return text
      .split(' ')
      .map((word) => word.isEmpty
          ? ''
          : word[0].toUpperCase() + word.substring(1).toLowerCase())
      .join(' ');
}

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  late DateTime selectedDate;
  String _sortBy = 'time';
  bool _sortAscending = true;
  String _searchQuery = '';
  String _appointmentStatusFilter = 'all';
  String _selectedDoctorFilter = dashboardDoctorFilterAll;
  String _selectedTreatmentFilter = dashboardTreatmentFilterAll;
  bool _showAllTreatmentStats = false;
  final TextEditingController _searchController = TextEditingController();
  late final Future<void> _bootstrapFuture;
  String? _initialSyncWarning;

  String? _doctorFilterChipLabel() {
    if (_selectedDoctorFilter == dashboardDoctorFilterAll) return null;
    if (_selectedDoctorFilter == dashboardDoctorFilterUnassigned) {
      return 'Doctor: Unassigned';
    }
    final doctorName = doctors.get(_selectedDoctorFilter)?.title ?? 'Unknown';
    return 'Doctor: $doctorName';
  }

  String? _treatmentFilterChipLabel() {
    if (_selectedTreatmentFilter == dashboardTreatmentFilterAll) return null;
    return 'Treatment: $_selectedTreatmentFilter';
  }

  @override
  void initState() {
    super.initState();
    _bootstrapFuture = _initializeStores();
    selectedDate = _dateOnly(dashboardPersistedDate);
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text;
      });
    });
  }

  Future<void> _initializeStores() async {
    await Future.wait([
      appointments.loaded,
      patients.loaded,
      doctors.loaded,
    ]);
    await _awaitInitialAppointmentsSync();
  }

  Future<void> _awaitInitialAppointmentsSync() async {
    if (_dashboardInitialAppointmentsSyncSettled) return;
    if (appointments.remote == null) {
      _dashboardInitialAppointmentsSyncSettled = true;
      return;
    }

    final startedAt = DateTime.now();
    var attemptedRemoteSync = false;

    try {
      final alreadyInSync =
          await appointments.inSync().timeout(const Duration(seconds: 8));

      if (!alreadyInSync) {
        attemptedRemoteSync = true;
        unawaited(appointments.synchronize());

        final syncDeadline = DateTime.now().add(const Duration(seconds: 90));
        var converged = false;
        while (DateTime.now().isBefore(syncDeadline)) {
          final inSyncNow = await appointments
              .inSync()
              .timeout(const Duration(seconds: 5), onTimeout: () => false);
          if (inSyncNow) {
            converged = true;
            break;
          }
          await Future.delayed(const Duration(milliseconds: 350));
        }

        if (!converged) {
          _initialSyncWarning =
              'Could not finish full server sync. Showing available local data.';
        }
      }
    } on TimeoutException {
      if (networkActions.isSyncing() > 0) {
        _initialSyncWarning =
            'Server sync is taking longer than expected. Showing available local data.';
      }
    } catch (_) {
      _initialSyncWarning =
          'Could not finish full server sync. Showing available local data.';
    } finally {
      if (attemptedRemoteSync) {
        final elapsed = DateTime.now().difference(startedAt);
        const minSkeletonVisibility = Duration(milliseconds: 700);
        if (elapsed < minSkeletonVisibility) {
          await Future.delayed(minSkeletonVisibility - elapsed);
        }
      }
      _dashboardInitialAppointmentsSyncSettled = true;
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _changeDate(int days) {
    setState(() {
      selectedDate = _dateOnly(selectedDate.add(Duration(days: days)));
      dashboardPersistedDate = selectedDate;
    });
  }

  void _goToday() {
    setState(() {
      selectedDate = _dateOnly(DateTime.now());
      dashboardPersistedDate = selectedDate;
    });
  }

  Future<void> _pickDate(BuildContext context) async {
    final picked = await material.showDatePicker(
      context: context,
      initialDate: selectedDate,
      firstDate: DateTime(2000, 1, 1),
      lastDate: DateTime(2100, 12, 31),
      helpText: 'Select date',
      builder: apexoDatePickerBuilder(context),
    );

    if (picked == null) return;
    setState(() {
      selectedDate = _dateOnly(picked);
      dashboardPersistedDate = selectedDate;
    });
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

  List<Appointment> _filteredAndSorted(List<Appointment> source) {
    final q = _searchQuery.trim().toLowerCase();

    final filtered = source.where((a) {
      if (q.isEmpty) return true;
      final name = a.title.toLowerCase();
      final phone = (a.patient?.phone ?? '').toLowerCase();
      return name.contains(q) || phone.contains(q);
    }).toList();

    int compare(Appointment a, Appointment b) {
      switch (_sortBy) {
        case 'patient':
          return a.title.toLowerCase().compareTo(b.title.toLowerCase());
        case 'doctor':
          final aDoctor = a.operators.isEmpty
              ? 'unassigned'
              : a.operators.map((d) => d.title).join(', ');
          final bDoctor = b.operators.isEmpty
              ? 'unassigned'
              : b.operators.map((d) => d.title).join(', ');
          return aDoctor.toLowerCase().compareTo(bDoctor.toLowerCase());
        case 'treatment':
          final aTreatment = a.selectedTreatments.isEmpty
              ? ''
              : a.selectedTreatments.join(', ');
          final bTreatment = b.selectedTreatments.isEmpty
              ? ''
              : b.selectedTreatments.join(', ');
          return aTreatment.toLowerCase().compareTo(bTreatment.toLowerCase());
        case 'status':
          return a.isDone == b.isDone ? 0 : (a.isDone ? 1 : -1);
        case 'paymentMode':
          return _paymentMode(a).compareTo(_paymentMode(b));
        case 'payment':
          final aPayment = a.paid + a.prescriptionPaid;
          final bPayment = b.paid + b.prescriptionPaid;
          return aPayment.compareTo(bPayment);
        case 'actions':
          return a.id.compareTo(b.id);
        case 'time':
        default:
          return a.date.compareTo(b.date);
      }
    }

    filtered.sort(compare);
    if (!_sortAscending) {
      return filtered.reversed.toList();
    }
    return filtered;
  }

  List<Appointment> _statusFilteredAppointments(List<Appointment> source) {
    final normalizedStages = source
        .map((appointment) => normalizeCheckinStage(appointment.checkinStage))
        .toSet();
    final effectiveFilter = _appointmentStatusFilter == 'all' ||
            normalizedStages.contains(_appointmentStatusFilter)
        ? _appointmentStatusFilter
        : 'all';
    if (effectiveFilter == 'all') return source;
    return source.where((appointment) {
      final stage = normalizeCheckinStage(appointment.checkinStage);
      if (effectiveFilter == 'cancelled') {
        return stage == 'cancelled';
      }
      if (effectiveFilter == 'billing') {
        return stage == 'billing';
      }
      if (effectiveFilter == 'treatment') {
        return stage == 'treatment';
      }
      if (effectiveFilter == 'complete' || effectiveFilter == 'completed') {
        return stage == 'complete';
      }

      if (effectiveFilter == 'waiting') return stage == 'waiting';
      if (effectiveFilter == 'scheduled') return stage == 'scheduled';
      return true;
    }).toList(growable: false);
  }

  Set<String> _availableStatusFilters(List<Appointment> source) {
    final stages = <String>{};
    for (final appointment in source) {
      stages.add(normalizeCheckinStage(appointment.checkinStage));
    }
    return stages;
  }

  String _paymentMode(Appointment a) {
    final digital = a.treatmentGpayPaid || a.prescriptionGpayPaid;
    return digital ? 'upi' : 'cash';
  }

  static DateTime _dateOnly(DateTime input) {
    return DateTime(input.year, input.month, input.day);
  }

  List<Appointment> _doctorFiltered(List<Appointment> source) {
    if (_selectedDoctorFilter == dashboardDoctorFilterAll) return source;
    if (_selectedDoctorFilter == dashboardDoctorFilterUnassigned) {
      return source.where((a) => a.operatorsIDs.isEmpty).toList();
    }
    return source
        .where((a) => a.operatorsIDs.contains(_selectedDoctorFilter))
        .toList();
  }

  List<Appointment> _treatmentFiltered(List<Appointment> source) {
    if (_selectedTreatmentFilter == dashboardTreatmentFilterAll) return source;
    final treatment = _selectedTreatmentFilter.toLowerCase();
    return source
        .where(
          (a) => a.selectedTreatments.any(
            (t) => t.trim().toLowerCase() == treatment,
          ),
        )
        .toList();
  }

  List<MapEntry<String, int>> _treatmentDistributionRows(
      List<Appointment> source) {
    final counts = <String, int>{};
    for (final a in source) {
      for (final t in a.selectedTreatments) {
        final name = t.trim();
        if (name.isEmpty) continue;
        counts[name] = (counts[name] ?? 0) + 1;
      }
    }
    final rows = counts.entries.toList(growable: false)
      ..sort((a, b) => b.value.compareTo(a.value));
    return rows.take(6).toList(growable: false);
  }

  void _openOutstandingDialog() {
    showOutstandingBalanceModal(context);
  }

  void _openNewPatientsDialog(List<Appointment> todaysAppointments) {
    final newPatientAppointments = todaysAppointments
        .where((a) => a.firstAppointmentForThisPatient)
        .toList()
      ..sort((a, b) => a.date.compareTo(b.date));

    showDialog(
      context: context,
      builder: (dialogContext) => ContentDialog(
        title: const Text(
          'New Patients Today',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: AppColors.blue7502,
          ),
        ),
        content: SizedBox(
          width: 520,
          child: newPatientAppointments.isEmpty
              ? const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    'No new patients for this date.',
                    style: TextStyle(color: Color(0xFF5B7498)),
                  ),
                )
              : ListView.separated(
                  shrinkWrap: true,
                  itemCount: newPatientAppointments.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 6),
                  itemBuilder: (_, index) {
                    final appointment = newPatientAppointments[index];
                    final patient = appointment.patient;
                    final patientName = appointment.title.trim().isEmpty
                        ? 'Unnamed patient'
                        : appointment.title;
                    final phone = (patient?.phone ?? '').trim();
                    final age = patient?.age ?? 0;
                    final address = (patient?.address ?? '').trim();

                    return Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF5F9FF),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFD7E5F7)),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 28,
                            height: 28,
                            decoration: BoxDecoration(
                              color: const Color(0xFFDDEBFF),
                              borderRadius: BorderRadius.circular(7),
                            ),
                            alignment: Alignment.center,
                            child: const Icon(
                              FluentIcons.contact,
                              size: 14,
                              color: Color(0xFF1468CC),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                GestureDetector(
                                  onTap: patient == null
                                      ? null
                                      : () async {
                                          Navigator.pop(dialogContext);
                                          await openAddPatientPopup(
                                            context: context,
                                            existingPatient: patient,
                                          );
                                        },
                                  child: Text(
                                    patientName,
                                    style: const TextStyle(
                                      color: AppColors.success,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 4,
                                  children: [
                                    Text(
                                      age > 0 ? 'Age: $age' : 'Age: -',
                                      style: const TextStyle(
                                        color: AppColors.success,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    if (phone.isNotEmpty)
                                      Text(
                                        phone,
                                        style: const TextStyle(
                                          color: AppColors.success,
                                          fontSize: 12,
                                        ),
                                      ),
                                  ],
                                ),
                                if (address.isNotEmpty) ...[
                                  const SizedBox(height: 4),
                                  Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Icon(
                                        FluentIcons.location,
                                        size: 12,
                                        color: Color(0xFF6B83A6),
                                      ),
                                      const SizedBox(width: 5),
                                      Expanded(
                                        child: Text(
                                          address,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            color: Color(0xFF5B7498),
                                            fontSize: 11,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
        actions: [
          AppButton(
            label: 'Close',
            onPressed: () => Navigator.pop(context),
            variant: AppButtonVariant.primary,
          ),
        ],
      ),
    );
  }

  DateTime _withCurrentTime(DateTime date) {
    final now = DateTime.now();
    return DateTime(date.year, date.month, date.day, now.hour, now.minute);
  }

  Future<void> _openAddAppointmentFromDashboard() async {
    await showPatientCheckinLookupDialog(
      context: context,
      selectedDate: selectedDate,
      onAddPatient: (query) => openAddPatientPopup(
        context: context,
        initialInput: query,
      ),
      onOpenExisting: (appointment) async {
        await openAppointmentJourneyDialog(context, appointment);
      },
      onCheckInPatient: (patient) async {
        final appointment = Appointment.fromJson({
          'patientID': patient.id,
          'date': _withCurrentTime(selectedDate).millisecondsSinceEpoch,
          'isCheckedIn': true,
          'checkinStage': 'waiting',
          'checkedInAt': DateTime.now().millisecondsSinceEpoch,
        });
        appointments.set(appointment);
        await openAppointmentJourneyDialog(context, appointment);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _bootstrapFuture,
      builder: (context, bootSnapshot) {
        if (bootSnapshot.connectionState != ConnectionState.done) {
          return const _DashboardLoadingOverlay();
        }

        return StreamBuilder(
          stream: appointments.observableMap.stream,
          builder: (context, _) {
            final todaysAppointments = appointments.forDate(selectedDate)
              ..sort((a, b) => a.date.compareTo(b.date));

            final allAppointments =
                appointments.present.values.toList(growable: false);
            final doctorScopedAppointments =
                _doctorFiltered(todaysAppointments);
            final doctorAndTreatmentFiltered =
                _treatmentFiltered(doctorScopedAppointments);
            final availableStatusFilters =
                _availableStatusFilters(doctorAndTreatmentFiltered);
            final selectedStatusFilter = _appointmentStatusFilter == 'all' ||
                    availableStatusFilters.contains(_appointmentStatusFilter)
                ? _appointmentStatusFilter
                : 'all';
            final tableAppointments = _filteredAndSorted(
              _statusFilteredAppointments(doctorAndTreatmentFiltered),
            );
            final treatmentStats =
                DashboardTreatmentStats.from(doctorScopedAppointments);

            final doctorFilterChip = _doctorFilterChipLabel();
            final treatmentFilterChip = _treatmentFilterChipLabel();
            final isDoctorFilterApplied =
                _selectedDoctorFilter != dashboardDoctorFilterAll ||
                    _selectedTreatmentFilter != dashboardTreatmentFilterAll;

            final duplicatePatientCounts = <String, int>{};
            for (final appointment in tableAppointments) {
              final pid = appointment.patientID;
              if (pid == null || pid.isEmpty) continue;
              duplicatePatientCounts[pid] =
                  (duplicatePatientCounts[pid] ?? 0) + 1;
            }
            final duplicatePatientKeys = duplicatePatientCounts.entries
                .where((entry) => entry.value > 1)
                .map((entry) => entry.key)
                .toSet();

            final waiting = doctorScopedAppointments.where((appointment) {
              final stage = normalizeCheckinStage(appointment.checkinStage);
              return stage == 'waiting';
            }).length;
            final scheduled = doctorScopedAppointments.where((appointment) {
              final stage = normalizeCheckinStage(appointment.checkinStage);
              return stage == 'scheduled';
            }).length;
            final treatment = doctorScopedAppointments.where((appointment) {
              final stage = normalizeCheckinStage(appointment.checkinStage);
              return stage == 'with_doctor';
            }).length;
            final billing = doctorScopedAppointments.where((appointment) {
              final stage = normalizeCheckinStage(appointment.checkinStage);
              return stage == 'checkout';
            }).length;
            final completed = doctorScopedAppointments.where((appointment) {
              final stage = normalizeCheckinStage(appointment.checkinStage);
              return stage == 'complete';
            }).length;

            final newPatients = doctorScopedAppointments
                .where(
                    (appointment) => appointment.firstAppointmentForThisPatient)
                .length;
            final returningPatients =
                math.max(0, doctorScopedAppointments.length - newPatients);

            final treatmentRevenue = doctorScopedAppointments.fold<double>(
              0,
              (sum, appointment) => sum + appointment.paid,
            );
            final prescriptionRevenue = doctorScopedAppointments.fold<double>(
              0,
              (sum, appointment) => sum + appointment.prescriptionPaid,
            );
            final revenueToday = treatmentRevenue + prescriptionRevenue;

            final doctorFeeToday = doctorScopedAppointments.fold<double>(
              0,
              (sum, appointment) => sum + appointment.doctorPayableAmount,
            );
            final netProfitToday = revenueToday - doctorFeeToday;

            final outstandingBalance = dashboardCtrl.totalDueAmount();

            double morningCash = 0;
            double morningUpi = 0;
            int morningPatients = 0;
            double eveningCash = 0;
            double eveningUpi = 0;
            int eveningPatients = 0;

            for (final appointment in doctorScopedAppointments) {
              final totalPayment =
                  appointment.paid + appointment.prescriptionPaid;
              final isDigital = appointment.treatmentGpayPaid ||
                  appointment.prescriptionGpayPaid;
              final hour = appointment.date.hour;

              if (hour < 15) {
                morningPatients += 1;
                if (isDigital) {
                  morningUpi += totalPayment;
                } else {
                  morningCash += totalPayment;
                }
              } else {
                eveningPatients += 1;
                if (isDigital) {
                  eveningUpi += totalPayment;
                } else {
                  eveningCash += totalPayment;
                }
              }
            }

            final firstVisitByPatient = <String, DateTime>{};
            for (final a in allAppointments) {
              final pid = a.patientID;
              if (pid == null || pid.isEmpty) continue;
              final visitDate = _dateOnly(a.date);
              final existing = firstVisitByPatient[pid];
              if (existing == null || visitDate.isBefore(existing)) {
                firstVisitByPatient[pid] = visitDate;
              }
            }

            final dailyTreatmentDistribution =
                _treatmentDistributionRows(todaysAppointments);

            return Container(
              color: AppTheme.light.scaffoldBackgroundColor,
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _OverviewHeader(
                      selectedDate: selectedDate,
                      onPrevious: () => _changeDate(-1),
                      onNext: () => _changeDate(1),
                      onPick: () => _pickDate(context),
                      onToday: _goToday,
                    ),
                    if (_initialSyncWarning != null) ...[
                      const SizedBox(height: 8),
                      InfoBar(
                        severity: InfoBarSeverity.warning,
                        title: const Text('Sync Incomplete'),
                        content: Text(_initialSyncWarning!),
                      ),
                    ],
                    const SizedBox(height: 10),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final cards = [
                          _AppointmentsTodayCard(
                            totalAppointments: todaysAppointments.length,
                            newPatients: newPatients,
                            returningPatients: returningPatients,
                            onTap: () =>
                                _openNewPatientsDialog(todaysAppointments),
                          ),
                          _StatusSummaryCard(
                            waiting: waiting,
                            scheduled: scheduled,
                            treatment: treatment,
                            billing: billing,
                            completed: completed,
                          ),
                          _RevenueCard(
                            title: 'Revenue Today',
                            value: _money(revenueToday),
                            revenueTotal: revenueToday,
                            doctorFee: doctorFeeToday,
                            netProfit: netProfitToday,
                          ),
                          _SessionRevenueCard(
                            title: 'Morning',
                            range: '12 AM - 3 PM',
                            total: morningCash + morningUpi,
                            cash: morningCash,
                            upi: morningUpi,
                            patientCount: morningPatients,
                            borderColor: AppColors.amber200,
                            background: AppColors.amber1004,
                            iconColor: AppColors.amber500,
                          ),
                          _SessionRevenueCard(
                            title: 'Evening',
                            range: '3 PM - 12 AM',
                            total: eveningCash + eveningUpi,
                            cash: eveningCash,
                            upi: eveningUpi,
                            patientCount: eveningPatients,
                            borderColor: AppColors.violet400,
                            background: AppColors.slate1008,
                            iconColor: AppColors.primary800,
                          ),
                          _TopDailyTreatmentCard(
                            rows: dailyTreatmentDistribution,
                          ),
                        ];
                        const gap = 10.0;

                        return Wrap(
                          spacing: gap,
                          runSpacing: gap,
                          children: cards,
                        );
                      },
                    ),
                    const SizedBox(height: 16),
                    const _SectionTitle('Financial Summary'),
                    const SizedBox(height: 10),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final isNarrow = constraints.maxWidth < 980;
                        if (isNarrow) {
                          return Column(
                            children: [
                              _FinanceCard(
                                title: 'Treatment Revenue',
                                value: _money(treatmentRevenue),
                                icon: FluentIcons.money,
                                iconColor: AppColors.successTeal,
                                iconBackground: AppColors.violet1005,
                                valueColor: AppColors.blue600,
                              ),
                              const SizedBox(height: 10),
                              _FinanceCard(
                                title: 'Prescription Revenue',
                                value: _money(prescriptionRevenue),
                                icon: FluentIcons.precipitation,
                                iconColor: AppColors.successTeal,
                                iconBackground: AppColors.green1002,
                                valueColor: AppColors.blue600,
                              ),
                              const SizedBox(height: 10),
                              _FinanceCard(
                                title: 'Outstanding Balance',
                                value: _money(outstandingBalance),
                                icon: FluentIcons.status_error_full,
                                iconColor: AppColors.dangerRose,
                                iconBackground: AppColors.amber2003,
                                valueColor: AppColors.blue7508,
                                onTap: _openOutstandingDialog,
                              ),
                            ],
                          );
                        }

                        return Row(
                          children: [
                            Expanded(
                              child: _FinanceCard(
                                title: 'Treatment Revenue',
                                value: _money(treatmentRevenue),
                                icon: FluentIcons.money,
                                iconColor: AppColors.successTeal,
                                iconBackground: AppColors.violet1005,
                                valueColor: AppColors.blue600,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _FinanceCard(
                                title: 'Prescription Revenue',
                                value: _money(prescriptionRevenue),
                                icon: FluentIcons.precipitation,
                                iconColor: AppColors.successTeal,
                                iconBackground: AppColors.green1002,
                                valueColor: AppColors.blue600,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _FinanceCard(
                                title: 'Outstanding Balance',
                                value: _money(outstandingBalance),
                                icon: FluentIcons.status_error_full,
                                iconColor: AppColors.dangerRose,
                                iconBackground: AppColors.amber2003,
                                valueColor: AppColors.blue7508,
                                onTap: _openOutstandingDialog,
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 14),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final useColumn = constraints.maxWidth < 1080;
                        if (useColumn) {
                          return Column(
                            children: [
                              RepaintBoundary(
                                child: DashboardDoctorInsightsCard(
                                  todaysAppointments: todaysAppointments,
                                  selectedFilter: _selectedDoctorFilter,
                                  allFilterToken: dashboardDoctorFilterAll,
                                  unassignedFilterToken:
                                      dashboardDoctorFilterUnassigned,
                                  onFilterChanged: (v) => setState(() {
                                    _selectedDoctorFilter =
                                        _selectedDoctorFilter == v
                                            ? dashboardDoctorFilterAll
                                            : v;
                                  }),
                                ),
                              ),
                              const SizedBox(height: 10),
                              RepaintBoundary(
                                child: DashboardTreatmentStatsCard(
                                  stats: treatmentStats,
                                  selectedTreatment: _selectedTreatmentFilter,
                                  allTreatmentFilterToken:
                                      dashboardTreatmentFilterAll,
                                  showAll: _showAllTreatmentStats,
                                  onFilterChanged: (v) => setState(() {
                                    _selectedTreatmentFilter =
                                        _selectedTreatmentFilter == v
                                            ? dashboardTreatmentFilterAll
                                            : v;
                                  }),
                                  onToggleShowAll: () => setState(
                                    () => _showAllTreatmentStats =
                                        !_showAllTreatmentStats,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 10),
                              RepaintBoundary(
                                child: _RightDashboardColumn(
                                  tableAppointments: tableAppointments,
                                  duplicatePatientKeys: duplicatePatientKeys,
                                  isFilterApplied: isDoctorFilterApplied,
                                  doctorFilterChip: doctorFilterChip,
                                  treatmentFilterChip: treatmentFilterChip,
                                  searchController: _searchController,
                                  selectedDate: selectedDate,
                                  sortBy: _sortBy,
                                  sortAscending: _sortAscending,
                                  onSort: _onSort,
                                  onPreviousDate: () => _changeDate(-1),
                                  onNextDate: () => _changeDate(1),
                                  onPickDate: () => _pickDate(context),
                                  onGoToday: _goToday,
                                  onAddAppointment:
                                      _openAddAppointmentFromDashboard,
                                  onClearDoctorFilter: () => setState(() {
                                    _selectedDoctorFilter =
                                        dashboardDoctorFilterAll;
                                  }),
                                  onClearTreatmentFilter: () => setState(() {
                                    _selectedTreatmentFilter =
                                        dashboardTreatmentFilterAll;
                                  }),
                                  onClearFilters: () => setState(() {
                                    _selectedDoctorFilter =
                                        dashboardDoctorFilterAll;
                                    _selectedTreatmentFilter =
                                        dashboardTreatmentFilterAll;
                                    _appointmentStatusFilter = 'all';
                                  }),
                                  selectedStatusFilter: selectedStatusFilter,
                                  availableStatusFilters:
                                      availableStatusFilters,
                                  onStatusFilterChanged: (value) => setState(
                                      () => _appointmentStatusFilter = value),
                                ),
                              ),
                            ],
                          );
                        }
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SizedBox(
                              width: 320,
                              child: Column(
                                children: [
                                  RepaintBoundary(
                                    child: DashboardDoctorInsightsCard(
                                      todaysAppointments: todaysAppointments,
                                      selectedFilter: _selectedDoctorFilter,
                                      allFilterToken: dashboardDoctorFilterAll,
                                      unassignedFilterToken:
                                          dashboardDoctorFilterUnassigned,
                                      onFilterChanged: (v) => setState(() {
                                        _selectedDoctorFilter =
                                            _selectedDoctorFilter == v
                                                ? dashboardDoctorFilterAll
                                                : v;
                                      }),
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  RepaintBoundary(
                                    child: DashboardTreatmentStatsCard(
                                      stats: treatmentStats,
                                      selectedTreatment:
                                          _selectedTreatmentFilter,
                                      allTreatmentFilterToken:
                                          dashboardTreatmentFilterAll,
                                      showAll: _showAllTreatmentStats,
                                      onFilterChanged: (v) => setState(() {
                                        _selectedTreatmentFilter =
                                            _selectedTreatmentFilter == v
                                                ? dashboardTreatmentFilterAll
                                                : v;
                                      }),
                                      onToggleShowAll: () => setState(
                                        () => _showAllTreatmentStats =
                                            !_showAllTreatmentStats,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: RepaintBoundary(
                                child: _RightDashboardColumn(
                                  tableAppointments: tableAppointments,
                                  duplicatePatientKeys: duplicatePatientKeys,
                                  isFilterApplied: isDoctorFilterApplied,
                                  doctorFilterChip: doctorFilterChip,
                                  treatmentFilterChip: treatmentFilterChip,
                                  searchController: _searchController,
                                  selectedDate: selectedDate,
                                  sortBy: _sortBy,
                                  sortAscending: _sortAscending,
                                  onSort: _onSort,
                                  onPreviousDate: () => _changeDate(-1),
                                  onNextDate: () => _changeDate(1),
                                  onPickDate: () => _pickDate(context),
                                  onGoToday: _goToday,
                                  onAddAppointment:
                                      _openAddAppointmentFromDashboard,
                                  onClearDoctorFilter: () => setState(() {
                                    _selectedDoctorFilter =
                                        dashboardDoctorFilterAll;
                                  }),
                                  onClearTreatmentFilter: () => setState(() {
                                    _selectedTreatmentFilter =
                                        dashboardTreatmentFilterAll;
                                  }),
                                  onClearFilters: () => setState(() {
                                    _selectedDoctorFilter =
                                        dashboardDoctorFilterAll;
                                    _selectedTreatmentFilter =
                                        dashboardTreatmentFilterAll;
                                    _appointmentStatusFilter = 'all';
                                  }),
                                  selectedStatusFilter: selectedStatusFilter,
                                  availableStatusFilters:
                                      availableStatusFilters,
                                  onStatusFilterChanged: (value) => setState(
                                      () => _appointmentStatusFilter = value),
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  static String _money(double value) {
    final formatter = NumberFormat('#,##0.##');
    return '₹${formatter.format(value)}';
  }
}

class _PatientGrowthMetricsCard extends StatelessWidget {
  final int newPatientsToday;
  final int newPatientsWeek;
  final int newPatientsPrevWeek;
  final double growthPct;

  const _PatientGrowthMetricsCard({
    required this.newPatientsToday,
    required this.newPatientsWeek,
    required this.newPatientsPrevWeek,
    required this.growthPct,
  });

  @override
  Widget build(BuildContext context) {
    return _CardShell(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Patient Growth Metrics',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppColors.blue7502,
            ),
          ),
          const SizedBox(height: 10),
          _InsightLine(label: 'New patients today', value: '$newPatientsToday'),
          _InsightLine(
              label: 'New patients this week', value: '$newPatientsWeek'),
          _InsightLine(
              label: 'New patients prev week', value: '$newPatientsPrevWeek'),
          _InsightLine(
            label: 'Week-over-week growth',
            value: '${growthPct.toStringAsFixed(1)}%',
          ),
        ],
      ),
    );
  }
}

class _RightDashboardColumn extends StatelessWidget {
  final List<Appointment> tableAppointments;
  final Set<String> duplicatePatientKeys;
  final bool isFilterApplied;
  final String? doctorFilterChip;
  final String? treatmentFilterChip;
  final TextEditingController searchController;
  final DateTime selectedDate;
  final String sortBy;
  final bool sortAscending;
  final ValueChanged<String> onSort;
  final VoidCallback onPreviousDate;
  final VoidCallback onNextDate;
  final VoidCallback onPickDate;
  final VoidCallback onGoToday;
  final VoidCallback onAddAppointment;
  final VoidCallback onClearDoctorFilter;
  final VoidCallback onClearTreatmentFilter;
  final VoidCallback onClearFilters;
  final String selectedStatusFilter;
  final Set<String> availableStatusFilters;
  final ValueChanged<String> onStatusFilterChanged;

  const _RightDashboardColumn({
    required this.tableAppointments,
    required this.duplicatePatientKeys,
    required this.isFilterApplied,
    required this.doctorFilterChip,
    required this.treatmentFilterChip,
    required this.searchController,
    required this.selectedDate,
    required this.sortBy,
    required this.sortAscending,
    required this.onSort,
    required this.onPreviousDate,
    required this.onNextDate,
    required this.onPickDate,
    required this.onGoToday,
    required this.onAddAppointment,
    required this.onClearDoctorFilter,
    required this.onClearTreatmentFilter,
    required this.onClearFilters,
    required this.selectedStatusFilter,
    required this.availableStatusFilters,
    required this.onStatusFilterChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _AppointmentsTableCard(
          tableAppointments: tableAppointments,
          duplicatePatientKeys: duplicatePatientKeys,
          isFilterApplied: isFilterApplied,
          doctorFilterChip: doctorFilterChip,
          treatmentFilterChip: treatmentFilterChip,
          searchController: searchController,
          selectedDate: selectedDate,
          sortBy: sortBy,
          sortAscending: sortAscending,
          onSort: onSort,
          onPreviousDate: onPreviousDate,
          onNextDate: onNextDate,
          onPickDate: onPickDate,
          onGoToday: onGoToday,
          onAddAppointment: onAddAppointment,
          onClearDoctorFilter: onClearDoctorFilter,
          onClearTreatmentFilter: onClearTreatmentFilter,
          onClearFilters: onClearFilters,
          selectedStatusFilter: selectedStatusFilter,
          availableStatusFilters: availableStatusFilters,
          onStatusFilterChanged: onStatusFilterChanged,
        ),
      ],
    );
  }
}

class _AppointmentsTableCard extends StatelessWidget {
  final List<Appointment> tableAppointments;
  final Set<String> duplicatePatientKeys;
  final bool isFilterApplied;
  final String? doctorFilterChip;
  final String? treatmentFilterChip;
  final TextEditingController searchController;
  final DateTime selectedDate;
  final String sortBy;
  final bool sortAscending;
  final ValueChanged<String> onSort;
  final VoidCallback onPreviousDate;
  final VoidCallback onNextDate;
  final VoidCallback onPickDate;
  final VoidCallback onGoToday;
  final VoidCallback onAddAppointment;
  final VoidCallback onClearDoctorFilter;
  final VoidCallback onClearTreatmentFilter;
  final VoidCallback onClearFilters;
  final String selectedStatusFilter;
  final Set<String> availableStatusFilters;
  final ValueChanged<String> onStatusFilterChanged;

  const _AppointmentsTableCard({
    required this.tableAppointments,
    required this.duplicatePatientKeys,
    required this.isFilterApplied,
    required this.doctorFilterChip,
    required this.treatmentFilterChip,
    required this.searchController,
    required this.selectedDate,
    required this.sortBy,
    required this.sortAscending,
    required this.onSort,
    required this.onPreviousDate,
    required this.onNextDate,
    required this.onPickDate,
    required this.onGoToday,
    required this.onAddAppointment,
    required this.onClearDoctorFilter,
    required this.onClearTreatmentFilter,
    required this.onClearFilters,
    required this.selectedStatusFilter,
    required this.availableStatusFilters,
    required this.onStatusFilterChanged,
  });

  @override
  Widget build(BuildContext context) {
    final rows = tableAppointments.take(100).toList(growable: false);
    final duplicateCount = duplicatePatientKeys.length;
    final duplicateText = duplicateCount == 1
        ? '1 patient has duplicate appointment in this list'
        : '$duplicateCount patients have duplicate appointments in this list';

    return _CardShell(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Today\'s Appointments',
                      style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: AppColors.blue7502),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      duplicateText,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF637EA3),
                      ),
                    ),
                    if (doctorFilterChip != null ||
                        treatmentFilterChip != null) ...[
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          if (doctorFilterChip != null)
                            _FilterChipTag(
                              label: doctorFilterChip!,
                              onRemove: onClearDoctorFilter,
                            ),
                          if (treatmentFilterChip != null)
                            _FilterChipTag(
                              label: treatmentFilterChip!,
                              onRemove: onClearTreatmentFilter,
                            ),
                          Text(
                            '${rows.length} results',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textBlueMuted,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          GestureDetector(
                            onTap: onClearFilters,
                            child: const Text(
                              'Clear all',
                              style: TextStyle(
                                color: AppColors.brandBlue,
                                fontWeight: FontWeight.w700,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              Expanded(
                child: Align(
                  alignment: Alignment.topCenter,
                  child: _DateNavigator(
                    selectedDate: selectedDate,
                    onPrevious: onPreviousDate,
                    onNext: onNextDate,
                    onPick: onPickDate,
                    onToday: onGoToday,
                    showBorder: false,
                  ),
                ),
              ),
              Expanded(
                child: Align(
                  alignment: Alignment.topRight,
                  child: SizedBox(
                    width: 370,
                    child: Row(
                      children: [
                        Expanded(
                          child: TextBox(
                            controller: searchController,
                            placeholder: 'Search patient name or phone',
                          ),
                        ),
                        const SizedBox(width: 10),
                        AppButton(
                          label: 'Check-in',
                          onPressed: onAddAppointment,
                          leading: const Icon(FluentIcons.add, size: 14),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _CompactStatusFilterChip(
                label: 'All',
                value: 'all',
                selectedValue: selectedStatusFilter,
                onChanged: onStatusFilterChanged,
              ),
              if (availableStatusFilters.contains('scheduled'))
                _CompactStatusFilterChip(
                  label: 'Scheduled',
                  value: 'scheduled',
                  selectedValue: selectedStatusFilter,
                  onChanged: onStatusFilterChanged,
                ),
              if (availableStatusFilters.contains('waiting'))
                _CompactStatusFilterChip(
                  label: 'Waiting',
                  value: 'waiting',
                  selectedValue: selectedStatusFilter,
                  onChanged: onStatusFilterChanged,
                ),
              if (availableStatusFilters.contains('billing'))
                _CompactStatusFilterChip(
                  label: 'Billing',
                  value: 'billing',
                  selectedValue: selectedStatusFilter,
                  onChanged: onStatusFilterChanged,
                ),
              if (availableStatusFilters.contains('treatment'))
                _CompactStatusFilterChip(
                  label: 'Treatment',
                  value: 'treatment',
                  selectedValue: selectedStatusFilter,
                  onChanged: onStatusFilterChanged,
                ),
              if (availableStatusFilters.contains('cancelled'))
                _CompactStatusFilterChip(
                  label: 'Cancelled',
                  value: 'cancelled',
                  selectedValue: selectedStatusFilter,
                  onChanged: onStatusFilterChanged,
                ),
              if (availableStatusFilters.contains('complete'))
                _CompactStatusFilterChip(
                  label: 'Completed',
                  value: 'complete',
                  selectedValue: selectedStatusFilter,
                  onChanged: onStatusFilterChanged,
                ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            decoration: BoxDecoration(
              border: Border.all(color: AppColors.violet1506),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              children: [
                _TableHeader(
                  sortBy: sortBy,
                  sortAscending: sortAscending,
                  isFilterApplied: isFilterApplied,
                  onSort: onSort,
                ),
                if (rows.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(16),
                    child: Text(
                      'No appointments today',
                      style: TextStyle(color: Color(0xFF557195)),
                    ),
                  )
                else ...[
                  ...rows.map(
                    (a) => _AppointmentRow(
                      appointment: a,
                      isDuplicatePatient: duplicatePatientKeys.contains(
                        _duplicatePatientKey(a),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CompactStatusFilterChip extends StatelessWidget {
  final String label;
  final String value;
  final String selectedValue;
  final ValueChanged<String> onChanged;

  const _CompactStatusFilterChip({
    required this.label,
    required this.value,
    required this.selectedValue,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final selected = value == selectedValue;
    return GestureDetector(
      onTap: () => onChanged(value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: selected ? AppColors.brandBlue : const Color(0xFFF1F6FD),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected ? AppColors.brandBlue : const Color(0xFFD2E2F6),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : const Color(0xFF375A84),
            fontWeight: FontWeight.w700,
            fontSize: 11,
          ),
        ),
      ),
    );
  }
}

class _TableHeader extends StatelessWidget {
  final String sortBy;
  final bool sortAscending;
  final bool isFilterApplied;
  final ValueChanged<String> onSort;

  const _TableHeader({
    required this.sortBy,
    required this.sortAscending,
    required this.isFilterApplied,
    required this.onSort,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color:
            isFilterApplied ? const Color(0xFF1A74DB) : const Color(0xFFEFF4FB),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
      ),
      child: Row(
        children: [
          Expanded(
              flex: 11,
              child: _SortableHeader(
                  label: 'Time',
                  keyName: 'time',
                  current: sortBy,
                  ascending: sortAscending,
                  onSort: onSort,
                  onDark: isFilterApplied)),
          Expanded(
              flex: 15,
              child: _SortableHeader(
                  label: 'Patient',
                  keyName: 'patient',
                  current: sortBy,
                  ascending: sortAscending,
                  onSort: onSort,
                  onDark: isFilterApplied)),
          Expanded(
              flex: 13,
              child: _SortableHeader(
                  label: 'Doctor',
                  keyName: 'doctor',
                  current: sortBy,
                  ascending: sortAscending,
                  onSort: onSort,
                  onDark: isFilterApplied)),
          Expanded(
              flex: 14,
              child: _SortableHeader(
                  label: 'Treatment',
                  keyName: 'treatment',
                  current: sortBy,
                  ascending: sortAscending,
                  onSort: onSort,
                  onDark: isFilterApplied)),
          Expanded(
              flex: 10,
              child: _SortableHeader(
                  label: 'Status',
                  keyName: 'status',
                  current: sortBy,
                  ascending: sortAscending,
                  onSort: onSort,
                  onDark: isFilterApplied)),
          Expanded(
              flex: 10,
              child: _SortableHeader(
                  label: 'Mode',
                  keyName: 'paymentMode',
                  current: sortBy,
                  ascending: sortAscending,
                  onSort: onSort,
                  onDark: isFilterApplied)),
          Expanded(
              flex: 12,
              child: _SortableHeader(
                  label: 'Payment',
                  keyName: 'payment',
                  current: sortBy,
                  ascending: sortAscending,
                  onSort: onSort,
                  onDark: isFilterApplied)),
          Expanded(
              flex: 14,
              child: _SortableHeader(
                  label: 'Actions',
                  keyName: 'actions',
                  current: sortBy,
                  ascending: sortAscending,
                  onSort: onSort,
                  onDark: isFilterApplied)),
        ],
      ),
    );
  }
}

class _SortableHeader extends StatelessWidget {
  final String label;
  final String keyName;
  final String current;
  final bool ascending;
  final ValueChanged<String> onSort;
  final bool onDark;

  const _SortableHeader({
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
    return GestureDetector(
      onTap: () => onSort(keyName),
      child: Row(
        children: [
          Text(label,
              style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: onDark ? Colors.white : const Color(0xFF2C4468))),
          const SizedBox(width: 4),
          Icon(
            active
                ? (ascending
                    ? FluentIcons.chevron_up
                    : FluentIcons.chevron_down)
                : FluentIcons.switch_user,
            size: 10,
            color: onDark ? Colors.white : AppColors.blue5004,
          ),
        ],
      ),
    );
  }
}

class _AppointmentRow extends StatelessWidget {
  final Appointment appointment;
  final bool isDuplicatePatient;

  const _AppointmentRow({
    required this.appointment,
    required this.isDuplicatePatient,
  });

  void _openPatientHistoryDialog(BuildContext context) {
    final patient = appointment.patient;
    if (patient == null) return;
    showPatientHistoryDialog(
      context: context,
      patient: patient,
      rows: patient.patientDetails,
      onEditTreatment: (appointmentId) async {
        final appt = appointments.present[appointmentId];
        if (appt == null || !context.mounted) return;
        await openAppointmentJourneyDialog(context, appt);
      },
    );
  }

  void _deleteAppointment(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => ContentDialog(
        title: const Text('Delete Appointment'),
        content: Text(
          'Delete appointment for ${appointment.title.trim().isEmpty ? 'this patient' : appointment.title}?',
        ),
        actions: [
          AppButton(
            label: 'Cancel',
            onPressed: () => Navigator.pop(context),
            variant: AppButtonVariant.secondary,
          ),
          AppButton(
            label: 'Delete',
            variant: AppButtonVariant.danger,
            onPressed: () {
              appointments.delete(appointment.id);
              Navigator.pop(context);
            },
          ),
        ],
      ),
    );
  }

  void _openLabworkForPatient(BuildContext context) {
    final patient = appointment.patient;
    final draft = Labwork.fromJson({
      'patientID': patient?.id,
      'operatorsIDs': appointment.operatorsIDs,
      'date':
          (appointment.date.millisecondsSinceEpoch / (60 * 60 * 1000)).round(),
      'typeOfWork': appointment.selectedTreatments.isEmpty
          ? ''
          : appointment.selectedTreatments.first,
      'selectedTeeth': appointment.selectedTeeth,
    });
    openLabworkDialog(context, draft);
  }

  Future<void> _openEditTreatmentModal(BuildContext context) async {
    await CheckinStageModalRouter.openForStage(
      context: context,
      appointment: appointment,
      openTreatmentModal: openAppointmentJourneyDialog,
      openBillingModal: openAppointmentJourneyDialog,
      openCompleteModal: openAppointmentJourneyDialog,
    );
  }

  Future<void> _openPatientEditor(BuildContext context) async {
    final patient = appointment.patient;
    if (patient == null) return;
    await openAddPatientPopup(
      context: context,
      existingPatient: patient,
    );
  }

  @override
  Widget build(BuildContext context) {
    final doctorName = appointment.operators.isEmpty
        ? 'Unassigned'
        : appointment.operators.map((d) => d.title).join(', ');
    final treatment = appointment.selectedTreatments.isEmpty
        ? '-'
        : appointment.selectedTreatments.join(', ');
    final time = formatClinicDateTime(appointment.date, pattern: 'h:mm a');
    final payment = appointment.paid + appointment.prescriptionPaid;
    final isDigital =
        appointment.treatmentGpayPaid || appointment.prescriptionGpayPaid;
    final patientPhone = appointment.patient?.phone ?? '-';
    final patientAge = appointment.patient?.age ?? 0;
    final previousVisit = _previousVisitForPatient(appointment);
    final previousVisitText = previousVisit == null
        ? 'Prev: -'
        : 'Prev: ${formatClinicDate(previousVisit, pattern: 'dd MMM yyyy')}';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color:
            isDuplicatePatient ? const Color(0xFFFFF1F1) : Colors.transparent,
        border: const Border(top: BorderSide(color: Color(0xFFE2ECF8))),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 11,
            child: Text(time, style: const TextStyle(color: Color(0xFF355279))),
          ),
          Expanded(
            flex: 15,
            child: GestureDetector(
              onTap: () => _openPatientEditor(context),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _toTitleCase(appointment.title),
                    style: const TextStyle(
                      color: AppColors.textActive,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    '$patientPhone • ${patientAge}y',
                    style: const TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 11,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    previousVisitText,
                    style: const TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 11,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            flex: 13,
            child: Text(_toTitleCase(doctorName),
                style: const TextStyle(color: AppColors.textSecondary)),
          ),
          Expanded(
            flex: 14,
            child: Text(
              treatment,
              style: const TextStyle(color: AppColors.textSecondary),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Expanded(
            flex: 10,
            child: _StatusBadge(
              done: appointment.isDone,
              stage: appointment.checkinStage,
            ),
          ),
          Expanded(
            flex: 10,
            child: Row(
              children: [
                isDigital
                    ? Image.asset(
                        'assets/gpay.png',
                        width: 16,
                        height: 16,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const Icon(
                          FluentIcons.receipt_processing,
                          size: 14,
                          color: AppColors.brandBlue,
                        ),
                      )
                    : const Icon(
                        FluentIcons.money,
                        size: 14,
                        color: Color(0xFF3B9A42),
                      ),
                const SizedBox(width: 4),
                Text(
                  isDigital ? 'UPI' : 'Cash',
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            flex: 12,
            child: Text(
              '₹${payment.toStringAsFixed(0)}',
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            flex: 14,
            child: Row(
              children: [
                _ActionIconButton(
                  tooltip: 'Edit Treatment',
                  icon: FluentIcons.edit,
                  color: const Color(0xFF8267D6),
                  hoverColor: const Color(0xFFF1EDFB),
                  onTap: () => _openEditTreatmentModal(context),
                ),
                const SizedBox(width: 6),
                _ActionIconButton(
                  tooltip: 'History',
                  icon: FluentIcons.history,
                  color: AppColors.brandBlue,
                  hoverColor: const Color(0xFFE7F1FF),
                  onTap: () => _openPatientHistoryDialog(context),
                ),
                const SizedBox(width: 6),
                _ActionIconButton(
                  tooltip: 'Add Labwork',
                  icon: FluentIcons.test_beaker,
                  color: AppColors.successTeal,
                  hoverColor: const Color(0xFFEAF8F1),
                  onTap: () => _openLabworkForPatient(context),
                ),
                const SizedBox(width: 6),
                _ActionIconButton(
                  tooltip: 'Delete',
                  icon: FluentIcons.delete,
                  color: AppColors.dangerRose,
                  hoverColor: const Color(0xFFFFECEF),
                  onTap: () => _deleteAppointment(context),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

DateTime? _previousVisitForPatient(Appointment current) {
  final patientId = current.patientID;
  if (patientId == null || patientId.isEmpty) return null;

  DateTime? previous;
  for (final row in appointments.present.values) {
    if (row.id == current.id) continue;
    if (row.patientID != patientId) continue;
    if (!row.date.isBefore(current.date)) continue;
    if (previous == null || row.date.isAfter(previous)) {
      previous = row.date;
    }
  }

  return previous;
}

class _ActionIconButton extends StatefulWidget {
  final String tooltip;
  final IconData icon;
  final Color color;
  final Color hoverColor;
  final VoidCallback onTap;

  const _ActionIconButton({
    required this.tooltip,
    required this.icon,
    required this.color,
    required this.hoverColor,
    required this.onTap,
  });

  @override
  State<_ActionIconButton> createState() => _ActionIconButtonState();
}

class _ActionIconButtonState extends State<_ActionIconButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: widget.tooltip,
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: _hovered ? widget.hoverColor : Colors.transparent,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(
              widget.icon,
              size: 16,
              color: widget.color,
            ),
          ),
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final bool done;
  final String? stage;

  const _StatusBadge({required this.done, this.stage});

  @override
  Widget build(BuildContext context) {
    String label;
    Color fg;
    Color bg;
    if (done) {
      label = 'Completed';
      fg = const Color(0xFF166534);
      bg = const Color(0xFFE8F7EE);
    } else {
      final normalized = (stage ?? '').trim().toLowerCase();
      if (normalized == 'billing' || normalized == 'checkout') {
        label = 'Billing';
        fg = const Color(0xFF5B2FA8);
        bg = const Color(0xFFF1EBFF);
      } else if (normalized == 'scheduled' || normalized == 'pending') {
        label = 'Scheduled';
        fg = AppColors.scheduledChipFg;
        bg = AppColors.scheduledChipBg;
      } else if (normalized == 'treatment' || normalized == 'with_doctor') {
        label = 'Treatment';
        fg = const Color(0xFF1E40AF);
        bg = const Color(0xFFEAF0FF);
      } else if (normalized == 'cancelled') {
        label = 'Cancelled';
        fg = const Color(0xFFDC2626);
        bg = const Color(0xFFFFF1F2);
      } else {
        label = 'Waiting';
        fg = const Color(0xFF8A5A00);
        bg = const Color(0xFFFFF4D9);
      }
    }

    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: fg,
            fontWeight: FontWeight.w700,
          ),
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

class _SectionTitle extends StatelessWidget {
  final String text;

  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 28,
        fontWeight: FontWeight.w600,
        color: Color(0xFF112E54),
        letterSpacing: 0.1,
      ),
    );
  }
}

class _OverviewHeader extends StatelessWidget {
  final DateTime selectedDate;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final VoidCallback onPick;
  final VoidCallback onToday;

  const _OverviewHeader({
    required this.selectedDate,
    required this.onPrevious,
    required this.onNext,
    required this.onPick,
    required this.onToday,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Align(
            alignment: Alignment.centerLeft,
            child: AppScreenTitle(title: 'Today\'s Overview'),
          ),
        ),
        Expanded(
          child: Align(
            alignment: Alignment.center,
            child: _DateNavigator(
              selectedDate: selectedDate,
              onPrevious: onPrevious,
              onNext: onNext,
              onPick: onPick,
              onToday: onToday,
            ),
          ),
        ),
        const Expanded(child: SizedBox()),
      ],
    );
  }
}

class _DateNavigator extends StatelessWidget {
  final DateTime selectedDate;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final VoidCallback onPick;
  final VoidCallback onToday;
  final bool showBorder;

  const _DateNavigator({
    required this.selectedDate,
    required this.onPrevious,
    required this.onNext,
    required this.onPick,
    required this.onToday,
    this.showBorder = true,
  });

  @override
  Widget build(BuildContext context) {
    return DateNavigatorBar(
      selectedDate: selectedDate,
      onPrevious: onPrevious,
      onNext: onNext,
      onPick: onPick,
      onToday: onToday,
      showBorder: showBorder,
    );
  }
}

String _duplicatePatientKey(Appointment appointment) {
  final patientId = appointment.patientID;
  if (patientId != null && patientId.isNotEmpty) {
    return 'id:$patientId';
  }
  final title = appointment.title.trim().toLowerCase();
  final phone = (appointment.patient?.phone ?? '').trim().toLowerCase();
  return 'name:$title|phone:$phone';
}

Set<String> _duplicatePatientKeys(List<Appointment> appointmentsForView) {
  final counts = <String, int>{};
  for (final appointment in appointmentsForView) {
    final key = _duplicatePatientKey(appointment);
    counts[key] = (counts[key] ?? 0) + 1;
  }
  return counts.entries
      .where((entry) => entry.value > 1)
      .map((entry) => entry.key)
      .toSet();
}

class _InsightLine extends StatelessWidget {
  final String label;
  final String value;

  const _InsightLine({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                  color: Color(0xFF36557C), fontWeight: FontWeight.w600),
            ),
          ),
          Text(
            value,
            style: const TextStyle(
                color: Color(0xFF1A3D69), fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class _AppointmentsTodayCard extends StatelessWidget {
  final int totalAppointments;
  final int newPatients;
  final int returningPatients;
  final VoidCallback? onTap;

  const _AppointmentsTodayCard({
    required this.totalAppointments,
    required this.newPatients,
    required this.returningPatients,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    Widget summaryBlock(String label, int value, Color fg, Color bg) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                color: fg,
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              '$value',
              style: TextStyle(
                color: fg,
                fontWeight: FontWeight.w800,
                fontSize: 16,
              ),
            ),
          ],
        ),
      );
    }

    return GestureDetector(
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 180, maxWidth: 220),
        child: SizedBox(
          height: 168,
          child: _CardShell(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Appointments Today',
                  style: TextStyle(
                    fontSize: 13,
                    color: Color(0xFF496489),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '$totalAppointments',
                  style: const TextStyle(
                    fontSize: 30,
                    color: Color(0xFF1B3557),
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const Spacer(flex: 1),
                Row(
                  children: [
                    Expanded(
                      child: summaryBlock(
                        'New',
                        newPatients,
                        const Color(0xFF214F86),
                        const Color(0xFFE6F0FD),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: summaryBlock(
                        'Returning',
                        returningPatients,
                        const Color(0xFF166534),
                        const Color(0xFFE8F7EE),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TopDailyTreatmentCard extends StatelessWidget {
  final List<MapEntry<String, int>> rows;

  const _TopDailyTreatmentCard({required this.rows});

  @override
  Widget build(BuildContext context) {
    final palette = [
      AppColors.brandBlue,
      AppColors.successTeal,
      const Color(0xFFE09C31),
      const Color(0xFF7D8FA7),
      AppColors.dangerRose,
      const Color(0xFF8D5CF6),
    ];
    final topRows = rows.take(10).toList(growable: false);

    Widget chip(String label, int value, Color fg, Color bg) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          '${_toTitleCase(label)} $value',
          style: TextStyle(
            color: fg,
            fontWeight: FontWeight.w700,
            fontSize: 10,
          ),
        ),
      );
    }

    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 180, maxWidth: 220),
      child: SizedBox(
        height: 168,
        child: _CardShell(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Daily Treatment',
                style: TextStyle(
                  fontSize: 14,
                  color: Color(0xFF496489),
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              if (topRows.isEmpty)
                const Text(
                  'No treatments today',
                  style: TextStyle(color: AppColors.blue5004, fontSize: 12),
                )
              else
                Expanded(
                  child: Align(
                    alignment: Alignment.topLeft,
                    child: Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: topRows.asMap().entries.map((entry) {
                        final color = palette[entry.key % palette.length];
                        return chip(
                          entry.value.key,
                          entry.value.value,
                          color,
                          color.withValues(alpha: 0.14),
                        );
                      }).toList(growable: false),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TopCurrentMonthRevenueCard extends StatelessWidget {
  final String monthLabel;
  final double value;

  const _TopCurrentMonthRevenueCard({
    required this.monthLabel,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 220, maxWidth: 300),
      child: SizedBox(
        height: 140,
        child: _CardShell(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$monthLabel Daily Avg Revenue',
                style: const TextStyle(
                  fontSize: 13,
                  color: Color(0xFF496489),
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '₹${value.toStringAsFixed(0)}',
                style: const TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1468CC),
                ),
              ),
              const Spacer(),
              const Text(
                'Fixed to current month progression',
                style: TextStyle(
                  color: AppColors.blue5004,
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

class _TopCurrentMonthAppointmentsCard extends StatelessWidget {
  final String monthLabel;
  final double avgPerDay;
  final int total;

  const _TopCurrentMonthAppointmentsCard({
    required this.monthLabel,
    required this.avgPerDay,
    required this.total,
  });

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 220, maxWidth: 300),
      child: SizedBox(
        height: 140,
        child: _CardShell(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$monthLabel Appointment Trend',
                style: const TextStyle(
                  fontSize: 13,
                  color: Color(0xFF496489),
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '${avgPerDay.toStringAsFixed(1)}/day',
                style: const TextStyle(
                  fontSize: 33,
                  fontWeight: FontWeight.w700,
                  color: AppColors.successTeal,
                ),
              ),
              const Spacer(),
              Text(
                '$total total appointments this month',
                style: const TextStyle(
                  color: AppColors.blue5004,
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

class _TopMonthRevenueCard extends StatelessWidget {
  final double thisMonthRevenue;
  final double lastMonthRevenue;
  final double twoMonthsAgoRevenue;
  final double threeMonthsAgoRevenue;
  final double changePct;
  final String thisMonthLabel;
  final String lastMonthLabel;
  final String twoMonthsAgoLabel;
  final String threeMonthsAgoLabel;

  const _TopMonthRevenueCard({
    required this.thisMonthRevenue,
    required this.lastMonthRevenue,
    required this.twoMonthsAgoRevenue,
    required this.threeMonthsAgoRevenue,
    required this.changePct,
    required this.thisMonthLabel,
    required this.lastMonthLabel,
    required this.twoMonthsAgoLabel,
    required this.threeMonthsAgoLabel,
  });

  @override
  Widget build(BuildContext context) {
    final up = changePct >= 0;
    final color = up ? AppColors.successTeal : AppColors.dangerRose;
    final maxBar = math.max(
      1.0,
      math.max(
        math.max(thisMonthRevenue, lastMonthRevenue),
        math.max(twoMonthsAgoRevenue, threeMonthsAgoRevenue),
      ),
    );

    Widget barLine(String label, double value, Color barColor) {
      return Tooltip(
        message: '$label: ₹${value.toStringAsFixed(0)}',
        child: Row(
          children: [
            SizedBox(
              width: 64,
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 11,
                  color: Color(0xFF456284),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: Container(
                  height: 8,
                  color: AppColors.violet1005,
                  child: FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: (value / maxBar).clamp(0.0, 1.0),
                    child: Container(color: barColor),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 6),
            SizedBox(
              width: 54,
              child: Text(
                formatIndianShortCurrency(value),
                textAlign: TextAlign.right,
                style: const TextStyle(
                  fontSize: 10,
                  color: Color(0xFF456284),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 220, maxWidth: 320),
      child: SizedBox(
        height: 140,
        child: _CardShell(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '$thisMonthLabel Revenue',
                      style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFF496489),
                          fontWeight: FontWeight.w600),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    formatIndianShortCurrency(thisMonthRevenue),
                    style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1468CC)),
                  ),
                  const SizedBox(width: 6),
                  Icon(
                      up
                          ? material.Icons.trending_up
                          : material.Icons.trending_down,
                      size: 11,
                      color: color),
                  const SizedBox(width: 4),
                  Text(
                    '${changePct.toStringAsFixed(1)}%',
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: color),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              barLine(thisMonthLabel, thisMonthRevenue, AppColors.brandBlue),
              const SizedBox(height: 4),
              barLine(
                  lastMonthLabel, lastMonthRevenue, const Color(0xFF9BB9DD)),
              const SizedBox(height: 4),
              barLine(twoMonthsAgoLabel, twoMonthsAgoRevenue,
                  const Color(0xFFC6D8EE)),
              const SizedBox(height: 4),
              barLine(threeMonthsAgoLabel, threeMonthsAgoRevenue,
                  const Color(0xFFDCE8F6)),
            ],
          ),
        ),
      ),
    );
  }
}

class _TopMonthlyRevenueBarsCard extends StatelessWidget {
  final List<({String month, double value})> rows;

  const _TopMonthlyRevenueBarsCard({required this.rows});

  @override
  Widget build(BuildContext context) {
    final maxValue = rows.fold<double>(1, (m, e) => e.value > m ? e.value : m);
    final latest = rows.isEmpty ? 0.0 : rows.last.value;

    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 240, maxWidth: 360),
      child: SizedBox(
        height: 160,
        child: _CardShell(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Monthly Revenue Snapshot',
                      style: TextStyle(
                        fontSize: 13,
                        color: Color(0xFF496489),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Text(
                    formatIndianShortCurrency(latest),
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF1468CC),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    for (final item in rows)
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 1.5),
                          child: Tooltip(
                            message:
                                '${item.month}: ${formatIndianShortCurrency(item.value)}',
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                Expanded(
                                  child: Align(
                                    alignment: Alignment.bottomCenter,
                                    child: FractionallySizedBox(
                                      heightFactor: (item.value / maxValue)
                                          .clamp(0.0, 1.0),
                                      child: Container(
                                        decoration: BoxDecoration(
                                          borderRadius:
                                              const BorderRadius.vertical(
                                                  top: Radius.circular(4)),
                                          color: item.value == latest
                                              ? AppColors.brandBlue
                                              : const Color(0xFFB8CCE6),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  item.month,
                                  style: const TextStyle(
                                    fontSize: 9,
                                    color: AppColors.blue5004,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DailyRevenueChartCard extends StatelessWidget {
  final List<({DateTime day, double value})> rows;

  const _DailyRevenueChartCard({required this.rows});

  @override
  Widget build(BuildContext context) {
    final peak = rows.fold<double>(1, (m, e) => e.value > m ? e.value : m);
    const tickCount = 7;
    final yTicks = List<double>.generate(
      tickCount,
      (index) => peak * ((tickCount - 1 - index) / (tickCount - 1)),
      growable: false,
    );
    final startLabel = rows.isEmpty
        ? '-'
        : formatClinicDate(rows.first.day, pattern: 'dd MMM');
    final endLabel =
        rows.isEmpty ? '-' : formatClinicDate(rows.last.day, pattern: 'dd MMM');

    return _CardShell(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Daily Revenue (Last 30 Days)',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.blue7502,
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 190,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  width: 48,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: yTicks
                        .map(
                          (tick) => Text(
                            formatIndianShortCurrency(tick),
                            style: const TextStyle(
                              fontSize: 9,
                              color: AppColors.textBlueMuted,
                            ),
                          ),
                        )
                        .toList(growable: false),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Column(
                    children: [
                      Expanded(
                        child: Stack(
                          children: [
                            Column(
                              children: List.generate(
                                tickCount,
                                (index) => Expanded(
                                  child: Container(
                                    decoration: const BoxDecoration(
                                      border: Border(
                                        bottom: BorderSide(
                                          color: Color(0xFFE5EFFA),
                                          width: 1,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: rows.map((row) {
                                return Expanded(
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 1),
                                    child: Tooltip(
                                      message:
                                          'Revenue\n${formatClinicDate(row.day, pattern: 'dd MMM')}\n₹${row.value.toStringAsFixed(0)}',
                                      child: Container(
                                        height: 140 *
                                            (row.value / peak).clamp(0.0, 1.0),
                                        decoration: BoxDecoration(
                                          gradient: const LinearGradient(
                                            colors: [
                                              Color(0xFF66A8F0),
                                              AppColors.brandBlue,
                                            ],
                                            begin: Alignment.topCenter,
                                            end: Alignment.bottomCenter,
                                          ),
                                          borderRadius:
                                              BorderRadius.circular(2),
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              }).toList(growable: false),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            startLabel,
                            style: const TextStyle(
                              fontSize: 10,
                              color: AppColors.textBlueMuted,
                            ),
                          ),
                          const Text(
                            'Date',
                            style: TextStyle(
                              fontSize: 10,
                              color: AppColors.textBlueMuted,
                            ),
                          ),
                          Text(
                            endLabel,
                            style: const TextStyle(
                              fontSize: 10,
                              color: AppColors.textBlueMuted,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 2),
          const Text(
            'Last 30 days overview. Hover bars for exact values.',
            style: TextStyle(
              fontSize: 9,
              color: Color(0xFF8AA0BC),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _AppointmentTrendChartCard extends StatelessWidget {
  final List<({DateTime day, int count})> rows;

  const _AppointmentTrendChartCard({required this.rows});

  @override
  Widget build(BuildContext context) {
    final peak = rows.fold<int>(1, (m, e) => e.count > m ? e.count : m);
    const tickCount = 7;
    final yTicks = List<int>.generate(
      tickCount,
      (index) => ((peak * ((tickCount - 1 - index) / (tickCount - 1))).round()),
      growable: false,
    );
    final startLabel = rows.isEmpty
        ? '-'
        : formatClinicDate(rows.first.day, pattern: 'dd MMM');
    final endLabel =
        rows.isEmpty ? '-' : formatClinicDate(rows.last.day, pattern: 'dd MMM');

    return _CardShell(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Appointment Trend',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.blue7502,
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 190,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  width: 38,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: yTicks
                        .map(
                          (tick) => Text(
                            '$tick',
                            style: const TextStyle(
                              fontSize: 9,
                              color: AppColors.textBlueMuted,
                            ),
                          ),
                        )
                        .toList(growable: false),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Column(
                    children: [
                      Expanded(
                        child: Stack(
                          children: [
                            Column(
                              children: List.generate(
                                tickCount,
                                (index) => Expanded(
                                  child: Container(
                                    decoration: const BoxDecoration(
                                      border: Border(
                                        bottom: BorderSide(
                                          color: Color(0xFFE5EFFA),
                                          width: 1,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: rows.map((row) {
                                return Expanded(
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 1),
                                    child: Tooltip(
                                      message:
                                          'Appointments\n${formatClinicDate(row.day, pattern: 'dd MMM')}\n${row.count}',
                                      child: Container(
                                        height: 140 *
                                            (row.count / peak).clamp(0.0, 1.0),
                                        decoration: BoxDecoration(
                                          gradient: const LinearGradient(
                                            colors: [
                                              Color(0xFF6ED1B3),
                                              AppColors.successTeal,
                                            ],
                                            begin: Alignment.topCenter,
                                            end: Alignment.bottomCenter,
                                          ),
                                          borderRadius:
                                              BorderRadius.circular(2),
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              }).toList(growable: false),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            startLabel,
                            style: const TextStyle(
                              fontSize: 10,
                              color: AppColors.textBlueMuted,
                            ),
                          ),
                          const Text(
                            'Date',
                            style: TextStyle(
                              fontSize: 10,
                              color: AppColors.textBlueMuted,
                            ),
                          ),
                          Text(
                            endLabel,
                            style: const TextStyle(
                              fontSize: 10,
                              color: AppColors.textBlueMuted,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 2),
          const Text(
            'Trend reflects appointment count by day (30-day window).',
            style: TextStyle(
              fontSize: 9,
              color: Color(0xFF8AA0BC),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _RevenueCard extends StatelessWidget {
  final String title;
  final String value;
  final double revenueTotal;
  final double doctorFee;
  final double netProfit;

  const _RevenueCard({
    required this.title,
    required this.value,
    required this.revenueTotal,
    required this.doctorFee,
    required this.netProfit,
  });

  @override
  Widget build(BuildContext context) {
    final profitPct =
        revenueTotal <= 0 ? 0.0 : ((netProfit / revenueTotal) * 100);
    final doctorFeePct =
        revenueTotal <= 0 ? 0.0 : ((doctorFee / revenueTotal) * 100);
    final profitColor =
        netProfit >= 0 ? const Color(0xFF1F8D5A) : AppColors.dangerRose;

    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 180, maxWidth: 220),
      child: SizedBox(
        height: 168,
        child: _CardShell(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF496489),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.violet1005,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: const Text(
                      'Today',
                      style: TextStyle(
                        fontSize: 10,
                        color: Color(0xFF214F86),
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
              const Expanded(child: SizedBox()),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 30,
                  color: Color(0xFF1468CC),
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _metricTile(
                      label: 'Fee (${doctorFeePct.toStringAsFixed(1)}%)',
                      metricValue: formatIndianShortCurrency(doctorFee),
                      fg: const Color(0xFF8B1D3B),
                      bg: const Color(0xFFFFEAF0),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: _metricTile(
                      label: 'Profit (${profitPct.toStringAsFixed(1)}%)',
                      metricValue: formatIndianShortCurrency(netProfit),
                      fg: profitColor,
                      bg: netProfit >= 0
                          ? const Color(0xFFE7F8EF)
                          : const Color(0xFFFFEEF0),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _metricTile({
    required String label,
    required String metricValue,
    required Color fg,
    required Color bg,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(9),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: fg,
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            metricValue,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: fg,
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusSummaryCard extends StatelessWidget {
  final int waiting;
  final int scheduled;
  final int treatment;
  final int billing;
  final int completed;

  const _StatusSummaryCard({
    required this.waiting,
    required this.scheduled,
    required this.treatment,
    required this.billing,
    required this.completed,
  });

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 180, maxWidth: 220),
      child: SizedBox(
        height: 168,
        child: _CardShell(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Status Today',
                style: TextStyle(
                  fontSize: 13,
                  color: Color(0xFF496489),
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: Align(
                  alignment: Alignment.topLeft,
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 12,
                    children: [
                      _statusChip('Waiting $waiting', const Color(0xFF8A5A00),
                          const Color(0xFFFFF4D9)),
                      _statusChip(
                        'Scheduled $scheduled',
                        AppColors.scheduledChipFg,
                        AppColors.scheduledChipBg,
                      ),
                      _statusChip('Treatment $treatment',
                          const Color(0xFF1E40AF), const Color(0xFFEAF0FF)),
                      _statusChip('Billing $billing', const Color(0xFF5B2FA8),
                          const Color(0xFFF1EBFF)),
                      _statusChip(
                        'Completed $completed',
                        const Color(0xFF166534),
                        const Color(0xFFE8F7EE),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _statusChip(String label, Color fg, Color bg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: fg,
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
      ),
    );
  }
}

class _SessionRevenueCard extends StatelessWidget {
  final String title;
  final String range;
  final double total;
  final double cash;
  final double upi;
  final int patientCount;
  final Color borderColor;
  final Color background;
  final Color iconColor;

  const _SessionRevenueCard({
    required this.title,
    required this.range,
    required this.total,
    required this.cash,
    required this.upi,
    required this.patientCount,
    required this.borderColor,
    required this.background,
    required this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    final isMorning = title == 'Morning';
    const cashBg = Color(0xFFFFF1E5);
    const cashFg = Color(0xFF9B4C00);
    const upiBg = Color(0xFFEEF0FF);
    const upiFg = Color(0xFF344FA7);

    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 180, maxWidth: 220),
      child: SizedBox(
        height: 168,
        child: _CardShell(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: background,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: borderColor),
                    ),
                    child: Icon(
                      title == 'Morning'
                          ? material.Icons.wb_sunny
                          : material.Icons.nightlight_round,
                      size: 14,
                      color: iconColor,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(
                        fontSize: 18,
                        color: Color(0xFF111827),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE6F0FD),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      '$patientCount',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF214F86),
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
              Text(
                range,
                style: const TextStyle(
                  fontSize: 11,
                  color: Color(0xFF1F2937),
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                _DashboardScreenState._money(total),
                style: const TextStyle(
                  fontSize: 30,
                  color: Color(0xFF1468CC),
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Expanded(
                    child: _paymentBlock(
                      label: 'Cash',
                      amount: _DashboardScreenState._money(cash),
                      fg: cashFg,
                      bg: cashBg,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: _paymentBlock(
                      label: 'UPI',
                      amount: _DashboardScreenState._money(upi),
                      fg: upiFg,
                      bg: upiBg,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _paymentBlock({
    required String label,
    required String amount,
    required Color fg,
    required Color bg,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: fg,
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 2),
          SizedBox(
            width: double.infinity,
            child: FittedBox(
              alignment: Alignment.centerLeft,
              fit: BoxFit.scaleDown,
              child: Text(
                amount,
                style: TextStyle(
                  color: fg,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterChipTag extends StatelessWidget {
  final String label;
  final VoidCallback onRemove;

  const _FilterChipTag({required this.label, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.violet1005,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFD0E2F7)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            FluentIcons.filter,
            size: 11,
            color: Color(0xFF1F4E85),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1F4E85),
            ),
          ),
          const SizedBox(width: 6),
          GestureDetector(
            onTap: onRemove,
            child: const Icon(
              FluentIcons.chrome_close,
              size: 10,
              color: AppColors.brandBlue,
            ),
          ),
        ],
      ),
    );
  }
}

class _FinanceCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color iconColor;
  final Color iconBackground;
  final Color valueColor;
  final VoidCallback? onTap;

  const _FinanceCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.iconColor,
    required this.iconBackground,
    required this.valueColor,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: _CardShell(
        child: Row(
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: iconBackground,
                borderRadius: BorderRadius.circular(7),
              ),
              child: Icon(icon, size: 15, color: iconColor),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF2E4E76),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Text(
              value,
              style: TextStyle(
                fontSize: 30,
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

class _DashboardLoadingOverlay extends StatelessWidget {
  const _DashboardLoadingOverlay();

  Widget _skeletonCard({double height = 168}) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFD7E3F0)),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 120,
            height: 12,
            decoration: BoxDecoration(
              color: AppColors.slate100,
              borderRadius: BorderRadius.circular(6),
            ),
          ),
          const SizedBox(height: 12),
          ...List.generate(
            5,
            (_) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Container(
                width: double.infinity,
                height: 10,
                decoration: BoxDecoration(
                  color: AppColors.slate1004,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            growable: false,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppTheme.light.scaffoldBackgroundColor,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              height: 38,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFD7E3F0)),
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                SizedBox(width: 220, child: _skeletonCard()),
                SizedBox(width: 220, child: _skeletonCard()),
                SizedBox(width: 220, child: _skeletonCard()),
                SizedBox(width: 220, child: _skeletonCard()),
                SizedBox(width: 220, child: _skeletonCard()),
                SizedBox(width: 220, child: _skeletonCard()),
              ],
            ),
            const SizedBox(height: 14),
            _skeletonCard(height: 420),
          ],
        ),
      ),
    );
  }
}
