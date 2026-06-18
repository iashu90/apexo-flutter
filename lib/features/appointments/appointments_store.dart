import 'package:apexo/common_widgets/patient_report.dart';
import 'package:apexo/core/observable.dart';
import 'package:apexo/features/appointments/treatment_model.dart';
import 'package:apexo/services/archived.dart';
import 'package:apexo/services/launch.dart';
import 'package:apexo/services/network.dart';
import 'package:apexo/utils/hash.dart';
import 'package:apexo/utils/demo_generator.dart';

import '../../core/save_local.dart';
import '../../core/save_remote.dart';
import '../network_actions/network_actions_controller.dart';
import '../../services/login.dart';
import 'appointment_model.dart';
import '../../core/store.dart';

const _storeName = "appointments";

class Appointments extends Store<Appointment> {
  Appointments()
      : super(
          modeling: Appointment.fromJson,
          isDemo: launch.isDemo,
          showArchived: showArchived,
          onSyncStart: () {
            networkActions.isSyncing(networkActions.isSyncing() + 1);
          },
          onSyncEnd: () {
            networkActions.isSyncing(networkActions.isSyncing() - 1);
          },
          criticalWriteGuardEnabled: true,
        );

  @override
  init() {
    super.init();

    observableMap.observe((_) => _allPrescriptions = null);

    login.activators[_storeName] = () async {
      await loaded;

      local = SaveLocal(name: _storeName, uniqueId: simpleHash(login.url));
      await recoverCriticalJournalWrites();
      await deleteMemoryAndLoadFromPersistence();

      if (launch.isDemo) {
        if (docs.isEmpty) setAll(demoAppointments(1000));
      } else {
        remote = SaveRemote(
          pbInstance: login.pb!,
          storeName: _storeName,
          onOnlineStatusChange: (current) {
            if (network.isOnline() != current) {
              network.isOnline(current);
            }
          },
        );
      }

      return () async {
        networkActions.syncCallbacks[_storeName] = synchronize;
        networkActions.reconnectCallbacks[_storeName] = remote!.checkOnline;

        network.onOnline[_storeName] = synchronize;
        network.onOffline[_storeName] = cancelRealtimeSub;
      };
    };
  }

  final doctorId = ObservableState("");

  Map<String, Appointment> get filtered {
    if (doctorId().isEmpty) return present;
    return Map<String, Appointment>.fromEntries(present.entries
        .where((entry) => entry.value.operatorsIDs.contains(doctorId())));
  }

  List<String>? _allPrescriptions;
  List<String> get allPrescriptions {
    return _allPrescriptions ??=
        Set<String>.from(present.values.expand((doc) => doc.prescriptions))
            .toList();
  }
}

extension AppointmentsDateExtension on Appointments {
  List<Appointment> forDate(DateTime date) {
    return present.values
        .where((appointment) =>
            appointment.date.year == date.year &&
            appointment.date.month == date.month &&
            appointment.date.day == date.day)
        .toList();
  }
}

extension AppointmentListToPatientDetailRows on List<Appointment> {
  /// [usePrescription] - if true, use prescriptionPrice/prescriptionPaid, else use price/paid
  List<ReportDetailRow> toPatientDetailRows({bool usePrescription = false}) {
    return map((appointment) {
      final dateStr = appointment.date;

      final costStr = usePrescription
          ? '₹${appointment.prescriptionPrice.toStringAsFixed(2)}'
          : '₹${appointment.price.toStringAsFixed(2)}';

      final paidStr = usePrescription
          ? '₹${appointment.prescriptionPaid.toStringAsFixed(2)}'
          : '₹${appointment.paid.toStringAsFixed(2)}';

      final prescriptionStr = appointment.prescriptions.isNotEmpty
          ? appointment.prescriptions.join(', ')
          : '';

      final treatmentStr = appointment.selectedTreatments.isNotEmpty
          ? appointment.selectedTreatments.join(', ')
          : '';

      final teethStr = appointment.selectedTeeth.isNotEmpty
          ? appointment.selectedTeeth.join(', ')
          : '';

      final treatmentPaymentMode =
          appointment.treatmentGpayPaid == true ? 'GPay' : 'Cash';
      final preceptionPaymentMode =
          appointment.prescriptionGpayPaid == true ? 'GPay' : 'Cash';

      return ReportDetailRow(
        appointmentId: appointment.id,
        date: dateStr,
        cost: costStr,
        paid: paidStr,
        prescription: prescriptionStr,
        treatment: treatmentStr,
        teeth: teethStr,
        isDone: appointment.isDone,
        patient: appointment.patient,
        treatmentPaymentMode: treatmentPaymentMode,
        preceptionPaymentMode: preceptionPaymentMode,
      );
    }).toList();
  }
}

final List<Treatment> allTreatments = [
  Treatment(name: 'Follow-up', price: 0),
  Treatment(name: 'Consultation', price: 100),
  Treatment(name: 'IOPA (X-ray)', price: 10),
  Treatment(name: 'GIC', price: 500, multiplier: true),
  Treatment(name: 'Ant Composite', price: 1000, multiplier: true),
  Treatment(name: 'Post Composite', price: 800, multiplier: true),
  Treatment(name: 'Localized Scaling', price: 200),
  Treatment(name: 'Scaling', price: 800),
  Treatment(name: 'Scaling & Polishing', price: 1000),
  Treatment(name: 'RCT', price: 3000, multiplier: true),
  Treatment(name: 'PFM Crowns', price: 3000, multiplier: true),
  Treatment(name: 'Zirconia Crowns', price: 6000, multiplier: true),
  Treatment(name: 'Extraction', price: 800, multiplier: true),
  Treatment(name: 'Wisdom Teeth Extraction', price: 1000, multiplier: true),
  Treatment(name: 'Impaction', price: 2500, multiplier: true),
  Treatment(name: 'Ortho', price: 0),
];
final List<String> allDiagnosis = [
  'Caries',
  'Periodontitis',
  'Pulpitis',
  'Gingivitis',
  'Fracture',
  'Malocclusion',
  'GD-Grossly Decayed',
  'DC-Dental Caries',
  'Partially Erupted',
  'Impacted',
  'Chronic Pulpitis',
  'Ortho',
  'Calculus',
  'Stains',
  'Abscess',
];
final List<String> rctSittings = ["AO & BMP", "Obturation", "PCS"];
final List<String> crownSittings = ["Tooth preparation", "Crown luting"];

final appointments = Appointments();
