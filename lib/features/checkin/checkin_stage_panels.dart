part of 'checkin_screen.dart';

class _CheckinTreatmentStageScreen extends StatelessWidget {
  final Appointment appointment;
  final List<Appointment> allAppointmentsForPatient;
  final String forcedStage;
  final bool showInlineBottomActions;
  final bool boxed;
  final double? panelHeight;
  final VoidCallback? onDraftChanged;

  const _CheckinTreatmentStageScreen({
    required this.appointment,
    required this.allAppointmentsForPatient,
    required this.forcedStage,
    this.showInlineBottomActions = false,
    this.boxed = false,
    this.panelHeight,
    this.onDraftChanged,
  });

  @override
  Widget build(BuildContext context) {
    final content = SingleChildScrollView(
      child: _CheckinOperativeForm(
        appointment: appointment,
        allAppointmentsForPatient: allAppointmentsForPatient,
        showInlineBottomActions: showInlineBottomActions,
        forcedStage: forcedStage,
        onDraftChanged: onDraftChanged,
      ),
    );

    if (!boxed) {
      return content;
    }

    return Container(
      width: double.infinity,
      height: panelHeight,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFD7E5F6)),
      ),
      padding: const EdgeInsets.all(10),
      child: content,
    );
  }
}

class _CheckinCompletedStageScreen extends StatelessWidget {
  final Appointment appointment;
  final Appointment? lastVisit;
  final bool boxed;

  const _CheckinCompletedStageScreen({
    required this.appointment,
    required this.lastVisit,
    this.boxed = false,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
      stream: appointments.observableMap.stream,
      builder: (context, _) {
        final upcomingForPatient = appointments.present.values
            .where(
              (candidate) =>
                  (candidate.patientID ?? '').trim() ==
                      (appointment.patientID ?? '').trim() &&
                  candidate.id != appointment.id &&
                  !candidate.isCheckedIn &&
                  candidate.checkinStage == 'scheduled' &&
                  candidate.date.isAfter(DateTime.now().subtract(
                    const Duration(minutes: 1),
                  )),
            )
            .toList(growable: true)
          ..sort((a, b) => a.date.compareTo(b.date));
        final scheduledNext =
            upcomingForPatient.isNotEmpty ? upcomingForPatient.first : null;

        final content = SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _patientDisplayName(appointment),
                style: const TextStyle(
                  color: Color(0xFF163F70),
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                _patientFocusSummary(appointment),
                style: const TextStyle(
                  color: Color(0xFF4F6C90),
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              LayoutBuilder(
                builder: (context, constraints) {
                  final stacked = constraints.maxWidth < 860;
                  if (stacked) {
                    return Column(
                      children: [
                        TodayAppointmentInsightCard(appointment: appointment),
                        const SizedBox(height: 8),
                        _LastAppointmentInsightCard(lastAppointment: lastVisit),
                      ],
                    );
                  }
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: TodayAppointmentInsightCard(
                            appointment: appointment),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _LastAppointmentInsightCard(
                            lastAppointment: lastVisit),
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 12),
              _InlineNextAppointmentCard(
                appointment: appointment,
                includeCancelledSection: true,
              ),
              const SizedBox(height: 12),
              _CheckoutBillingSummaryPanel(
                appointment: appointment,
                discountEnabled: appointment.discount > 0,
                totalPaidOverride: appointment.paid,
                includeTodayInOutstanding: true,
                showTreatmentAndToothSection: true,
                onDoctorEdit: () async {
                  final picked = await pickDoctorDialog(
                    context,
                    initialSelected: appointment.operatorsIDs,
                    title: 'Assign Doctor(s)',
                  );
                  if (picked == null || !context.mounted) return;
                  appointment.operatorsIDs = picked;
                  appointments.set(appointment);
                },
                onScheduleAppointment: () {
                  _upsertScheduledFollowUpAppointment(
                    context,
                    appointment,
                    existingScheduled: scheduledNext,
                  );
                },
                onDeleteScheduledAppointment: scheduledNext == null
                    ? null
                    : () => _confirmDeleteScheduledFollowUpAppointment(
                          context,
                          scheduledNext,
                        ),
              ),
            ],
          ),
        );

        if (!boxed) {
          return content;
        }

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFD7E5F6)),
          ),
          child: content,
        );
      },
    );
  }
}
