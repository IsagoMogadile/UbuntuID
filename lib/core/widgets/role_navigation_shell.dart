import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'app_logo.dart';

class AppNavDestination {
  const AppNavDestination({
    required this.icon,
    required this.selectedIcon,
    required this.label,
    this.badgeCount = 0,
  });

  final IconData icon;
  final IconData selectedIcon;
  final String label;

  /// Shown as a small red badge on this destination's icon when > 0 --
  /// e.g. an unread-notification count that updates live via Realtime.
  final int badgeCount;

  Widget _icon(IconData data) {
    if (badgeCount <= 0) return Icon(data);
    return _PulsingBadge(
      count: badgeCount,
      child: Icon(data),
    );
  }
}

/// Pops with a brief scale animation whenever [count] changes -- e.g. a
/// live-updating unread-notification badge, so a new arrival feels like an
/// event rather than a number silently changing.
class _PulsingBadge extends StatelessWidget {
  const _PulsingBadge({required this.count, required this.child});

  final int count;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Badge(
      label: TweenAnimationBuilder<double>(
        key: ValueKey(count),
        tween: Tween(begin: 1.5, end: 1.0),
        duration: const Duration(milliseconds: 350),
        curve: Curves.elasticOut,
        builder: (context, scale, labelChild) => Transform.scale(scale: scale, child: labelChild),
        child: Text(count > 99 ? '99+' : '$count'),
      ),
      child: child,
    );
  }
}

/// The shared role-scoped navigation frame: a [NavigationBar] on narrow
/// (mobile) layouts and a [NavigationRail] on wide (desktop/tablet)
/// layouts, wrapping a [StatefulNavigationShell] branch.
class RoleNavigationShell extends StatelessWidget {
  const RoleNavigationShell({
    super.key,
    required this.navigationShell,
    required this.title,
    required this.destinations,
    this.appBarActions,
  });

  final StatefulNavigationShell navigationShell;
  final String title;
  final List<AppNavDestination> destinations;
  final List<Widget>? appBarActions;

  static const _wideBreakpoint = 840.0;

  void _onDestinationSelected(int index) {
    navigationShell.goBranch(index, initialLocation: index == navigationShell.currentIndex);
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.sizeOf(context).width >= _wideBreakpoint;

    if (isWide) {
      return Scaffold(
        appBar: _buildAppBar(context),
        body: Row(
          children: [
            NavigationRail(
              selectedIndex: navigationShell.currentIndex,
              onDestinationSelected: _onDestinationSelected,
              labelType: NavigationRailLabelType.all,
              destinations: [
                for (final d in destinations)
                  NavigationRailDestination(
                    icon: d._icon(d.icon),
                    selectedIcon: d._icon(d.selectedIcon),
                    label: Text(d.label),
                  ),
              ],
            ),
            const VerticalDivider(width: 1),
            Expanded(child: navigationShell),
          ],
        ),
      );
    }

    return Scaffold(
      appBar: _buildAppBar(context),
      body: navigationShell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: navigationShell.currentIndex,
        onDestinationSelected: _onDestinationSelected,
        destinations: [
          for (final d in destinations)
            NavigationDestination(icon: d._icon(d.icon), selectedIcon: d._icon(d.selectedIcon), label: d.label),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context) {
    return AppBar(
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const AppLogo(size: 28, showWordmark: false),
          const SizedBox(width: 10),
          Text(title),
        ],
      ),
      actions: appBarActions,
    );
  }
}
