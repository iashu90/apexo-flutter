import 'package:apexo/common_widgets/patient_timeline_card.dart';
import 'package:apexo/features/appointments/appointment_model.dart';
import 'package:apexo/utils/clinic_time.dart';
import 'package:flutter/material.dart';

class CheckinTimelineMapper {
  static List<TimelineItem> fromAppointments(List<Appointment> rows) {
    return rows.take(12).toList(growable: false).asMap().entries.map((entry) {
      final row = entry.value;
      final treatments = row.selectedTreatments
          .where((item) => item.trim().isNotEmpty)
          .toList(growable: false);
      final doctorNames = row.operators
          .map((doctor) => doctor.title.trim())
          .where((name) => name.isNotEmpty)
          .toList(growable: false);
      final notes = row.preOpNotes.trim().isEmpty ? null : row.preOpNotes.trim();
      final teeth = row.selectedTeeth
          .where((item) => item.trim().isNotEmpty)
          .toList(growable: false);

      return TimelineItem(
        title: treatments.isEmpty ? 'Consultation' : treatments.join(', '),
        date: formatClinicDate(row.date, pattern: 'dd MMM yyyy'),
        time: formatClinicDateTime(row.date, pattern: 'h:mm a'),
        color: _colorForIndex(entry.key),
        doctor: doctorNames.isEmpty ? 'Unassigned' : doctorNames.join(', '),
        visitType: row.visitType.trim().isEmpty
            ? 'Follow-up Visit'
            : row.visitType,
        notes: notes,
        teeth: teeth.isEmpty ? null : teeth,
      );
    }).toList(growable: false);
  }

  static Color _colorForIndex(int index) {
    const palette = <Color>[
      Color(0xFF7C6CF6),
      Color(0xFFF59E0B),
      Color(0xFF60A5FA),
      Color(0xFF34D399),
      Color(0xFF3B82F6),
    ];
    return palette[index % palette.length];
  }
}
