part of 'checkin_screen.dart';

class _CheckoutBillingSummaryPanel extends StatelessWidget {
  final Appointment appointment;
  final bool discountEnabled;
  final double? totalPaidOverride;
  final List<String>? doctorNames;
  final List<Appointment>? scheduledAppointments;
  final String? scheduledAppointmentText;
  final List<String>? scheduledAppointmentTexts;
  final VoidCallback? onScheduleAppointment;
  final VoidCallback? onDeleteScheduledAppointment;
  final ValueChanged<Appointment>? onEditScheduledAppointment;
  final ValueChanged<Appointment>? onDeleteScheduledAppointmentForRow;
  final bool includeTodayInOutstanding;
  final bool showTreatmentAndToothSection;

  const _CheckoutBillingSummaryPanel({
    required this.appointment,
    required this.discountEnabled,
    this.totalPaidOverride,
    this.doctorNames,
    this.scheduledAppointments,
    this.scheduledAppointmentText,
    this.scheduledAppointmentTexts,
    this.onScheduleAppointment,
    this.onDeleteScheduledAppointment,
    this.onEditScheduledAppointment,
    this.onDeleteScheduledAppointmentForRow,
    this.includeTodayInOutstanding = true,
    this.showTreatmentAndToothSection = true,
  });

  @override
  Widget build(BuildContext context) {
    final a = appointment;
    final appointmentDate = DateTime(a.date.year, a.date.month, a.date.day);
    final patientId = (a.patientID ?? '').trim();

    double outstandingForAppointment(Appointment row) {
      final discounted = row.discountType == 'percent'
          ? (row.price - (row.price * row.discount / 100))
              .clamp(0, double.infinity)
          : (row.price - row.discount).clamp(0, double.infinity);
      return (discounted - row.paid).clamp(0, double.infinity).toDouble();
    }

    final allPatientRows = patientId.isEmpty
        ? <Appointment>[]
        : appointments.present.values
            .where((row) => row.patientID == patientId)
            .toList(growable: false);

    final outstandingRows = includeTodayInOutstanding
        ? allPatientRows
        : allPatientRows.where((row) {
            final rowDate =
                DateTime(row.date.year, row.date.month, row.date.day);
            return rowDate != appointmentDate;
          }).toList(growable: false);

    final existingOutstandingRows = allPatientRows.where((row) {
      final rowDate = DateTime(row.date.year, row.date.month, row.date.day);
      return rowDate != appointmentDate;
    }).toList(growable: false);

    final aggregatedOutstanding = outstandingRows.fold<double>(
      0,
      (sum, row) => sum + outstandingForAppointment(row),
    );
    final existingOutstanding = existingOutstandingRows.fold<double>(
      0,
      (sum, row) => sum + outstandingForAppointment(row),
    );
    final discountedTotal = a.discountType == 'percent'
        ? (a.price - (a.price * a.discount / 100)).clamp(0, double.infinity)
        : (a.price - a.discount).clamp(0, double.infinity);
    final outstanding = (discountedTotal - a.paid).clamp(0, double.infinity);
    final displayedOutstanding =
        allPatientRows.isEmpty ? outstanding : aggregatedOutstanding;
    final totalAfter =
        (totalPaidOverride ?? a.paid).clamp(0, double.infinity).toDouble();
    final treatmentCostForTotal = a.price.clamp(0, double.infinity).toDouble();
    final todayBalance = (treatmentCostForTotal - totalAfter)
        .clamp(0, double.infinity)
        .toDouble();
    final effectiveExisting =
        allPatientRows.isEmpty ? 0.0 : existingOutstanding;
    final computedTotalBalance =
        (effectiveExisting + treatmentCostForTotal - totalAfter)
            .clamp(0, double.infinity)
            .toDouble();
    final status = computedTotalBalance <= 0 ? 'PAID' : 'DUE';
    final resolvedDoctorNames = doctorNames ??
        a.operators
            .map((doctor) => doctor.title.trim())
            .where((name) => name.isNotEmpty)
            .toList(growable: false);
    final treatmentSummary = a.selectedTreatments
        .where((t) => t.trim().isNotEmpty)
        .join(', ')
        .trim();
    final toothSummary =
        a.selectedTeeth.where((t) => t.trim().isNotEmpty).join(', ').trim();

    Widget sectionCard({
      required String title,
      required List<Widget> children,
      Widget? trailing,
    }) {
      return Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FBFF),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFDCE8F8)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      color: Color(0xFF2D476D),
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                ),
                if (trailing != null) trailing,
              ],
            ),
            const SizedBox(height: 8),
            ...children,
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showTreatmentAndToothSection)
          sectionCard(
            title: 'Treatment & Tooth Info',
            children: [
              _checkoutSummaryLine(
                'Doctor',
                resolvedDoctorNames.isEmpty
                    ? '-'
                    : resolvedDoctorNames.join(', '),
              ),
              _checkoutSummaryLine(
                'Treatment',
                treatmentSummary.isEmpty ? '-' : treatmentSummary,
              ),
              _checkoutSummaryLine(
                'Tooth/Area',
                toothSummary.isEmpty ? '-' : toothSummary,
              ),
            ],
          ),
        sectionCard(
          title: 'Billing Summary',
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF1F2),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFF4C4CB)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    FluentIcons.warning,
                    size: 14,
                    color: Color(0xFFD6455D),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Previous Balance',
                          style: TextStyle(
                            color: Color(0xFFD6455D),
                            fontWeight: FontWeight.w800,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '₹${displayedOutstanding.toStringAsFixed(0)}',
                          style: const TextStyle(
                            color: Color(0xFFB42336),
                            fontWeight: FontWeight.w800,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            _checkoutSummaryLine(
                'Treatment Cost', '₹${a.price.toStringAsFixed(0)}'),
            if (discountEnabled) ...[
              _checkoutSummaryLine(
                'Discount Applied',
                a.discount <= 0
                    ? '-'
                    : a.discountType == 'percent'
                        ? '-${a.discount.toStringAsFixed(0)}%'
                        : '-₹${a.discount.toStringAsFixed(0)}',
                valueColor: const Color(0xFFD6455D),
              ),
              _checkoutSummaryLine(
                'Discounted Total',
                '₹${discountedTotal.toStringAsFixed(0)}',
                valueColor: const Color(0xFF1459AD),
              ),
            ],
            _checkoutSummaryLine(
              'Paid Today',
              '₹${totalAfter.toStringAsFixed(0)}',
            ),
            _checkoutSummaryLine(
              'Today Balance',
              '₹${todayBalance.toStringAsFixed(0)}',
              valueColor: const Color(0xFFD6455D),
            ),
            const Divider(direction: Axis.horizontal),
            const SizedBox(height: 8),
            _checkoutSummaryLine(
              'Total Balance',
              '₹${computedTotalBalance.toStringAsFixed(0)}',
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: status == 'PAID'
                    ? const Color(0xFFDCFCE7)
                    : const Color(0xFFFFF1F2),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                status,
                style: TextStyle(
                  color: status == 'PAID'
                      ? const Color(0xFF16A34A)
                      : const Color(0xFFD6455D),
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

Widget _checkoutSummaryLine(String label, String value, {Color? valueColor}) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Color(0xFF5A7397),
            fontWeight: FontWeight.w600,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            color: valueColor ?? const Color(0xFF2D476D),
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    ),
  );
}
