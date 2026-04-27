import 'dart:async';

import 'package:apexo/app/routes.dart';
import 'package:apexo/core/save_local.dart';
import 'package:apexo/core/store.dart';
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

const String loginLocalServerUrl = 'http://127.0.0.1:8090';
const String loginRemoteServerUrl = 'http://34.105.117.49:8090';

class _LoginService extends ObservablePersistingObject {
  _LoginService(super.identifier);

  String url = "";
  String email = "";
  String password = "F";
  String token = "";
  String adminCollectionId = "__UNDEFINED__";
  String serverMode = 'server';
  String customServerUrl = '';
  String rememberedEmail = '';
  String rememberedPassword = '';
  int rememberUntilEpochMs = 0;

  String get currentUserID {
    if (token.isEmpty) return "";
    if (pb == null) return "";
    if (pb!.authStore.record == null) return "";
    return pb!.authStore.record!.id;
  }

  // PocketBase instance
  PocketBase? pb;
  final Set<String> _backgroundSecondStageStarted = {};

  Doctor? get currentMember {
    return doctors.getByEmail(email);
  }

  bool get isAdmin {
    final tokenSegments = token.split(".");
    if (tokenSegments.length == 3 &&
        decode(tokenSegments[1]).contains(adminCollectionId)) {
      return true;
    }

    if (pb == null) return false;
    if (pb!.authStore.isValid == false) return false;
    if (pb!.authStore.record == null) return false;
    return pb!.authStore.record!.collectionName == "_superusers";
  }

  String _urlForMode(String mode) {
    if (mode == 'local') return loginLocalServerUrl;
    if (mode == 'custom') {
      final custom = customServerUrl.trim();
      return custom.isEmpty ? loginRemoteServerUrl : custom;
    }
    return loginRemoteServerUrl;
  }

  bool get hasValidRememberedCredentials {
    if (rememberedEmail.trim().isEmpty || rememberedPassword.isEmpty) {
      return false;
    }
    return DateTime.now().millisecondsSinceEpoch <= rememberUntilEpochMs;
  }

  void applyServerMode(String mode, {String? customUrl}) {
    if (customUrl != null) {
      customServerUrl = customUrl.trim();
    }
    if (mode == 'local') {
      serverMode = 'local';
    } else if (mode == 'custom') {
      serverMode = 'custom';
    } else {
      serverMode = 'server';
    }
    url = _urlForMode(serverMode);
    loginCtrl.urlField.text = url;
    notifyAndPersist();
  }

  void setRememberedCredentials({
    required bool enable,
    required String email,
    required String password,
  }) {
    if (enable) {
      rememberedEmail = email;
      rememberedPassword = password;
      rememberUntilEpochMs = DateTime.now()
          .add(const Duration(days: 1))
          .millisecondsSinceEpoch;
    } else {
      rememberedEmail = '';
      rememberedPassword = '';
      rememberUntilEpochMs = 0;
    }
    notifyAndPersist();
  }

  void logout() {
    Store.clearAllInMemory();
    final clearTasks = List<ClearingFunction>.from(removeAllLocalData);
    unawaited(Future.wait(clearTasks.map((task) => task())));

    launch.open(false);
    url = "";
    email = "";
    password = "";
    token = "";
    pb?.authStore.clear();
    if (hasValidRememberedCredentials) {
      loginCtrl.emailField.text = rememberedEmail;
      loginCtrl.passwordField.text = rememberedPassword;
      loginCtrl.rememberMeForDay(true);
    } else {
      loginCtrl.emailField.clear();
      loginCtrl.passwordField.clear();
      loginCtrl.rememberMeForDay(false);
    }
    notifyAndPersist();
    routes.panels([]);
    return loginCtrl.finishedLoginProcess();
  }

  Future<String> authenticateWithPassword(String email, String password) async {
    try {
      final auth =
          await pb!.collection("_superusers").authWithPassword(email, password);
      adminCollectionId = auth.record.collectionId;
      return auth.token;
    } catch (e) {
      final auth =
          await pb!.collection("users").authWithPassword(email, password);
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
          token =
              await authenticateWithPassword(credentials[0], credentials[1]);
          email = credentials[0];
          password = credentials[1];
          url = inputURL;
          setRememberedCredentials(
            enable: loginCtrl.rememberMeForDay(),
            email: credentials[0],
            password: credentials[1],
          );
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
            await pb!
                .collection(dataCollectionName)
                .getList(page: 1, perPage: 1);
            await pb!
                .collection(publicCollectionName)
                .getList(page: 1, perPage: 1);
          } catch (e) {
            launch.isFirstLaunch(true);
            if (isAdmin) {
              loginCtrl
                  .loadingIndicator("Creating collections for the first time");
              await initializePocketbase(pb!);
            } else {
              logger(
                "ERROR: The first login must be done by an admin user. Please contact the admin to create the database.",
                StackTrace.current,
              );
            }
          }
        } catch (e) {
          throw Exception(
              "Error while creating the collection for the first time: $e");
        }
      } catch (e, s) {
        if (e.runtimeType != ClientException) {
          loginCtrl.loginError("Error while logging-in: $e.");
        } else if ((e as ClientException).statusCode == 404) {
          loginCtrl.loginError(
              "Invalid server, make sure PocketBase is installed and running.");
        } else if (e.statusCode == 400) {
          loginCtrl.loginError("Invalid email or password.");
        } else if (e.statusCode == 0) {
          loginCtrl.loginError(
              "Unable to connect, please check your internet connection, firewall, or the server URL field.");
        } else {
          loginCtrl
              .loginError("Unknown client exception while authenticating: $e.");
        }
        logger("Could not login due to the following error: $e", s, 2);
        return loginCtrl.finishedLoginProcess(loginCtrl.loginError());
      }

      loginCtrl.proceededOffline(false);
    }

    /// if we reached here it means it was a successful login

    final List<({String key, Future<void> Function() run})>
        backgroundSecondStages = [];
    for (var entry in activators.entries) {
      try {
        final secondStage = await entry.value();
        if (online && launch.isDemo == false) {
          if (entry.key == 'settings_global') {
            await secondStage();
          } else {
            backgroundSecondStages.add((key: entry.key, run: secondStage));
          }
        }
        notifyAndPersist(); // this would persist the data to the disk so we don't have to login again
      } catch (e, s) {
        logger("Error during running activators: $e", s);
      }
    }

    launch.open(true);
    if (online && launch.isDemo == false && backgroundSecondStages.isNotEmpty) {
      for (final stage in backgroundSecondStages) {
        if (_backgroundSecondStageStarted.contains(stage.key)) continue;
        _backgroundSecondStageStarted.add(stage.key);
        unawaited(
          Future<void>.delayed(const Duration(milliseconds: 20), () async {
            try {
              await stage.run();
            } catch (e, s) {
              logger(
                'Lazy second-stage setup failed for ${stage.key}: $e',
                s,
              );
            }
          }),
        );
      }

      // Trigger the active screen's sync strategy without blocking login.
      unawaited(
        Future<void>.delayed(const Duration(milliseconds: 140), () async {
          try {
            routes.currentRoute.onSelect?.call();
          } catch (e, s) {
            logger('Lazy route sync trigger failed: $e', s);
          }
        }),
      );
    }
    return loginCtrl.finishedLoginProcess();
  }

  /// activators are a series of callbacks that run after a successful login
  /// each activator function would first connect to local storage then return another callback
  /// the second callback (would be called only when online) connects to the server
  /// and synchronizes the local storage with the server
  Map<String, Future<Future<void> Function()> Function()> activators = {};

  @override
  fromJson(Map<String, dynamic> json) async {
    final savedMode = (json['serverMode'] as String?)?.trim() ?? 'server';
    serverMode = (savedMode == 'local' || savedMode == 'custom')
        ? savedMode
        : 'server';
    customServerUrl = (json['customServerUrl'] as String?)?.trim() ?? '';
    url = (json["url"] as String?)?.trim() ?? '';
    if (url.isEmpty) {
      url = _urlForMode(serverMode);
    }
    email = "";
    token = json["token"] ?? token;
    adminCollectionId = json["adminCollectionId"] ?? adminCollectionId;
    rememberedEmail = json['rememberedEmail'] ?? '';
    rememberedPassword = json['rememberedPassword'] ?? '';
    rememberUntilEpochMs = json['rememberUntilEpochMs'] ?? 0;
    if (!hasValidRememberedCredentials) {
      rememberedEmail = '';
      rememberedPassword = '';
      rememberUntilEpochMs = 0;
    }
    loginCtrl.urlField.text = url;
    loginCtrl.emailField.text = rememberedEmail;
    loginCtrl.passwordField.text = rememberedPassword;
    loginCtrl.rememberMeForDay(hasValidRememberedCredentials);
    launch.open(false);
  }

  @override
  Map<String, dynamic> toJson() {
    final Map<String, dynamic> json = {};
    json['url'] = url;
    json['email'] = email;
    json["token"] = token;
    json["adminCollectionId"] = adminCollectionId;
    json['serverMode'] = serverMode;
    json['customServerUrl'] = customServerUrl;
    json['rememberedEmail'] = rememberedEmail;
    json['rememberedPassword'] = rememberedPassword;
    json['rememberUntilEpochMs'] = rememberUntilEpochMs;
    return json;
  }
}

final login = _LoginService("main-state");
