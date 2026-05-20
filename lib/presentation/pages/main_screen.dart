import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
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
  bool _isCollapsed = false;

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
    final isWide = MediaQuery.of(context).size.width > 800;
    final selectedIndex = _selectedIndex(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),
      body: Row(
        children: [
          if (isWide)
            SidebarWidget(
              selectedIndex: selectedIndex,
              onDestinationSelected: (i) => _navigate(i, context),
              isCollapsed: _isCollapsed,
              onToggleCollapse: () => setState(() => _isCollapsed = !_isCollapsed),
            ),
          Expanded(child: widget.child),
        ],
      ),
      // Floating nav only on narrow screens
      bottomNavigationBar: isWide
          ? null
          : _FloatingNavBar(
              selectedIndex: selectedIndex,
              onTap: (i) => _navigate(i, context),
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

    return GestureDetector(
      onTap: onTap,
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
    );
  }
}

// ─────────────────────────────────────────
//  Sidebar (wide screens — unchanged premium dark)
// ─────────────────────────────────────────
class SidebarWidget extends StatelessWidget {
  final int selectedIndex;
  final Function(int) onDestinationSelected;
  final bool isCollapsed;
  final VoidCallback onToggleCollapse;

  const SidebarWidget({
    super.key,
    required this.selectedIndex,
    required this.onDestinationSelected,
    required this.isCollapsed,
    required this.onToggleCollapse,
  });

  @override
  Widget build(BuildContext context) {
    final primaryColor = const Color(0xFF4F8EF7);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: isCollapsed ? 76 : 240,
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E2C),
        border: Border(
          right: BorderSide(
            color: Colors.grey.shade800.withOpacity(0.5),
            width: 1,
          ),
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: isCollapsed
                  ? const EdgeInsets.symmetric(vertical: 20.0, horizontal: 6.0)
                  : const EdgeInsets.symmetric(vertical: 20.0, horizontal: 12.0),
              child: Row(
                mainAxisAlignment: isCollapsed
                    ? MainAxisAlignment.center
                    : MainAxisAlignment.start,
                children: [
                  Container(
                    padding: isCollapsed
                        ? const EdgeInsets.all(6.0)
                        : const EdgeInsets.all(8.0),
                    decoration: BoxDecoration(
                      color: primaryColor.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: primaryColor.withOpacity(0.3), width: 1.5),
                    ),
                    child: Icon(Icons.store,
                        color: primaryColor, size: isCollapsed ? 20 : 26),
                  ),
                  if (!isCollapsed) ...[
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'SmartPOS',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              letterSpacing: 0.5,
                            ),
                          ),
                          Text(
                            'Zimbabwe Terminal',
                            style: TextStyle(color: Colors.grey, fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),

            // Collapse toggle
            Padding(
              padding: isCollapsed
                  ? EdgeInsets.zero
                  : const EdgeInsets.symmetric(horizontal: 12.0),
              child: isCollapsed
                  ? Center(
                      child: InkWell(
                        onTap: onToggleCollapse,
                        borderRadius: BorderRadius.circular(8),
                        child: Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Icon(Icons.chevron_right,
                              color: Colors.grey.shade400, size: 20),
                        ),
                      ),
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        IconButton(
                          icon: Icon(Icons.chevron_left,
                              color: Colors.grey.shade400, size: 20),
                          onPressed: onToggleCollapse,
                          tooltip: 'Collapse Sidebar',
                        ),
                      ],
                    ),
            ),

            Divider(color: Colors.grey.shade800.withOpacity(0.6), height: 1),
            const SizedBox(height: 16),

            // Nav items
            ..._destinations.asMap().entries.map((e) => _SidebarItem(
                  icon: e.value.icon,
                  activeIcon: e.value.activeIcon,
                  label: e.key == 0
                      ? 'POS Checkout'
                      : e.key == 1
                          ? 'Inventory Control'
                          : e.key == 2
                              ? 'Reports & Analytics'
                              : 'Settings & Admin',
                  isSelected: selectedIndex == e.key,
                  isCollapsed: isCollapsed,
                  onTap: () => onDestinationSelected(e.key),
                  activeColor: primaryColor,
                )),

            const Spacer(),

            // Footer
            Divider(color: Colors.grey.shade800.withOpacity(0.6), height: 1),
            Padding(
              padding: isCollapsed
                  ? const EdgeInsets.symmetric(vertical: 16.0, horizontal: 4.0)
                  : const EdgeInsets.symmetric(
                      vertical: 16.0, horizontal: 12.0),
              child: isCollapsed
                  ? Column(
                      children: [
                        CircleAvatar(
                          backgroundColor: Colors.grey.shade800,
                          radius: 18,
                          child: const Icon(Icons.person,
                              color: Colors.white70, size: 18),
                        ),
                        const SizedBox(height: 12),
                        InkWell(
                          onTap: () {
                            context.read<AuthBloc>().add(LogoutRequested());
                            context.go('/login');
                          },
                          borderRadius: BorderRadius.circular(8),
                          child: const Padding(
                            padding: EdgeInsets.all(8.0),
                            child: Icon(Icons.logout,
                                color: Colors.redAccent, size: 20),
                          ),
                        ),
                      ],
                    )
                  : Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: Colors.grey.shade800,
                          child: const Icon(Icons.person, color: Colors.white70),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Cashier Active',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                'Store #01',
                                style:
                                    TextStyle(color: Colors.grey, fontSize: 11),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.logout, color: Colors.redAccent),
                          tooltip: 'Logout',
                          onPressed: () {
                            context.read<AuthBloc>().add(LogoutRequested());
                            context.go('/login');
                          },
                        ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────
//  Sidebar nav item
// ─────────────────────────────────────────
class _SidebarItem extends StatelessWidget {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool isSelected;
  final bool isCollapsed;
  final VoidCallback onTap;
  final Color activeColor;

  const _SidebarItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.isSelected,
    required this.isCollapsed,
    required this.onTap,
    required this.activeColor,
  });

  @override
  Widget build(BuildContext context) {
    final outerPadding = isCollapsed
        ? const EdgeInsets.symmetric(horizontal: 4.0, vertical: 4.0)
        : const EdgeInsets.symmetric(horizontal: 10.0, vertical: 4.0);

    final innerPadding = isCollapsed
        ? const EdgeInsets.symmetric(vertical: 12.0, horizontal: 8.0)
        : const EdgeInsets.symmetric(vertical: 12.0, horizontal: 16.0);

    return Padding(
      padding: outerPadding,
      child: Material(
        color: isSelected ? activeColor.withOpacity(0.12) : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Tooltip(
            message: isCollapsed ? label : '',
            child: Container(
              padding: innerPadding,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: isSelected
                    ? Border.all(
                        color: activeColor.withOpacity(0.25), width: 1)
                    : null,
              ),
              child: Row(
                mainAxisAlignment: isCollapsed
                    ? MainAxisAlignment.center
                    : MainAxisAlignment.start,
                children: [
                  Icon(
                    isSelected ? activeIcon : icon,
                    color: isSelected ? activeColor : Colors.grey.shade400,
                    size: 20,
                  ),
                  if (!isCollapsed) ...[
                    const SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        label,
                        style: TextStyle(
                          color: isSelected
                              ? Colors.white
                              : Colors.grey.shade400,
                          fontWeight: isSelected
                              ? FontWeight.bold
                              : FontWeight.normal,
                          fontSize: 13.5,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
