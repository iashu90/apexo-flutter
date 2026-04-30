part of 'checkin_screen.dart';

class _DoctorFilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _DoctorFilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return AppButton(
      label: label,
      onPressed: onTap,
      variant: selected ? AppButtonVariant.primary : AppButtonVariant.secondary,
    );
  }
}

class _WorkflowColumn extends StatelessWidget {
  final String title;
  final String stage;
  final Color color;
  final List<Appointment> rows;
  final Set<String> duplicatePatientIds;
  final bool showHistoryAction;
  final bool expanded;
  final VoidCallback onToggleExpanded;
  final ValueChanged<Appointment>? onSelect;
  final String? selectedAppointmentId;
  final bool interactionsEnabled;

  const _WorkflowColumn({
    required this.title,
    required this.stage,
    required this.color,
    required this.rows,
    required this.duplicatePatientIds,
    required this.expanded,
    required this.onToggleExpanded,
    this.showHistoryAction = false,
    this.onSelect,
    this.selectedAppointmentId,
    this.interactionsEnabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
        duration: const Duration(milliseconds: 120),
        opacity: interactionsEnabled ? 1 : 0.62,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.violet1506),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(11)),
                ),
                child: Row(
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: color,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: Icon(
                        expanded
                            ? FluentIcons.chevron_down
                            : FluentIcons.chevron_right,
                        size: 11,
                      ),
                      onPressed: interactionsEnabled ? onToggleExpanded : null,
                    ),
                  ],
                ),
              ),
              if (!expanded)
                const Padding(
                  padding: EdgeInsets.all(12),
                  child: Text(
                    'Collapsed',
                    style: TextStyle(color: AppColors.blue5004),
                  ),
                )
              else if (rows.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(12),
                  child: Text(
                    'No appointments in this state.',
                    style: TextStyle(color: AppColors.blue5004),
                  ),
                )
              else
                ...rows.map(
                  (a) => _WorkflowRow(
                    appointment: a,
                    stage: stage,
                    duplicateRecord: a.patientID != null &&
                        duplicatePatientIds.contains(a.patientID),
                    showHistoryAction: showHistoryAction,
                    selected: selectedAppointmentId == a.id,
                    interactionsEnabled: interactionsEnabled,
                    onSelect: onSelect,
                  ),
                ),
            ],
          ),
        ));
  }
}

class _WorkflowRow extends StatelessWidget {
  final Appointment appointment;
  final String stage;
  final bool duplicateRecord;
  final bool showHistoryAction;
  final bool selected;
  final bool interactionsEnabled;
  final ValueChanged<Appointment>? onSelect;

  const _WorkflowRow({
    required this.appointment,
    required this.stage,
    this.duplicateRecord = false,
    this.showHistoryAction = false,
    this.selected = false,
    this.interactionsEnabled = true,
    this.onSelect,
  });

  Future<void> _openNextAppointmentPrompt(
    BuildContext context,
    Appointment appointment,
  ) async {
    await _showNextAppointmentPromptDialog(context, appointment);
  }

  Future<void> _deleteScheduledAppointment(
    BuildContext context,
    Appointment appointment,
  ) async {
    await appointments.hardDelete(appointment.id);
  }

  Future<void> _openScheduleActions(
    BuildContext context,
    Appointment appointment,
  ) async {
    final originalDate = appointment.date;
    DateTime selectedDate = DateTime(
      originalDate.year,
      originalDate.month,
      originalDate.day,
    );
    material.TimeOfDay selectedTime = material.TimeOfDay(
      hour: originalDate.hour,
      minute: originalDate.minute,
    );
    bool confirmDelete = false;
    bool confirmCancel = false;

    final screenWidth = MediaQuery.of(context).size.width;
    // final dialogWidth = screenWidth < 760 ? screenWidth * 0.97 : 840.0;
    final dialogWidth = (screenWidth - 24).clamp(340.0, 1040.0);

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setStateDialog) {
          final updatedDateTime = DateTime(
            selectedDate.year,
            selectedDate.month,
            selectedDate.day,
            selectedTime.hour,
            selectedTime.minute,
          );
          final hasChanged = updatedDateTime != originalDate;

          return ContentDialog(
            title: Row(
              children: [
                const Expanded(child: Text('Edit Appointment')),
                IconButton(
                  icon: const Icon(FluentIcons.chrome_close, size: 11),
                  onPressed: () => Navigator.pop(dialogContext),
                ),
              ],
            ),
            content: ConstrainedBox(
              constraints: BoxConstraints(
                minWidth: screenWidth < 760 ? 360 : 600,
                maxWidth: dialogWidth,
                maxHeight: 540,
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        appointment.title.trim().isEmpty
                            ? 'Unnamed patient'
                            : _toTitleCase(appointment.title),
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          color: AppColors.blue750,
                          fontSize: 20,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          const Text(
                            'Date:',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(width: 8),
                          AppButton(
                            label: formatClinicDate(selectedDate,
                                pattern: 'dd MMM yyyy'),
                            variant: AppButtonVariant.secondary,
                            onPressed: () async {
                              final picked = await material.showDatePicker(
                                context: context,
                                initialDate: selectedDate,
                                firstDate: DateTime(2000, 1, 1),
                                lastDate: DateTime(2100, 12, 31),
                                builder: apexoDatePickerBuilder(context),
                              );
                              if (picked == null) return;
                              setStateDialog(() {
                                selectedDate = DateTime(
                                  picked.year,
                                  picked.month,
                                  picked.day,
                                );
                              });
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Text(
                            'Time:',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(width: 8),
                          AppButton(
                            label: selectedTime.format(context),
                            variant: AppButtonVariant.secondary,
                            onPressed: () async {
                              final picked = await material.showTimePicker(
                                context: context,
                                initialTime: selectedTime,
                                builder: apexoDatePickerBuilder(context),
                              );
                              if (picked == null) return;
                              setStateDialog(() {
                                selectedTime = picked;
                              });
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Text(
                        'Current: ${formatClinicDateTime(originalDate, pattern: 'dd MMM yyyy, h:mm a')}',
                        style: const TextStyle(
                          color: AppColors.textBlueMuted,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        'Updated: ${formatClinicDateTime(updatedDateTime, pattern: 'dd MMM yyyy, h:mm a')}',
                        style: TextStyle(
                          color: hasChanged
                              ? AppColors.brandBlueDark
                              : AppColors.textBlueMuted,
                          fontSize: 16,
                          fontWeight:
                              hasChanged ? FontWeight.w700 : FontWeight.w500,
                        ),
                      ),
                      if (confirmDelete) ...[
                        const SizedBox(height: 12),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppColors.slate10014,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AppColors.amber2002),
                          ),
                          child: const Text(
                            'Delete confirmation: this action is permanent and cannot be undone.',
                            style: TextStyle(
                              color: AppColors.rose750,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                      if (confirmCancel) ...[
                        const SizedBox(height: 12),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppColors.slate10014,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AppColors.amber2002),
                          ),
                          child: const Text(
                            'Cancel confirmation: this appointment will be moved to Cancelled.',
                            style: TextStyle(
                              color: AppColors.rose750,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
            actions: [
              SizedBox(
                width: dialogWidth - 48,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: AppButton(
                            label: hasChanged ? 'Update' : 'No Changes',
                            onPressed: hasChanged
                                ? () {
                                    final originalCheckedInAt =
                                        appointment.checkedInAt;
                                    appointment.date = updatedDateTime;
                                    appointment.checkedInAt =
                                        originalCheckedInAt;
                                    appointments.set(appointment);
                                    if (dialogContext.mounted) {
                                      Navigator.pop(dialogContext);
                                    }
                                  }
                                : null,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: AppButton(
                            label: confirmCancel
                                ? 'Confirm Cancel'
                                : 'Cancel Appt',
                            variant: AppButtonVariant.warning,
                            onPressed: () async {
                              if (!confirmCancel) {
                                setStateDialog(() {
                                  confirmCancel = true;
                                  confirmDelete = false;
                                });
                                return;
                              }
                              appointment.checkinStage = 'cancelled';
                              appointment.isCheckedIn = false;
                              appointments.set(appointment);
                              if (dialogContext.mounted) {
                                Navigator.pop(dialogContext);
                              }
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: AppButton(
                            label: confirmDelete ? 'Confirm Delete' : 'Delete',
                            variant: AppButtonVariant.danger,
                            onPressed: () async {
                              if (!confirmDelete) {
                                setStateDialog(() {
                                  confirmDelete = true;
                                  confirmCancel = false;
                                });
                                return;
                              }
                              await _deleteScheduledAppointment(
                                context,
                                appointment,
                              );
                              if (dialogContext.mounted) {
                                Navigator.pop(dialogContext);
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _moveStage(BuildContext context) async {
    await CheckinStageModalRouter.openForStage(
      context: context,
      appointment: appointment,
      openTreatmentModal: openAppointmentJourneyDialog,
      openBillingModal: openAppointmentJourneyDialog,
      openCompleteModal: openAppointmentJourneyDialog,
      onUpdated: () => onSelect?.call(appointment),
    );
  }

  Future<void> _undoStage(BuildContext context) async {
    final patientName = _patientDisplayName(appointment);

    if (stage == 'with_doctor') {
      final shouldMove = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => ContentDialog(
          title: Text('Move "$patientName" back to Waiting?'),
          content: Text(
            'Doctor assignment will be removed for $patientName.',
          ),
          actions: [
            AppButton(
              label: 'Cancel',
              variant: AppButtonVariant.secondary,
              onPressed: () => Navigator.pop(dialogContext, false),
            ),
            AppButton(
              label: 'Move to Waiting',
              variant: AppButtonVariant.danger,
              onPressed: () => Navigator.pop(dialogContext, true),
            ),
          ],
        ),
      );
      if (shouldMove != true) return;
      appointment.operatorsIDs = [];
      appointment.checkinStage = 'waiting';
      appointment.isDone = false;
      appointments.set(appointment);
      return;
    }

    if (stage == 'billing') {
      final shouldMove = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => ContentDialog(
          title: Text('Move "$patientName" back to Treatment?'),
          content: Text(
            'This appointment will be moved back to Treatment for $patientName.',
          ),
          actions: [
            AppButton(
              label: 'Cancel',
              variant: AppButtonVariant.secondary,
              onPressed: () => Navigator.pop(dialogContext, false),
            ),
            AppButton(
              label: 'Move to Treatment',
              variant: AppButtonVariant.danger,
              onPressed: () => Navigator.pop(dialogContext, true),
            ),
          ],
        ),
      );
      if (shouldMove != true) return;
      appointment.checkinStage = 'with_doctor';
      appointment.isDone = false;
      appointments.set(appointment);
      return;
    }

    if (stage == 'completed') {
      final shouldMove = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => ContentDialog(
          title: Text('Move "$patientName" back to Billing?'),
          content: Text(
            'This appointment will be moved back to Billing for $patientName.',
          ),
          actions: [
            AppButton(
              label: 'Cancel',
              variant: AppButtonVariant.secondary,
              onPressed: () => Navigator.pop(dialogContext, false),
            ),
            AppButton(
              label: 'Move to Billing',
              variant: AppButtonVariant.danger,
              onPressed: () => Navigator.pop(dialogContext, true),
            ),
          ],
        ),
      );
      if (shouldMove != true) return;
      appointment.checkinStage = 'billing';
      appointment.isDone = false;
      appointments.set(appointment);
      return;
    }

    if (stage == 'cancelled') {
      final shouldRestore = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => ContentDialog(
          title: Text('Restore "$patientName" to Scheduled?'),
          content: const Text(
            'This cancelled appointment will be moved back to Scheduled.',
          ),
          actions: [
            AppButton(
              label: 'Keep Cancelled',
              variant: AppButtonVariant.secondary,
              onPressed: () => Navigator.pop(dialogContext, false),
            ),
            AppButton(
              label: 'Restore',
              onPressed: () => Navigator.pop(dialogContext, true),
            ),
          ],
        ),
      );
      if (shouldRestore != true) return;
      appointment.checkinStage = 'scheduled';
      appointment.isDone = false;
      appointments.set(appointment);
    }
  }

  String _waitingLabel() {
    final started = appointment.checkedInAt;
    if (started == null) return 'Waiting';
    final elapsed = DateTime.now().difference(started);
    if (elapsed.inMinutes < 1) return 'Waiting 0m';
    if (elapsed.inHours < 1) return 'Waiting ${elapsed.inMinutes}m';
    final hours = elapsed.inHours;
    final mins = elapsed.inMinutes.remainder(60);
    return 'Waiting ${hours}h ${mins}m';
  }

  void _openPatientHistoryDialog(BuildContext context) {
    final patient = appointment.patient;
    if (patient == null) return;
    showPatientHistoryDialog(
      context: context,
      patient: patient,
      rows: patient.patientDetails,
    );
  }

  void _openLastTreatmentsDialog(BuildContext context) {
    final patient = appointment.patient;
    if (patient == null) return;
    showLastTreatmentsDialog(
      context: context,
      patient: patient,
    );
  }

  void _openLabHistoryDialog(BuildContext context) {
    final patient = appointment.patient;
    if (patient == null) return;
    showPatientHistoryDialog(
      context: context,
      patient: patient,
      rows: patient.patientDetails,
      labsOnly: true,
    );
  }

  @override
  Widget build(BuildContext context) {
    final patientName = appointment.title.trim().isEmpty
        ? 'Unnamed patient'
        : _toTitleCase(appointment.title);
    final doctorsList = appointment.operators.isEmpty
        ? const <String>['Unassigned']
        : appointment.operators.map((d) => d.title).toList(growable: false);

    final phone = appointment.patient?.phone ?? '-';
    final age = appointment.patient?.age ?? 0;
    final rawGender = appointment.patient?.gender;
    final genderLabel = rawGender == 1 ? 'M' : 'F';
    final allVisits =
        appointment.patient?.allAppointments.toList(growable: false) ??
            const <Appointment>[];
    final totalVisits = allVisits.length;
    final previousVisits = allVisits
        .where(
          (row) =>
              row.id != appointment.id && !row.date.isAfter(appointment.date),
        )
        .toList(growable: false)
      ..sort((x, y) => y.date.compareTo(x.date));
    final lastVisitLabel = previousVisits.isEmpty
        ? 'First visit'
        : formatClinicDate(previousVisits.first.date, pattern: 'dd MMM yyyy');
    final doctorLabel = doctorsList.join(', ');
    final hasLabworks = (appointment.patientID ?? '').trim().isNotEmpty &&
        labworks.present.values
            .any((labwork) => labwork.patientID == appointment.patientID);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: stage == 'completed'
            ? AppColors.checkinCompletedBg
            : Colors.transparent,
        border: const Border(
          top: BorderSide(color: AppColors.violet1002),
        ),
      ),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: !interactionsEnabled
            ? null
            : stage == 'cancelled'
                ? null
                : (stage == 'waiting' || stage == 'scheduled')
                    ? () => _moveStage(context)
                    : (onSelect == null ? null : () => onSelect!(appointment)),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        patientName,
                        style: const TextStyle(
                          color: AppColors.neutralBlack,
                          fontWeight: FontWeight.w600,
                          fontSize: 18,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Tooltip(
                        message: 'Last treatments',
                        child: IconButton(
                          icon: const Icon(
                            FluentIcons.report_document,
                            size: 14,
                            color: AppColors.violet550,
                          ),
                          onPressed: interactionsEnabled
                              ? () => _openLastTreatmentsDialog(context)
                              : null,
                        ),
                      ),
                      if (hasLabworks)
                        Tooltip(
                          message: 'Labworks history',
                          child: IconButton(
                            icon: const Icon(
                              FluentIcons.test_beaker,
                              size: 14,
                              color: AppColors.green550,
                            ),
                            onPressed: interactionsEnabled
                                ? () => _openLabHistoryDialog(context)
                                : null,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Text(
                        '$age$genderLabel · $phone',
                        style: const TextStyle(
                          color: AppColors.blue5509,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(width: 12),
                      if (stage == 'waiting') ...[
                        const SizedBox(width: 10),
                        AppBadge(
                          text: _waitingLabel(),
                          color: AppColors.warning,
                        ),
                      ],
                      if (stage == 'scheduled') ...[
                        const SizedBox(width: 10),
                        AppBadge(
                          text:
                              'Scheduled · ${formatClinicDateTime(appointment.date, pattern: 'h:mm a')}',
                          color: AppColors.scheduledChipFg,
                        ),
                      ],
                      if (duplicateRecord) ...[
                        const SizedBox(width: 10),
                        const AppBadge(
                          text: 'Duplicate',
                          type: BadgeType.error,
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Visits: $totalVisits · Last visit: $lastVisitLabel',
                    style: const TextStyle(
                      color: AppColors.textBlueMuted,
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: GestureDetector(
                      behavior: HitTestBehavior.deferToChild,
                      onTap: ((stage == 'with_doctor' ||
                                  stage == 'billing' ||
                                  stage == 'completed') &&
                              selected)
                          ? () async {
                              final pickedDoctorIds = await pickDoctorDialog(
                                context,
                                initialSelected: appointment.operatorsIDs,
                                subtitle: _patientFocusSummary(appointment),
                              );
                              if (pickedDoctorIds == null ||
                                  pickedDoctorIds.isEmpty) {
                                return;
                              }
                              appointment.operatorsIDs = pickedDoctorIds;
                              appointments.set(appointment);
                            }
                          : null,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            FluentIcons.contact,
                            size: 12,
                            color: AppColors.info,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            doctorLabel,
                            style: TextStyle(
                              color: AppColors.info,
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              decoration: ((stage == 'with_doctor' ||
                                          stage == 'billing' ||
                                          stage == 'completed') &&
                                      selected)
                                  ? TextDecoration.underline
                                  : TextDecoration.none,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (stage != 'waiting' && stage != 'scheduled')
                  Tooltip(
                    message: 'Undo',
                    child: IconButton(
                      icon: const Icon(material.Icons.undo_rounded, size: 18),
                      style: ButtonStyle(
                        padding: WidgetStateProperty.all(
                          const EdgeInsets.all(8),
                        ),
                        shape: WidgetStateProperty.all(
                          RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        backgroundColor:
                            WidgetStateProperty.all(AppColors.amber1003),
                        foregroundColor:
                            WidgetStateProperty.all(AppColors.amber500),
                      ),
                      onPressed: interactionsEnabled
                          ? () => _undoStage(context)
                          : null,
                    ),
                  ),
                if (stage != 'waiting' && stage != 'scheduled')
                  const SizedBox(width: 8),
                if (stage == 'scheduled' || stage == 'waiting')
                  Tooltip(
                    message: 'Edit or Delete Appointment',
                    child: IconButton(
                      icon: const Icon(material.Icons.edit, size: 18),
                      style: ButtonStyle(
                        padding: WidgetStateProperty.all(
                          const EdgeInsets.all(8),
                        ),
                        shape: WidgetStateProperty.all(
                          RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        foregroundColor:
                            WidgetStateProperty.all(AppColors.blue5509),
                      ),
                      onPressed: interactionsEnabled
                          ? () => _openScheduleActions(context, appointment)
                          : null,
                    ),
                  ),
                if (stage == 'scheduled' || stage == 'waiting')
                  const SizedBox(width: 8),
                if (stage == 'billing')
                  Tooltip(
                    message: 'Complete',
                    child: IconButton(
                      icon: const Icon(
                        material.Icons.task_alt_rounded,
                        size: 18,
                      ),
                      style: ButtonStyle(
                        padding: WidgetStateProperty.all(
                          const EdgeInsets.all(8),
                        ),
                        shape: WidgetStateProperty.all(
                          RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        backgroundColor: WidgetStateProperty.all(
                          AppColors.slate1003,
                        ),
                        foregroundColor: WidgetStateProperty.all(
                          AppColors.green550,
                        ),
                      ),
                      onPressed: interactionsEnabled
                          ? () => _moveStage(context)
                          : null,
                    ),
                  ),
                if (stage == 'completed')
                  Tooltip(
                    message: 'Schedule Appointment',
                    child: IconButton(
                      icon: const Icon(material.Icons.calendar_month, size: 18),
                      style: ButtonStyle(
                        padding: WidgetStateProperty.all(
                          const EdgeInsets.all(8),
                        ),
                        shape: WidgetStateProperty.all(
                          RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        backgroundColor:
                            WidgetStateProperty.all(AppColors.violet1006),
                        foregroundColor:
                            WidgetStateProperty.all(AppColors.brandBlue),
                      ),
                      onPressed: interactionsEnabled
                          ? () =>
                              _openNextAppointmentPrompt(context, appointment)
                          : null,
                    ),
                  ),
              ],
            ),
            if (showHistoryAction) ...[
              const SizedBox(width: 8),
              AppButton(
                label: 'History',
                variant: AppButtonVariant.secondary,
                onPressed: () => _openPatientHistoryDialog(context),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
