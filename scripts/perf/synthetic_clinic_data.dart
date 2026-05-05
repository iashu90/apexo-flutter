import 'dart:math';

class SyntheticPatientRow {
  final String id;
  final String name;
  final String phone;

  const SyntheticPatientRow({
    required this.id,
    required this.name,
    required this.phone,
  });
}

class SyntheticAppointmentRow {
  final String id;
  final String patientId;
  final String doctorId;
  final DateTime date;
  final String stage;
  final bool isCheckedIn;
  final double price;
  final double paid;
  final List<String> selectedTreatments;

  const SyntheticAppointmentRow({
    required this.id,
    required this.patientId,
    required this.doctorId,
    required this.date,
    required this.stage,
    required this.isCheckedIn,
    required this.price,
    required this.paid,
    required this.selectedTreatments,
  });
}

class SyntheticClinicData {
  final List<SyntheticPatientRow> patients;
  final List<SyntheticAppointmentRow> appointments;
  final List<String> doctorIds;
  final DateTime now;

  const SyntheticClinicData({
    required this.patients,
    required this.appointments,
    required this.doctorIds,
    required this.now,
  });
}

SyntheticClinicData buildSyntheticClinicData({
  int patientCount = 10000,
  int appointmentCount = 50000,
  int doctorCount = 40,
  int seed = 42,
}) {
  final random = Random(seed);
  final now = DateTime.now();

  final patients = List<SyntheticPatientRow>.generate(
    patientCount,
    (i) => SyntheticPatientRow(
      id: 'p_$i',
      name: 'Patient $i',
      phone: '9${(100000000 + i).toString().padLeft(9, '0')}',
    ),
    growable: false,
  );

  final doctorIds = List<String>.generate(
    doctorCount,
    (i) => 'd_$i',
    growable: false,
  );

  final treatmentPool = <String>[
    'Consultation',
    'RCT',
    'Extraction',
    'Scaling',
    'Filling',
    'Ortho',
    'Implant',
    'Crown',
  ];
  final stages = <String>[
    'waiting',
    'pending',
    'scheduled',
    'with_doctor',
    'checkout',
    'completed',
    'cancelled',
  ];

  final appointments = List<SyntheticAppointmentRow>.generate(
    appointmentCount,
    (i) {
      final patientId = patients[random.nextInt(patients.length)].id;
      final doctorId = doctorIds[random.nextInt(doctorIds.length)];
      final dayOffset = random.nextInt(30) - 15;
      final minuteOffset = random.nextInt(24 * 60);
      final date = DateTime(now.year, now.month, now.day)
          .add(Duration(days: dayOffset, minutes: minuteOffset));
      final stage = stages[random.nextInt(stages.length)];
      final treatmentCount = 1 + random.nextInt(3);
      final selectedTreatments = List<String>.generate(
        treatmentCount,
        (_) => treatmentPool[random.nextInt(treatmentPool.length)],
        growable: false,
      );
      final price = 100 + random.nextInt(3900).toDouble();
      final paid = (price * (0.2 + random.nextDouble() * 0.8));
      return SyntheticAppointmentRow(
        id: 'a_$i',
        patientId: patientId,
        doctorId: doctorId,
        date: date,
        stage: stage,
        isCheckedIn: random.nextBool(),
        price: price,
        paid: paid,
        selectedTreatments: selectedTreatments,
      );
    },
    growable: false,
  );

  return SyntheticClinicData(
    patients: patients,
    appointments: appointments,
    doctorIds: doctorIds,
    now: now,
  );
}
