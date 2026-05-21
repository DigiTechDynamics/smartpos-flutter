import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../core/services/service_locator.dart';
import '../../../domain/repositories/user_repository.dart';
import '../../widgets/common/manager_override_dialog.dart';
import '../../themes/colors.dart';
import '../../themes/text_styles.dart';

class ReportsPage extends StatefulWidget {
  const ReportsPage({super.key});

  @override
  State<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends State<ReportsPage> {
  bool _isLoading = true;
  bool _isAuthorized = false;

  @override
  void initState() {
    super.initState();
    _checkAccess();
  }

  Future<void> _checkAccess() async {
    setState(() => _isLoading = true);
    final userRepo = sl<UserRepository>();
    final currentUser = await userRepo.getCurrentUser();
    
    if (currentUser != null && (currentUser.role == 'admin' || currentUser.role == 'manager')) {
      setState(() {
        _isAuthorized = true;
        _isLoading = false;
      });
    } else {
      setState(() {
        _isAuthorized = false;
        _isLoading = false;
      });
      // Prompt manager override dialog automatically
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _requestOverride();
      });
    }
  }

  Future<void> _requestOverride() async {
    final manager = await ManagerOverrideDialog.show(
      context,
      actionName: 'Access Executive Analytics Hub',
    );
    if (manager != null) {
      setState(() {
        _isAuthorized = true;
      });
    }
  }

  Widget _buildLockScreen() {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400),
        child: Card(
          elevation: 4,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          margin: const EdgeInsets.all(24.0),
          child: Padding(
            padding: const EdgeInsets.all(32.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.secondary.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.lock_outline_rounded,
                      color: AppColors.secondary,
                      size: 48,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'Access Restricted',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.titleLarge.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'The Executive Analytics Hub contains sensitive financial metrics and trend analysis. Managers or administrators must authorize access to proceed.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 14,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 32),
                ElevatedButton.icon(
                  onPressed: _requestOverride,
                  icon: const Icon(Icons.shield_outlined, size: 20),
                  label: const Text('Authorize Access'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: () {
                    if (Navigator.of(context).canPop()) {
                      Navigator.of(context).pop();
                    } else {
                      context.go('/');
                    }
                  },
                  child: const Text(
                    'Return to Dashboard',
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (!_isAuthorized) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: const Text('Executive Dashboard', style: TextStyle(fontWeight: FontWeight.bold)),
          backgroundColor: Colors.white,
          elevation: 0,
          foregroundColor: Colors.black87,
        ),
        body: _buildLockScreen(),
      );
    }

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text('Executive Dashboard', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: Colors.black87,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Analytics Hub',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.black87),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: _DashboardCard(
                    title: 'Daily Report',
                    subtitle: 'Today\'s sales & transactions',
                    icon: Icons.today,
                    color: Colors.blue,
                    onTap: () => context.go('/reports/daily'),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _DashboardCard(
                    title: 'Sales Summary',
                    subtitle: 'Revenue trends over time',
                    icon: Icons.show_chart,
                    color: Colors.green,
                    onTap: () => context.go('/reports/summary'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Card(
              elevation: 4,
              shadowColor: Colors.black12,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Weekly Traffic Preview',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87),
                        ),
                        Icon(Icons.insights, color: Colors.grey.shade400),
                      ],
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      height: 120,
                      child: LineChart(
                        LineChartData(
                          gridData: const FlGridData(show: false),
                          titlesData: const FlTitlesData(show: false),
                          borderData: FlBorderData(show: false),
                          lineBarsData: [
                            LineChartBarData(
                              spots: const [
                                FlSpot(0, 3), FlSpot(1, 1), FlSpot(2, 4), FlSpot(3, 2), FlSpot(4, 5), FlSpot(5, 3), FlSpot(6, 4)
                              ],
                              isCurved: true,
                              color: Colors.blueAccent,
                              barWidth: 3,
                              isStrokeCapRound: true,
                              dotData: const FlDotData(show: false),
                              belowBarData: BarAreaData(
                                show: true,
                                color: Colors.blueAccent.withValues(alpha: 0.1),
                              ),
                            ),
                          ],
                          lineTouchData: const LineTouchData(enabled: false),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DashboardCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _DashboardCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.1),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
          border: Border.all(color: color.withValues(alpha: 0.2), width: 1.5),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(height: 16),
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 4),
            Text(subtitle, style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
          ],
        ),
      ),
    );
  }
}
