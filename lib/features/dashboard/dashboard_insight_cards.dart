import 'package:apexo/features/appointments/appointment_model.dart';
import 'package:apexo/features/doctors/doctors_store.dart';
import 'package:fluent_ui/fluent_ui.dart';

class DashboardDoctorInsightsCard extends StatelessWidget {
  final List<Appointment> todaysAppointments;
  final String selectedFilter;
  final String allFilterToken;
  final String unassignedFilterToken;
  final ValueChanged<String> onFilterChanged;
  final VoidCallback onAddAppointment;

  const DashboardDoctorInsightsCard({
    super.key,
    required this.todaysAppointments,
    required this.selectedFilter,
    required this.allFilterToken,
    required this.unassignedFilterToken,
    required this.onFilterChanged,
    required this.onAddAppointment,
  });

  @override
  Widget build(BuildContext context) {
    final doctorRows = <_DoctorInsightRow>[];
    final doctorCounts = <String, int>{};
    final doctorRevenue = <String, double>{};
    final doctorNameByBucket = <String, String>{};

    int unassignedCount = 0;
    double unassignedRevenue = 0;

    // Count each appointment once so "All" equals doctor+unassigned totals.
    for (final appointment in todaysAppointments) {
      final payment = appointment.paid + appointment.prescriptionPaid;
      if (appointment.operatorsIDs.isEmpty) {
        unassignedCount += 1;
        unassignedRevenue += payment;
        continue;
      }

      final primaryDoctorId = appointment.operatorsIDs.first;
      final resolvedDoctor = _findDoctorById(primaryDoctorId);
      final bucketId = resolvedDoctor?.id ?? '__unknown__:$primaryDoctorId';
      final bucketTitle = resolvedDoctor?.title.trim().isNotEmpty == true
          ? resolvedDoctor!.title
          : 'Unknown ($primaryDoctorId)';

      doctorCounts[bucketId] = (doctorCounts[bucketId] ?? 0) + 1;
      doctorRevenue[bucketId] = (doctorRevenue[bucketId] ?? 0) + payment;
      doctorNameByBucket[bucketId] = bucketTitle;
    }

    for (final entry in doctorCounts.entries) {
      doctorRows.add(
        _DoctorInsightRow(
          id: entry.key,
          title: doctorNameByBucket[entry.key] ?? 'Unknown',
          count: entry.value,
          revenue: doctorRevenue[entry.key] ?? 0,
        ),
      );
    }

    doctorRows.sort((a, b) => b.count.compareTo(a.count));

    final totalRevenue =
        doctorRows.fold<double>(0, (sum, row) => sum + row.revenue) +
            unassignedRevenue;

    return _CardShell(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Doctors Insights',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: Color(0xFF183A67),
            ),
          ),
          if (doctorRows.isEmpty) ...[
            const SizedBox(height: 6),
            const Text(
              'No doctors assigned for this day',
              style: TextStyle(color: Color(0xFF637EA3)),
            ),
          ],
          const SizedBox(height: 8),
          _ScheduleLine(
            title: 'All',
            count: todaysAppointments.length,
            secondaryMoney: '₹${totalRevenue.toStringAsFixed(0)}',
            secondaryPct: '100%',
            selected: selectedFilter == allFilterToken,
            onTap: () => onFilterChanged(allFilterToken),
          ),
          _ScheduleLine(
            title: 'Unassigned',
            count: unassignedCount,
            secondaryMoney: '₹${unassignedRevenue.toStringAsFixed(0)}',
            secondaryPct: totalRevenue <= 0
                ? '0%'
                : '${(unassignedRevenue / totalRevenue * 100).toStringAsFixed(0)}%',
            selected: selectedFilter == unassignedFilterToken,
            onTap: () => onFilterChanged(unassignedFilterToken),
          ),
          const SizedBox(height: 6),
          ...doctorRows.map(
                (row) => _ScheduleLine(
                  title: row.title,
                  count: row.count,
                  secondaryMoney: '₹${row.revenue.toStringAsFixed(0)}',
                  secondaryPct: totalRevenue <= 0
                      ? '0%'
                      : '${(row.revenue / totalRevenue * 100).toStringAsFixed(0)}%',
                  selected: selectedFilter == row.id,
                  onTap: () => onFilterChanged(row.id),
                ),
              ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: onAddAppointment,
            style: ButtonStyle(
              shape: WidgetStateProperty.all(
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(FluentIcons.add, size: 14, color: Colors.white),
                SizedBox(width: 8),
                Text(
                  'Check-in',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
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

class DashboardTreatmentStats {
  final List<MapEntry<String, int>> topTreatments;
  final int totalTreatments;

  const DashboardTreatmentStats({
    required this.topTreatments,
    required this.totalTreatments,
  });

  factory DashboardTreatmentStats.from(List<Appointment> appointmentsOnDay) {
    final counts = <String, int>{};
    for (final appointment in appointmentsOnDay) {
      for (final treatment in appointment.selectedTreatments) {
        final key = treatment.trim();
        if (key.isEmpty) continue;
        counts[key] = (counts[key] ?? 0) + 1;
      }
    }

    final sorted = counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final total = sorted.fold<int>(0, (sum, entry) => sum + entry.value);

    return DashboardTreatmentStats(
      topTreatments: sorted,
      totalTreatments: total,
    );
  }
}

class DashboardTreatmentStatsCard extends StatelessWidget {
  final DashboardTreatmentStats stats;
  final String selectedTreatment;
  final String allTreatmentFilterToken;
  final bool showAll;
  final ValueChanged<String> onFilterChanged;
  final VoidCallback onToggleShowAll;

  const DashboardTreatmentStatsCard({
    super.key,
    required this.stats,
    required this.selectedTreatment,
    required this.allTreatmentFilterToken,
    required this.showAll,
    required this.onFilterChanged,
    required this.onToggleShowAll,
  });

  @override
  Widget build(BuildContext context) {
    final visibleTreatments = showAll
        ? stats.topTreatments
        : stats.topTreatments.take(5).toList(growable: false);

    return _CardShell(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Treatment Stats',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: Color(0xFF183A67),
            ),
          ),
          const SizedBox(height: 8),
          _ScheduleLine(
            title: 'Total',
            count: stats.totalTreatments,
            selected: selectedTreatment == allTreatmentFilterToken,
            onTap: () => onFilterChanged(allTreatmentFilterToken),
          ),
          if (stats.topTreatments.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 6),
              child: Text(
                'No treatments recorded for this day',
                style: TextStyle(color: Color(0xFF637EA3)),
              ),
            )
          else
            ...visibleTreatments.map(
              (entry) => _ScheduleLine(
                title: entry.key,
                count: entry.value,
                selected:
                    selectedTreatment.toLowerCase() == entry.key.toLowerCase(),
                onTap: () => onFilterChanged(entry.key),
              ),
            ),
          if (stats.topTreatments.length > 5) ...[
            const SizedBox(height: 8),
            FilledButton(
              onPressed: onToggleShowAll,
              style: ButtonStyle(
                backgroundColor:
                    WidgetStateProperty.all(const Color(0xFF2D7BD8)),
                shape: WidgetStateProperty.all(
                  RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
              child: Text(showAll ? 'Show Top 5' : 'Show More'),
            ),
          ],
        ],
      ),
    );
  }
}

class _DoctorInsightRow {
  final String id;
  final String title;
  final int count;
  final double revenue;

  const _DoctorInsightRow({
    required this.id,
    required this.title,
    required this.count,
    required this.revenue,
  });
}

dynamic _findDoctorById(String doctorId) {
  final direct = doctors.get(doctorId);
  if (direct != null) return direct;

  final needle = doctorId.trim().toLowerCase();
  if (needle.isEmpty) return null;

  for (final doctor in doctors.present.values) {
    if (doctor.id.trim().toLowerCase() == needle) {
      return doctor;
    }
  }

  return null;
}

class _ScheduleLine extends StatelessWidget {
  final String title;
  final int count;
  final String? secondaryMoney;
  final String? secondaryPct;
  final bool selected;
  final VoidCallback onTap;

  const _ScheduleLine({
    required this.title,
    required this.count,
    this.secondaryMoney,
    this.secondaryPct,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(top: 2),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(6),
          color: selected ? const Color(0xFFDDEBFF) : const Color(0xFFF6F9FE),
          border: Border.all(
            color: selected ? const Color(0xFF8CB6E8) : Colors.transparent,
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: selected
                      ? const Color(0xFF123D71)
                      : const Color(0xFF27456D),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (secondaryMoney != null)
                  Text(
                    secondaryMoney!,
                    style: TextStyle(
                      color: selected
                          ? const Color(0xFF1459AD)
                          : const Color(0xFF2D7BD8),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                if (secondaryPct != null) ...[
                  const SizedBox(width: 6),
                  Text(
                    secondaryPct!,
                    style: TextStyle(
                      color: selected
                          ? const Color(0xFF2BA58D)
                          : const Color(0xFF4A8B73),
                      fontWeight: FontWeight.w700,
                      fontSize: 11,
                    ),
                  ),
                ],
                const SizedBox(width: 6),
                Text(
                  '($count)',
                  style: TextStyle(
                    color: selected
                        ? const Color(0xFF1A4B88)
                        : const Color(0xFF637EA3),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _CardShell extends StatelessWidget {
  final Widget child;

  const _CardShell({required this.child});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
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
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: child,
      ),
    );
  }
}
