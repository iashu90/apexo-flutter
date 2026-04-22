import 'package:apexo/app/panel_widget.dart';
import 'package:apexo/app/routes.dart';
import 'package:apexo/app/top_tabs_navbar.dart';
import 'package:apexo/common_widgets/dialogs/first_launch_dialog.dart';
import 'package:apexo/common_widgets/dialogs/new_version_dialog.dart';
import 'package:apexo/core/multi_stream_builder.dart';
import 'package:apexo/core/theme/app_theme.dart';
import 'package:apexo/features/login/login_screen.dart';
import 'package:apexo/features/settings/settings_stores.dart';
import 'package:apexo/services/launch.dart';
import 'package:apexo/services/localization/en.dart';
import 'package:apexo/services/localization/locale.dart';
import 'package:apexo/services/version.dart';
import 'package:apexo/theme/apexo_theme.dart';
import 'package:apexo/widget_keys.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' as material;

late BuildContext bContextV2;

class ApexoAppV2 extends StatelessWidget {
  const ApexoAppV2({super.key});

  @override
  StatelessElement createElement() {
    Future.delayed(const Duration(milliseconds: 1000), () {
      showDialogsIfNeeded();
    });
    return super.createElement();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
      stream: localSettings.stream,
      builder: (context, _) {
        final isDark = localSettings.selectedTheme == ThemeMode.dark;
        return FluentApp(
          key: WK.fluentApp,
          locale: Locale(locale.s.$code),
          theme: isDark ? FluentThemeData.dark() : FluentThemeData.light(),
          home: CupertinoTheme(
            data: isDark
                ? const CupertinoThemeData(brightness: Brightness.dark)
                : const CupertinoThemeData(brightness: Brightness.light),
            child: FluentTheme(
              data: isDark ? FluentThemeData.dark() : FluentThemeData.light(),
                child: material.Theme(
                  data: AppTheme.light,
                  child: MStreamBuilder(
                    streams: [
                      version.latest.stream,
                      version.current.stream,
                      launch.dialogShown.stream,
                      launch.isFirstLaunch.stream,
                      launch.open.stream,
                      routes.panels.stream,
                      routes.minimizePanels.stream,
                      routes.currentRouteIndex.stream,
                    ],
                    builder: (BuildContext context, _) {
                      bContextV2 = context;
                      return buildAppLayout();
                    },
                  ),
                ),
            ),
          ),
        );
      },
    );
  }

  void showDialogsIfNeeded() {
    if (!bContextV2.mounted) return;

    version.update().then((_) {
      if (version.newVersionAvailable && (!launch.dialogShown()) && bContextV2.mounted) {
        launch.dialogShown(true);
        showDialog(
          context: bContextV2,
          builder: (BuildContext context) => const NewVersionDialog(),
        );
      }
    });

    if (launch.isFirstLaunch() && (!launch.dialogShown()) && bContextV2.mounted) {
      launch.dialogShown(true);
      showDialog(
        context: bContextV2,
        builder: (BuildContext context) => const FirstLaunchDialog(),
      );
    }
  }

  Widget buildAppLayout() {
    return MStreamBuilder(
      streams: [launch.open.stream, routes.currentRouteIndex.stream, routes.panels.stream],
      key: WK.builder,
      builder: (context, _) => PopScope(
        canPop: false,
        onPopInvokedWithResult: (_, __) {
          if (launch.layoutWidth < 710 && routes.panels().isNotEmpty && routes.minimizePanels() == false) {
            routes.minimizePanels(true);
            return;
          }
          routes.goBack();
        },
        child: LayoutBuilder(
          builder: (context, constraints) {
            launch.layoutWidth = constraints.maxWidth;
            final hideSidePanel = routes.panels().isEmpty || !launch.open();
            return Container(
              color: ApexoThemeColors.appBackground,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  _buildPositionedMainScreen(constraints, hideSidePanel),
                  if (routes.panels().isNotEmpty && routes.minimizePanels() == false && constraints.maxWidth < 710)
                    ModalBarrier(
                      color: Colors.black.withValues(alpha: 0.28),
                      onDismiss: () => routes.minimizePanels(true),
                    ),
                  _buildPositionedPanel(constraints, hideSidePanel),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  AnimatedPositioned _buildPositionedMainScreen(BoxConstraints constraints, bool hideSidePanel) {
    return AnimatedPositioned(
      duration: const Duration(milliseconds: 300),
      top: 0,
      left: locale.s.$direction == Direction.rtl ? null : 0,
      right: locale.s.$direction == Direction.rtl ? 0 : null,
      height: constraints.maxHeight,
      width: (!hideSidePanel) && constraints.maxWidth >= 710 ? constraints.maxWidth - 355 : constraints.maxWidth,
      child: Container(
        decoration: BoxDecoration(
          color: ApexoThemeColors.appBackground,
          boxShadow: kElevationToShadow[4],
        ),
        child: Column(
          children: [
            if (launch.open()) const TopTabsNavBar(),
            Expanded(
              child: launch.open()
                  ? Container(
                      padding: const EdgeInsets.all(14),
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: ApexoThemeColors.surface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: ApexoThemeColors.divider),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: (routes.currentRoute.screen)(),
                        ),
                      ),
                    )
                  : const Login(key: WK.loginScreen),
            ),
          ],
        ),
      ),
    );
  }

  AnimatedPositioned _buildPositionedPanel(BoxConstraints constraints, bool hideSidePanel) {
    final minimized = routes.minimizePanels() && constraints.maxWidth < 710;
    return AnimatedPositioned(
      width: (constraints.maxWidth < 490 && minimized) ? constraints.maxWidth : 350,
      height: minimized ? 56 : constraints.maxHeight,
      top: minimized ? null : 0,
      bottom: minimized ? 0 : null,
      left: locale.s.$direction == Direction.ltr ? null : (hideSidePanel ? -400 : 0),
      right: locale.s.$direction == Direction.ltr ? (hideSidePanel ? -400 : 0) : null,
      duration: const Duration(milliseconds: 200),
      child: hideSidePanel
          ? const SizedBox()
          : SafeArea(
              top: minimized ? false : true,
              child: PanelScreen(
                key: Key(routes.panels().last.identifier),
                layoutHeight: constraints.maxHeight,
                layoutWidth: constraints.maxWidth,
                panel: routes.panels().last,
              ),
            ),
    );
  }
}
