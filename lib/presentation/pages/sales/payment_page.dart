import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../bloc/sale/sale_bloc.dart';
import '../../bloc/sale/sale_event.dart';
import '../../bloc/sale/sale_state.dart';
import 'receipt_page.dart';

class PaymentPage extends StatefulWidget {
  const PaymentPage({super.key});

  @override
  State<PaymentPage> createState() => _PaymentPageState();
}

class _PaymentPageState extends State<PaymentPage> {
  String _selectedMethod = 'cash';
  final _amountController = TextEditingController();
  double _change = 0.0;
  double _total = 0.0;

  final List<double> _usdDenominations = [1.0, 2.0, 5.0, 10.0, 20.0, 50.0, 100.0];

  @override
  void initState() {
    super.initState();
    final state = context.read<SaleBloc>().state;
    if (state is SaleInProgress) {
      _total = state.total;
      _amountController.text = _total.toStringAsFixed(2);
    }
  }

  void _calculateChange(String input) {
    final tendered = double.tryParse(input) ?? 0.0;
    setState(() {
      _change = tendered > _total ? tendered - _total : 0.0;
    });
  }

  void _addDenomination(double value) {
    final current = double.tryParse(_amountController.text) ?? 0.0;
    final newAmount = current + value;
    _amountController.text = newAmount.toStringAsFixed(2);
    _calculateChange(_amountController.text);
  }

  void _submit() {
    final tendered = double.tryParse(_amountController.text) ?? 0.0;
    context.read<SaleBloc>().add(
          ProcessPayment(_selectedMethod, tendered),
        );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Payment & Checkout'),
      ),
      body: BlocConsumer<SaleBloc, SaleState>(
        listener: (context, state) {
          if (state is SaleComplete) {
            context.go(
              '/sale/receipt',
              extra: {
                'saleId': state.saleId,
                'change': state.change,
              },
            );
          } else if (state is SaleError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(state.message), backgroundColor: Colors.red),
            );
          }
        },
        builder: (context, state) {
          return SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Summary Total Card
                Card(
                  color: Colors.blue.shade50,
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      children: [
                        const Text('TOTAL DUE',
                            style: TextStyle(fontSize: 14, color: Colors.grey, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        Text(
                          '\$${_total.toStringAsFixed(2)}',
                          style: TextStyle(
                              fontSize: 36,
                              fontWeight: FontWeight.bold,
                              color: Colors.blue.shade800),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Payment Method Selector
                const Text('SELECT PAYMENT METHOD',
                    style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: ChoiceChip(
                        label: const Padding(
                          padding: EdgeInsets.symmetric(vertical: 8.0),
                          child: Column(
                            children: [
                              Icon(Icons.money),
                              SizedBox(height: 4),
                              Text('Cash'),
                            ],
                          ),
                        ),
                        selected: _selectedMethod == 'cash',
                        onSelected: (val) {
                          if (val) setState(() => _selectedMethod = 'cash');
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ChoiceChip(
                        label: const Padding(
                          padding: EdgeInsets.symmetric(vertical: 8.0),
                          child: Column(
                            children: [
                              Icon(Icons.phone_android),
                              SizedBox(height: 4),
                              Text('EcoCash'),
                            ],
                          ),
                        ),
                        selected: _selectedMethod == 'mobile',
                        onSelected: (val) {
                          if (val) setState(() => _selectedMethod = 'mobile');
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ChoiceChip(
                        label: const Padding(
                          padding: EdgeInsets.symmetric(vertical: 8.0),
                          child: Column(
                            children: [
                              Icon(Icons.credit_card),
                              SizedBox(height: 4),
                              Text('Card'),
                            ],
                          ),
                        ),
                        selected: _selectedMethod == 'card',
                        onSelected: (val) {
                          if (val) setState(() => _selectedMethod = 'card');
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Amount Tendered Field
                TextFormField(
                  controller: _amountController,
                  decoration: const InputDecoration(
                    labelText: 'Amount Tendered',
                    prefixText: '\$ ',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  onChanged: _calculateChange,
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),

                // Denominations shortcuts (Only for Cash)
                if (_selectedMethod == 'cash') ...[
                  const Text('QUICK USD DENOMINATIONS',
                      style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _usdDenominations.map((denom) {
                      return ActionChip(
                        label: Text('+\$${denom.toInt()}'),
                        onPressed: () => _addDenomination(denom),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Change Due:', style: TextStyle(fontSize: 18)),
                      Text(
                        '\$${_change.toStringAsFixed(2)}',
                        style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.green),
                      ),
                    ],
                  ),
                ],

                const SizedBox(height: 48),

                ElevatedButton(
                  onPressed: _submit,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 18),
                  ),
                  child: const Text('PROCESS TRANSACTION',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
