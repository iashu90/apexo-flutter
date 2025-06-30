import '../../core/store.dart';
import 'prescriptions_model.dart';
import '../../core/save_local.dart';
import '../../core/save_remote.dart';
import '../../services/login.dart';
import '../../services/network.dart';
import '../network_actions/network_actions_controller.dart';
import '../../services/launch.dart';
import 'package:apexo/utils/hash.dart';
import '../../services/archived.dart';
import '../../features/login/login_controller.dart';

const _storeName = "prescriptions";
List<String>? _prescriptions;

class PrescriptionsStore extends Store<Prescriptions> {
  PrescriptionsStore()
      : super(
          modeling: (json) => Prescriptions.fromJson(json),
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
    observableMap.observe((_) => _prescriptions = null);
    observableMap.observe((_) {
      for (var prescription in observableMap.values) {
        print(prescription);
      }
    });
    login.activators[_storeName] = () async {
      await loaded;
      local = SaveLocal(name: _storeName, uniqueId: simpleHash(login.url));
      await deleteMemoryAndLoadFromPersistence();
      if (launch.isDemo) {
        if (docs.isEmpty) setAll([]); // Optionally add demo data
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
        loginCtrl.loadingIndicator("Synchronizing prescriptions");
        await synchronize();
        networkActions.syncCallbacks[_storeName] = synchronize;
        networkActions.reconnectCallbacks[_storeName] = remote!.checkOnline;
        network.onOnline[_storeName] = synchronize;
        network.onOffline[_storeName] = cancelRealtimeSub;
      };
    };
  }

  List<String> get prescriptions {
    return present.values.map((p) => p.prescription).toList();
  }
}

final prescriptionsStore = PrescriptionsStore();
