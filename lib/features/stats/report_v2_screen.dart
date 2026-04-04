import 'dart:math' as math;

import 'package:apexo/core/multi_stream_builder.dart';
import 'package:apexo/features/appointments/appointments_store.dart';
import 'package:apexo/features/patients/patients_store.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:intl/intl.dart';

class ReportV2Screen extends StatelessWidget {
  const ReportV2Screen({super.key});

  @override
  Widget build(BuildContext context) {
    return ScaffoldPage.scrollable(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
      children: [
        MStreamBuilder(
          streams: [
            appointments.observableMap.stream,
            patients.observableMap.stream,
          ],
          builder: (context, _) {
            final allAppointments =
                appointments.present.values.toList(growable: false);
            final now = DateTime.now();
            final thisMonthStart = DateTime(now.year, now.month, 1);
            final nextMonthStart = DateTime(now.year, now.month + 1, 1);
            final lastMonthStart = DateTime(now.year, now.month - 1, 1);

            final thisMonthRows = allAppointments
                .where((a) =>
                    !a.date.isBefore(thisMonthStart) &&
                    a.date.isBefore(nextMonthStart))
                .toList(growable: false);
            final lastMonthRows = allAppointments
                .where((a) =>
                    !a.date.isBefore(lastMonthStart) &&
                    a.date.isBefore(thisMonthStart))
                .toList(growable: false);

            final thisRevenue = thisMonthRows.fold<double>(
              0,
              (sum, a) => sum + a.paid + a.prescriptionPaid,
            );
            final lastRevenue = lastMonthRows.fold<double>(
              0,
              (sum, a) => sum + a.paid + a.prescriptionPaid,
            );
            final revenueGrowth = lastRevenue == 0
                ? (thisRevenue > 0 ? 100.0 : 0.0)
                : ((thisRevenue - lastRevenue) / lastRevenue) * 100;

            final thisAppts = thisMonthRows.length;
            final lastAppts = lastMonthRows.length;
            final apptGrowth = lastAppts == 0
                ? (thisAppts > 0 ? 100.0 : 0.0)
                : ((thisAppts - lastAppts) / lastAppts) * 100;

            final predictedRevenue =
                thisRevenue * (1 + (revenueGrowth / 100).clamp(-0.4, 0.6));
            final predictedAppointments =
                (thisAppts * (1 + (apptGrowth / 100).clamp(-0.4, 0.6))).round();

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Report V2',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF12355F),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Forecast based on ${DateFormat('MMMM').format(thisMonthStart)} and ${DateFormat('MMMM').format(lastMonthStart)} performance',
                  style: const TextStyle(
                    color: Color(0xFF5A7397),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    _ReportCard(
                      title: 'Revenue Forecast',
                      subtitle: 'Predicted next month revenue',
                      value: 'Rs ${predictedRevenue.toStringAsFixed(0)}',
                      hint:
                          'Growth trend: ${revenueGrowth.toStringAsFixed(1)}%',
                      accent: const Color(0xFF2D7BD8),
                    ),
                    _ReportCard(
                      title: 'Appointment Forecast',
                      subtitle: 'Predicted next month appointments',
                      value: '$predictedAppointments',
                      hint: 'Growth trend: ${apptGrowth.toStringAsFixed(1)}%',
                      accent: const Color(0xFF2BA58D),
                    ),
                    _ReportCard(
                      title: 'Revenue Risk Meter',
                      subtitle: 'Simple volatility indicator',
                      value: _riskLabel(revenueGrowth),
                      hint:
                          'Stable when growth remains between -10% and 20%',
                      accent: const Color(0xFFE09C31),
                    ),
                    _ReportCard(
                      title: 'Patient Load Prediction',
                      subtitle: 'Expected monthly load band',
                      value:
                          '${math.max(0, predictedAppointments - 20)} - ${predictedAppointments + 20}',
                      hint: 'Uses momentum from the past two months',
                      accent: const Color(0xFFD6455D),
                    ),
                  ],
                ),
              ],
            );
          },
        ),
      ],
    );
  }

  static String _riskLabel(double growth) {
    if (growth < -20) return 'High Risk';
    if (growth < -5) return 'Watch Closely';
    if (growth <= 25) return 'Stable';
    return 'Aggressive Upside';
  }
}

class _ReportCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final String value;
  final String hint;
  final Color accent;

  const _ReportCard({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.hint,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 320,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFD7E3F0)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x160D2F5B),
              blurRadius: 10,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                color: Color(0xFF183A67),
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: const TextStyle(
                color: Color(0xFF6D84A8),
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              value,
              style: TextStyle(
                fontSize: 30,
                color: accent,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              hint,
              style: const TextStyle(
                color: Color(0xFF5A7397),
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
