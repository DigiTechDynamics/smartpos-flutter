import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../bloc/auth/auth_bloc.dart';
import '../bloc/auth/auth_event.dart';

class MainScreen extends StatefulWidget {
  final Widget child;

  const MainScreen({super.key, required this.child});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  bool _isCollapsed = false;

  int _calculateSelectedIndex(BuildContext context) {
    final String location = GoRouterState.of(context).uri.path;
    if (location.startsWith('/sale')) return 0;
    if (location.startsWith('/inventory')) return 1;
    if (location.startsWith('/reports')) return 2;
    if (location.startsWith('/settings')) return 3;
    return 0;
  }

  void _onItemTapped(int index, BuildContext context) {
    switch (index) {
      case 0:
        context.go('/sale');
        break;
      case 1:
        context.go('/inventory');
        break;
      case 2:
        context.go('/reports');
        break;
      case 3:
        context.go('/settings');
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width > 800;

    return Scaffold(
      body: Row(
        children: [
          if (isWide)
            SidebarWidget(
              selectedIndex: _calculateSelectedIndex(context),
              onDestinationSelected: (index) => _onItemTapped(index, context),
              isCollapsed: _isCollapsed,
              onToggleCollapse: () {
                setState(() {
                  _isCollapsed = !_isCollapsed;
                });
              },
            ),
          Expanded(child: widget.child),
        ],
      ),
      bottomNavigationBar: isWide
          ? null
          : BottomNavigationBar(
              type: BottomNavigationBarType.fixed,
              selectedItemColor: Colors.blue,
              unselectedItemColor: Colors.grey,
              currentIndex: _calculateSelectedIndex(context),
              onTap: (index) => _onItemTapped(index, context),
              items: const [
                BottomNavigationBarItem(
                  icon: Icon(Icons.point_of_sale),
                  label: 'POS',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.inventory),
                  label: 'Inventory',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.bar_chart),
                  label: 'Reports',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.settings),
                  label: 'Settings',
                ),
              ],
            ),
    );
  }
}

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
    final theme = Theme.of(context);
    final primaryColor = theme.primaryColor;
    
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: isCollapsed ? 76 : 240,
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E2C), // Deep premium dark background
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
            // Header Section
            Padding(
              padding: isCollapsed
                  ? const EdgeInsets.symmetric(vertical: 20.0, horizontal: 6.0)
                  : const EdgeInsets.symmetric(vertical: 20.0, horizontal: 12.0),
              child: Row(
                mainAxisAlignment: isCollapsed ? MainAxisAlignment.center : MainAxisAlignment.start,
                children: [
                  Container(
                    padding: isCollapsed
                        ? const EdgeInsets.all(6.0)
                        : const EdgeInsets.all(8.0),
                    decoration: BoxDecoration(
                      color: primaryColor.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: primaryColor.withOpacity(0.3), width: 1.5),
                    ),
                    child: Icon(Icons.store, color: primaryColor, size: isCollapsed ? 20 : 26),
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
                            style: TextStyle(
                              color: Colors.grey,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            
            // Toggle Button
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
                          child: Icon(
                            Icons.chevron_right,
                            color: Colors.grey.shade400,
                            size: 20,
                          ),
                        ),
                      ),
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        IconButton(
                          icon: Icon(
                            Icons.chevron_left,
                            color: Colors.grey.shade400,
                            size: 20,
                          ),
                          onPressed: onToggleCollapse,
                          tooltip: 'Collapse Sidebar',
                        ),
                      ],
                    ),
            ),
            
            Divider(color: Colors.grey.shade800.withOpacity(0.6), height: 1),
            const SizedBox(height: 16),
            
            // Navigation Items
            _SidebarItem(
              icon: Icons.point_of_sale,
              label: 'POS Checkout',
              isSelected: selectedIndex == 0,
              isCollapsed: isCollapsed,
              onTap: () => onDestinationSelected(0),
              activeColor: primaryColor,
            ),
            _SidebarItem(
              icon: Icons.inventory,
              label: 'Inventory Control',
              isSelected: selectedIndex == 1,
              isCollapsed: isCollapsed,
              onTap: () => onDestinationSelected(1),
              activeColor: primaryColor,
            ),
            _SidebarItem(
              icon: Icons.bar_chart,
              label: 'Reports & Analytics',
              isSelected: selectedIndex == 2,
              isCollapsed: isCollapsed,
              onTap: () => onDestinationSelected(2),
              activeColor: primaryColor,
            ),
            _SidebarItem(
              icon: Icons.settings,
              label: 'Settings & Admin',
              isSelected: selectedIndex == 3,
              isCollapsed: isCollapsed,
              onTap: () => onDestinationSelected(3),
              activeColor: primaryColor,
            ),
            
            const Spacer(),
            
            // Footer Session / User Info
            Divider(color: Colors.grey.shade800.withOpacity(0.6), height: 1),
            Padding(
              padding: isCollapsed
                  ? const EdgeInsets.symmetric(vertical: 16.0, horizontal: 4.0)
                  : const EdgeInsets.symmetric(vertical: 16.0, horizontal: 12.0),
              child: isCollapsed
                  ? Column(
                      children: [
                        CircleAvatar(
                          backgroundColor: Colors.grey.shade800,
                          radius: 18,
                          child: const Icon(Icons.person, color: Colors.white70, size: 18),
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
                            child: Icon(Icons.logout, color: Colors.redAccent, size: 20),
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
                                style: TextStyle(
                                  color: Colors.grey,
                                  fontSize: 11,
                                ),
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

class _SidebarItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final bool isCollapsed;
  final VoidCallback onTap;
  final Color activeColor;

  const _SidebarItem({
    required this.icon,
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
                    ? Border.all(color: activeColor.withOpacity(0.25), width: 1)
                    : null,
              ),
              child: Row(
                mainAxisAlignment: isCollapsed ? MainAxisAlignment.center : MainAxisAlignment.start,
                children: [
                  Icon(
                    icon,
                    color: isSelected ? activeColor : Colors.grey.shade400,
                    size: 20,
                  ),
                  if (!isCollapsed) ...[
                    const SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        label,
                        style: TextStyle(
                          color: isSelected ? Colors.white : Colors.grey.shade400,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
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

