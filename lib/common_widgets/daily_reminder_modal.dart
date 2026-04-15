import 'package:apexo/features/appointments/appointments_store.dart';
import 'package:apexo/features/labwork/labworks_store.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:intl/intl.dart';
import 'package:flutter/cupertino.dart';

/// In-memory flag — resets every app session (not persisted).
bool dailyReminderShown = false;

void showDailyReminderIfNeeded(BuildContext context) {
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

  final todaysAppointments = appointments.forDate(today);
  final pendingLabworks = labworks.present.values
      .where((l) => !l.deliveredToDoctor)
      .toList(growable: false);

  final scheduledCount = todaysAppointments.length;
  final pendingLabCount = pendingLabworks.length;

  await showDialog<void>(
    context: context,
    builder: (dialogContext) => ContentDialog(
      title: Row(
        children: [
          const Icon(
            CupertinoIcons.bell_solid,
            color: Colors.black,
            size: 28.0,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  "Today's Briefing",
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                Text(
                  DateFormat('EEEE, d MMMM yyyy').format(now),
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF6D84A8),
                    fontWeight: FontWeight.w500,
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
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _ReminderCard(
              icon: FluentIcons.calendar,
              iconColor: const Color(0xFF2D7BD8),
              bgColor: const Color(0xFFEAF2FF),
              label: 'Appointments Today',
              value: '$scheduledCount',
              subtitle: scheduledCount == 0
                  ? 'No appointments scheduled'
                  : scheduledCount == 1
                      ? '1 appointment scheduled'
                      : '$scheduledCount appointments scheduled',
            ),
            const SizedBox(height: 10),
            _ReminderCard(
              icon: FluentIcons.test_beaker,
              iconColor: const Color(0xFFD6455D),
              bgColor: const Color(0xFFFFF0F2),
              label: 'Pending Lab Works',
              value: '$pendingLabCount',
              subtitle: pendingLabCount == 0
                  ? 'All lab works are ready'
                  : pendingLabCount == 1
                      ? '1 lab work not ready yet'
                      : '$pendingLabCount lab works not ready yet',
            ),
          ],
        ),
      ),
      actions: [
        FilledButton(
          style: ButtonStyle(
            backgroundColor: WidgetStateProperty.all(const Color(0xFF2D7BD8)),
          ),
          onPressed: () => Navigator.pop(dialogContext),
          child: const Text('Got it'),
        ),
      ],
    ),
  );
}

class _ReminderCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final Color bgColor;
  final String label;
  final String value;
  final String subtitle;

  const _ReminderCard({
    required this.icon,
    required this.iconColor,
    required this.bgColor,
    required this.label,
    required this.value,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: iconColor.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 20, color: iconColor),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: iconColor.withValues(alpha: 0.8),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 28,
                    color: iconColor,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF6D84A8),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
