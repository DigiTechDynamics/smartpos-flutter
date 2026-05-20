import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../bloc/auth/auth_bloc.dart';
import '../../bloc/auth/auth_event.dart';
import 'printer_settings_page.dart';
import 'app_settings_page.dart';
import 'user_management_page.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings & Administration')),
      body: ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.store, color: Colors.blue),
            title: const Text('Store Configuration'),
            subtitle: const Text('Configure store name, default currency, tax rules'),
            onTap: () {
              context.go('/settings/store');
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.print, color: Colors.blue),
            title: const Text('Printer Settings'),
            subtitle: const Text('Pair, connect, and test Bluetooth thermal printers'),
            onTap: () {
              context.go('/settings/printer');
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.settings_applications, color: Colors.blue),
            title: const Text('Application Preference'),
            subtitle: const Text('Configure theme, auto-print, sound effects'),
            onTap: () {
              context.go('/settings/app');
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.people_outline, color: Colors.blue),
            title: const Text('User Management'),
            subtitle: const Text('Manage cashiers, managers, and access roles'),
            onTap: () {
              context.go('/settings/users');
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.sync, color: Colors.blue),
            title: const Text('Sync Status & Health'),
            subtitle: const Text('Check cloud connection, synched database records'),
            onTap: () {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Offline-first Sync Status'),
                  content: const Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Network Status:'),
                          Text('Connected', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                        ],
                      ),
                      SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Pending Queue Items:'),
                          Text('0', style: TextStyle(fontWeight: FontWeight.bold)),
                        ],
                      ),
                      SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Last Synched At:'),
                          Text('Just Now', style: TextStyle(fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ],
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('CLOSE'),
                    ),
                  ],
                ),
              );
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.red),
            title: const Text('Logout', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
            subtitle: const Text('Sign out of active cashier session'),
            onTap: () {
              context.read<AuthBloc>().add(LogoutRequested());
              context.go('/login');
            },
          ),
        ],
      ),
    );
  }
}
