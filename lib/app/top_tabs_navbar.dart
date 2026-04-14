import 'package:apexo/app/routes.dart' as app_routes;
import 'package:apexo/features/network_actions/network_actions_widget.dart';
import 'package:apexo/services/localization/locale.dart';
import 'package:apexo/services/login.dart';
import 'package:apexo/theme/apexo_theme.dart';
import 'package:fluent_ui/fluent_ui.dart';

class TopTabsNavBar extends StatelessWidget {
  const TopTabsNavBar({super.key});

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final compact = width < 980;
    final veryCompact = width < 760;

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [
            ApexoThemeColors.navGradientStart,
            ApexoThemeColors.navGradientEnd,
          ],
        ),
      ),
      padding: EdgeInsets.symmetric(horizontal: veryCompact ? 8 : 14),
      child: SafeArea(
        bottom: false,
        child: SizedBox(
          height: compact ? 56 : 64,
          child: Row(
            children: [
              _LogoCluster(compact: compact),
              SizedBox(width: veryCompact ? 8 : 14),
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: StreamBuilder(
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
                  ),
                ),
              ),
              const SizedBox(width: 6),
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
      'doctors_v2',
      'labworks_v2',
      'expenses',
      'report_v2',
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

  const _LogoCluster({required this.compact});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Image.asset(
          'assets/drnowdentallogo.png',
          height: compact ? 46 : 58,
          fit: BoxFit.contain,
        ),
      ],
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
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: GestureDetector(
        onTap: () => app_routes.routes.navigate(route),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: active ? ApexoThemeColors.navActiveTab : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: active
                  ? Colors.white.withValues(alpha: 0.2)
                  : Colors.transparent,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                route.icon,
                size: 14,
                color: active
                    ? ApexoThemeColors.navText
                    : ApexoThemeColors.navTextMuted,
              ),
              const SizedBox(width: 8),
              Text(
                _displayTitle(route),
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: active ? FontWeight.w700 : FontWeight.w600,
                  color: active
                      ? ApexoThemeColors.navText
                      : ApexoThemeColors.navTextMuted,
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
    if (route.identifier == 'report_v2') return 'Report';
    if (route.identifier == 'labworks_v2') return 'Labwork';
    return route.title;
  }
}

class _UserChip extends StatelessWidget {
  const _UserChip();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
      stream: login.stream,
      builder: (context, _) {
        final mail = login.email.trim();
        final initials = _initials(mail);

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
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
                color: Colors.white,
              ),
            ],
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
