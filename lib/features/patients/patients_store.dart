import 'dart:async';

import 'package:apexo/core/activity_logger.dart';
import 'package:apexo/features/appointments/appointments_store.dart';
import 'package:apexo/features/labwork/labworks_store.dart';
import 'package:apexo/services/archived.dart';
import 'package:apexo/services/launch.dart';
import 'package:apexo/services/network.dart';
import 'package:apexo/utils/hash.dart';
import 'package:apexo/utils/demo_generator.dart';

import 'patient_model.dart';
import '../../services/login.dart';
import '../../core/observable.dart';
import '../../core/save_local.dart';
import '../../core/save_remote.dart';
import '../network_actions/network_actions_controller.dart';
import '../../core/store.dart';

const _storeName = "patients";

class Patients extends Store<Patient> {
  final Map<String, ({String title, String phone})> _coreSnapshot = {};
  Timer? _integrityAuditDebounce;

  Patients()
      : super(
          modeling: Patient.fromJson,
          isDemo: launch.isDemo,
          showArchived: showArchived,
          onSyncStart: () {
            networkActions.isSyncing(networkActions.isSyncing() + 1);
          },
          onSyncEnd: () {
            networkActions.isSyncing(networkActions.isSyncing() - 1);
          },
        );

  @override
  init() {
    super.init();

    _primeSnapshot();
    observableMap.observe((events) {
      _auditCoreFieldLoss(events);
      _scheduleIntegrityAudit();
    });
    appointments.observableMap.observe((_) => _scheduleIntegrityAudit());
    labworks.observableMap.observe((_) => _scheduleIntegrityAudit());

    login.activators[_storeName] = () async {
      await loaded;

      local = SaveLocal(name: _storeName, uniqueId: simpleHash(login.url));
      await deleteMemoryAndLoadFromPersistence();
      _primeSnapshot();

      if (launch.isDemo) {
        if (docs.isEmpty) setAll(demoPatients(100));
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

  List<String> get allTags {
    return Set<String>.from(present.values.expand((doc) => doc.tags)).toList();
  }

  @override
  void set(Patient item) {
    final existing = get(item.id);
    if (_looksSparse(item)) {
      if (existing == null) {
        ActivityLogger.logAction(
          'Blocked sparse patient write',
          screen: 'PatientsStore',
          data: {'id': item.id},
        );
        return;
      }

      item
        ..title = existing.title
        ..birth = existing.birth
        ..gender = existing.gender
        ..phone = existing.phone
        ..email = existing.email
        ..address = existing.address
        ..tags = List<String>.from(existing.tags)
        ..teeth = Map<String, String>.from(existing.teeth)
        ..referralSource = existing.referralSource;

      ActivityLogger.logAction(
        'Merged sparse patient write with existing fields',
        screen: 'PatientsStore',
        data: {'id': item.id},
      );
    }

    super.set(item);
  }

  @override
  void setAll(List<Patient> items) {
    for (final item in items) {
      set(item);
    }
  }

  @override
  Future<void> hardDelete(String id) async {
    final hasAppointments =
        appointments.docs.values.any((a) => a.patientID == id);
    final hasLabworks = labworks.docs.values.any((lw) => lw.patientID == id);
    if (hasAppointments || hasLabworks) {
      ActivityLogger.logAction(
        'Blocked patient hard-delete due references',
        screen: 'PatientsStore',
        data: {
          'id': id,
          'hasAppointments': hasAppointments,
          'hasLabworks': hasLabworks,
        },
      );
      throw StateError(
        'Patient cannot be hard-deleted because appointments/labworks still reference this patient.',
      );
    }
    await super.hardDelete(id);
  }

  PatientIntegrityAuditResult runIntegrityAudit() {
    final referencedIds = <String>{};

    for (final appointment in appointments.docs.values) {
      final pid = appointment.patientID;
      if (pid != null && pid.isNotEmpty) {
        referencedIds.add(pid);
      }
    }

    for (final lw in labworks.docs.values) {
      final pid = lw.patientID;
      if (pid != null && pid.isNotEmpty) {
        referencedIds.add(pid);
      }
    }

    final missing = <String>[];
    final sparse = <String>[];

    for (final id in referencedIds) {
      final patient = get(id);
      if (patient == null) {
        missing.add(id);
        continue;
      }
      if (patient.title.trim().isEmpty || patient.phone.trim().isEmpty) {
        sparse.add(id);
      }
    }

    missing.sort();
    sparse.sort();

    if (missing.isNotEmpty || sparse.isNotEmpty) {
      ActivityLogger.logAction(
        'Patient integrity audit issues detected',
        screen: 'PatientsStore',
        data: {
          'missingCount': missing.length,
          'sparseCount': sparse.length,
          'missingIds': missing.take(20).toList(growable: false),
          'sparseIds': sparse.take(20).toList(growable: false),
        },
      );
    }

    return PatientIntegrityAuditResult(
      referencedCount: referencedIds.length,
      missingPatientIds: missing,
      sparsePatientIds: sparse,
    );
  }

  bool _looksSparse(Patient p) {
    final hasText = p.title.trim().isNotEmpty ||
        p.phone.trim().isNotEmpty ||
        p.email.trim().isNotEmpty ||
        p.address.trim().isNotEmpty ||
        p.referralSource.trim().isNotEmpty;
    final hasStructured =
        p.tags.isNotEmpty || p.teeth.isNotEmpty || p.birth > 0;
    return !hasText && !hasStructured;
  }

  void _primeSnapshot() {
    for (final entry in docs.entries) {
      _coreSnapshot[entry.key] = (
        title: entry.value.title.trim(),
        phone: entry.value.phone.trim(),
      );
    }
  }

  void _auditCoreFieldLoss(List<DictEvent> events) {
    for (final event in events) {
      if (event.type == DictEventType.remove) {
        _coreSnapshot.remove(event.id);
        continue;
      }

      final current = get(event.id);
      if (current == null) {
        _coreSnapshot.remove(event.id);
        continue;
      }

      final previous = _coreSnapshot[event.id];
      final currentTitle = current.title.trim();
      final currentPhone = current.phone.trim();

      if (previous != null) {
        final lostTitle = previous.title.isNotEmpty && currentTitle.isEmpty;
        final lostPhone = previous.phone.isNotEmpty && currentPhone.isEmpty;
        if (lostTitle || lostPhone) {
          ActivityLogger.logAction(
            'Patient core fields dropped unexpectedly',
            screen: 'PatientsStore',
            data: {
              'id': event.id,
              'lostTitle': lostTitle,
              'lostPhone': lostPhone,
              'oldTitle': previous.title,
              'oldPhone': previous.phone,
            },
          );
        }
      }

      _coreSnapshot[event.id] = (title: currentTitle, phone: currentPhone);
    }
  }

  void _scheduleIntegrityAudit() {
    _integrityAuditDebounce?.cancel();
    _integrityAuditDebounce =
        Timer(const Duration(seconds: 2), runIntegrityAudit);
  }

  Future<PatientIntegrityAuditResult> runIntegrityAuditAsync() async {
    await loaded;
    return runIntegrityAudit();
  }
}

class PatientIntegrityAuditResult {
  final int referencedCount;
  final List<String> missingPatientIds;
  final List<String> sparsePatientIds;

  const PatientIntegrityAuditResult({
    required this.referencedCount,
    required this.missingPatientIds,
    required this.sparsePatientIds,
  });

  bool get hasIssues =>
      missingPatientIds.isNotEmpty || sparsePatientIds.isNotEmpty;
}

final patients = Patients();
// don't forget to initialize it in main.dart
