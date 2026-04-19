import 'dart:convert';

import 'package:apexo/app/routes.dart';
import 'package:apexo/core/observable.dart';
import 'package:apexo/services/launch.dart';
import 'package:apexo/utils/logger.dart';
import 'package:apexo/services/login.dart';

enum UserRole {
  admin,
  receptionist,
  doctor,
}

class _Permissions extends ObservablePersistingObject {
  static const int doctorsPermissionIndex = 0;
  static const int patientsPermissionIndex = 1;
  static const int appointmentsPermissionIndex = 2;
  static const int labworksPermissionIndex = 3;
  static const int expensesPermissionIndex = 4;
  static const int statisticsPermissionIndex = 5;

  static const List<bool> _allAccess = [
    true,
    true,
    true,
    true,
    true,
    true,
  ];

  static const List<bool> _receptionistDefaults = [
    false,
    true,
    true,
    false,
    true,
    false,
  ];

  static const List<bool> _doctorDefaults = [
    false,
    true,
    true,
    true,
    false,
    false,
  ];

  List<bool> list = launch.isDemo
      ? [..._allAccess]
      : [..._receptionistDefaults];
  List<bool> editingList = [..._receptionistDefaults];
  List<bool> doctorList = launch.isDemo ? [..._allAccess] : [..._doctorDefaults];
  List<bool> editingDoctorList = [..._doctorDefaults];

  UserRole? get _roleFromAuthRecord {
    final record = login.pb?.authStore.record;
    if (record == null) return null;

    const keys = ['role', 'userRole', 'user_type', 'userType', 'permission'];
    for (final key in keys) {
      final raw = record.data[key]?.toString().trim().toLowerCase();
      if (raw == null || raw.isEmpty) continue;
      if (raw == '0' || raw == 'admin') return UserRole.admin;
      if (raw == '1' || raw == 'reception' || raw == 'receptionist') {
        return UserRole.receptionist;
      }
      if (raw == '2' || raw == 'doctor') return UserRole.doctor;
    }

    return null;
  }

  UserRole get currentRole {
    if (login.isAdmin) return UserRole.admin;
    final recordRole = _roleFromAuthRecord;
    if (recordRole != null) return recordRole;
    if (login.currentMember != null) return UserRole.doctor;
    return UserRole.receptionist;
  }

  String get currentRoleLabel {
    switch (currentRole) {
      case UserRole.admin:
        return 'Admin';
      case UserRole.receptionist:
        return 'Receptionist';
      case UserRole.doctor:
        return 'Doctor';
    }
  }

  List<bool> get currentRolePermissions {
    if (login.isAdmin) return _allAccess;
    if (currentRole == UserRole.doctor) return doctorList;
    return list;
  }

  bool hasAccess(int index) {
    if (login.isAdmin) return true;
    final rolePermissions = currentRolePermissions;
    if (index < 0 || index >= rolePermissions.length) return false;
    return rolePermissions[index];
  }

  bool canAccessByRouteIdentifier(String routeIdentifier) {
    if (currentRole != UserRole.admin) {
      return routeIdentifier == 'checkin';
    }

    switch (routeIdentifier) {
      case 'doctors_v2':
        return true;
      case 'labworks':
        return true;
      case 'patients':
        return true;
      case 'calendar':
      case 'checkin':
        return true;
      case 'expenses':
        return true;
      case 'report_v2':
        return true;
      default:
        return true;
    }
  }

  bool get edited {
    return jsonEncode(editingList) != jsonEncode(list) ||
        jsonEncode(editingDoctorList) != jsonEncode(doctorList);
  }

  List<bool> _normalizeRolePermissions(
    dynamic value,
    List<bool> fallback,
  ) {
    if (value is List) {
      final normalized = value.map((e) => e == true).toList(growable: true);
      if (normalized.length < fallback.length) {
        normalized.addAll(
          List.generate(fallback.length - normalized.length, (_) => false),
        );
      }
      if (normalized.length > fallback.length) {
        return normalized.sublist(0, fallback.length);
      }
      return normalized;
    }
    return [...fallback];
  }

  void _refreshRoutes() {
    routes.allRoutes = routes.genAllRoutes();
    final current = routes.currentRoute;
    if (!current.accessible) {
      final checkinIndex = routes.allRoutes.indexWhere(
        (route) => route.identifier == 'checkin' && route.accessible,
      );
      if (checkinIndex >= 0) {
        routes.currentRouteIndex(checkinIndex);
        return;
      }

      final firstAccessibleIndex = routes.allRoutes.indexWhere(
        (route) => route.accessible,
      );
      routes.currentRouteIndex(firstAccessibleIndex >= 0 ? firstAccessibleIndex : 0);
      return;
    }

    routes.currentRouteIndex(routes.currentRouteIndex());
  }

  reset() {
    editingList = [...list];
    editingDoctorList = [...doctorList];
    notifyAndPersist();
  }

  save() async {
    try {
      final permissionPayload = {
        'receptionist': editingList,
        'doctor': editingDoctorList,
      };
      await login.pb!.collection("data").update("permissions____", body: {
        "data": {
          "id": "permissions____",
          "value": jsonEncode(permissionPayload),
          "date": DateTime.now().millisecondsSinceEpoch,
        }
      });
    } catch (e, s) {
      logger("Error while saving permissions: $e", s);
    }

    await reloadFromRemote();
    notifyAndPersist();
  }

  Future<void> reloadFromRemote() async {
    if (login.pb == null || login.token.isEmpty || login.pb!.authStore.isValid == false) {
      return;
    }
    notifyAndPersist();
    try {
      final rawValue = (await login.pb!
          .collection("data")
          .getOne("permissions____")).get<Map<String, dynamic>>("data")["value"];
      final decoded = jsonDecode(rawValue.toString());

      if (decoded is List) {
        list = _normalizeRolePermissions(decoded, _receptionistDefaults);
        doctorList = [..._doctorDefaults];
      } else if (decoded is Map<String, dynamic>) {
        list = _normalizeRolePermissions(
          decoded['receptionist'],
          _receptionistDefaults,
        );
        doctorList = _normalizeRolePermissions(
          decoded['doctor'],
          _doctorDefaults,
        );
      } else {
        list = [..._receptionistDefaults];
        doctorList = [..._doctorDefaults];
      }

      editingList = [...list];
      editingDoctorList = [...doctorList];
    } catch (e, s) {
      logger("Error when getting full list of permissions service: $e", s);
    }
    notifyAndPersist();
    _refreshRoutes();
  }

  _Permissions() : super("permissions");

  @override
  fromJson(Map<String, dynamic> json) {
    final localList = json["list"];
    final localDoctorList = json["doctorList"];

    list = _normalizeRolePermissions(localList, _receptionistDefaults);
    doctorList = _normalizeRolePermissions(localDoctorList, _doctorDefaults);

    if (launch.isDemo) {
      list = [..._allAccess];
      doctorList = [..._allAccess];
    }

    editingList = [...list];
    editingDoctorList = [...doctorList];
    _refreshRoutes();
    reloadFromRemote();
  }

  @override
  Map<String, dynamic> toJson() {
    return {
      "list": list,
      "doctorList": doctorList,
    };
  }
}

final permissions = _Permissions();
