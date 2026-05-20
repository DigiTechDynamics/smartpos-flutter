import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'daily_report_page.dart';
import 'sales_summary_page.dart';

class ReportsPage extends StatelessWidget {
  const ReportsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Reports'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          ListTile(
            leading: const Icon(Icons.today),
            title: const Text('Daily Report'),
            subtitle: const Text("View today's sales and transactions"),
            onTap: () {
              context.go('/reports/daily');
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.bar_chart),
            title: const Text('Sales Summary'),
            subtitle: const Text('View sales trends over time'),
            onTap: () {
              context.go('/reports/summary');
            },
          ),
        ],
      ),
    );
  }
}
