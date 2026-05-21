import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter/services.dart';
import '../bloc/auth/auth_bloc.dart';
import '../bloc/auth/auth_event.dart';

// ─────────────────────────────────────────
//  Nav destination model
// ─────────────────────────────────────────
class _NavDest {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final String route;

  const _NavDest({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.route,
  });
}

const List<_NavDest> _destinations = [
  _NavDest(
    icon: Icons.point_of_sale_outlined,
    activeIcon: Icons.point_of_sale,
    label: 'POS',
    route: '/sale',
  ),
  _NavDest(
    icon: Icons.inventory_2_outlined,
    activeIcon: Icons.inventory_2,
    label: 'Inventory',
    route: '/inventory',
  ),
  _NavDest(
    icon: Icons.bar_chart_outlined,
    activeIcon: Icons.bar_chart,
    label: 'Reports',
    route: '/reports',
  ),
  _NavDest(
    icon: Icons.settings_outlined,
    activeIcon: Icons.settings,
    label: 'Settings',
    route: '/settings',
  ),
];

// ─────────────────────────────────────────
//  MainScreen shell
// ─────────────────────────────────────────
class MainScreen extends StatefulWidget {
  final Widget child;

  const MainScreen({super.key, required this.child});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex(BuildContext context) {
    final path = GoRouterState.of(context).uri.path;
    if (path.startsWith('/sale')) return 0;
    if (path.startsWith('/inventory')) return 1;
    if (path.startsWith('/reports')) return 2;
    if (path.startsWith('/settings')) return 3;
    return 0;
  }

  void _navigate(int index, BuildContext context) {
    context.go(_destinations[index].route);
  }

  @override
  Widget build(BuildContext context) {
    final selectedIndex = _selectedIndex(context);
    final isWide = MediaQuery.of(context).size.width > 800;

    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),
      extendBody: true, // Content will scroll behind the floating nav bar
      body: isWide
          ? SafeArea(
              child: Row(
                children: [
                  _FloatingSideNavBar(
                    selectedIndex: selectedIndex,
                    onTap: (i) => _navigate(i, context),
                  ),
                  Expanded(child: widget.child),
                ],
              ),
            )
          : widget.child,
      bottomNavigationBar: isWide
          ? null
          : Theme(
              data: Theme.of(context).copyWith(
                splashColor: Colors.transparent,
                highlightColor: Colors.transparent,
              ),
              child: _FloatingNavBar(
                selectedIndex: selectedIndex,
                onTap: (i) => _navigate(i, context),
              ),
            ),
    );
  }
}

// ─────────────────────────────────────────
//  Floating Side Navigation Bar (For Wide Screens)
// ─────────────────────────────────────────
class _FloatingSideNavBar extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onTap;

  const _FloatingSideNavBar({
    required this.selectedIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
        child: Center(
          child: Container(
            width: 80,
            padding: const EdgeInsets.symmetric(vertical: 16),
            decoration: BoxDecoration(
              color: const Color(0xFF1E1E2C),
              borderRadius: BorderRadius.circular(28),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.28),
                  blurRadius: 24,
                  offset: const Offset(4, 4),
                ),
                BoxShadow(
                  color: Colors.blue.withOpacity(0.08),
                  blurRadius: 12,
                  offset: const Offset(2, 2),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(_destinations.length, (i) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: SizedBox(
                    height: 70,
                    child: _FloatingNavItem(
                      dest: _destinations[i],
                      isSelected: selectedIndex == i,
                      onTap: () => onTap(i),
                    ),
                  ),
                );
              }),
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────
//  Floating Navigation Bar
// ─────────────────────────────────────────
class _FloatingNavBar extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onTap;

  const _FloatingNavBar({
    required this.selectedIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 550),
            child: Container(
              height: 70,
              decoration: BoxDecoration(
                color: const Color(0xFF1E1E2C),
                borderRadius: BorderRadius.circular(28),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.28),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  ),
                  BoxShadow(
                    color: Colors.blue.withOpacity(0.08),
                    blurRadius: 12,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: List.generate(_destinations.length, (i) {
                  return Expanded(
                    child: _FloatingNavItem(
                      dest: _destinations[i],
                      isSelected: selectedIndex == i,
                      onTap: () => onTap(i),
                    ),
                  );
                }),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────
//  Individual Floating Nav Item
// ─────────────────────────────────────────
class _FloatingNavItem extends StatelessWidget {
  final _NavDest dest;
  final bool isSelected;
  final VoidCallback onTap;

  const _FloatingNavItem({
    required this.dest,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    const activeColor = Color(0xFF4F8EF7);
    const inactiveColor = Color(0xFF7A7F9A);
    const activeBg = Color(0xFF2A2E45);

    return Semantics(
      label: dest.label,
      selected: isSelected,
      button: true,
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeInOut,
        margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? activeBg : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: isSelected
              ? Border.all(color: activeColor.withOpacity(0.25), width: 1)
              : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: Icon(
                isSelected ? dest.activeIcon : dest.icon,
                key: ValueKey(isSelected),
                color: isSelected ? activeColor : inactiveColor,
                size: 22,
              ),
            ),
            const SizedBox(height: 3),
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 200),
              style: TextStyle(
                color: isSelected ? activeColor : inactiveColor,
                fontSize: 10.5,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w400,
                letterSpacing: 0.2,
              ),
              child: Text(dest.label),
            ),
          ],
        ),
      ),
    ),
  );
}
}

