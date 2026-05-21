import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../bloc/sale/sale_bloc.dart';
import '../../bloc/sale/sale_event.dart';
import '../../bloc/sale/sale_state.dart';
import '../../../domain/usecases/sales/create_sale_usecase.dart';

class PaymentPage extends StatefulWidget {
  const PaymentPage({super.key});

  @override
  State<PaymentPage> createState() => _PaymentPageState();
}

class _PaymentPageState extends State<PaymentPage> {
  String _selectedMethod = 'cash';
  final _amountController = TextEditingController();
  double _total = 0.0;
  
  final List<SalePaymentInput> _payments = [];
  final List<double> _usdDenominations = [1.0, 2.0, 5.0, 10.0, 20.0, 50.0, 100.0];

  double get _totalTendered => _payments.fold(0.0, (sum, p) => sum + p.amount);
  double get _remaining => _total - _totalTendered;
  double get _change => _totalTendered > _total ? _totalTendered - _total : 0.0;

  @override
  void initState() {
    super.initState();
    final state = context.read<SaleBloc>().state;
    if (state is SaleInProgress) {
      _total = state.total;
      _amountController.text = _total.toStringAsFixed(2);
    }
  }

  void _addDenomination(double value) {
    final current = double.tryParse(_amountController.text) ?? 0.0;
    final newAmount = current + value;
    _amountController.text = newAmount.toStringAsFixed(2);
    setState(() {}); // trigger rebuild
  }

  void _addPayment() {
    final amount = double.tryParse(_amountController.text) ?? 0.0;
    if (amount <= 0) return;
    
    setState(() {
      _payments.add(SalePaymentInput(method: _selectedMethod, amount: amount));
      if (_remaining > 0) {
        _amountController.text = _remaining.toStringAsFixed(2);
      } else {
        _amountController.text = '';
      }
    });
  }

  void _removePayment(int index) {
    setState(() {
      _payments.removeAt(index);
      if (_remaining > 0) {
        _amountController.text = _remaining.toStringAsFixed(2);
      }
    });
  }

  void _submit() {
    // If the user hasn't explicitly clicked "Add Payment" but there's text, add it
    if (_remaining > 0 && _amountController.text.isNotEmpty) {
       final amount = double.tryParse(_amountController.text) ?? 0.0;
       if (amount > 0) {
         _payments.add(SalePaymentInput(method: _selectedMethod, amount: amount));
       }
    }
    
    context.read<SaleBloc>().add(ProcessPayment(_payments));
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
                  color: _remaining <= 0 ? Colors.green.shade50 : Colors.blue.shade50,
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      children: [
                        Text(_remaining <= 0 ? 'CHANGE DUE' : 'REMAINING BALANCE',
                            style: const TextStyle(fontSize: 14, color: Colors.grey, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        Text(
                          '\$${(_remaining <= 0 ? _change : _remaining).toStringAsFixed(2)}',
                          style: TextStyle(
                              fontSize: 36,
                              fontWeight: FontWeight.bold,
                              color: _remaining <= 0 ? Colors.green.shade800 : Colors.blue.shade800),
                        ),
                        if (_totalTendered > 0) ...[
                          const SizedBox(height: 8),
                          Text('Total Due: \$${_total.toStringAsFixed(2)} | Tendered: \$${_totalTendered.toStringAsFixed(2)}', 
                               style: const TextStyle(color: Colors.grey)),
                        ]
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                
                // Active Payments List
                if (_payments.isNotEmpty) ...[
                  const Text('TENDERED PAYMENTS', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
                  const SizedBox(height: 8),
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _payments.length,
                    itemBuilder: (context, index) {
                      final p = _payments[index];
                      return ListTile(
                        leading: Icon(p.method == 'cash' ? Icons.money : p.method == 'card' ? Icons.credit_card : Icons.phone_android),
                        title: Text('${p.method.toUpperCase()} Payment'),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text('\$${p.amount.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold)),
                            IconButton(
                              icon: const Icon(Icons.close, color: Colors.red),
                              onPressed: () => _removePayment(index),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                  const Divider(),
                ],

                if (_remaining > 0) ...[
                  // Payment Method Selector
                  const SizedBox(height: 12),
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
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _amountController,
                          decoration: const InputDecoration(
                            labelText: 'Amount Tendered',
                            prefixText: '\$ ',
                            border: OutlineInputBorder(),
                          ),
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          onChanged: (val) => setState((){}),
                          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(width: 16),
                      ElevatedButton(
                        onPressed: _addPayment,
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 24),
                        ),
                        child: const Text('ADD'),
                      ),
                    ],
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
                  ],
                ],

                const SizedBox(height: 48),

                ElevatedButton(
                  onPressed: (_remaining <= 0 || _amountController.text.isNotEmpty) ? _submit : null,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    backgroundColor: _remaining <= 0 ? Colors.green : Colors.blue,
                  ),
                  child: const Text('PROCESS TRANSACTION',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

