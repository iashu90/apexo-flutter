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
import 'expense_model.dart';
import '../../core/store.dart';

const _storeName = "expenses";

class Expenses extends Store<Expense> {
  Expenses()
      : super(
          modeling: Expense.fromJson,
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
        if (docs.isEmpty) setAll(demoExpenses(100));
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
        loginCtrl.loadingIndicator("Synchronizing expenses");
        print("Before clear: ${docs.length}");
        await local?.clear();
        print(
            "Local expenses box keys after clear: ${(await local!.mainHiveBox).keys}");
        await deleteMemoryAndLoadFromPersistence();
        print("After clear: ${docs.length}");
        await synchronize();
        print("After sync: ${docs.length}");
        networkActions.syncCallbacks[_storeName] = synchronize;
        networkActions.reconnectCallbacks[_storeName] = remote!.checkOnline;

        network.onOnline[_storeName] = synchronize;
        network.onOffline[_storeName] = cancelRealtimeSub;
      };
    };
  }

  List<String> get allIssuers {
    Set<String> issuers = {};
    for (var doc in docs.values) {
      issuers.add(doc.issuer);
    }
    return issuers.toList();
  }

  List<String> get allTags {
    Set<String> tags = {};
    for (var doc in docs.values) {
      for (var tag in doc.tags) {
        tags.add(tag);
      }
    }
    return tags.toList();
  }

  List<String> get allItems {
    Set<String> items = {};
    for (var doc in docs.values) {
      for (var item in doc.items) {
        items.add(item);
      }
    }
    return items.toList();
  }

  List<String> get allPhones {
    Set<String> phones = {};
    for (var doc in docs.values) {
      phones.add(doc.phoneNumber);
    }
    return phones.toList();
  }

  String? getPhoneNumber(String issuer) {
    for (var doc in docs.values) {
      if (doc.issuer == issuer) {
        return doc.phoneNumber;
      }
    }
    return null;
  }
}

final expenses = Expenses();
