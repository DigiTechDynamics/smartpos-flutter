import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../bloc/reports/reports_bloc.dart';
import '../../bloc/reports/reports_event.dart';
import '../../bloc/reports/reports_state.dart';
import '../../../core/services/service_locator.dart';
import '../../../domain/repositories/user_repository.dart';
import '../../../domain/usecases/sales/void_sale_usecase.dart';
import '../../widgets/common/manager_override_dialog.dart';
import '../../themes/colors.dart';

class SalesSummaryPage extends StatefulWidget {
  const SalesSummaryPage({super.key});

  @override
  State<SalesSummaryPage> createState() => _SalesSummaryPageState();
}

class _SalesSummaryPageState extends State<SalesSummaryPage> {
  DateTimeRange _dateRange = DateTimeRange(
    start: DateTime.now().subtract(const Duration(days: 7)),
    end: DateTime.now(),
  );

  @override
  void initState() {
    super.initState();
    _loadSummary();
  }

  void _loadSummary() {
    context.read<ReportsBloc>().add(LoadSalesSummary(_dateRange.start, _dateRange.end));
  }

  Future<void> _voidTransaction(BuildContext context, Map<String, dynamic> record) async {
    final saleId = record['id'] as String;
    final saleNum = record['saleNumber'] ?? saleId;
    
    final userRepo = sl<UserRepository>();
    final currentUser = await userRepo.getCurrentUser();
    
    bool isAuthorized = false;
    String authorizedBy = currentUser?.email ?? 'unknown';
    
    if (currentUser != null) {
      if (currentUser.role == 'admin' || currentUser.role == 'manager') {
        isAuthorized = true;
      } else {
        // Cashier needs override
        final manager = await ManagerOverrideDialog.show(
          context,
          actionName: 'Void Sale Transaction #$saleNum',
        );
        if (manager != null) {
          isAuthorized = true;
          authorizedBy = manager.email;
        }
      }
    }
    
    if (!isAuthorized) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Void cancelled or unauthorized'),
            backgroundColor: AppColors.error,
          ),
        );
      }
      return;
    }
    
    // Prompt for reason
    if (!context.mounted) return;
    final reason = await showDialog<String>(
      context: context,
      builder: (context) {
        final controller = TextEditingController();
        return AlertDialog(
          title: const Text('Reason for Voiding'),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(
              hintText: 'Enter reason (e.g. customer change of mind)',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, controller.text.trim()),
              child: const Text('Void Sale'),
            ),
          ],
        );
      },
    );
    
    if (reason == null || reason.isEmpty) return;
    
    // Call void usecase
    try {
      if (!context.mounted) return;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );
      
      final voidUsecase = sl<VoidSaleUseCase>();
      await voidUsecase.execute(VoidSaleParams(
        saleId: saleId,
        reason: '$reason (Authorized by: $authorizedBy)',
      ));
      
      if (context.mounted) {
        Navigator.pop(context); // Dismiss progress indicator
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Transaction voided successfully'),
            backgroundColor: AppColors.success,
          ),
        );
        _loadSummary(); // Refresh summary
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context); // Dismiss progress indicator
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error voiding transaction: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Widget _buildRevenueChart(List<MapEntry<DateTime, double>> entries, double maxRevenue) {
    if (entries.isEmpty) {
      return const Center(child: Text('No sales data', style: TextStyle(color: Colors.grey)));
    }

    List<FlSpot> spots = [];
    for (int i = 0; i < entries.length; i++) {
      spots.add(FlSpot(i.toDouble(), entries[i].value));
    }

    return LineChart(
      LineChartData(
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: maxRevenue > 0 ? (maxRevenue / 4 == 0 ? 1 : maxRevenue / 4) : 1,
          getDrawingHorizontalLine: (value) => FlLine(color: Colors.grey.shade200, strokeWidth: 1),
        ),
        titlesData: FlTitlesData(
          show: true,
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 40,
              getTitlesWidget: (value, meta) {
                if (value == 0) return const SizedBox.shrink();
                return Text('\$${value.toInt()}', style: const TextStyle(color: Colors.grey, fontSize: 10));
              },
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                if (value.toInt() >= 0 && value.toInt() < entries.length) {
                  final date = entries[value.toInt()].key;
                  return Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Text('${date.day}/${date.month}', style: const TextStyle(color: Colors.grey, fontSize: 10)),
                  );
                }
                return const SizedBox.shrink();
              },
            ),
          ),
        ),
        borderData: FlBorderData(show: false),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: Colors.blueAccent,
            barWidth: 4,
            isStrokeCapRound: true,
            dotData: const FlDotData(show: true),
            belowBarData: BarAreaData(
              show: true,
              color: Colors.blueAccent.withOpacity(0.15),
            ),
          ),
        ],
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipItems: (touchedSpots) {
              return touchedSpots.map((spot) {
                return LineTooltipItem(
                  '\$${spot.y.toStringAsFixed(2)}',
                  const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                );
              }).toList();
            },
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text('Sales Trends & Summaries', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: Colors.black87,
      ),
      body: Column(
        children: [
          // Range selector
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                )
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Date Range:',
                  style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black87),
                ),
                TextButton.icon(
                  onPressed: () async {
                    final picked = await showDateRangePicker(
                      context: context,
                      firstDate: DateTime(2020),
                      lastDate: DateTime.now(),
                      initialDateRange: _dateRange,
                    );
                    if (picked != null) {
                      setState(() {
                        _dateRange = picked;
                      });
                      _loadSummary();
                    }
                  },
                  icon: const Icon(Icons.date_range),
                  label: Text(
                    '${_dateRange.start.day}/${_dateRange.start.month} - ${_dateRange.end.day}/${_dateRange.end.month}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.blueAccent,
                    backgroundColor: Colors.blue.shade50,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: BlocBuilder<ReportsBloc, ReportsState>(
              builder: (context, state) {
                if (state is ReportsLoading) {
                  return const Center(child: CircularProgressIndicator());
                } else if (state is ReportsError) {
                  return Center(
                    child: Text('Error: ${state.message}',
                        style: const TextStyle(color: Colors.red)),
                  );
                } else if (state is SalesSummaryLoaded) {
                  final sortedEntries = state.revenueByDay.entries.toList()
                    ..sort((a, b) => a.key.compareTo(b.key));

                  double maxRevenue = 0.0;
                  for (final val in state.revenueByDay.values) {
                    if (val > maxRevenue) {
                      maxRevenue = val;
                    }
                  }
                  if (maxRevenue == 0.0) maxRevenue = 1.0;

                  final records = state.recentTransactions;

                  return SingleChildScrollView(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Revenue card
                        Card(
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                            side: BorderSide(color: Colors.blue.shade100, width: 1.5),
                          ),
                          color: Colors.blue.shade50,
                          child: Padding(
                            padding: const EdgeInsets.all(24.0),
                            child: Column(
                              children: [
                                Text('TOTAL REVENUE',
                                    style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue.shade800, letterSpacing: 1.2)),
                                const SizedBox(height: 8),
                                Text(
                                  '\$${state.totalRevenue.toStringAsFixed(2)}',
                                  style: TextStyle(
                                      fontSize: 36,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.blue.shade900),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Simple Revenue Trend visualizer
                        const Text(
                          'DAILY REVENUE TREND',
                          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black87, letterSpacing: 1.1),
                        ),
                        const SizedBox(height: 12),
                        Card(
                          elevation: 2,
                          shadowColor: Colors.black12,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(16, 32, 24, 16),
                            child: SizedBox(
                              height: 200,
                              child: sortedEntries.isEmpty
                                  ? const Center(
                                      child: Text(
                                        'No sales data for this period.',
                                        style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic),
                                      ),
                                    )
                                  : _buildRevenueChart(sortedEntries, maxRevenue),
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Detailed list of sales within range
                        const Text(
                          'DETAILED SALES LOG',
                          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black87, letterSpacing: 1.1),
                        ),
                        const SizedBox(height: 12),
                        Card(
                          elevation: 2,
                          shadowColor: Colors.black12,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          clipBehavior: Clip.antiAlias,
                          child: records.isEmpty
                              ? const Padding(
                                  padding: EdgeInsets.all(24.0),
                                  child: Center(
                                    child: Text(
                                      'No transactions found in this date range.',
                                      style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic),
                                    ),
                                  ),
                                )
                              : ListView.separated(
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  itemCount: records.length,
                                  separatorBuilder: (context, index) => const Divider(height: 1),
                                  itemBuilder: (context, index) {
                                    final record = records[index];
                                    final dt = record['date'] is int
                                        ? DateTime.fromMillisecondsSinceEpoch(record['date'])
                                        : record['date'] as DateTime;
                                    final timeStr = '${dt.day}/${dt.month} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
                                    final isVoided = record['method'] == 'void';
                                    
                                    return ListTile(
                                      leading: CircleAvatar(
                                        backgroundColor: isVoided ? Colors.red.shade50 : Colors.blue.shade50,
                                        child: Icon(
                                          isVoided ? Icons.cancel_outlined : Icons.receipt_outlined, 
                                          color: isVoided ? Colors.red : Colors.blueAccent
                                        ),
                                      ),
                                      title: Text(
                                        'Transaction #${record['saleNumber'] ?? record['id'] ?? ''}', 
                                        style: TextStyle(
                                          fontWeight: FontWeight.w600,
                                          decoration: isVoided ? TextDecoration.lineThrough : null,
                                          color: isVoided ? Colors.red.shade600 : Colors.black87,
                                        ),
                                      ),
                                      subtitle: Text(
                                        isVoided 
                                            ? '$timeStr • VOIDED' 
                                            : '$timeStr • ${record['method'] ?? ''}',
                                        style: TextStyle(
                                          color: isVoided ? Colors.red.shade400 : Colors.grey,
                                          fontWeight: isVoided ? FontWeight.bold : null,
                                        ),
                                      ),
                                      trailing: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            '\$${(record['total'] ?? 0.0).toStringAsFixed(2)}',
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold, 
                                              fontSize: 16, 
                                              color: isVoided ? Colors.red.shade400 : Colors.black87,
                                              decoration: isVoided ? TextDecoration.lineThrough : null,
                                            ),
                                          ),
                                          if (!isVoided) ...[
                                            const SizedBox(width: 8),
                                            PopupMenuButton<String>(
                                              onSelected: (value) {
                                                if (value == 'void') {
                                                  _voidTransaction(context, record);
                                                }
                                              },
                                              itemBuilder: (context) => [
                                                const PopupMenuItem(
                                                  value: 'void',
                                                  child: Row(
                                                    children: [
                                                      Icon(Icons.cancel_outlined, color: Colors.red, size: 20),
                                                      SizedBox(width: 8),
                                                      Text('Void Transaction', style: TextStyle(color: Colors.red)),
                                                    ],
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ],
                                      ),
                                    );
                                  },
                                ),
                        ),
                      ],
                    ),
                  );
                }

                return const Center(child: Text('Loading trends...'));
              },
            ),
          ),
        ],
      ),
    );
  }
}
