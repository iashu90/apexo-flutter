import 'package:apexo/common_widgets/patient_report.dart';
import 'package:apexo/core/observable.dart';
import 'package:apexo/features/appointments/treatment_model.dart';
import 'package:apexo/features/login/login_controller.dart';
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
        );

  Map<String, Map<String, List<Appointment>>> byPatient = {};
  Map<String, Map<String, List<Appointment>>> byDoctor = {};

  @override
  init() {
    super.init();

    observableMap.observe((_) => _allPrescriptions = null);
    observableMap.observe((_) {
      byPatient = {};
      byDoctor = {};
      for (var appointment in observableMap.values) {
        final patientID = appointment.patientID ?? "";
        final isDone = appointment.isDone;
        final isUpcoming = appointment.date.isAfter(DateTime.now());
        final isPast = appointment.date.isBefore(DateTime.now());

        // build patient caches
        if (byPatient[patientID] == null) {
          byPatient[patientID] = {
            "upcoming": [],
            "done": [],
            "past": [],
            "all": [],
          };
        }
        byPatient[patientID]!["all"]!.add(appointment);
        if (isUpcoming) {
          byPatient[patientID]!["upcoming"]!.add(appointment);
        } else if (isDone) {
          byPatient[patientID]!["done"]!.add(appointment);
        } else if (isPast) {
          byPatient[patientID]!["past"]!.add(appointment);
        }

        // build doctor caches
        for (var doctorId in appointment.operatorsIDs) {
          if (byDoctor[doctorId] == null) {
            byDoctor[doctorId] = {
              "upcoming": [],
              "done": [],
              "past": [],
              "all": [],
            };
          }
          byDoctor[doctorId]!["all"]!.add(appointment);
          if (isUpcoming) {
            byDoctor[doctorId]!["upcoming"]!.add(appointment);
          } else if (isDone) {
            byDoctor[doctorId]!["done"]!.add(appointment);
          } else if (isPast) {
            byDoctor[doctorId]!["past"]!.add(appointment);
          }
        }
      }
    });

    login.activators[_storeName] = () async {
      await loaded;

      local = SaveLocal(name: _storeName, uniqueId: simpleHash(login.url));
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
        loginCtrl.loadingIndicator("Synchronizing appointments");
        await synchronize();
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
  List<PatientDetailRow> toPatientDetailRows() {
    return map((appointment) {
      final dateStr = appointment.date.toString().substring(0, 10);

      final costStr = '₹${appointment.price.toStringAsFixed(2)}';
      final paidStr = '₹${appointment.paid.toStringAsFixed(2)}';

      final prescriptionStr = appointment.prescriptions.isNotEmpty
          ? appointment.prescriptions.join(', ')
          : '';

      final treatmentStr = appointment.selectedTreatments.isNotEmpty
          ? appointment.selectedTreatments.join(', ')
          : '';

      final teethStr = appointment.selectedTeeth.isNotEmpty
          ? appointment.selectedTeeth.join(', ')
          : '';

      final patientName = appointment.patient?.title ?? '';

      return PatientDetailRow(
          date: dateStr,
          cost: costStr,
          paid: paidStr,
          prescription: prescriptionStr,
          treatment: treatmentStr,
          teeth: teethStr,
          isDone: appointment.isDone,
          patientName: patientName);
    }).toList();
  }
}

final List<Treatment> allTreatments = [
  Treatment(name: 'Follow-up', price: 0),
  Treatment(name: 'Consultation', price: 100),
  Treatment(name: 'IOPA (X-ray)', price: 100),
  Treatment(name: 'GIC', price: 500),
  Treatment(name: 'Ant Composite', price: 1000),
  Treatment(name: 'Post Composite', price: 800),
  Treatment(name: 'Localized Scaling', price: 200),
  Treatment(name: 'Scaling', price: 800),
  Treatment(name: 'Scaling & Polishing', price: 1000),
  Treatment(name: 'RCT', price: 3000),
  Treatment(name: 'PFM Crowns', price: 3000),
  Treatment(name: 'Zirconia Crowns', price: 6000),
  Treatment(name: 'Normal Extraction', price: 800),
  Treatment(name: 'Wisdom Teeth Extraction', price: 1000),
  Treatment(name: 'Impaction', price: 2500),
];

final appointments = Appointments();
