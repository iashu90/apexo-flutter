// ignore_for_file: unused_element

import 'package:apexo/features/appointments/appointments_store.dart';
import 'package:apexo/features/appointments/appointment_model.dart';
import 'package:apexo/features/checkin/checkin_stage_modals.dart';
import 'package:apexo/features/doctors/doctors_store.dart';
import 'package:apexo/features/labwork/labworks_store.dart';
import 'package:apexo/app/routes.dart' as app_routes;
import 'package:fluent_ui/fluent_ui.dart';
import 'package:intl/intl.dart';
import 'package:flutter/cupertino.dart';

/// In-memory flag — resets every app session (not persisted).
bool dailyReminderShown = false;
bool dailyReminderEnabled = true;

void _navigateToRouteById(String identifier) {
  final route = app_routes.routes.getByIdentifier(identifier);
  if (route == null) return;
  app_routes.routes.navigate(route);
}

void showDailyReminderIfNeeded(BuildContext context) {
  if (!dailyReminderEnabled) return;
  if (dailyReminderShown) return;
  dailyReminderShown = true;
  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (!context.mounted) return;
    showDailyReminderModal(context);
  });
}

Future<void> showDailyReminderModal(BuildContext context) async {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final tomorrow = today.add(const Duration(days: 1));

  final todaysAppointments = appointments.forDate(today).toList(growable: false)
    ..sort((a, b) => a.date.compareTo(b.date));
  final tomorrowAppointments =
      appointments.forDate(tomorrow).toList(growable: false)
        ..sort((a, b) => a.date.compareTo(b.date));
  final pendingLabworks = labworks.present.values
      .where((l) => !l.deliveredToPatient)
      .toList(growable: false)
    ..sort((a, b) => a.date.compareTo(b.date));

  final upcoming = todaysAppointments
      .where((a) => !a.date.isBefore(now))
      .toList(growable: false);
  final nextPatient = upcoming.isNotEmpty
      ? upcoming.first
      : (todaysAppointments.isNotEmpty ? todaysAppointments.first : null);

  int scheduledCount = 0;
  int waitingCount = 0;
  int treatmentCount = 0;
  int completeCount = 0;
  int billingCount = 0;
  int noShowRiskCount = 0;
  int waitingOver15Count = 0;
  int missingPhoneCount = 0;
  int treatmentPlanMissingCount = 0;
  final waitingPatients = <String>[];
  final scheduledPatients = <String>[];

  for (final appointment in todaysAppointments) {
    final stage = normalizeCheckinStage(appointment.checkinStage);
    switch (stage) {
      case 'scheduled':
        scheduledCount++;
        if (appointment.title.trim().isNotEmpty) {
          scheduledPatients.add(appointment.title.trim());
        }
        break;
      case 'waiting':
        waitingCount++;
        if (appointment.title.trim().isNotEmpty) {
          waitingPatients.add(appointment.title.trim());
        }
        break;
      case 'treatment':
        treatmentCount++;
        break;
      case 'billing':
        billingCount++;
        break;
      case 'complete':
        completeCount++;
        break;
    }

    if (appointment.date.isBefore(now) &&
        !appointment.isDone &&
        stage != 'complete') {
      noShowRiskCount++;
    }

    final checkedInAt = appointment.checkedInAt;
    if (stage == 'waiting' && checkedInAt != null) {
      final waited = now.difference(checkedInAt).inMinutes;
      if (waited > 15) waitingOver15Count++;
    }

    if ((appointment.patient?.phone.trim().isEmpty ?? true)) {
      missingPhoneCount++;
    }

    if (appointment.selectedTreatments
        .where((t) => t.trim().isNotEmpty)
        .isEmpty) {
      treatmentPlanMissingCount++;
    }
  }

  final activeDoctors = <String>{
    for (final appointment in todaysAppointments) ...appointment.operatorsIDs,
  };

  final doctorCards = doctors.present.values
      .where((d) => activeDoctors.contains(d.id))
      .toList(growable: false)
    ..sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));

  final greetingStrip = () {
    if (waitingCount > 0) {
      return 'Next patient queue is active: $waitingCount waiting';
    }
    if (nextPatient == null) return 'No scheduled patients for today';
    final diff = nextPatient.date.difference(now).inMinutes;
    if (diff > 0) return 'Clinic opens in $diff minutes';
    if (diff >= -10) return 'Current slot in progress';
    return 'Next patient queue is active';
  }();

  await showDialog<void>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (context, setStateDialog) => ContentDialog(
        constraints: const BoxConstraints(maxWidth: 760, maxHeight: 980),
        title: Row(
          children: [
            const Icon(
              CupertinoIcons.bell_solid,
              color: Color(0xFF111827),
              size: 30,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    "Today's Briefing",
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 24,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    DateFormat('EEEE, d MMMM yyyy').format(now),
                    style: const TextStyle(
                      fontSize: 16,
                      color: Color(0xFF4B5563),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(FluentIcons.chrome_close, size: 12),
              onPressed: () => Navigator.pop(dialogContext),
            ),
          ],
        ),
        content: SizedBox(
          width: 700,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _InfoStrip(text: greetingStrip),
                const SizedBox(height: 4),
                _SectionTitle(
                  icon: FluentIcons.calendar,
                  title: "Today's Appointments",
                  color: const Color(0xFFE8B242),
                  trailing: _CounterPill(value: '${todaysAppointments.length}'),
                ),
                const SizedBox(height: 2),
                _AppointmentsSummaryGrid(
                  complete: completeCount,
                  treatment: treatmentCount,
                  waiting: waitingCount,
                  scheduled: scheduledCount,
                  billing: billingCount,
                  waitingPatients: waitingPatients,
                  scheduledPatients: scheduledPatients,
                  onCheckin: () {
                    _navigateToRouteById('checkin');
                    Navigator.pop(dialogContext);
                  },
                ),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 4,
                  runSpacing: 4,
                  children: [
                    SizedBox(
                      width: 340,
                      child: _DoctorsAndChairsCard(
                        doctorsList: doctorCards,
                        todaysAppointments: todaysAppointments,
                      ),
                    ),
                    SizedBox(
                      width: 340,
                      child: _LabFollowUpsCard(
                        labRows:
                            pendingLabworks.take(3).toList(growable: false),
                        totalPending: pendingLabworks.length,
                        onOpenLabOrders: () {
                          _navigateToRouteById('labworks_v2');
                          Navigator.pop(dialogContext);
                        },
                      ),
                    ),
                    SizedBox(
                      width: 340,
                      child: _TomorrowScheduleCard(
                        tomorrow: tomorrow,
                        appointments: tomorrowAppointments,
                      ),
                    ),
                    SizedBox(
                      width: 340,
                      child: _AttentionList(
                        rows: [
                          '$noShowRiskCount no-show risk patient${noShowRiskCount == 1 ? '' : 's'} (past slot, not completed)',
                          '$waitingOver15Count patient${waitingOver15Count == 1 ? '' : 's'} waiting > 15 min',
                          '$missingPhoneCount patient${missingPhoneCount == 1 ? '' : 's'} missing phone number',
                          '$treatmentPlanMissingCount patient${treatmentPlanMissingCount == 1 ? '' : 's'} without a treatment plan',
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Spacer(),
                    FilledButton(
                      style: ButtonStyle(
                        padding: WidgetStateProperty.all(
                          const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 11),
                        ),
                        backgroundColor:
                            WidgetStateProperty.all(const Color(0xFF2D7BD8)),
                      ),
                      onPressed: () {
                        _navigateToRouteById('checkin');
                        Navigator.pop(dialogContext);
                      },
                      child: const Text("Open Today's Schedule"),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

class _InfoStrip extends StatelessWidget {
  final String text;

  const _InfoStrip({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: const Color(0xFFEAF0FF),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(FluentIcons.info, size: 14, color: Color(0xFF2D7BD8)),
          const SizedBox(width: 8),
          Text(
            text,
            style: const TextStyle(
              color: Color(0xFF2D5DAB),
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final IconData icon;
  final String title;
  final Color color;
  final Widget? trailing;

  const _SectionTitle({
    required this.icon,
    required this.title,
    required this.color,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 6),
        Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 22,
            color: Color(0xFF1F2937),
          ),
        ),
        if (trailing != null) ...[
          const SizedBox(width: 6),
          trailing!,
        ],
      ],
    );
  }
}

class _CounterPill extends StatelessWidget {
  final String value;

  const _CounterPill({required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: const Color(0xFFE5EAF4),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        value,
        style: const TextStyle(
          color: Color(0xFF4B5A76),
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _NextPatientCard extends StatelessWidget {
  final Appointment? appointment;
  final DateTime now;
  final ({int complete, int treatment, int waiting, int nextHour}) stageCounts;
  final int noShowRiskCount;
  final VoidCallback onCallPatient;
  final VoidCallback onViewSchedule;

  const _NextPatientCard({
    required this.appointment,
    required this.now,
    required this.stageCounts,
    required this.noShowRiskCount,
    required this.onCallPatient,
    required this.onViewSchedule,
  });

  @override
  Widget build(BuildContext context) {
    if (appointment == null) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFFFFCF5),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFEFDEC0)),
        ),
        child: const Text(
          'No upcoming patient for today.',
          style: TextStyle(
            color: Color(0xFF6D84A8),
            fontWeight: FontWeight.w600,
          ),
        ),
      );
    }

    final patient = appointment!.patient;
    final doctorName = appointment!.operators.isNotEmpty
        ? appointment!.operators.first.title
        : 'Doctor not assigned';
    final minsToArrival = appointment!.date.difference(now).inMinutes;
    final treatment = appointment!.selectedTreatments
        .where((t) => t.trim().isNotEmpty)
        .join(', ');

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFCF5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE8D9BA)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: const BoxDecoration(
                  color: Color(0xFFE7ECF6),
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Text(
                  _initials(appointment!.title),
                  style: const TextStyle(
                    color: Color(0xFF32537F),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      appointment!.title.trim().isEmpty
                          ? 'Unnamed patient'
                          : appointment!.title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF1F2937),
                        fontSize: 34,
                      ),
                    ),
                    Text(
                      '${DateFormat('hh:mm a').format(appointment!.date)} • ${treatment.isEmpty ? 'Consultation' : treatment}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF374151),
                        fontSize: 17,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Dr. $doctorName • ${minsToArrival > 0 ? 'Arriving in $minsToArrival min' : 'In progress'}',
                      style: const TextStyle(
                        color: Color(0xFF6B7280),
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                DateFormat('hh:mm a').format(appointment!.date),
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF1F2937),
                  fontSize: 30,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _StageProgressBar(counts: stageCounts),
          const SizedBox(height: 8),
          Wrap(
            spacing: 10,
            runSpacing: 6,
            children: [
              _chip(
                  'Completed ${stageCounts.complete}', const Color(0xFF2BA58D)),
              _chip('In Treatment ${stageCounts.treatment}',
                  const Color(0xFF2D7BD8)),
              _chip('Waiting ${stageCounts.waiting}', const Color(0xFFE09C31)),
              _chip(
                  'Next Hour ${stageCounts.nextHour}', const Color(0xFF6AA7F2)),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Text(
                'No-show Risk $noShowRiskCount',
                style: const TextStyle(
                  color: Color(0xFF6B7280),
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                ),
              ),
              const Spacer(),
              Button(
                onPressed: patient?.phone.trim().isNotEmpty == true
                    ? onCallPatient
                    : null,
                child: const Text('Call Patient'),
              ),
              const SizedBox(width: 8),
              Button(
                onPressed: onViewSchedule,
                child: const Text('View Schedule'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _chip(String text, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(FluentIcons.circle_fill, size: 8, color: color),
        const SizedBox(width: 4),
        Text(
          text,
          style: const TextStyle(
            color: Color(0xFF374151),
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
        ),
      ],
    );
  }

  String _initials(String name) {
    final parts = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((e) => e.isNotEmpty)
        .toList(growable: false);
    if (parts.isEmpty) return 'P';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts[0].substring(0, 1) + parts[1].substring(0, 1)).toUpperCase();
  }
}

class _StageProgressBar extends StatelessWidget {
  final ({int complete, int treatment, int waiting, int nextHour}) counts;

  const _StageProgressBar({required this.counts});

  @override
  Widget build(BuildContext context) {
    final total =
        (counts.complete + counts.treatment + counts.waiting + counts.nextHour)
            .clamp(1, 1000000);

    Widget segment(int count, Color color) {
      return Expanded(
        flex: count == 0 ? 1 : count,
        child: Container(
          height: 6,
          decoration: BoxDecoration(
            color: count == 0 ? const Color(0xFFE5E7EB) : color,
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
    }

    return Row(
      children: [
        segment(counts.complete, const Color(0xFF2BA58D)),
        const SizedBox(width: 2),
        segment(counts.treatment, const Color(0xFF2D7BD8)),
        const SizedBox(width: 2),
        segment(counts.waiting, const Color(0xFFE09C31)),
        const SizedBox(width: 2),
        segment(total - counts.complete - counts.treatment - counts.waiting,
            const Color(0xFFD1D5DB)),
      ],
    );
  }
}

class _AppointmentsSummaryGrid extends StatelessWidget {
  final int complete;
  final int treatment;
  final int waiting;
  final int scheduled;
  final int billing;
  final List<String> waitingPatients;
  final List<String> scheduledPatients;
  final VoidCallback onCheckin;

  const _AppointmentsSummaryGrid({
    required this.complete,
    required this.treatment,
    required this.waiting,
    required this.scheduled,
    required this.billing,
    required this.waitingPatients,
    required this.scheduledPatients,
    required this.onCheckin,
  });

  @override
  Widget build(BuildContext context) {
    final queueNames = [
      ...waitingPatients,
      ...scheduledPatients,
    ];

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 3,
          child: Column(
            children: [
              _SmallInfoCard(
                title: 'Scheduled',
                value: '$scheduled',
                hint: 'today',
                color: const Color(0xFF5578A4),
                bg: const Color(0xFFF3F7FF),
              ),
              const SizedBox(height: 8),
              _SmallInfoCard(
                title: 'Waiting',
                value: '$waiting',
                hint: waiting == 1 ? 'patient' : 'patients',
                color: const Color(0xFFE09C31),
                bg: const Color(0xFFF3F7FF),
              ),
              const SizedBox(height: 8),
              _SmallInfoCard(
                title: 'Treatment',
                value: '$treatment',
                hint: 'active',
                color: const Color(0xFF2D7BD8),
                bg: const Color(0xFFF3F7FF),
              ),
              const SizedBox(height: 8),
              _SmallInfoCard(
                title: 'Billing',
                value: '$billing',
                hint: 'pending',
                color: const Color(0xFF7B61D1),
                bg: const Color(0xFFF3F7FF),
              ),
              const SizedBox(height: 8),
              _SmallInfoCard(
                title: 'Completed',
                value: '$complete',
                hint: 'done',
                color: const Color(0xFF2BA58D),
                bg: const Color(0xFFF3F7FF),
              ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          flex: 4,
          child: _SmallActionCard(
            title: 'Waiting + Scheduled Queue',
            subtitle: queueNames.isEmpty
                ? 'No waiting or scheduled patients'
                : queueNames.join('\n'),
            actionLabel: 'Check-in',
            onAction: onCheckin,
            maxSubtitleLines: 12,
          ),
        ),
      ],
    );
  }
}

class _DoctorsAndChairsCard extends StatelessWidget {
  final List<dynamic> doctorsList;
  final List<Appointment> todaysAppointments;

  const _DoctorsAndChairsCard({
    required this.doctorsList,
    required this.todaysAppointments,
  });

  @override
  Widget build(BuildContext context) {
    final rows = doctorsList.take(2).map((doctor) {
      final byDoctor = todaysAppointments
          .where((a) => a.operatorsIDs.contains(doctor.id))
          .toList(growable: false);
      final hasTreatment = byDoctor
          .any((a) => normalizeCheckinStage(a.checkinStage) == 'treatment');
      final hasWaiting = byDoctor
          .any((a) => normalizeCheckinStage(a.checkinStage) == 'waiting');
      final upcoming = byDoctor
          .where((a) => a.date.isAfter(DateTime.now()))
          .toList(growable: false)
        ..sort((a, b) => a.date.compareTo(b.date));

      String status;
      Color dot;
      if (hasTreatment) {
        status = 'In Treatment';
        dot = const Color(0xFF2D7BD8);
      } else if (hasWaiting) {
        status = 'Waiting';
        dot = const Color(0xFFE09C31);
      } else if (upcoming.isNotEmpty) {
        final mins = upcoming.first.date.difference(DateTime.now()).inMinutes;
        status = 'Free in ${mins < 0 ? 0 : mins} min';
        dot = const Color(0xFF2BA58D);
      } else {
        status = 'Free';
        dot = const Color(0xFF2BA58D);
      }

      return Row(
        children: [
          Expanded(
            child: Text(
              'Dr. ${doctor.title}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Color(0xFF1F2937),
                fontWeight: FontWeight.w700,
                fontSize: 14,
              ),
            ),
          ),
          Icon(FluentIcons.circle_fill, size: 8, color: dot),
          const SizedBox(width: 6),
          Text(
            status,
            style: const TextStyle(
              color: Color(0xFF4B5563),
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
        ],
      );
    }).toList(growable: false);

    return _SimplePanel(
      titleIcon: FluentIcons.medical,
      title: 'Doctors',
      titleColor: const Color(0xFF2D7BD8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (rows.isEmpty)
            const Text(
              'No active doctors today',
              style: TextStyle(color: Color(0xFF6B7280)),
            )
          else ...[
            ...rows,
          ],
        ],
      ),
    );
  }
}

class _LabFollowUpsCard extends StatelessWidget {
  final List<dynamic> labRows;
  final int totalPending;
  final VoidCallback onOpenLabOrders;

  const _LabFollowUpsCard({
    required this.labRows,
    required this.totalPending,
    required this.onOpenLabOrders,
  });

  @override
  Widget build(BuildContext context) {
    return _SimplePanel(
      titleIcon: FluentIcons.test_beaker,
      title: 'Lab Follow-ups',
      titleColor: const Color(0xFFC75A4A),
      child: Column(
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Showing ${labRows.length} of $totalPending pending follow-ups (ordered by oldest first)',
              style: const TextStyle(
                color: Color(0xFF6B7280),
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
          ),
          const SizedBox(height: 8),
          if (labRows.isEmpty)
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'No pending lab follow-ups.',
                style: TextStyle(color: Color(0xFF6B7280)),
              ),
            )
          else
            ...labRows.map((labwork) {
              final age = DateTime.now().difference(labwork.date).inDays;
              final patientName = (labwork.patient?.title ?? '').trim();
              return Container(
                margin: const EdgeInsets.only(bottom: 6),
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF3F3),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFF0DADA)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        patientName.isEmpty ? 'Unknown patient' : patientName,
                        style: const TextStyle(
                          color: Color(0xFF1F2937),
                          fontWeight: FontWeight.w700,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '$age day${age == 1 ? '' : 's'}',
                      style: const TextStyle(
                        color: Color(0xFF6B7280),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              );
            }),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: Button(
              onPressed: onOpenLabOrders,
              child: const Text('Open Lab Orders'),
            ),
          ),
        ],
      ),
    );
  }
}

class _TomorrowScheduleCard extends StatelessWidget {
  final DateTime tomorrow;
  final List<Appointment> appointments;

  const _TomorrowScheduleCard({
    required this.tomorrow,
    required this.appointments,
  });

  @override
  Widget build(BuildContext context) {
    final rows = appointments
        .where((a) {
          final stage = normalizeCheckinStage(a.checkinStage);
          return stage == 'scheduled' || stage == 'waiting';
        })
        .take(5)
        .toList(growable: false);

    return _SimplePanel(
      titleIcon: FluentIcons.calendar_work_week,
      title: 'Tomorrow Schedule',
      titleColor: const Color(0xFF355A84),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            DateFormat('EEEE, dd MMM yyyy').format(tomorrow),
            style: const TextStyle(
              color: Color(0xFF4B5563),
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          if (rows.isEmpty)
            const Text(
              'No scheduled appointments for tomorrow.',
              style: TextStyle(color: Color(0xFF6B7280)),
            )
          else
            ...rows.map((appointment) {
              final title = appointment.title.trim().isEmpty
                  ? 'Unnamed patient'
                  : appointment.title.trim();
              final treatment = appointment.selectedTreatments
                  .where((t) => t.trim().isNotEmpty)
                  .join(', ');
              return Container(
                margin: const EdgeInsets.only(bottom: 6),
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFFF3F7FF),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFDCE7F6)),
                ),
                child: Row(
                  children: [
                    Text(
                      DateFormat('hh:mm a').format(appointment.date),
                      style: const TextStyle(
                        color: Color(0xFF1F446E),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        treatment.isEmpty ? title : '$title • $treatment',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFF1F2937),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
          if (appointments.length > rows.length)
            Text(
              '+${appointments.length - rows.length} more tomorrow',
              style: const TextStyle(
                color: Color(0xFF5E738F),
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
        ],
      ),
    );
  }
}

class _AttentionList extends StatelessWidget {
  final List<String> rows;

  const _AttentionList({required this.rows});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: rows
            .map(
              (row) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    const Icon(FluentIcons.warning,
                        size: 12, color: Color(0xFFE8B242)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        row,
                        style: const TextStyle(
                          color: Color(0xFF374151),
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            )
            .toList(growable: false),
      ),
    );
  }
}

class _SmallInfoCard extends StatelessWidget {
  final String title;
  final String value;
  final String hint;
  final Color color;
  final Color bg;

  const _SmallInfoCard({
    required this.title,
    required this.value,
    required this.hint,
    required this.color,
    required this.bg,
  });

  @override
  Widget build(BuildContext context) {
    final showHint = hint.trim().isNotEmpty && hint.trim() != value.trim();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(FluentIcons.circle_fill, size: 10, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                color: Color(0xFF1F2937),
                fontWeight: FontWeight.w700,
                fontSize: 14,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              color: Color(0xFF1F2937),
              fontWeight: FontWeight.w700,
            ),
          ),
          if (showHint) ...[
            const SizedBox(width: 10),
            Text(
              hint,
              style: const TextStyle(
                color: Color(0xFF6B7280),
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _SmallActionCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final String actionLabel;
  final VoidCallback onAction;
  final int maxSubtitleLines;

  const _SmallActionCard({
    required this.title,
    required this.subtitle,
    required this.actionLabel,
    required this.onAction,
    this.maxSubtitleLines = 1,
  });

  @override
  Widget build(BuildContext context) {
    final rows = subtitle
        .split('\n')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList(growable: false);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFD6E2F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Color(0xFF183A67),
              fontWeight: FontWeight.w800,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 8),
          if (rows.isEmpty)
            const Text(
              'No waiting or scheduled patients',
              style: TextStyle(
                color: Color(0xFF6B7280),
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            )
          else
            ...rows.take(maxSubtitleLines).map(
                  (name) => Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(bottom: 6),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFE3ECF8)),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          FluentIcons.contact,
                          size: 12,
                          color: Color(0xFF2D7BD8),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Color(0xFF1F446E),
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: onAction,
              style: ButtonStyle(
                backgroundColor:
                    WidgetStateProperty.all(const Color(0xFF2D7BD8)),
              ),
              child: Text(actionLabel),
            ),
          ),
        ],
      ),
    );
  }
}

class _SimplePanel extends StatelessWidget {
  final IconData titleIcon;
  final String title;
  final Color titleColor;
  final Widget child;

  const _SimplePanel({
    required this.titleIcon,
    required this.title,
    required this.titleColor,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(titleIcon, size: 15, color: titleColor),
              const SizedBox(width: 6),
              Text(
                title,
                style: const TextStyle(
                  color: Color(0xFF1F2937),
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}
