import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uuid/uuid.dart';
import '../../../presentation/bloc/auth/auth_bloc.dart';
import '../../../presentation/bloc/auth/auth_state.dart';
import '../../../core/services/service_locator.dart';
import '../../../domain/repositories/product_repository.dart';
import '../../../domain/repositories/inventory_repository.dart';
import '../../../data/databases/app_database.dart';

class InventoryPage extends StatefulWidget {
  const InventoryPage({super.key});

  @override
  State<InventoryPage> createState() => _InventoryPageState();
}

class _InventoryPageState extends State<InventoryPage> {
  bool _isLoading = false;
  List<Product> _products = [];
  Map<String, double> _stockMap = {};
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  Future<void> _loadProducts() async {
    setState(() => _isLoading = true);
    try {
      final products = await sl<ProductRepository>().getAll();
      final inventoryRepo = sl<InventoryRepository>();
      final Map<String, double> stockMap = {};
      for (final p in products) {
        final stock = await inventoryRepo.getStock(p.id);
        stockMap[p.id] = stock?.quantityOnHand ?? 0.0;
      }
      setState(() {
        _products = products;
        _stockMap = stockMap;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load products: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _searchProducts(String query) async {
    if (query.isEmpty) {
      _loadProducts();
      return;
    }
    setState(() => _isLoading = true);
    try {
      final products = await sl<ProductRepository>().search(query);
      final inventoryRepo = sl<InventoryRepository>();
      final Map<String, double> stockMap = {};
      for (final p in products) {
        final stock = await inventoryRepo.getStock(p.id);
        stockMap[p.id] = stock?.quantityOnHand ?? 0.0;
      }
      setState(() {
        _products = products;
        _stockMap = stockMap;
      });
    } catch (e) {
      // ignore
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showAddEditProductDialog({Product? product}) {
    final nameController = TextEditingController(text: product?.name ?? '');
    final skuController = TextEditingController(text: product?.sku ?? '');
    final barcodeController = TextEditingController(text: product?.barcode ?? '');
    final sellPriceController = TextEditingController(text: product?.sellingPrice.toString() ?? '');
    final costPriceController = TextEditingController(text: product?.costPrice.toString() ?? '');
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(product == null ? 'Add Product' : 'Edit Product'),
          content: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: nameController,
                    decoration: const InputDecoration(labelText: 'Name'),
                    validator: (v) => v!.isEmpty ? 'Required' : null,
                  ),
                  TextFormField(
                    controller: skuController,
                    decoration: const InputDecoration(labelText: 'SKU'),
                    validator: (v) => v!.isEmpty ? 'Required' : null,
                  ),
                  TextFormField(
                    controller: barcodeController,
                    decoration: const InputDecoration(labelText: 'Barcode (Optional)'),
                  ),
                  TextFormField(
                    controller: costPriceController,
                    decoration: const InputDecoration(labelText: 'Cost Price'),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    validator: (v) => v!.isEmpty ? 'Required' : null,
                  ),
                  TextFormField(
                    controller: sellPriceController,
                    decoration: const InputDecoration(labelText: 'Selling Price'),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    validator: (v) => v!.isEmpty ? 'Required' : null,
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (formKey.currentState!.validate()) {
                  final newProduct = Product(
                    id: product?.id ?? const Uuid().v4(),
                    name: nameController.text.trim(),
                    sku: skuController.text.trim(),
                    barcode: barcodeController.text.trim().isEmpty ? null : barcodeController.text.trim(),
                    costPrice: double.parse(costPriceController.text),
                    sellingPrice: double.parse(sellPriceController.text),
                    taxRate: product?.taxRate ?? 0.0,
                    createdAt: product?.createdAt ?? DateTime.now().millisecondsSinceEpoch,
                    updatedAt: DateTime.now().millisecondsSinceEpoch,
                    syncedAt: product?.syncedAt,
                    syncStatus: 'pending',
                  );

                  try {
                    if (product == null) {
                      await sl<ProductRepository>().add(newProduct);
                    } else {
                      await sl<ProductRepository>().updateProduct(newProduct);
                    }
                    Navigator.pop(context);
                    _loadProducts();
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error: $e')),
                    );
                  }
                }
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  void _showAdjustStockDialog(Product product) async {
    final inventoryRepo = sl<InventoryRepository>();
    final currentStock = await inventoryRepo.getStock(product.id);
    
    final qtyController = TextEditingController();
    final reasonController = TextEditingController(text: 'Stock Take');

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Adjust Stock: ${product.name}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Current Quantity on Hand: ${currentStock?.quantityOnHand ?? 0.0}'),
              const SizedBox(height: 16),
              TextField(
                controller: qtyController,
                decoration: const InputDecoration(labelText: 'Quantity Change (+ or -)'),
                keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
              ),
              TextField(
                controller: reasonController,
                decoration: const InputDecoration(labelText: 'Reason'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                final qty = double.tryParse(qtyController.text);
                if (qty != null && qty != 0) {
                  try {
                    await inventoryRepo.adjustStock(
                      product.id,
                      qty,
                      reasonController.text.trim(),
                      _getUserId(),
                    );
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Stock updated successfully')),
                    );
                    _loadProducts();
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Failed to adjust stock: $e')),
                    );
                  }
                }
              },
              child: const Text('Update Stock'),
            ),
          ],
        );
      },
    );
  }

  String _getUserId() {
    final state = context.read<AuthBloc>().state;
    if (state is Authenticated) {
      return state.userId;
    }
    return 'unknown_user';
  }

  Widget _buildKPICards() {
    final totalProducts = _products.length;
    final lowStock = _stockMap.values.where((qty) => qty > 0 && qty <= 5).length;
    final outOfStock = _stockMap.values.where((qty) => qty <= 0).length;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      child: Row(
        children: [
          Expanded(
            child: _buildKPITile(
              title: 'Total Items',
              value: totalProducts.toString(),
              icon: Icons.inventory_2_outlined,
              color: Colors.blue,
              valueColor: Colors.blue.shade800,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildKPITile(
              title: 'Low Stock',
              value: lowStock.toString(),
              icon: Icons.warning_amber_rounded,
              color: Colors.orange,
              valueColor: Colors.orange.shade900,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildKPITile(
              title: 'Out of Stock',
              value: outOfStock.toString(),
              icon: Icons.error_outline_rounded,
              color: Colors.redAccent,
              valueColor: Colors.red.shade900,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildKPITile({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    required Color valueColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.12), width: 1.5),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: color.withOpacity(0.1),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: valueColor,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Inventory Management'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadProducts,
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildKPICards(),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search products by name or SKU...',
                prefixIcon: const Icon(Icons.search, size: 20),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () {
                          _searchController.clear();
                          _loadProducts();
                        },
                      )
                    : null,
                contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                filled: true,
                fillColor: Colors.grey.shade100,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: Colors.grey.shade300, width: 1),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: Colors.grey.shade200, width: 1),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Colors.blue, width: 1.5),
                ),
              ),
              onChanged: _searchProducts,
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _products.isEmpty
                    ? const Center(child: Text('No products found.'))
                    : ListView.separated(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                        itemCount: _products.length,
                        separatorBuilder: (context, index) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final product = _products[index];
                          final qty = _stockMap[product.id] ?? 0.0;
                          
                          Color badgeColor;
                          Color badgeTextColor;
                          String badgeLabel;
                          
                          if (qty <= 0) {
                            badgeColor = Colors.red.shade50;
                            badgeTextColor = Colors.red.shade800;
                            badgeLabel = 'Out of stock';
                          } else if (qty <= 5) {
                            badgeColor = Colors.orange.shade50;
                            badgeTextColor = Colors.orange.shade800;
                            badgeLabel = 'Low stock (${qty.toStringAsFixed(0)})';
                          } else {
                            badgeColor = Colors.green.shade50;
                            badgeTextColor = Colors.green.shade800;
                            badgeLabel = 'In stock (${qty.toStringAsFixed(0)})';
                          }

                          return Card(
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: BorderSide(color: Colors.grey.shade200, width: 1),
                            ),
                            margin: EdgeInsets.zero,
                            child: Padding(
                              padding: const EdgeInsets.all(12.0),
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    backgroundColor: Colors.blue.shade50,
                                    child: const Icon(Icons.inventory_2_outlined, color: Colors.blue, size: 20),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          product.name,
                                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                        ),
                                        const SizedBox(height: 4),
                                        Row(
                                          children: [
                                            Text(
                                              'SKU: ${product.sku}',
                                              style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                                            ),
                                            const SizedBox(width: 12),
                                            Container(
                                              width: 4,
                                              height: 4,
                                              decoration: BoxDecoration(
                                                color: Colors.grey.shade400,
                                                shape: BoxShape.circle,
                                              ),
                                            ),
                                            const SizedBox(width: 12),
                                            Text(
                                              'Price: \$${product.sellingPrice.toStringAsFixed(2)}',
                                              style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: badgeColor,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      badgeLabel,
                                      style: TextStyle(
                                        color: badgeTextColor,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  IconButton(
                                    icon: const Icon(Icons.edit_outlined, color: Colors.blue, size: 20),
                                    onPressed: () => _showAddEditProductDialog(product: product),
                                    tooltip: 'Edit Product',
                                    constraints: const BoxConstraints(),
                                    padding: EdgeInsets.zero,
                                  ),
                                  const SizedBox(width: 8),
                                  IconButton(
                                    icon: const Icon(Icons.add_box_outlined, color: Colors.green, size: 20),
                                    onPressed: () => _showAdjustStockDialog(product),
                                    tooltip: 'Adjust Stock',
                                    constraints: const BoxConstraints(),
                                    padding: EdgeInsets.zero,
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddEditProductDialog(),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        child: const Icon(Icons.add),
      ),
    );
  }
}
