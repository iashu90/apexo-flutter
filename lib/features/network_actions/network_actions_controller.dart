import 'package:apexo/features/login/login_controller.dart';
import 'package:apexo/features/settings/settings_stores.dart';
import 'package:apexo/services/launch.dart';
import 'package:apexo/services/network.dart';
import 'package:apexo/core/activity_logger.dart';
import 'package:fluent_ui/fluent_ui.dart';
import '../../services/login.dart';
import '../../core/observable.dart';

class NetworkAction {
  String tooltip;
  IconData iconData;
  void Function()? onPressed;
  Color activeColor;
  bool? hidden;
  bool? disabled;
  bool? processing;
  bool? animate;
  String? badge;
  NetworkAction({
    required this.tooltip,
    required this.iconData,
    required this.onPressed,
    required this.activeColor,
    this.hidden,
    this.disabled,
    this.processing,
    this.animate,
    this.badge,
  });
}

class _NetworkActions {
  final isSyncing = ObservableState(0);

  Map<String, void Function()> syncCallbacks = {};
  Map<String, void Function()> reconnectCallbacks = {};

  Future<void> resync() async {
    ActivityLogger.logEvent(
      'Network',
      'Manual Resync Requested',
      data: {
        'callbacks': syncCallbacks.length,
        'online': network.isOnline(),
      },
    );
    isSyncing(isSyncing() + 1);
    try {
      await login.activate(login.url, [login.token], true);
    } catch (e, s) {
      ActivityLogger.logException(e, s, 'NetworkActions.resync');
      rethrow;
    } finally {
      isSyncing(isSyncing() - 1);
    }

    for (var callback in syncCallbacks.values) {
      callback();
    }

    ActivityLogger.logEvent(
      'Network',
      'Manual Resync Completed',
      data: {
        'callbacks': syncCallbacks.length,
      },
    );
  }

  List<NetworkAction> get actions {
    return [
      NetworkAction(
        tooltip: "Theme",
        iconData: (localSettings.selectedTheme == ThemeMode.light) ? FluentIcons.sunny : FluentIcons.clear_night,
        onPressed: () {
          final nextTheme =
              localSettings.selectedTheme == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
          ActivityLogger.logEvent(
            'UI',
            'Theme Toggled',
            data: {
              'from': localSettings.selectedTheme.name,
              'to': nextTheme.name,
            },
          );
          localSettings.selectedTheme =
              nextTheme;
          localSettings.notifyAndPersist();
        },
        animate: false,
        activeColor: Colors.transparent,
      ),
      NetworkAction(
        tooltip: "Synchronize",
        iconData: FluentIcons.sync,
        onPressed: () async {
          if (launch.isDemo) return;
          await resync();
        },
        badge: isSyncing() > 0 ? "${isSyncing()}" : syncCallbacks.length.toString(),
        disabled: (network.isOnline() == false || isSyncing() > 0 || loginCtrl.proceededOffline()),
        processing: isSyncing() > 0 || loginCtrl.loadingIndicator().isNotEmpty,
        animate: true,
        activeColor: Colors.blue,
      ),
      NetworkAction(
        tooltip: "Reconnect",
        iconData:
            (network.isOnline() && !loginCtrl.proceededOffline()) ? FluentIcons.streaming : FluentIcons.streaming_off,
        onPressed: () async {
          if (launch.isDemo) return;
          ActivityLogger.logEvent(
            'Network',
            'Reconnect Requested',
            data: {
              'callbacks': reconnectCallbacks.length,
              'online': network.isOnline(),
            },
          );
          try {
            await login.activate(login.url, [login.token], true);
            for (var callback in reconnectCallbacks.values) {
              callback();
            }
            ActivityLogger.logEvent(
              'Network',
              'Reconnect Completed',
              data: {
                'callbacks': reconnectCallbacks.length,
              },
            );
          } catch (e, s) {
            ActivityLogger.logException(e, s, 'NetworkActions.reconnect');
            rethrow;
          }
        },
        disabled: (network.isOnline() && !loginCtrl.proceededOffline()),
        processing: (network.isOnline() && !loginCtrl.proceededOffline()),
        animate: false,
        activeColor: Colors.teal,
      ),
    ];
  }
}

final networkActions = _NetworkActions();
