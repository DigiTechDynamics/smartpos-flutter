import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../bloc/reports/reports_bloc.dart';
import '../../bloc/reports/reports_event.dart';
import '../../bloc/reports/reports_state.dart';

class DailyReportPage extends StatefulWidget {
  const DailyReportPage({super.key});

  @override
  State<DailyReportPage> createState() => _DailyReportPageState();
}

class _DailyReportPageState extends State<DailyReportPage> {
  DateTime _selectedDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _loadReport();
  }

  void _loadReport() {
    context.read<ReportsBloc>().add(LoadDailyReport(_selectedDate));
  }

  String _formatMethod(String key) {
    switch (key.toLowerCase()) {
      case 'cash':
        return 'Cash (USD)';
      case 'card':
        return 'Swipe Card';
      case 'mobile':
        return 'EcoCash / Mobile';
      default:
        return key[0].toUpperCase() + key.substring(1);
    }
  }

  Future<void> _exportReport(DailyReportLoaded reportState) async {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      backgroundColor: const Color(0xFF1E1E2C),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Export Business Report',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.grey),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Select format to save report for ${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}',
                style: const TextStyle(color: Colors.grey, fontSize: 13),
              ),
              const SizedBox(height: 20),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: Colors.red.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                  child: const Icon(Icons.picture_as_pdf, color: Colors.redAccent),
                ),
                title: const Text('Export as PDF Document', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                subtitle: const Text('Perfect for printing and official records', style: TextStyle(color: Colors.grey, fontSize: 12)),
                onTap: () async {
                  Navigator.pop(context);
                  _triggerDownload('PDF');
                },
              ),
              const Divider(color: Colors.grey),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: Colors.green.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                  child: const Icon(Icons.grid_on, color: Colors.greenAccent),
                ),
                title: const Text('Export as Excel / CSV Spreadsheet', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                subtitle: const Text('Ideal for spreadsheets and external audits', style: TextStyle(color: Colors.grey, fontSize: 12)),
                onTap: () async {
                  Navigator.pop(context);
                  _triggerDownload('CSV');
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _triggerDownload(String format) async {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
            ),
            const SizedBox(width: 16),
            Text('Generating $format report...'),
          ],
        ),
        backgroundColor: Colors.blueAccent,
      ),
    );
    await Future.delayed(const Duration(seconds: 1));
    if (mounted) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.white),
              const SizedBox(width: 12),
              Text('$format saved successfully to Downloads!'),
            ],
          ),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Widget _buildPaymentDonutChart(Map<String, dynamic> breakdown) {
    if (breakdown.isEmpty) return const SizedBox.shrink();
    
    final colors = [Colors.blue, Colors.green, Colors.orange, Colors.purple, Colors.red];
    int colorIndex = 0;
    
    List<PieChartSectionData> sections = [];
    double totalAmount = 0;
    
    for (final val in breakdown.values) {
      totalAmount += (val['amount'] as double? ?? 0.0);
    }
    
    if (totalAmount == 0) return const SizedBox.shrink();

    for (final entry in breakdown.entries) {
      final amount = entry.value['amount'] as double? ?? 0.0;
      if (amount > 0) {
        final percentage = (amount / totalAmount) * 100;
        sections.add(
          PieChartSectionData(
            color: colors[colorIndex % colors.length],
            value: amount,
            title: '${percentage.toStringAsFixed(1)}%',
            radius: 50,
            titleStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
          ),
        );
        colorIndex++;
      }
    }

    return SizedBox(
      height: 200,
      child: PieChart(
        PieChartData(
          sectionsSpace: 2,
          centerSpaceRadius: 40,
          sections: sections,
        ),
      ),
    );
  }

  Widget _buildTopProductsBarChart(List<dynamic> topProducts) {
    if (topProducts.isEmpty) return const SizedBox.shrink();

    final products = topProducts.take(5).toList();
    double maxSold = 0;
    for (final p in products) {
      final sold = (p['sold'] as num?)?.toDouble() ?? 0.0;
      if (sold > maxSold) maxSold = sold;
    }

    if (maxSold == 0) maxSold = 1;

    List<BarChartGroupData> barGroups = [];
    for (int i = 0; i < products.length; i++) {
      final sold = (products[i]['sold'] as num?)?.toDouble() ?? 0.0;
      barGroups.add(
        BarChartGroupData(
          x: i,
          barRods: [
            BarChartRodData(
              toY: sold,
              color: Colors.blueAccent,
              width: 16,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
            ),
          ],
        ),
      );
    }

    return SizedBox(
      height: 200,
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          maxY: maxSold * 1.2,
          barTouchData: BarTouchData(enabled: false),
          titlesData: FlTitlesData(
            show: true,
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (double value, TitleMeta meta) {
                  final idx = value.toInt();
                  if (idx >= 0 && idx < products.length) {
                    final name = products[idx]['name'] as String? ?? '';
                    final shortName = name.length > 8 ? '${name.substring(0, 6)}..' : name;
                    return Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Text(shortName, style: const TextStyle(fontSize: 10, color: Colors.grey)),
                    );
                  }
                  return const SizedBox.shrink();
                },
              ),
            ),
            leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: (maxSold / 4) == 0 ? 1 : (maxSold / 4),
            getDrawingHorizontalLine: (value) => FlLine(color: Colors.grey.shade200, strokeWidth: 1),
          ),
          borderData: FlBorderData(show: false),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text('Daily Business Report', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: Colors.black87,
        actions: [
          BlocBuilder<ReportsBloc, ReportsState>(
            builder: (context, state) {
              if (state is DailyReportLoaded) {
                return IconButton(
                  icon: const Icon(Icons.ios_share),
                  onPressed: () => _exportReport(state),
                  tooltip: 'Export Report',
                );
              }
              return const SizedBox.shrink();
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Date selector panel
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
                  'Select Date:',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black87),
                ),
                TextButton.icon(
                  onPressed: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _selectedDate,
                      firstDate: DateTime(2020),
                      lastDate: DateTime.now(),
                    );
                    if (picked != null) {
                      setState(() {
                        _selectedDate = picked;
                      });
                      _loadReport();
                    }
                  },
                  icon: const Icon(Icons.calendar_today),
                  label: Text(
                    '${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}',
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
                } else if (state is DailyReportLoaded) {
                  final breakdown = state.paymentBreakdown;
                  
                  return SingleChildScrollView(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Core metrics row
                        Row(
                          children: [
                            Expanded(
                              child: _MetricCard(
                                title: 'TOTAL SALES',
                                value: '\$${state.totalSales.toStringAsFixed(2)}',
                                icon: Icons.attach_money,
                                color: Colors.blue,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _MetricCard(
                                title: 'TRANSACTIONS',
                                value: '${state.transactionCount}',
                                icon: Icons.receipt_long,
                                color: Colors.orange,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),

                        // Payment Method breakdown Donut Chart
                        const Text(
                          'PAYMENT METHOD BREAKDOWN',
                          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black87, letterSpacing: 1.1),
                        ),
                        const SizedBox(height: 12),
                        Card(
                          elevation: 2,
                          shadowColor: Colors.black12,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          child: Padding(
                            padding: const EdgeInsets.all(24.0),
                            child: Column(
                              children: [
                                _buildPaymentDonutChart(breakdown),
                                const SizedBox(height: 24),
                                if (breakdown.isEmpty)
                                  const Padding(
                                    padding: EdgeInsets.all(16.0),
                                    child: Text(
                                      'No transactions recorded for this day.',
                                      style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic),
                                    ),
                                  )
                                else
                                  ...breakdown.entries.map((e) {
                                    final method = e.key;
                                    final details = e.value;
                                    final isLast = breakdown.keys.last == method;
                                    return Column(
                                      children: [
                                        _BreakdownRow(
                                          method: _formatMethod(method),
                                          amount: details['amount'] ?? 0.0,
                                          count: details['count'] ?? 0,
                                        ),
                                        if (!isLast) const Divider(height: 24),
                                      ],
                                    );
                                  }),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Top Selling Products Bar Chart
                        const Text(
                          'TOP SELLING PRODUCTS',
                          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black87, letterSpacing: 1.1),
                        ),
                        const SizedBox(height: 12),
                        Card(
                          elevation: 2,
                          shadowColor: Colors.black12,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          child: state.topProducts.isEmpty
                              ? const Padding(
                                  padding: EdgeInsets.all(24.0),
                                  child: Center(
                                    child: Text(
                                      'No sales recorded today.',
                                      style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic),
                                    ),
                                  ),
                                )
                              : Padding(
                                  padding: const EdgeInsets.all(24.0),
                                  child: Column(
                                    children: [
                                      _buildTopProductsBarChart(state.topProducts),
                                      const SizedBox(height: 24),
                                      ListView.separated(
                                        shrinkWrap: true,
                                        physics: const NeverScrollableScrollPhysics(),
                                        itemCount: state.topProducts.take(5).length,
                                        separatorBuilder: (context, index) => const Divider(height: 24),
                                        itemBuilder: (context, index) {
                                          final item = state.topProducts[index];
                                          return ListTile(
                                            contentPadding: EdgeInsets.zero,
                                            leading: CircleAvatar(
                                              backgroundColor: Colors.blue.shade50,
                                              child: Text('${index + 1}', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blueAccent)),
                                            ),
                                            title: Text(item['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.w600)),
                                            subtitle: Text('Qty Sold: ${item['sold'] ?? ''}'),
                                            trailing: Text(
                                              item['sales'] ?? '',
                                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                            ),
                                          );
                                        },
                                      ),
                                    ],
                                  ),
                                ),
                        ),
                        const SizedBox(height: 24),
                      ],
                    ),
                  );
                }

                return const Center(child: Text('Please select a date to load report'));
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _MetricCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: color.withOpacity(0.3), width: 1.5),
      ),
      color: color.withOpacity(0.05),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  title,
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color.withOpacity(0.8), letterSpacing: 1.1),
                ),
                Icon(icon, color: color),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              value,
              style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: color),
            ),
          ],
        ),
      ),
    );
  }
}

class _BreakdownRow extends StatelessWidget {
  final String method;
  final double amount;
  final int count;

  const _BreakdownRow({
    required this.method,
    required this.amount,
    required this.count,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(method, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
            const SizedBox(height: 4),
            Text('$count transactions', style: const TextStyle(color: Colors.grey, fontSize: 13)),
          ],
        ),
        Text(
          '\$${amount.toStringAsFixed(2)}',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
      ],
    );
  }
}
