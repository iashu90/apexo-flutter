part of 'checkin_screen.dart';

class _InlineNextAppointmentCard extends StatelessWidget {
  final Appointment appointment;
  final bool includeCancelledSection;

  const _InlineNextAppointmentCard({
    required this.appointment,
    this.includeCancelledSection = false,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
      stream: appointments.observableMap.stream,
      builder: (context, _) {
        final upcomingRows = appointments.present.values
            .where(
              (row) =>
                  row.patientID == appointment.patientID &&
                  row.id != appointment.id &&
                  (row.checkinStage == 'scheduled' ||
                      row.checkinStage == 'pending') &&
                  !row.isCheckedIn &&
                  row.date.isAfter(DateTime.now()),
            )
            .toList(growable: true)
          ..sort((a, b) => a.date.compareTo(b.date));
        final cancelledRows = appointments.present.values
            .where(
              (row) =>
                  includeCancelledSection &&
                  row.patientID == appointment.patientID &&
                  row.id != appointment.id &&
                  row.checkinStage == 'cancelled',
            )
            .toList(growable: true)
          ..sort((a, b) => b.date.compareTo(a.date));

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFD7E0EB)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Next Appointment',
                style: TextStyle(
                  color: Color(0xFF223B5E),
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
                      ? const Color(0xFF5A6B7F)
                      : const Color(0xFF1459AD),
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
              if (upcomingRows.isNotEmpty) ...[
                const SizedBox(height: 6),
                ...upcomingRows.map(
                  (row) => Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            formatClinicDateTime(row.date,
                                pattern: 'dd MMM yyyy • h:mm a'),
                            style: const TextStyle(
                              color: Color(0xFF184A9C),
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
                              color: Color(0xFFC2415B),
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
                              color: Color(0xFFD6455D),
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
                    color: Color(0xFFC2415B),
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
                              color: Color(0xFF8A5066),
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
                              color: Color(0xFF7A5AF8),
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
      },
    );
  }
}
