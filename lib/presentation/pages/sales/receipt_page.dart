import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:drift/drift.dart' as drift;
import '../../../core/services/service_locator.dart';
import '../../../core/services/printer_service.dart';
import '../../../data/databases/app_database.dart';

class ReceiptPage extends StatefulWidget {
  final String saleId;
  final double change;

  const ReceiptPage({
    super.key,
    required this.saleId,
    required this.change,
  });

  @override
  State<ReceiptPage> createState() => _ReceiptPageState();
}

class _ReceiptPageState extends State<ReceiptPage> {
  bool _isLoading = true;
  Sale? _sale;
  List<SaleItem> _saleItems = [];
  List<Product> _products = [];
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadReceiptDetails();
  }

  Future<void> _loadReceiptDetails() async {
    try {
      final db = sl<AppDatabase>();
      
      final sale = await (db.select(db.sales)
        ..where((tbl) => tbl.id.equals(widget.saleId))).getSingleOrNull();
      
      if (sale == null) {
        setState(() {
          _errorMessage = 'Transaction not found';
          _isLoading = false;
        });
        return;
      }

      final items = await (db.select(db.saleItems)
        ..where((tbl) => tbl.saleId.equals(widget.saleId))).get();

      final productIds = items.map((item) => item.productId).toList();
      final products = await (db.select(db.products)
        ..where((tbl) => tbl.id.isIn(productIds))).get();

      setState(() {
        _sale = sale;
        _saleItems = items;
        _products = products;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load receipt details: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _printReceipt(BuildContext context) async {
    if (_sale == null) return;
    try {
      final printerService = sl<PrinterService>();
      
      final receipt = ReceiptData(
        storeName: 'SmartPOS Zimbabwe',
        storeAddress: '123 Harare St, Harare',
        phone: '+263770000000',
        items: _saleItems.map((item) {
          final prod = _products.firstWhere(
            (p) => p.id == item.productId,
            orElse: () => Product(
              id: item.productId,
              sku: '',
              name: 'Unknown Item',
              sellingPrice: item.unitPrice,
              costPrice: 0.0,
              taxRate: 0.0,
              createdAt: DateTime.now().millisecondsSinceEpoch,
              updatedAt: DateTime.now().millisecondsSinceEpoch,
              syncStatus: 'pending',
            ),
          );
          return ReceiptItem(name: prod.name, quantity: item.quantity, price: item.unitPrice);
        }).toList(),
        subtotal: _sale!.subtotal,
        tax: _sale!.tax,
        discount: _sale!.discount,
        total: _sale!.total,
        paymentMethod: _sale!.paymentMethod,
        amountTendered: _sale!.total + widget.change,
        change: widget.change,
      );

      if (printerService.isConnected) {
        await printerService.printReceipt(receipt);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Receipt printed successfully!'), backgroundColor: Colors.green),
          );
        }
      } else {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Printer not connected. Please connect via settings.'), backgroundColor: Colors.orange),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Print error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Widget _buildReceiptPreview() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_errorMessage != null) {
      return Center(child: Text(_errorMessage!, style: const TextStyle(color: Colors.red)));
    }
    if (_sale == null) {
      return const Center(child: Text('No transaction details loaded'));
    }

    final formattedDate = DateTime.fromMillisecondsSinceEpoch(_sale!.createdAt).toLocal().toString().substring(0, 19);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipPath(
        clipper: ReceiptClipper(),
        child: Container(
          color: Colors.yellow.shade50.withOpacity(0.4),
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Store Details Header
              const Text(
                'SmartPOS Zimbabwe',
                textAlign: TextAlign.center,
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, fontFamily: 'monospace'),
              ),
              const SizedBox(height: 4),
              const Text(
                '123 Harare St, Harare\nTel: +263 770 000 000',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: Colors.black87, fontFamily: 'monospace'),
              ),
              const SizedBox(height: 12),
              _buildDashedLine(),
              const SizedBox(height: 8),

              // Transaction Info
              Text(
                'Date: $formattedDate\nSale #: ${_sale!.saleNumber}\nPayment: ${_sale!.paymentMethod.toUpperCase()}',
                style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
              ),
              const SizedBox(height: 8),
              _buildDashedLine(),
              const SizedBox(height: 12),

              // Items Header
              const Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    flex: 3,
                    child: Text('ITEM', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, fontFamily: 'monospace')),
                  ),
                  Expanded(
                    child: Text('QTY', textAlign: TextAlign.right, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, fontFamily: 'monospace')),
                  ),
                  Expanded(
                    child: Text('PRICE', textAlign: TextAlign.right, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, fontFamily: 'monospace')),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              _buildDashedLine(),
              const SizedBox(height: 8),

              // Item List
              ..._saleItems.map((item) {
                final prod = _products.firstWhere(
                  (p) => p.id == item.productId,
                  orElse: () => Product(
                    id: item.productId,
                    sku: '',
                    name: 'Unknown Item',
                    sellingPrice: item.unitPrice,
                    costPrice: 0.0,
                    taxRate: 0.0,
                    createdAt: DateTime.now().millisecondsSinceEpoch,
                    updatedAt: DateTime.now().millisecondsSinceEpoch,
                    syncStatus: 'pending',
                  ),
                );
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        flex: 3,
                        child: Text(
                          prod.name,
                          style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          item.quantity.toStringAsFixed(0),
                          textAlign: TextAlign.right,
                          style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          '\$${item.unitPrice.toStringAsFixed(2)}',
                          textAlign: TextAlign.right,
                          style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
                        ),
                      ),
                    ],
                  ),
                );
              }),

              const SizedBox(height: 8),
              _buildDashedLine(),
              const SizedBox(height: 8),

              // Financial breakdown
              _buildReceiptRow('Subtotal', _sale!.subtotal),
              _buildReceiptRow('Tax', _sale!.tax),
              if (_sale!.discount > 0.0) _buildReceiptRow('Discount', -_sale!.discount),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('TOTAL', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, fontFamily: 'monospace')),
                  Text('\$${_sale!.total.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, fontFamily: 'monospace')),
                ],
              ),
              const SizedBox(height: 6),
              _buildDashedLine(),
              const SizedBox(height: 8),

              // Payment breakdown
              _buildReceiptRow('Amount Tendered', _sale!.total + widget.change),
              _buildReceiptRow('Change', widget.change),
              const SizedBox(height: 12),

              // Footer Barcode or message
              const Text(
                'Thank you for shopping with us!\nSmartPOS Africa',
                textAlign: TextAlign.center,
                style: TextStyle(fontStyle: FontStyle.italic, fontSize: 11, fontFamily: 'monospace'),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildReceiptRow(String label, double value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, fontFamily: 'monospace')),
          Text('\$${value.toStringAsFixed(2)}', style: const TextStyle(fontSize: 12, fontFamily: 'monospace')),
        ],
      ),
    );
  }

  Widget _buildDashedLine() {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final boxWidth = constraints.constrainWidth();
        const dashWidth = 5.0;
        const dashHeight = 1.0;
        final dashCount = (boxWidth / (2 * dashWidth)).floor();
        return Flex(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          direction: Axis.horizontal,
          children: List.generate(dashCount, (_) {
            return const SizedBox(
              width: dashWidth,
              height: dashHeight,
              child: DecoratedBox(
                decoration: BoxDecoration(color: Colors.grey),
              ),
            );
          }),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width > 850;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Transaction Complete'),
        automaticallyImplyLeading: false,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 1000),
            child: isWide
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Left Section: Status, Actions, Change Info
                      Expanded(
                        flex: 5,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _buildSuccessHeader(),
                            const SizedBox(height: 24),
                            _buildChangeCard(),
                            const SizedBox(height: 32),
                            _buildActionButtons(),
                          ],
                        ),
                      ),
                      const SizedBox(width: 48),
                      // Right Section: Receipt Preview
                      Expanded(
                        flex: 4,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const Text(
                              'RECEIPT PREVIEW',
                              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey, fontSize: 13),
                            ),
                            const SizedBox(height: 12),
                            _buildReceiptPreview(),
                          ],
                        ),
                      ),
                    ],
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildSuccessHeader(),
                      const SizedBox(height: 24),
                      _buildChangeCard(),
                      const SizedBox(height: 24),
                      const Text(
                        'RECEIPT PREVIEW',
                        style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey, fontSize: 13),
                      ),
                      const SizedBox(height: 12),
                      _buildReceiptPreview(),
                      const SizedBox(height: 32),
                      _buildActionButtons(),
                    ],
                  ),
          ),
        ),
      ),
    );
  }

  Widget _buildSuccessHeader() {
    return Column(
      children: [
        const Icon(Icons.check_circle, size: 80, color: Colors.green),
        const SizedBox(height: 16),
        const Text(
          'PAYMENT SUCCESSFUL',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.green),
        ),
        const SizedBox(height: 8),
        Text(
          'Transaction ID: ${widget.saleId}',
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.grey),
        ),
      ],
    );
  }

  Widget _buildChangeCard() {
    if (widget.change <= 0.0) return const SizedBox.shrink();
    return Card(
      color: Colors.green.shade50,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: Colors.green.shade100),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            Text('GIVE CHANGE DUE', style: TextStyle(color: Colors.green.shade800, fontWeight: FontWeight.bold, letterSpacing: 1.1)),
            const SizedBox(height: 8),
            Text(
              '\$${widget.change.toStringAsFixed(2)}',
              style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.green.shade900),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ElevatedButton.icon(
          onPressed: _isLoading ? null : () => _printReceipt(context),
          icon: const Icon(Icons.print),
          label: const Text('PRINT RECEIPT'),
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 18),
            elevation: 2,
          ),
        ),
        const SizedBox(height: 12),
        OutlinedButton(
          onPressed: () {
            context.go('/sale');
          },
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 18),
          ),
          child: const Text('NEW TRANSACTION'),
        ),
      ],
    );
  }
}

class ReceiptClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    Path path = Path();
    double width = size.width;
    double height = size.height;
    
    // Start at top-left
    path.moveTo(0.0, 0.0);
    // Line down left side to bottom-left
    path.lineTo(0.0, height);
    
    // Bottom zig-zag pattern from left to right
    double toothWidth = 8.0;
    double toothHeight = 4.0;
    int toothCount = (width / toothWidth).floor();
    
    for (int i = 0; i <= toothCount; i++) {
      double x = i * toothWidth;
      double y = height - (i % 2 == 0 ? toothHeight : 0);
      if (x > width) x = width;
      path.lineTo(x, y);
    }
    
    // Ensure we reach bottom-right corner exactly
    path.lineTo(width, height);
    // Line up right side to top-right
    path.lineTo(width, 0.0);
    // Close the path back to top-left
    path.close();
    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}
