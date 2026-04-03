import 'package:apexo/core/multi_stream_builder.dart';
import 'package:apexo/features/appointments/appointments_store.dart';
import 'package:apexo/features/doctors/doctor_model.dart';
import 'package:apexo/features/doctors/doctors_store.dart';
import 'package:fluent_ui/fluent_ui.dart';

class DoctorsScreenV2 extends StatelessWidget {
  const DoctorsScreenV2({super.key});

  @override
  Widget build(BuildContext context) {
    return ScaffoldPage.scrollable(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
      children: [
        const Text(
          'Doctors V2',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w700,
            color: Color(0xFF12355F),
          ),
        ),
        const SizedBox(height: 10),
        MStreamBuilder(
          streams: [
            doctors.observableMap.stream,
            appointments.observableMap.stream,
          ],
          builder: (context, _) {
            final allDoctors = doctors.present.values.toList(growable: false);
            final allAppointments =
                appointments.present.values.toList(growable: false);
            final now = DateTime.now();
            final startOfToday = DateTime(now.year, now.month, now.day);
            final endOfToday = startOfToday.add(const Duration(days: 1));

            final todaysAppointments = allAppointments
                .where(
                  (a) =>
                      !a.date.isBefore(startOfToday) && a.date.isBefore(endOfToday),
                )
                .toList(growable: false);

            final activeDoctorIdsToday = <String>{};
            double todayDoctorPay = 0;
            for (final appointment in todaysAppointments) {
              activeDoctorIdsToday.addAll(appointment.operatorsIDs);
              todayDoctorPay += appointment.paidToDoctor;
            }

            final doctorActivity = allDoctors
                .map((doctor) {
                  final rows = todaysAppointments
                      .where((a) => a.operatorsIDs.contains(doctor.id))
                      .toList(growable: false);
                  final count = rows.length;
                  final paid = rows.fold<double>(0, (s, a) => s + a.paidToDoctor);
                  return (doctor: doctor, count: count, paid: paid);
                })
                .toList(growable: false)
              ..sort((a, b) => b.count.compareTo(a.count));

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    _MetricCard(
                      title: 'Total Doctors',
                      value: '${allDoctors.length}',
                      color: const Color(0xFF1D3E67),
                    ),
                    _MetricCard(
                      title: 'Active Today',
                      value: '${activeDoctorIdsToday.length}',
                      color: const Color(0xFF2BA58D),
                    ),
                    _MetricCard(
                      title: 'Appointments Today',
                      value: '${todaysAppointments.length}',
                      color: const Color(0xFF2D7BD8),
                    ),
                    _MetricCard(
                      title: 'Paid to Doctors Today',
                      value: 'Rs ${todayDoctorPay.toStringAsFixed(0)}',
                      color: const Color(0xFFE09C31),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _DoctorsActivityCard(rows: doctorActivity),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _MetricCard extends StatelessWidget {
  final String title;
  final String value;
  final Color color;

  const _MetricCard({
    required this.title,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 270,
      height: 140,
      child: DecoratedBox(
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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 13,
                  color: Color(0xFF3C5E87),
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                value,
                style: TextStyle(
                  fontSize: 30,
                  color: color,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DoctorsActivityCard extends StatelessWidget {
  final List<({Doctor doctor, int count, double paid})> rows;

  const _DoctorsActivityCard({required this.rows});

  @override
  Widget build(BuildContext context) {
    final maxCount = rows.fold<int>(1, (m, e) => e.count > m ? e.count : m);

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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Doctor Activity Today',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Color(0xFF183A67),
              ),
            ),
            const SizedBox(height: 10),
            if (rows.isEmpty)
              const Text(
                'No doctors available.',
                style: TextStyle(color: Color(0xFF6D84A8)),
              )
            else
              ...rows.take(12).map(
                (row) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 180,
                        child: Text(
                          row.doctor.title,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Color(0xFF1F446E),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            height: 10,
                            color: const Color(0xFFEAF2FC),
                            child: FractionallySizedBox(
                              alignment: Alignment.centerLeft,
                              widthFactor: maxCount == 0 ? 0 : row.count / maxCount,
                              child: Container(color: const Color(0xFF2D7BD8)),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      SizedBox(
                        width: 140,
                        child: Text(
                          '${row.count} appts | Rs ${row.paid.toStringAsFixed(0)}',
                          textAlign: TextAlign.right,
                          style: const TextStyle(
                            color: Color(0xFF5B789F),
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
