import 'package:flutter/material.dart';

class AppSettingsPage extends StatefulWidget {
  const AppSettingsPage({super.key});

  @override
  State<AppSettingsPage> createState() => _AppSettingsPageState();
}

class _AppSettingsPageState extends State<AppSettingsPage> {
  bool _darkMode = false;
  bool _autoPrint = true;
  String _defaultPayment = 'cash';
  bool _soundEffects = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Application Settings'),
      ),
      body: ListView(
        children: [
          SwitchListTile(
            title: const Text('Dark Theme'),
            subtitle: const Text('Toggle dark mode theme for the POS interface'),
            value: _darkMode,
            onChanged: (val) {
              setState(() => _darkMode = val);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Theme settings updated!')),
              );
            },
          ),
          const Divider(),
          SwitchListTile(
            title: const Text('Auto-print Receipt'),
            subtitle: const Text('Automatically print receipt on checkout completion'),
            value: _autoPrint,
            onChanged: (val) {
              setState(() => _autoPrint = val);
            },
          ),
          const Divider(),
          ListTile(
            title: const Text('Default Payment Mode'),
            subtitle: Text('Current: ${_defaultPayment.toUpperCase()}'),
            trailing: DropdownButton<String>(
              value: _defaultPayment,
              items: const [
                DropdownMenuItem(value: 'cash', child: Text('Cash')),
                DropdownMenuItem(value: 'mobile', child: Text('EcoCash')),
                DropdownMenuItem(value: 'card', child: Text('Card')),
              ],
              onChanged: (val) {
                if (val != null) {
                  setState(() => _defaultPayment = val);
                }
              },
            ),
          ),
          const Divider(),
          SwitchListTile(
            title: const Text('POS Sound Effects'),
            subtitle: const Text('Play sounds for barcode scans and item actions'),
            value: _soundEffects,
            onChanged: (val) {
              setState(() => _soundEffects = val);
            },
          ),
        ],
      ),
    );
  }
}
