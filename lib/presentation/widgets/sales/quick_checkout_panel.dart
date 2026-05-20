import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../bloc/sale/sale_bloc.dart';
import '../../bloc/sale/sale_event.dart';
import '../../bloc/sale/sale_state.dart';

class QuickCheckoutPanel extends StatelessWidget {
  final SaleInProgress state;

  const QuickCheckoutPanel({super.key, required this.state});

  List<double> _getQuickCashOptions(double total) {
    final List<double> bills = [1.0, 2.0, 5.0, 10.0, 20.0, 50.0, 100.0];
    final options = <double>[];
    
    // Add dynamic rounding bill suggestions
    if (total > 0 && total % 1 != 0) {
      options.add(total.ceilToDouble());
    }
    
    for (final bill in bills) {
      if (bill > total) {
        options.add(bill);
      }
    }
    
    if (total > 100) {
      options.add(((total / 50).ceil() * 50).toDouble());
      options.add(((total / 100).ceil() * 100).toDouble());
    }

    return options.toSet().toList()..sort();
  }

  @override
  Widget build(BuildContext context) {
    final total = state.total;
    final cashOptions = _getQuickCashOptions(total);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        const Divider(height: 24, thickness: 0.8),
        Row(
          children: [
            const Icon(Icons.bolt, color: Colors.amber, size: 16),
            const SizedBox(width: 6),
            Text(
              'SEAMLESS QUICK CHECKOUT',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 11,
                color: Colors.grey.shade600,
                letterSpacing: 0.8,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        
        // Horizontal grid of exact payment options
        Row(
          children: [
            Expanded(
              child: _buildQuickMethodCard(
                context: context,
                label: 'Exact Cash',
                icon: Icons.money,
                color: Colors.green,
                onPressed: () {
                  context.read<SaleBloc>().add(ProcessPayment('cash', total));
                },
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildQuickMethodCard(
                context: context,
                label: 'Quick Card',
                icon: Icons.credit_card,
                color: Colors.indigo,
                onPressed: () {
                  context.read<SaleBloc>().add(ProcessPayment('card', total));
                },
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildQuickMethodCard(
                context: context,
                label: 'EcoCash',
                icon: Icons.phone_android,
                color: Colors.amber,
                onPressed: () {
                  context.read<SaleBloc>().add(ProcessPayment('mobile', total));
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        
        // Cash bill recommendations
        if (cashOptions.isNotEmpty) ...[
          Text(
            'TENDER CASH SUGGESTIONS',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 10,
              color: Colors.grey.shade500,
              letterSpacing: 0.6,
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 38,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: cashOptions.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final amount = cashOptions[index];
                final change = amount - total;
                return ActionChip(
                  avatar: const Icon(Icons.attach_money, size: 14, color: Colors.green),
                  label: Text(
                    '+\$${amount.toStringAsFixed(0)}',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.green),
                  ),
                  tooltip: change > 0 ? 'Change due: \$${change.toStringAsFixed(2)}' : 'Exact cash',
                  backgroundColor: Colors.green.shade50,
                  side: BorderSide(color: Colors.green.shade200, width: 0.8),
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
                  onPressed: () {
                    context.read<SaleBloc>().add(ProcessPayment('cash', amount));
                  },
                );
              },
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildQuickMethodCard({
    required BuildContext context,
    required String label,
    required IconData icon,
    required MaterialColor color,
    required VoidCallback onPressed,
  }) {
    return Material(
      color: color.shade50,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: color.shade200, width: 0.8),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: color.shade800, size: 22),
              const SizedBox(height: 6),
              Text(
                label,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 11,
                  color: color.shade900,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
