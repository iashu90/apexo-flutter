import 'dart:async';
import 'dart:convert';
import 'package:apexo/core/activity_logger.dart';
import 'package:apexo/core/model.dart';
import 'package:apexo/core/store.dart';
import 'package:apexo/features/dashboard/dashboard_screen.dart';
import 'package:apexo/features/data/prescriptions_store.dart';
import 'package:apexo/features/expenses/expenses_screen.dart';
import 'package:apexo/features/labwork/labworks_screen.dart';
import 'package:apexo/features/checkin/checkin_screen.dart';
import 'package:apexo/features/doctors/doctors_screen.dart';
import 'package:apexo/features/patients/patients_screen.dart';
import 'package:apexo/features/stats/report_screen.dart';
import 'package:apexo/services/admins.dart';
import 'package:apexo/services/backups.dart';
import 'package:apexo/features/stats/charts_controller.dart';
import 'package:apexo/services/permissions.dart';
import 'package:apexo/services/sync_priority.dart';
import 'package:apexo/features/expenses/expenses_store.dart';
import 'package:apexo/features/labwork/labworks_store.dart';
import 'package:apexo/features/patients/patients_store.dart';
import 'package:apexo/features/doctors/doctors_store.dart';
import 'package:apexo/services/users.dart';
import 'package:fluent_ui/fluent_ui.dart';
import '../services/localization/locale.dart';
import 'package:apexo/features/settings/settings_screen.dart';
import 'package:apexo/features/settings/access_control_screen.dart';
import '../core/observable.dart';
import "../features/appointments/appointments_store.dart";
import "../features/settings/settings_stores.dart";
import 'package:apexo/features/data/data_screen.dart';

class PanelTab {
  final String title;
  final IconData icon;
  final Widget body;
  final double padding;
  final bool onlyIfSaved;
  final Widget? footer;
  PanelTab({
    required this.title,
    required this.icon,
    required this.body,
    this.footer,
    this.onlyIfSaved = false,
    this.padding = 10,
  });
}

class Panel<T extends Model> {
  final T item;
  final Store store;
  final List<PanelTab> tabs;
  final IconData icon;
  String? title;
  final inProgress = ObservableState(false);
  final selectedTab = ObservableState<int>(0);
  final ObservableState<bool> hasUnsavedChanges = ObservableState(false);
  final ObservableState<bool> hasValidTitle = ObservableState(false);
  late String savedJson;
  late String identifier;
  final Completer<T> result = Completer<T>();
  final int creationDate = DateTime.now().millisecondsSinceEpoch;
  Panel({
    required this.item,
    required this.store,
    required this.tabs,
    required this.icon,
    this.title,
  }) {
    identifier =
        store.get(item.id) == null ? "new+${store.local!.name}" : item.id;
    savedJson = jsonEncode(item.toJson());
    hasValidTitle(item.title.isNotEmpty);
  }

  String get storeSingularName {
    return store.local!.name.substring(0, store.local!.name.length - 1);
  }
}

class Route {
  IconData icon;
  String title;
  String identifier;
  Widget Function() screen;
  String navbarTitle;

  /// show in the navigation pane and thus being activated
  bool accessible;

  /// show in the footer of the navigation pane
  bool onFooter;

  /// callback to be called when the route is selected
  void Function()? onSelect;

  Route({
    required this.title,
    required this.identifier,
    required this.icon,
    required this.screen,
    this.navbarTitle = "",
    this.accessible = true,
    this.onFooter = false,
    this.onSelect,
  });
}

class _Routes {
  _Routes() {
    currentRouteIndex.observe((_) {
      final route = currentRoute;
      ActivityLogger.logEvent(
        'Navigation',
        'Route Changed',
        data: {
          'route': route.identifier,
          'title': route.title,
          'historyDepth': history.length,
        },
      );
    });

    panels.observe((_) {
      ActivityLogger.logEvent(
        'Panel',
        'Panels Updated',
        data: {
          'count': panels().length,
          'active': panels().isNotEmpty ? panels().last.identifier : null,
        },
      );
    });
  }

  final ObservableState<List<Panel>> panels = ObservableState([]);
  final minimizePanels = ObservableState(false);
  Timer? _routeSyncDebounce;
  Future<void> Function()? _pendingRouteSync;
  bool _routeSyncRunning = false;

  void _scheduleRouteSync(
    String routeIdentifier,
    Future<void> Function() syncWork,
  ) {
    _pendingRouteSync = syncWork;
    _routeSyncDebounce?.cancel();
    _routeSyncDebounce = Timer(
      const Duration(milliseconds: 280),
      () => _runPendingRouteSync(routeIdentifier),
    );
  }

  Future<void> _runPendingRouteSync(String routeIdentifier) async {
    if (_routeSyncRunning) return;

    while (_pendingRouteSync != null) {
      final work = _pendingRouteSync!;
      _pendingRouteSync = null;
      _routeSyncRunning = true;
      try {
        await syncPriorityDeferral.waitForTypingIdle();
        await work();
      } catch (e, s) {
        ActivityLogger.logException(
          e,
          s,
          'Route sync failed for $routeIdentifier',
        );
      } finally {
        _routeSyncRunning = false;
      }
    }
  }

  void openPanel(Panel panel) {
    final foundPanel = panels()
        .indexWhere((element) => element.identifier == panel.identifier);
    if (foundPanel > -1) {
      // bring to front
      bringPanelToFront(foundPanel);
    } else {
      // add to end
      panels(panels()..add(panel));
      routes.minimizePanels(false);
      ActivityLogger.logEvent(
        'Panel',
        'Panel Opened',
        data: {
          'identifier': panel.identifier,
          'store': panel.store.local?.name,
          'tabs': panel.tabs.length,
        },
      );
    }
  }

  void bringPanelToFront(int index) {
    final target = panels()[index];
    panels(panels()..add(panels().removeAt(index)));
    routes.minimizePanels(false);
    ActivityLogger.logEvent(
      'Panel',
      'Panel Brought To Front',
      data: {
        'identifier': target.identifier,
      },
    );
  }

  List<Route> genAllRoutes() => [
        Route(
          title: txt("dashboard"),
          identifier: "dashboard",
          icon: FluentIcons.home,
          screen: DashboardScreen.new,
          accessible: permissions.canAccessByRouteIdentifier('dashboard'),
          navbarTitle: txt("home"),
          onSelect: () {
            chartsCtrl.resetSelected();
            _scheduleRouteSync('dashboard', () async {
              await patients.synchronize();
              await appointments.synchronize();
            });
          },
        ),
        Route(
          title: 'Doctors',
          identifier: 'doctors',
          icon: FluentIcons.medical,
          screen: DoctorsScreen.new,
          accessible: permissions.canAccessByRouteIdentifier('doctors'),
          navbarTitle: 'Doctors',
          onSelect: () {
            _scheduleRouteSync('doctors', () async {
              await doctors.synchronize();
              await patients.synchronize();
              await appointments.synchronize();
            });
          },
        ),
        Route(
          title: txt("labworks"),
          identifier: "labworks",
          navbarTitle: txt("labworks"),
          icon: FluentIcons.test_beaker,
          screen: LabworksScreen.new,
          accessible: permissions.canAccessByRouteIdentifier('labworks'),
          onSelect: () {
            _scheduleRouteSync('labworks', () async {
              await doctors.synchronize();
              await patients.synchronize();
              await labworks.synchronize();
            });
          },
        ),
        Route(
          title: txt("patients"),
          identifier: "patients",
          navbarTitle: txt("patients"),
          icon: FluentIcons.medication_admin,
          screen: PatientsScreen.new,
          accessible: permissions.canAccessByRouteIdentifier('patients'),
          onSelect: () {
            _scheduleRouteSync('patients', () async {
              await doctors.synchronize();
              await patients.synchronize();
              await appointments.synchronize();
            });
          },
        ),
        Route(
          title: txt("appointments"),
          identifier: "calendar",
          navbarTitle: txt("calendar"),
          icon: FluentIcons.calendar,
          screen: CheckinScreen.new,
          accessible: permissions.canAccessByRouteIdentifier('calendar'),
          onSelect: () {
            _scheduleRouteSync('calendar', () async {
              await doctors.synchronize();
              await patients.synchronize();
              await appointments.synchronize();
            });
          },
        ),
        Route(
          title: 'Checkin',
          identifier: 'checkin',
          navbarTitle: 'Checkin',
          icon: FluentIcons.preview_link,
          screen: CheckinScreen.new,
          accessible: permissions.canAccessByRouteIdentifier('checkin'),
          onSelect: () {
            _scheduleRouteSync('checkin', () async {
              await doctors.synchronize();
              await patients.synchronize();
              await appointments.synchronize();
            });
          },
        ),
        Route(
          title: txt("expenses"),
          identifier: "expenses",
          navbarTitle: txt("expenses"),
          icon: FluentIcons.receipt_processing,
          screen: ExpensesScreen.new,
          accessible: permissions.canAccessByRouteIdentifier('expenses'),
          onSelect: () {
            _scheduleRouteSync('expenses', () async {
              await doctors.synchronize();
              await patients.synchronize();
              await expenses.synchronize();
            });
          },
        ),
        Route(
          title: 'Report',
          identifier: 'report',
          icon: FluentIcons.report_document,
          screen: ReportScreen.new,
          accessible: permissions.canAccessByRouteIdentifier('report'),
          onSelect: () {
            _scheduleRouteSync('report', () async {
              await doctors.synchronize();
              await patients.synchronize();
              await appointments.synchronize();
            });
          },
        ),
        Route(
          title: txt("data"),
          identifier: "data",
          icon: FluentIcons.database,
          screen: DataScreen.new,
          accessible: permissions.canAccessByRouteIdentifier('data'),
          onFooter: false,
          onSelect: () {
            chartsCtrl.resetSelected();
            _scheduleRouteSync('data', () async {
              await doctors.synchronize();
              await patients.synchronize();
              await appointments.synchronize();
              await prescriptionsStore.synchronize();
            });
          },
        ),
        Route(
          title: 'Setting',
          identifier: 'access_control',
          icon: FluentIcons.settings_secure,
          screen: AccessControlScreen.new,
          accessible: permissions.canAccessByRouteIdentifier('access_control'),
          onFooter: false,
          onSelect: () {
            permissions.reloadFromRemote();
          },
        ),
        Route(
          title: txt("settings"),
          identifier: "settings",
          icon: FluentIcons.settings,
          screen: SettingsScreen.new,
          accessible: permissions.canAccessByRouteIdentifier('settings'),
          onFooter: false,
          onSelect: () {
            globalSettings.synchronize();
            admins.reloadFromRemote();
            backups.reloadFromRemote();
            permissions.reloadFromRemote();
            users.reloadFromRemote();
          },
        ),
      ];

  late List<Route> allRoutes = genAllRoutes();
  final showBottomNav = ObservableState(false);
  final bottomNavFlyoutController = FlyoutController();
  final currentRouteIndex = ObservableState(0);
  List<int> history = [];

  int selectedTabInSheet = 0;

  Route get currentRoute {
    if (currentRouteIndex() < 0 || currentRouteIndex() >= allRoutes.length) {
      return allRoutes.first;
    }
    return allRoutes[currentRouteIndex()];
  }

  closePanel(String itemId) {
    panels(panels()..removeWhere((p) => p.item.id == itemId));
    ActivityLogger.logEvent(
      'Panel',
      'Panel Closed',
      data: {
        'itemId': itemId,
      },
    );
  }

  goBack() {
    if (history.isNotEmpty) {
      final previousIndex = history.last;
      currentRouteIndex(history.removeLast());
      ActivityLogger.logEvent(
        'Navigation',
        'Back Navigation',
        data: {
          'toRoute': allRoutes[previousIndex].identifier,
          'historyDepth': history.length,
        },
      );
      if (currentRoute.onSelect != null) {
        currentRoute.onSelect!();
      }
    }
  }

  navigate(Route route) {
    if (currentRouteIndex() == allRoutes.indexOf(route)) return;
    final fromRoute = currentRoute.identifier;
    history.add(currentRouteIndex());
    currentRouteIndex(allRoutes.indexOf(route));
    ActivityLogger.logEvent(
      'Navigation',
      'Route Clicked',
      data: {
        'fromRoute': fromRoute,
        'toRoute': route.identifier,
        'title': route.title,
      },
    );
    if (currentRoute.onSelect != null) {
      currentRoute.onSelect!();
    }
  }

  Route? getByIdentifier(String identifier) {
    var target = allRoutes.where((element) => element.identifier == identifier);
    if (target.isEmpty) return null;
    return target.first;
  }
}

final routes = _Routes();

