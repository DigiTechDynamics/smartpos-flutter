import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../bloc/reports/reports_bloc.dart';
import '../../bloc/reports/reports_event.dart';
import '../../bloc/reports/reports_state.dart';

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sales Trends & Summaries'),
      ),
      body: Column(
        children: [
          // Range selector
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: Colors.grey.shade100,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Date Range:',
                  style: TextStyle(fontWeight: FontWeight.bold),
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
                          color: Colors.blue.shade50,
                          child: Padding(
                            padding: const EdgeInsets.all(24.0),
                            child: Column(
                              children: [
                                const Text('TOTAL REVENUE',
                                    style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
                                const SizedBox(height: 8),
                                Text(
                                  '\$${state.totalRevenue.toStringAsFixed(2)}',
                                  style: TextStyle(
                                      fontSize: 32,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.blue.shade800),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Simple Revenue Trend visualizer
                        const Text(
                          'DAILY REVENUE TREND',
                          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey),
                        ),
                        const SizedBox(height: 12),
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: SizedBox(
                              height: 160,
                              child: sortedEntries.isEmpty
                                  ? const Center(
                                      child: Text(
                                        'No sales data for this period.',
                                        style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic),
                                      ),
                                    )
                                  : SingleChildScrollView(
                                      scrollDirection: Axis.horizontal,
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                        crossAxisAlignment: CrossAxisAlignment.end,
                                        children: sortedEntries.map((e) {
                                          final date = e.key;
                                          final revenue = e.value;
                                          final normalized = revenue / maxRevenue;
                                          final dayLabel = '${date.day}/${date.month}';
                                          return Padding(
                                            padding: const EdgeInsets.symmetric(horizontal: 10.0),
                                            child: _Bar(
                                              label: dayLabel,
                                              value: normalized,
                                              amount: revenue,
                                            ),
                                          );
                                        }).toList(),
                                      ),
                                    ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Detailed list of sales within range
                        const Text(
                          'DETAILED SALES LOG',
                          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey),
                        ),
                        const SizedBox(height: 12),
                        Card(
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
                                  separatorBuilder: (context, index) => const Divider(),
                                  itemBuilder: (context, index) {
                                    final record = records[index];
                                    final dt = record['date'] is int
                                        ? DateTime.fromMillisecondsSinceEpoch(record['date'])
                                        : record['date'] as DateTime;
                                    final timeStr = '${dt.day}/${dt.month} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
                                    
                                    return ListTile(
                                      leading: const Icon(Icons.receipt_outlined, color: Colors.blue),
                                      title: Text('Transaction ${record['id'] ?? ''}'),
                                      subtitle: Text('$timeStr via ${record['method'] ?? ''}'),
                                      trailing: Text(
                                        '\$${(record['total'] ?? 0.0).toStringAsFixed(2)}',
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
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

class _Bar extends StatelessWidget {
  final String label;
  final double value; // 0.0 to 1.0
  final double amount;

  const _Bar({
    required this.label,
    required this.value,
    required this.amount,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        if (amount > 0)
          Text(
            '\$${amount.toStringAsFixed(0)}',
            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.blue),
          ),
        const SizedBox(height: 4),
        Container(
          width: 32,
          height: 100 * value,
          decoration: BoxDecoration(
            color: Colors.blue.shade400,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(4),
              topRight: Radius.circular(4),
            ),
            gradient: LinearGradient(
              begin: Alignment.bottomCenter,
              end: Alignment.topCenter,
              colors: [
                Colors.blue.shade600,
                Colors.blue.shade300,
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
      ],
    );
  }
}
