import 'dart:convert';

import 'package:apexo/core/observable.dart';
import 'package:apexo/features/login/login_controller.dart';
import 'package:apexo/services/archived.dart';
import 'package:apexo/services/launch.dart';
import 'package:apexo/services/network.dart';
import 'package:apexo/utils/hash.dart';
import 'package:apexo/services/admins.dart';
import 'package:apexo/services/backups.dart';
import 'package:apexo/services/permissions.dart';
import 'package:apexo/services/users.dart';
import 'package:fluent_ui/fluent_ui.dart';
import '../../core/save_local.dart';
import '../../core/save_remote.dart';
import '../network_actions/network_actions_controller.dart';
import '../../services/login.dart';
import 'settings_model.dart';
import '../../core/store.dart';

const _storeNameGlobal = "settings_global";
const _storeNameLocal = "settings_local";

class GlobalSettings extends Store<Setting> {
  Map<String, String> defaults = {
    "currency_______": "USD",
    "phone__________": "1234567890",
    "prescriptionFot": "",
    "permissions____": jsonEncode({
      "receptionist": [false, true, true, false, true, false, true],
      "doctor": [false, true, true, true, false, false, false],
    }),
    "start_day_of_wk": "monday",
  };

  @override
  Setting get(String id) {
    return super.get(id) ?? Setting.fromJson({"id": id, "value": defaults[id]});
  }

  GlobalSettings()
      : super(
          modeling: Setting.fromJson,
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
    login.activators[_storeNameGlobal] = () async {
      await loaded;

      local = SaveLocal(name: _storeNameGlobal, uniqueId: simpleHash(login.url));
      await deleteMemoryAndLoadFromPersistence();

      remote = SaveRemote(
        pbInstance: login.pb!,
        storeName: _storeNameGlobal,
        onOnlineStatusChange: (current) {
          if (network.isOnline() != current) {
            network.isOnline(current);
          }
        },
      );

      return () async {
        loginCtrl.loadingIndicator("Synchronizing settings");
        await Future.wait([loaded, synchronize()]).then((_) {
          defaults.forEach((key, value) {
            if (has(key) == false) {
              set(Setting.fromJson({"id": key, "value": value}));
            }
          });
        });
        networkActions.syncCallbacks[_storeNameGlobal] = () async {
          await Future.wait([
            synchronize(),
            admins.reloadFromRemote(),
            backups.reloadFromRemote(),
            users.reloadFromRemote(),
            permissions.reloadFromRemote()
          ]);
        };
        networkActions.reconnectCallbacks[_storeNameGlobal] = remote!.checkOnline;

        network.onOnline[_storeNameGlobal] = synchronize;
        network.onOffline[_storeNameGlobal] = cancelRealtimeSub;

        // setting services
        await Future.wait([
          admins.reloadFromRemote(),
          backups.reloadFromRemote(),
          users.reloadFromRemote(),
          permissions.reloadFromRemote()
        ]);
      };
    };
  }
}

class LocalSettings extends ObservablePersistingObject {
  LocalSettings() : super(_storeNameLocal);

  String dateFormat = "dd/MM/yyyy";
  ThemeMode selectedTheme = ThemeMode.light;
  Map<String, String> savedLabs = {};

  @override
  fromJson(Map<String, dynamic> json) {
    dateFormat = json["dateFormat"] ?? dateFormat;
    selectedTheme = json["selectedTheme"] == 1 ? ThemeMode.dark : ThemeMode.light;
    final rawSavedLabs = json["savedLabs"];
    if (rawSavedLabs is Map) {
      savedLabs = rawSavedLabs.map(
        (key, value) => MapEntry(
          key.toString().trim(),
          value?.toString().trim() ?? '',
        ),
      )..removeWhere((key, _) => key.isEmpty);
    }
  }

  @override
  Map<String, dynamic> toJson() {
    return {
      "dateFormat": dateFormat,
      "selectedTheme": selectedTheme == ThemeMode.dark ? 1 : 0,
      "savedLabs": savedLabs,
    };
  }
}

final globalSettings = GlobalSettings();
final localSettings = LocalSettings();
