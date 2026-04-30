import 'package:apexo/features/appointments/appointments_store.dart';
import 'package:apexo/core/theme/app_colors.dart';
import 'package:apexo/core/ui/components/app_button.dart';
import 'package:apexo/features/patients/patient_model.dart';
import 'package:apexo/utils/clinic_time.dart';
import 'package:fluent_ui/fluent_ui.dart';

class _LastTreatmentRow {
  final DateTime date;
  final String teeth;
  final String doctor;
  final String chiefComplaint;
  final String diagnosis;
  final String treatment;

  const _LastTreatmentRow({
    required this.date,
    required this.teeth,
    required this.doctor,
    required this.chiefComplaint,
    required this.diagnosis,
    required this.treatment,
  });
}

Future<void> showLastTreatmentsDialog({
  required BuildContext context,
  required Patient patient,
  int maxRows = 8,
}) {
  final rows = patient.patientDetails
      .where((row) {
        final treatment = row.treatment.trim();
        if (treatment.isEmpty) return false;
        return !treatment.toLowerCase().startsWith('labwork:');
      })
      .map((row) {
        final appointmentId = row.appointmentId?.trim() ?? '';
        final appointment =
            appointmentId.isEmpty ? null : appointments.present[appointmentId];
        final chiefComplaint = appointment == null ||
                appointment.chiefComplaints.isEmpty
            ? '-'
            : appointment.chiefComplaints
                .map((item) => item.trim())
                .where((item) => item.isNotEmpty)
                .join(', ');
        final diagnosis = appointment == null || appointment.diagnosis.isEmpty
            ? '-'
            : appointment.diagnosis
                .map((item) => item.trim())
                .where((item) => item.isNotEmpty)
                .join(', ');
        return _LastTreatmentRow(
          date: row.date,
          teeth: row.teeth.trim().isEmpty ? '-' : row.teeth.trim(),
          doctor: row.doctorName.trim().isEmpty ? '-' : row.doctorName.trim(),
          chiefComplaint: chiefComplaint.trim().isEmpty ? '-' : chiefComplaint,
          diagnosis: diagnosis.trim().isEmpty ? '-' : diagnosis,
          treatment: row.treatment.trim().isEmpty ? '-' : row.treatment.trim(),
        );
      })
      .toList(growable: false)
    ..sort((a, b) => b.date.compareTo(a.date));

  final visible = rows.take(maxRows).toList(growable: false);

  return showDialog<void>(
    context: context,
    barrierColor: AppColors.overlay22,
    builder: (dialogContext) {
      final screen = MediaQuery.of(dialogContext).size;
      final width = (screen.width - 24).clamp(760.0, 1280.0);
      final height = (screen.height - 28).clamp(520.0, 860.0);

      return Center(
        child: Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            color: AppColors.bgCard,
            borderRadius: BorderRadius.circular(14),
            boxShadow: const [
              BoxShadow(
                color: AppColors.overlay22,
                blurRadius: 24,
                offset: Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [AppColors.brandBlue, AppColors.brandBlueDark],
                  ),
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(14),
                    topRight: Radius.circular(14),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Last Treatments',
                            style: TextStyle(
                              color: AppColors.bgCard,
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${visible.length} recent visit${visible.length == 1 ? '' : 's'}',
                            style: const TextStyle(
                              color: AppColors.violet150,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(FluentIcons.chrome_close, size: 11),
                      style: ButtonStyle(
                        foregroundColor: WidgetStateProperty.all(AppColors.bgCard),
                      ),
                      onPressed: () => Navigator.pop(dialogContext),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: visible.isEmpty
                    ? const Center(
                        child: Text(
                          'No treatment history found for this patient.',
                          style: TextStyle(color: AppColors.textBlueMuted),
                        ),
                      )
                    : Container(
                        color: AppColors.slate504,
                        padding: const EdgeInsets.fromLTRB(10, 10, 10, 6),
                        child: SizedBox(
                          width: double.infinity,
                          child: Column(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 9,
                                ),
                                decoration: BoxDecoration(
                                    color: AppColors.surfaceBlueSoft,
                                  border: Border.all(
                                    color: AppColors.borderBlueSoft,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    const SizedBox(
                                      width: 120,
                                      child: Text(
                                        'Date',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w800,
                                            color: AppColors.textBlueStrong,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(
                                      width: 110,
                                      child: Text(
                                        'Teeth',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w800,
                                            color: AppColors.textBlueStrong,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(
                                      width: 160,
                                      child: Text(
                                        'Doctor',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w800,
                                            color: AppColors.textBlueStrong,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(
                                      width: 250,
                                      child: Text(
                                        'Chief Complaint',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w800,
                                            color: AppColors.textBlueStrong,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(
                                      width: 230,
                                      child: Text(
                                        'Diagnosis',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w800,
                                            color: AppColors.textBlueStrong,
                                        ),
                                      ),
                                    ),
                                    const Expanded(
                                      child: Text(
                                        'Treatment',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w800,
                                            color: AppColors.textBlueStrong,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 8),
                              SizedBox(
                                height: height - 180,
                                child: ListView.separated(
                                  itemCount: visible.length,
                                  separatorBuilder: (_, __) =>
                                      const SizedBox(height: 6),
                                  itemBuilder: (context, index) {
                                    final row = visible[index];
                                    return Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 8,
                                      ),
                                      decoration: BoxDecoration(
                                          color: AppColors.bgCard,
                                        border: Border.all(
                                            color: AppColors.violet1002,
                                        ),
                                      ),
                                      child: Row(
                                        children: [
                                          SizedBox(
                                            width: 120,
                                            child: Text(
                                              formatClinicDate(
                                                row.date,
                                                pattern: 'dd MMM yyyy',
                                              ),
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w700,
                                                color: AppColors.textBlueStrong,
                                              ),
                                            ),
                                          ),
                                          SizedBox(
                                            width: 110,
                                            child: Text(
                                              row.teeth,
                                              style: const TextStyle(
                                                color: AppColors.textBlueStrong,
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                          ),
                                          SizedBox(
                                            width: 160,
                                            child: Text(
                                              row.doctor,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                color: AppColors.textBlueStrong,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ),
                                          SizedBox(
                                            width: 250,
                                            child: Text(
                                              row.chiefComplaint,
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                color: AppColors.textBlueMuted,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ),
                                          SizedBox(
                                            width: 230,
                                            child: Text(
                                              row.diagnosis,
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                color: AppColors.textBlueMuted,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ),
                                          Expanded(
                                            child: Text(
                                              row.treatment,
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                color: AppColors.blue7005,
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                child: Row(
                  children: [
                    const Spacer(),
                    AppButton(
                      label: 'Close',
                      variant: AppButtonVariant.secondary,
                      onPressed: () => Navigator.pop(dialogContext),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}
