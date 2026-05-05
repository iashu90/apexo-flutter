part of 'checkin_screen.dart';

class _InlineNextAppointmentCard extends StatefulWidget {
  final Appointment appointment;
  final bool includeCancelledSection;

  const _InlineNextAppointmentCard({
    required this.appointment,
    this.includeCancelledSection = false,
  });

  @override
  State<_InlineNextAppointmentCard> createState() =>
      _InlineNextAppointmentCardState();
}

class _InlineNextAppointmentCardState extends State<_InlineNextAppointmentCard> {
  StreamSubscription? _appointmentsSubscription;
  List<Appointment> _upcomingRows = const [];
  List<Appointment> _cancelledRows = const [];

  @override
  void initState() {
    super.initState();
    _recomputeRows();
    _appointmentsSubscription = appointments.observableMap.stream.listen((_) {
      if (!mounted) return;
      _recomputeRows();
    });
  }

  @override
  void didUpdateWidget(covariant _InlineNextAppointmentCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.appointment.id != widget.appointment.id ||
        oldWidget.appointment.patientID != widget.appointment.patientID ||
        oldWidget.includeCancelledSection != widget.includeCancelledSection) {
      _recomputeRows();
    }
  }

  @override
  void dispose() {
    _appointmentsSubscription?.cancel();
    super.dispose();
  }

  void _recomputeRows() {
    PerfMarkers.track(
      'checkin.recompute.nextAppointments',
      () {
        final upcomingRows = <Appointment>[];
        final cancelledRows = <Appointment>[];
        final now = DateTime.now();

        for (final row in appointments.present.values) {
          if (row.patientID != widget.appointment.patientID) continue;
          if (row.id == widget.appointment.id) continue;

          final stage = row.checkinStage;
          final isUpcoming =
              (stage == 'scheduled' || stage == 'pending') &&
                  !row.isCheckedIn &&
                  row.date.isAfter(now);
          if (isUpcoming) {
            upcomingRows.add(row);
            continue;
          }

          final isCancelled =
              widget.includeCancelledSection && stage == 'cancelled';
          if (isCancelled) {
            cancelledRows.add(row);
          }
        }

        upcomingRows.sort((a, b) => a.date.compareTo(b.date));
        cancelledRows.sort((a, b) => b.date.compareTo(a.date));

        setState(() {
          _upcomingRows = upcomingRows;
          _cancelledRows = cancelledRows;
        });
      },
      data: {
        'includeCancelled': widget.includeCancelledSection,
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final appointment = widget.appointment;
    final includeCancelledSection = widget.includeCancelledSection;
    final upcomingRows = _upcomingRows;
    final cancelledRows = _cancelledRows;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.borderBlueSoft),
      ),
      child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Next Appointment',
                style: TextStyle(
                  color: AppColors.blue7508,
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                upcomingRows.isEmpty
                    ? 'Not scheduled'
                    : '${upcomingRows.length} future appointment(s)',
                style: TextStyle(
                  color: upcomingRows.isEmpty
                      ? AppColors.textBlueMuted
                      : AppColors.brandBlueDark,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
              if (upcomingRows.isNotEmpty) ...[
                const SizedBox(height: 6),
                ...upcomingRows.map(
                  (row) => Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                formatClinicDateTime(row.date,
                                    pattern: 'dd MMM yyyy • h:mm a'),
                                style: const TextStyle(
                                  color: AppColors.blue700,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                            Tooltip(
                              message: 'Edit scheduled appointment',
                              child: IconButton(
                                icon: const Icon(FluentIcons.edit, size: 14),
                                onPressed: () =>
                                    _upsertScheduledFollowUpAppointment(
                                  context,
                                  appointment,
                                  existingScheduled: row,
                                ),
                              ),
                            ),
                            Tooltip(
                              message: 'Cancel appointment',
                              child: IconButton(
                                icon: const Icon(
                                  FluentIcons.blocked2,
                                  size: 14,
                                  color: AppColors.rose6003,
                                ),
                                onPressed: () =>
                                    _confirmCancelScheduledFollowUpAppointment(
                                  context,
                                  row,
                                ),
                              ),
                            ),
                            Tooltip(
                              message: 'Delete scheduled appointment',
                              child: IconButton(
                                icon: const Icon(
                                  FluentIcons.delete,
                                  size: 14,
                                  color: AppColors.dangerRose,
                                ),
                                onPressed: () =>
                                    _confirmDeleteScheduledFollowUpAppointment(
                                  context,
                                  row,
                                ),
                              ),
                            ),
                          ],
                        ),
                        Padding(
                          padding: const EdgeInsets.only(top: 2, left: 2),
                          child: Text(
                            row.operators.isEmpty
                                ? 'Doctor: Unassigned'
                                : 'Doctor: ${row.operators.map((d) => d.title.trim().isEmpty ? 'Unnamed doctor' : d.title.trim()).join(', ')}',
                            style: const TextStyle(
                              color: AppColors.textBlueMuted,
                              fontWeight: FontWeight.w600,
                              fontSize: 11,
                            ),
                          ),
                        ),
                         const Divider(direction: Axis.horizontal),
                      ],
                    ),
                  ),
                ),
              ],
              if (includeCancelledSection && cancelledRows.isNotEmpty) ...[
                const SizedBox(height: 10),
                const Divider(direction: Axis.horizontal),
                const SizedBox(height: 8),
                Text(
                  'Cancelled (${cancelledRows.length})',
                  style: const TextStyle(
                    color: AppColors.rose6003,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 6),
                ...cancelledRows.map(
                  (row) => Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            formatClinicDateTime(row.date,
                                pattern: 'dd MMM yyyy • h:mm a'),
                            style: const TextStyle(
                              color: AppColors.rose700,
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        Tooltip(
                          message: 'Restore to scheduled',
                          child: IconButton(
                            icon: const Icon(
                              material.Icons.undo_rounded,
                              size: 14,
                              color: AppColors.violet550,
                            ),
                            onPressed: () {
                              row.checkinStage = 'scheduled';
                              row.isDone = false;
                              appointments.set(row);
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: AppButton(
                      label: '+ Add',
                      variant: AppButtonVariant.secondary,
                      expanded: true,
                      onPressed: () => _upsertScheduledFollowUpAppointment(
                        context,
                        appointment,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
              ),
            ],
          ),
    );
  }
}
