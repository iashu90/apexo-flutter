import 'package:apexo/app/routes.dart';
import 'package:apexo/features/login/login_controller.dart';
import 'package:apexo/services/launch.dart';
import 'package:apexo/utils/constants.dart';
import 'package:apexo/utils/encode.dart';
import 'package:apexo/utils/init_pocketbase.dart';
import 'package:apexo/utils/logger.dart';
import 'package:apexo/features/doctors/doctor_model.dart';
import 'package:apexo/features/doctors/doctors_store.dart';
import '../core/observable.dart';
import 'package:pocketbase/pocketbase.dart';

class _LoginService extends ObservablePersistingObject {
  _LoginService(super.identifier);

  String url = "";
  String email = "";
  String password = "";
  String token = "";
  String adminCollectionId = "__UNDEFINED__";

  String get currentUserID {
    if (token.isEmpty) return "";
    if (pb == null) return "";
    if (pb!.authStore.record == null) return "";
    return pb!.authStore.record!.id;
  }

  // PocketBase instance
  PocketBase? pb;

  Doctor? get currentMember {
    return doctors.getByEmail(email);
  }

  bool get isAdmin {
    final tokenSegments = token.split(".");
    if (tokenSegments.length == 3 && decode(tokenSegments[1]).contains(adminCollectionId)) {
      return true;
    }

    if (pb == null) return false;
    if (pb!.authStore.isValid == false) return false;
    if (pb!.authStore.record == null) return false;
    return pb!.authStore.record!.collectionName == "_superusers";
  }

  void logout() {
    launch.open(false);
    url = "";
    email = "";
    password = "";
    token = "";
    pb!.authStore.clear();
    notifyAndPersist();
    routes.panels([]);
    return loginCtrl.finishedLoginProcess();
  }

  Future<String> authenticateWithPassword(String email, String password) async {
    try {
      final auth = await pb!.collection("_superusers").authWithPassword(email, password);
      adminCollectionId = auth.record.collectionId;
      return auth.token;
    } catch (e) {
      final auth = await pb!.collection("users").authWithPassword(email, password);
      return auth.token;
    }
  }

  Future<String> authenticateWithToken(String token) async {
    try {
      final auth = await pb!.collection("_superusers").authRefresh();
      adminCollectionId = auth.record.collectionId;
      return auth.token;
    } catch (e) {
      final auth = await pb!.collection("users").authRefresh();
      return auth.token;
    }
  }

  /// run a series of callbacks that would require the login credentials to be active
  activate(String inputURL, List<String> credentials, bool online) async {
    if ((pb == null || pb?.baseURL.isEmpty == true) || !launch.open()) {
      pb = PocketBase(inputURL);
    }

    loginCtrl.loadingIndicator("Connecting to the server");
    loginCtrl.loginError("");

    if (url.isNotEmpty) {
      url = inputURL;
    }

    if (online && launch.isDemo == false) {
      try {
        // email and password authentication
        if (credentials.length == 2) {
          token = await authenticateWithPassword(credentials[0], credentials[1]);
          email = credentials[0];
          url = inputURL;
        }
        // token authentication
        if (credentials.length == 1) {
          pb!.authStore.save(credentials[0], null);
          if (pb!.authStore.isValid == false) {
            throw Exception("Invalid token");
          }
          token = await authenticateWithToken(token);
          url = inputURL;
        }

        // create database if it doesn't exist
        try {
          try {
            loginCtrl.loadingIndicator("Verifying collections");
            await pb!.collection(dataCollectionName).getList(page: 1, perPage: 1);
            await pb!.collection(publicCollectionName).getList(page: 1, perPage: 1);
          } catch (e) {
            launch.isFirstLaunch(true);
            if (isAdmin) {
              loginCtrl.loadingIndicator("Creating collections for the first time");
              await initializePocketbase(pb!);
            } else {
              logger(
                "ERROR: The first login must be done by an admin user. Please contact the admin to create the database.",
                StackTrace.current,
              );
            }
          }
        } catch (e) {
          throw Exception("Error while creating the collection for the first time: $e");
        }
      } catch (e, s) {
        if (e.runtimeType != ClientException) {
          loginCtrl.loginError("Error while logging-in: $e.");
        } else if ((e as ClientException).statusCode == 404) {
          loginCtrl.loginError("Invalid server, make sure PocketBase is installed and running.");
        } else if (e.statusCode == 400) {
          loginCtrl.loginError("Invalid email or password.");
        } else if (e.statusCode == 0) {
          loginCtrl.loginError(
              "Unable to connect, please check your internet connection, firewall, or the server URL field.");
        } else {
          loginCtrl.loginError("Unknown client exception while authenticating: $e.");
        }
        logger("Could not login due to the following error: $e", s, 2);
        return loginCtrl.finishedLoginProcess(loginCtrl.loginError());
      }

      loginCtrl.proceededOffline(false);
    }

    /// if we reached here it means it was a successful login

    for (var callback in activators.values) {
      try {
        final secondStage = await callback();
        if (online && launch.isDemo == false) await secondStage();
        notifyAndPersist(); // this would persist the data to the disk so we don't have to login again
      } catch (e, s) {
        logger("Error during running activators: $e", s);
      }
    }

    launch.open(true);
    return loginCtrl.finishedLoginProcess();
  }

  /// activators are a series of callbacks that run after a successful login
  /// each activator function would first connect to local storage then return another callback
  /// the second callback (would be called only when online) connects to the server
  /// and synchronizes the local storage with the server
  Map<String, Future<Future<void> Function()> Function()> activators = {};

  @override
  fromJson(Map<String, dynamic> json) async {
    url = json["url"] ?? url;
    email = json["email"] ?? email;
    token = json["token"] ?? token;
    adminCollectionId = json["adminCollectionId"] ?? adminCollectionId;
    loginCtrl.urlField.text = url;
    loginCtrl.emailField.text = email;
    if (token.isNotEmpty) {
      await activate(url, [token], true);
    } else {
      launch.open(false);
    }
  }

  @override
  Map<String, dynamic> toJson() {
    final Map<String, dynamic> json = {};
    json['url'] = url;
    json['email'] = email;
    json["token"] = token;
    json["adminCollectionId"] = adminCollectionId;
    return json;
  }
}

final login = _LoginService("main-state");
