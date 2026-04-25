import 'package:apexo/services/archived.dart';
import 'package:apexo/services/launch.dart';
import 'package:apexo/services/network.dart';
import 'package:apexo/utils/hash.dart';
import 'package:apexo/utils/demo_generator.dart';
import 'doctor_model.dart';
import '../../services/login.dart';
import '../../core/save_local.dart';
import '../../core/save_remote.dart';
import '../network_actions/network_actions_controller.dart';
import '../../core/store.dart';

const _storeName = "doctors";

class Doctors extends Store<Doctor> {
  Doctors()
      : super(
          modeling: Doctor.fromJson,
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
    login.activators[_storeName] = () async {
      await loaded;
      local = SaveLocal(name: _storeName, uniqueId: simpleHash(login.url));
      await deleteMemoryAndLoadFromPersistence();

      if (launch.isDemo) {
        if (docs.isEmpty) setAll(demoDoctors(5));
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

  Doctor? getByEmail(String email) {
    for (var member in present.values) {
      if (member.email == email) return member;
    }
    return null;
  }
}

final doctors = Doctors();
// don't forget to initialize it in main.dart
