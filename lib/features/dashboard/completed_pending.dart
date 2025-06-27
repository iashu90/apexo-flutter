import 'package:fluent_ui/fluent_ui.dart';

import 'package:apexo/features/appointments/appointment_model.dart';

class CompletedVsPendingAppointmentsNumbers extends StatelessWidget {
  final List<Appointment> appointments;

  const CompletedVsPendingAppointmentsNumbers({
    super.key,
    required this.appointments,
  });

  @override
  Widget build(BuildContext context) {
    final completed = appointments.where((a) => a.isDone == true).length;
    final pending = appointments.where((a) => a.isDone != true).length;

    return Row(
      children: [
        _pill(
          color: Colors.green,
          icon: FluentIcons.check_mark,
          label: "Completed",
          count: completed,
        ),
        const SizedBox(width: 16),
        _pill(
          color: Colors.orange,
          icon: FluentIcons.clock,
          label: "Pending",
          count: pending,
        ),
      ],
    );
  }

  Widget _pill({
    required Color color,
    required IconData icon,
    required String label,
    required int count,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 8),
          Text(
            "$label: ",
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w600,
              fontSize: 16,
            ),
          ),
          Text(
            "$count",
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
        ],
      ),
    );
  }
}