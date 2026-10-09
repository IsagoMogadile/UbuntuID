import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'app_logo.dart';

class AppNavDestination {
  const AppNavDestination({
    required this.icon,
    required this.selectedIcon,
    required this.label,
    this.badgeCount = 0,
    this.onSelected,
  });

  final IconData icon;
  final IconData selectedIcon;
  final String label;

  /// Shown as a small red badge on this destination's icon when > 0 --
  /// e.g. an unread-notification count that updates live via Realtime.
  final int badgeCount;

  /// When set, selecting this destination runs this action (e.g. "Log Out")
  /// instead of switching to a branch. Action destinations must come after
  /// every branch destination so the remaining indices still line up with
  /// the shell's branches.
  final void Function(BuildContext context)? onSelected;

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
///
/// A bottom bar only fits [_maxBarItems] destinations, so on narrow layouts
/// any beyond the first `_maxBarItems - 1` (typically Settings and Log Out)
/// move behind a "More" item that opens them in a bottom sheet.
///
/// Profile isn't a destination: it's the button in the far top-right of the
/// header, opening [profileRoute]. A role with a [headerSearch] gets it in
/// the middle of the header on wide layouts, and as an icon just before
/// Profile on narrow ones.
class RoleNavigationShell extends StatelessWidget {
  const RoleNavigationShell({
    super.key,
    required this.navigationShell,
    required this.title,
    required this.destinations,
    required this.profileRoute,
    this.headerSearch,
  });

  final StatefulNavigationShell navigationShell;
  final String title;
  final List<AppNavDestination> destinations;
  final String profileRoute;
  final Widget? headerSearch;

  static const _wideBreakpoint = 840.0;
  static const _centredSearchBreakpoint = 600.0;
  static const _maxBarItems = 5;

  void _onDestinationSelected(BuildContext context, int index) {
    final action = destinations[index].onSelected;
    if (action != null) {
      action(context);
      return;
    }
    navigationShell.goBranch(index, initialLocation: index == navigationShell.currentIndex);
  }

  Future<void> _showMore(BuildContext context, int firstOverflowIndex) async {
    final selected = await showModalBottomSheet<int>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = firstOverflowIndex; i < destinations.length; i++)
              ListTile(
                leading: destinations[i]._icon(
                  i == navigationShell.currentIndex ? destinations[i].selectedIcon : destinations[i].icon,
                ),
                title: Text(destinations[i].label),
                selected: i == navigationShell.currentIndex,
                onTap: () => Navigator.pop(sheetContext, i),
              ),
          ],
        ),
      ),
    );
    // Run the choice with the shell's own context, after the sheet has
    // closed, so an action like Log Out can show its own dialog.
    if (selected != null && context.mounted) _onDestinationSelected(context, selected);
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.sizeOf(context).width >= _wideBreakpoint;

    if (isWide) {
      return Scaffold(
        appBar: _buildAppBar(context),
        body: Row(
          children: [
            // Scrollable so a role with many destinations (admin has 8)
            // never overflows a short desktop window.
            LayoutBuilder(
              builder: (context, constraints) => SingleChildScrollView(
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: IntrinsicHeight(
                    child: NavigationRail(
                      selectedIndex: navigationShell.currentIndex,
                      onDestinationSelected: (index) => _onDestinationSelected(context, index),
                      labelType: NavigationRailLabelType.all,
                      // Centred with roomy spacing rather than packed into
                      // the top-left corner; still scrolls when the window
                      // is too short for them all.
                      groupAlignment: 0,
                      minWidth: 104,
                      leading: const SizedBox(height: 16),
                      trailing: const SizedBox(height: 16),
                      destinations: [
                        for (final d in destinations)
                          NavigationRailDestination(
                            icon: d._icon(d.icon),
                            selectedIcon: d._icon(d.selectedIcon),
                            label: Text(d.label),
                            padding: const EdgeInsets.symmetric(vertical: 10),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const VerticalDivider(width: 1),
            Expanded(child: navigationShell),
          ],
        ),
      );
    }

    final overflows = destinations.length > _maxBarItems;
    final barDestinations = overflows ? destinations.sublist(0, _maxBarItems - 1) : destinations;
    final moreIndex = barDestinations.length;
    final currentIndex = navigationShell.currentIndex;
    final moreSelected = overflows && currentIndex >= moreIndex;

    return Scaffold(
      appBar: _buildAppBar(context),
      body: navigationShell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: moreSelected ? moreIndex : currentIndex,
        onDestinationSelected: (index) {
          if (overflows && index == moreIndex) {
            _showMore(context, moreIndex);
          } else {
            _onDestinationSelected(context, index);
          }
        },
        destinations: [
          for (final d in barDestinations)
            NavigationDestination(icon: d._icon(d.icon), selectedIcon: d._icon(d.selectedIcon), label: d.label),
          if (overflows)
            const NavigationDestination(icon: Icon(Icons.menu), selectedIcon: Icon(Icons.menu_open), label: 'More'),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context) {
    final search = headerSearch;
    final centreSearch = search != null && MediaQuery.sizeOf(context).width >= _centredSearchBreakpoint;
    final brand = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const AppLogo(size: 36, showWordmark: false),
        const SizedBox(width: 10),
        Text(title),
      ],
    );

    return AppBar(
      // With a centred search, equal flexible space either side keeps it in
      // the middle of the header, between the brand and Profile.
      title: centreSearch
          ? Row(
              children: [
                Expanded(child: Align(alignment: Alignment.centerLeft, child: brand)),
                search,
                const Expanded(child: SizedBox()),
              ],
            )
          : brand,
      actions: [
        if (search != null && !centreSearch) search,
        Padding(
          padding: const EdgeInsets.only(right: 8),
          child: IconButton(
            icon: const Icon(Icons.account_circle_outlined, size: 28),
            tooltip: 'Profile',
            onPressed: () => context.push(profileRoute),
          ),
        ),
      ],
    );
  }
}
