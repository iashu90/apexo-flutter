import 'package:apexo/services/localization/locale.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/material.dart' as material;

class CompletedVsPendingAppointmentsBar extends StatelessWidget {
  final List appointments;

  const CompletedVsPendingAppointmentsBar({
    super.key,
    required this.appointments,
  });

  @override
  Widget build(BuildContext context) {
    final total = appointments.length;
    final completed = appointments.where((a) => a.isDone == true).length;
    final pending = total - completed;
    final completedPercent = total == 0 ? 0.0 : completed / total;
    final pendingPercent = total == 0 ? 0.0 : pending / total;

    // Hide the bar if there are no appointments
    if (total == 0) return const SizedBox.shrink();

    // Define your custom colors
    const completedColor = material.Colors.teal;
    const pendingColor = material.Colors.red;

    return Container(
      alignment: Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 800),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
        child: Card(
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Txt(
                  txt("completedVsPendingAppointments"),
                  style: const TextStyle(
                    fontWeight: FontWeight.w500,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    if (completed == total)
                      // Only completed bar (full width)
                      Expanded(
                        child: Container(
                          height: 24,
                          decoration: BoxDecoration(
                            color: completedColor,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            "${txt("completed")}: $completed",
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      )
                    else if (pending == total)
                      // Only pending bar (full width)
                      Expanded(
                        child: Container(
                          height: 24,
                          decoration: BoxDecoration(
                            color: pendingColor,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            "${txt("pending")}: $pending",
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      )
                    else ...[
                      // Both bars
                      Expanded(
                        flex: (completedPercent * 100).round(),
                        child: Container(
                          height: 24,
                          decoration: BoxDecoration(
                            color: completedColor,
                            borderRadius: const BorderRadius.horizontal(
                                left: Radius.circular(12)),
                          ),
                          alignment: Alignment.centerLeft,
                          child: Padding(
                            padding: const EdgeInsets.only(left: 8.0),
                            child: Text(
                              "${txt("completed")}: $completed",
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        flex: (pendingPercent * 100).round(),
                        child: Container(
                          height: 24,
                          decoration: BoxDecoration(
                            color: pendingColor,
                            borderRadius: const BorderRadius.horizontal(
                                right: Radius.circular(12)),
                          ),
                          alignment: Alignment.centerRight,
                          child: Padding(
                            padding: const EdgeInsets.only(right: 8.0),
                            child: Text(
                              "${txt("pending")}: $pending",
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
