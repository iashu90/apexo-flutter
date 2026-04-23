import 'package:apexo/app/routes.dart' as app_routes;
import 'package:apexo/common_widgets/bulk_update_dialog.dart';
import 'package:apexo/common_widgets/daily_reminder_modal.dart';
import 'package:apexo/core/ui/components/app_button.dart';
import 'package:apexo/features/network_actions/network_actions_widget.dart';
import 'package:apexo/services/localization/locale.dart';
import 'package:apexo/services/login.dart';
import 'package:apexo/services/permissions.dart';
import 'package:apexo/theme/apexo_theme.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/cupertino.dart';

class TopTabsNavBar extends StatelessWidget {
  const TopTabsNavBar({super.key});

  @override
  Widget build(BuildContext context) {
    // Auto-show reminder once per session
    showDailyReminderIfNeeded(context);

    final width = MediaQuery.sizeOf(context).width;
    final compact = width < 980;
    final veryCompact = width < 760;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(color: Colors.grey.withValues(alpha: 0.22)),
        ),
      ),
      padding: EdgeInsets.symmetric(horizontal: veryCompact ? 8 : 14),
      child: SafeArea(
        bottom: false,
        child: SizedBox(
          height: compact ? 56 : 64,
          child: Row(
            children: [
              _LogoCluster(compact: compact, veryCompact: veryCompact),
              SizedBox(width: veryCompact ? 8 : 14),
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: StreamBuilder(
                    stream: permissions.stream,
                    builder: (context, _) {
                      return StreamBuilder(
                        stream: app_routes.routes.currentRouteIndex.stream,
                        builder: (context, _) {
                          return Row(
                            children: [
                              ..._primaryRoutes.map(
                                (r) => _TabButton(route: r),
                              ),
                            ],
                          );
                        },
                      );
                    },
                  ),
                ),
              ),
              Tooltip(
                message: "Today's Briefing",
                child: _TopRightActionIcon(
                  icon: CupertinoIcons.bell_fill,
                  onPressed: () => showDailyReminderModal(context),
                ),
              ),
              const SizedBox(width: 8),
              Tooltip(
                message: 'Bulk Update',
                child: _TopRightActionIcon(
                  icon: FluentIcons.edit,
                  onPressed: () => showBulkUpdateDialog(context),
                ),
              ),
              const SizedBox(width: 8),
              const NetworkActions(),
              if (!veryCompact) ...[
                const SizedBox(width: 6),
                const _UserChip(),
              ],
            ],
          ),
        ),
      ),
    );
  }

  List<app_routes.Route> get _primaryRoutes {
    final preferred = [
      'dashboard',
      'patients',
      'checkin',
      'doctors',
      'labworks',
      'expenses',
      'report',
      'access_control'
    ];

    final byId = {
      for (final r in app_routes.routes.allRoutes)
        if (r.accessible) r.identifier: r,
    };

    return preferred
        .where((id) => byId.containsKey(id))
        .map((id) => byId[id]!)
        .toList();
  }
}

class _LogoCluster extends StatelessWidget {
  final bool compact;
  final bool veryCompact;

  const _LogoCluster({required this.compact, required this.veryCompact});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Image.asset(
          'assets/drnowdentallogo.png',
          height: compact ? 38 : 52,
          fit: BoxFit.contain,
          color: const Color(0xFF1E4FBD),
          colorBlendMode: BlendMode.srcIn,
          errorBuilder: (_, __, ___) => Image.asset(
            'assets/images/logo.png',
            height: compact ? 38 : 52,
            fit: BoxFit.contain,
            color: const Color(0xFF1E4FBD),
            colorBlendMode: BlendMode.srcIn,
          ),
        ),
      ],
    );
  }
}

class _TopRightActionIcon extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onPressed;

  const _TopRightActionIcon({required this.icon, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(
        icon,
        color: const Color(0xFF5B6475),
        size: 18,
      ),
      onPressed: onPressed,
      iconButtonMode: IconButtonMode.large,
      style: ButtonStyle(
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(50)),
        ),
        iconSize: WidgetStateProperty.all(18),
        backgroundColor: const WidgetStatePropertyAll(Colors.transparent),
      ),
    );
  }
}

class _TabButton extends StatelessWidget {
  final app_routes.Route route;

  const _TabButton({required this.route});

  @override
  Widget build(BuildContext context) {
    final active =
        route.identifier == app_routes.routes.currentRoute.identifier;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      child: GestureDetector(
        onTap: () => app_routes.routes.navigate(route),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: active ? const Color(0xFFEFF4FF) : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            border: Border(
              bottom: BorderSide(
                color: active ? const Color(0xFF3A7BF8) : Colors.transparent,
                width: 2,
              ),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                route.icon,
                size: 14.5,
                color:
                    active ? const Color(0xFF1E4FBD) : const Color(0xFF7D8697),
              ),
              const SizedBox(width: 8),
              Text(
                _displayTitle(route),
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: active ? FontWeight.w700 : FontWeight.w600,
                  color: active
                      ? const Color(0xFF1E4FBD)
                      : const Color(0xFF707A8A),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _displayTitle(app_routes.Route route) {
    if (route.identifier == 'statistics') return txt('reports');
    if (route.identifier == 'report') return 'Report';
    if (route.identifier == 'labworks') return 'Labwork';
    return route.title;
  }
}

class _UserChip extends StatefulWidget {
  const _UserChip();

  @override
  State<_UserChip> createState() => _UserChipState();
}

class _UserChipState extends State<_UserChip> {
  final FlyoutController _userMenuController = FlyoutController();

  Future<void> _confirmAndLogout(BuildContext context) async {
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => ContentDialog(
        title: const Text('Logout confirmation'),
        content: const Text('Do you want to logout from this session?'),
        actions: [
          AppButton(
            label: 'Cancel',
            variant: AppButtonVariant.secondary,
            onPressed: () => Navigator.pop(dialogContext, false),
          ),
          AppButton(
            label: txt('logout'),
            variant: AppButtonVariant.danger,
            onPressed: () => Navigator.pop(dialogContext, true),
          ),
        ],
      ),
    );

    if (shouldLogout == true) {
      login.logout();
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
      stream: login.stream,
      builder: (context, _) {
        final mail = login.email.trim();
        final initials = _initials(mail);

        return FlyoutTarget(
          controller: _userMenuController,
          child: GestureDetector(
            onTap: () {
              _userMenuController.showFlyout(
                dismissWithEsc: true,
                builder: (menuContext) => MenuFlyout(
                  items: [
                    MenuFlyoutItem(
                      leading: const Icon(FluentIcons.contact, size: 14),
                      text: Text(mail.isEmpty ? 'Unknown user' : mail),
                      onPressed: null,
                    ),
                    const MenuFlyoutSeparator(),
                    MenuFlyoutItem(
                      leading: const Icon(FluentIcons.sign_out),
                      text: Text(txt('logout')),
                      onPressed: () async {
                        Flyout.of(menuContext).close();
                        await _confirmAndLogout(context);
                      },
                    ),
                  ],
                ),
              );
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFF3F7FF),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFD9E6FF)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 30,
                    height: 30,
                    decoration: const BoxDecoration(
                      color: ApexoThemeColors.avatarBackground,
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        initials,
                        style: const TextStyle(
                          color: ApexoThemeColors.avatarForeground,
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  const Icon(
                    FluentIcons.chevron_down,
                    size: 11,
                    color: Color(0xFF4D5B74),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  String _initials(String email) {
    if (email.isEmpty) return 'U';
    final handle = email.split('@').first;
    final tokens = handle
        .split(RegExp(r'[._-]'))
        .where((t) => t.trim().isNotEmpty)
        .toList();

    if (tokens.isEmpty) {
      return handle.substring(0, 1).toUpperCase();
    }

    if (tokens.length == 1) {
      return tokens.first.substring(0, 1).toUpperCase();
    }

    return (tokens[0].substring(0, 1) + tokens[1].substring(0, 1))
        .toUpperCase();
  }
}
