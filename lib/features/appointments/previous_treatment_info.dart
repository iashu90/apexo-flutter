import 'package:apexo/features/appointments/appointment_model.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/material.dart' as material;
import 'package:intl/intl.dart';

class PreviousTreatmentInfo extends StatefulWidget {
  final List<Appointment> appointments;

  const PreviousTreatmentInfo({
    super.key,
    required this.appointments,
  });

  @override
  State<PreviousTreatmentInfo> createState() => _PreviousTreatmentInfoState();
}

class _PreviousTreatmentInfoState extends State<PreviousTreatmentInfo> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    if (widget.appointments.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: material.Colors.blueGrey.shade50.withOpacity(0.7),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: material.Colors.blue.shade100, width: 1),
        boxShadow: [
          BoxShadow(
            color: material.Colors.blueGrey.shade100.withOpacity(0.15),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: () => setState(() => _expanded = !_expanded),
            child: Row(
              children: [
                Icon(
                  _expanded
                      ? FluentIcons.chevron_down
                      : FluentIcons.chevron_right,
                  size: 14,
                  color: material.Colors.blueGrey,
                ),
                const SizedBox(width: 6),
                const Text(
                  "Previous Treatments",
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: material.Colors.blueGrey,
                    letterSpacing: 0.2,
                  ),
                ),
              ],
            ),
          ),
          if (_expanded)
            ...widget.appointments.map((appointment) {
              final treatments = appointment.selectedTreatments;
              final subTreatments = appointment.subTreatments;
              final dateStr = DateFormat('d MMM yyyy').format(appointment.date);

              return Padding(
                padding: const EdgeInsets.only(top: 10.0, bottom: 6.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          FluentIcons.calendar,
                          size: 15,
                          color: material.Colors.blue.shade300,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          dateStr,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                            color: material.Colors.blueGrey,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    ...treatments.map((treatment) {
                      return Padding(
                        padding: const EdgeInsets.only(left: 22.0, bottom: 2.0),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              FluentIcons.check_mark,
                              size: 14,
                              color: material.Colors.blue.shade300,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: RichText(
                                text: TextSpan(
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14,
                                    color: material.Colors.black87,
                                  ),
                                  children: [
                                    TextSpan(text: treatment),
                                    if (subTreatments.isNotEmpty) ...[
                                      const TextSpan(
                                        text: "  –  ",
                                        style: TextStyle(
                                          color: material.Colors.blueGrey,
                                          fontWeight: FontWeight.normal,
                                        ),
                                      ),
                                      TextSpan(
                                        text: subTreatments.join(', '),
                                        style: const TextStyle(
                                          color: material.Colors.blueGrey,
                                          fontWeight: FontWeight.normal,
                                        ),
                                      ),
                                    ]
                                  ],
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
            }),
        ],
      ),
    );
  }
}
