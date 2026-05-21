import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uuid/uuid.dart';
import 'package:barcode_scan2/barcode_scan2.dart';
import '../../../presentation/bloc/auth/auth_bloc.dart';
import '../../../presentation/bloc/auth/auth_state.dart';
import '../../../core/services/service_locator.dart';
import '../../../domain/repositories/product_repository.dart';
import '../../../domain/repositories/inventory_repository.dart';
import '../../../domain/repositories/user_repository.dart';
import '../../../data/databases/app_database.dart';
import '../../widgets/common/manager_override_dialog.dart';

enum InventoryFilter { all, lowStock, outOfStock }

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
  InventoryFilter _currentFilter = InventoryFilter.all;

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

  Future<void> _scanBarcode() async {
    try {
      final result = await BarcodeScanner.scan();
      if (result.type == ResultType.Barcode && result.rawContent.isNotEmpty) {
        _searchController.text = result.rawContent;
        _searchProducts(result.rawContent);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to scan barcode: $e')),
      );
    }
  }

  Future<void> _quickAdjustStock(Product product, double change) async {
    final hasAccess = await _ensureManagerOrAdmin(
      'Quick Adjust Stock: ${product.name} (${change > 0 ? "+" : ""}${change.toStringAsFixed(0)})'
    );
    if (!hasAccess) return;

    final inventoryRepo = sl<InventoryRepository>();
    
    // Optimistic UI update
    setState(() {
      _stockMap[product.id] = (_stockMap[product.id] ?? 0.0) + change;
    });

    try {
      await inventoryRepo.adjustStock(
        product.id,
        change,
        'Quick adjust',
        _getUserId(),
      );
    } catch (e) {
      // Revert on failure
      setState(() {
        _stockMap[product.id] = (_stockMap[product.id] ?? 0.0) - change;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to adjust stock: $e')),
      );
    }
  }

  void _showAddEditProductDialog({Product? product}) async {
    final hasAccess = await _ensureManagerOrAdmin(
      product == null ? 'Add New Product' : 'Edit Product: ${product.name}'
    );
    if (!hasAccess) return;

    final nameController = TextEditingController(text: product?.name ?? '');
    final skuController = TextEditingController(text: product?.sku ?? '');
    final barcodeController = TextEditingController(text: product?.barcode ?? '');
    final categoryController = TextEditingController(text: product?.category ?? '');
    final imageUrlController = TextEditingController(text: product?.imageUrl ?? '');
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
                    controller: categoryController,
                    decoration: const InputDecoration(labelText: 'Category (Optional)'),
                  ),
                  TextFormField(
                    controller: imageUrlController,
                    decoration: const InputDecoration(labelText: 'Image URL (Optional)'),
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
                    category: categoryController.text.trim().isEmpty ? null : categoryController.text.trim(),
                    imageUrl: imageUrlController.text.trim().isEmpty ? null : imageUrlController.text.trim(),
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
    final hasAccess = await _ensureManagerOrAdmin('Detailed Stock Adjust: ${product.name}');
    if (!hasAccess) return;

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

  Future<bool> _ensureManagerOrAdmin(String action) async {
    final userRepo = sl<UserRepository>();
    final currentUser = await userRepo.getCurrentUser();
    if (currentUser != null) {
      if (currentUser.role == 'admin' || currentUser.role == 'manager') {
        return true;
      }
      
      // Trigger manager override dialog
      if (!mounted) return false;
      final manager = await ManagerOverrideDialog.show(
        context,
        actionName: action,
      );
      return manager != null;
    }
    return false;
  }

  Color _getAvatarColor(String id) {
    final colors = [
      Colors.blue, Colors.red, Colors.green, Colors.orange, 
      Colors.purple, Colors.teal, Colors.pink, Colors.indigo
    ];
    int hash = id.hashCode;
    return colors[hash.abs() % colors.length];
  }

  Widget _buildProductAvatar(Product product) {
    if (product.imageUrl != null && product.imageUrl!.isNotEmpty) {
      return CircleAvatar(
        backgroundImage: NetworkImage(product.imageUrl!),
        backgroundColor: Colors.grey.shade200,
        radius: 22,
      );
    }
    
    final color = _getAvatarColor(product.id);
    final initial = product.name.isNotEmpty ? product.name[0].toUpperCase() : '?';
    
    return CircleAvatar(
      backgroundColor: color.withOpacity(0.15),
      radius: 22,
      child: Text(
        initial,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.bold,
          fontSize: 16,
        ),
      ),
    );
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
              isSelected: _currentFilter == InventoryFilter.all,
              onTap: () => setState(() => _currentFilter = InventoryFilter.all),
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
              isSelected: _currentFilter == InventoryFilter.lowStock,
              onTap: () => setState(() => _currentFilter = InventoryFilter.lowStock),
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
              isSelected: _currentFilter == InventoryFilter.outOfStock,
              onTap: () => setState(() => _currentFilter = InventoryFilter.outOfStock),
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
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16.0),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.15) : color.withOpacity(0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? color : color.withOpacity(0.12), 
            width: isSelected ? 2.0 : 1.5
          ),
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
                      color: Colors.grey.shade700,
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
                suffixIcon: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_searchController.text.isNotEmpty)
                      IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () {
                          _searchController.clear();
                          _searchProducts('');
                        },
                      ),
                    IconButton(
                      icon: const Icon(Icons.qr_code_scanner, color: Colors.blue),
                      onPressed: _scanBarcode,
                      tooltip: 'Scan Barcode',
                    ),
                  ],
                ),
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
            child: Builder(
              builder: (context) {
                if (_isLoading) return const Center(child: CircularProgressIndicator());
                
                final displayProducts = _products.where((p) {
                  final qty = _stockMap[p.id] ?? 0.0;
                  if (_currentFilter == InventoryFilter.lowStock) return qty > 0 && qty <= 5;
                  if (_currentFilter == InventoryFilter.outOfStock) return qty <= 0;
                  return true;
                }).toList();

                if (displayProducts.isEmpty) {
                   return const Center(child: Text('No products found matching criteria.'));
                }

                return ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                  itemCount: displayProducts.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final product = displayProducts[index];
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
                            _buildProductAvatar(product),
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
                                      if (product.category != null && product.category!.isNotEmpty) ...[
                                        const SizedBox(width: 8),
                                        Container(
                                          width: 4,
                                          height: 4,
                                          decoration: BoxDecoration(
                                            color: Colors.grey.shade400,
                                            shape: BoxShape.circle,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          product.category!,
                                          style: TextStyle(color: Colors.blue.shade600, fontSize: 12, fontWeight: FontWeight.w500),
                                        ),
                                      ],
                                      const SizedBox(width: 8),
                                      Container(
                                        width: 4,
                                        height: 4,
                                        decoration: BoxDecoration(
                                          color: Colors.grey.shade400,
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        '\$${product.sellingPrice.toStringAsFixed(2)}',
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
                            // Quick adjust buttons
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: Icon(Icons.remove_circle_outline, color: Colors.red.shade400, size: 24),
                                  onPressed: () => _quickAdjustStock(product, -1),
                                  tooltip: 'Decrease by 1',
                                  constraints: const BoxConstraints(),
                                  padding: const EdgeInsets.symmetric(horizontal: 4),
                                ),
                                IconButton(
                                  icon: Icon(Icons.add_circle_outline, color: Colors.green.shade400, size: 24),
                                  onPressed: () => _quickAdjustStock(product, 1),
                                  tooltip: 'Increase by 1',
                                  constraints: const BoxConstraints(),
                                  padding: const EdgeInsets.symmetric(horizontal: 4),
                                ),
                              ],
                            ),
                            const SizedBox(width: 8),
                            IconButton(
                              icon: const Icon(Icons.edit_outlined, color: Colors.blue, size: 20),
                              onPressed: () => _showAddEditProductDialog(product: product),
                              tooltip: 'Edit Product',
                              constraints: const BoxConstraints(),
                              padding: EdgeInsets.zero,
                            ),
                            const SizedBox(width: 8),
                            IconButton(
                              icon: const Icon(Icons.inventory_outlined, color: Colors.orange, size: 20),
                              onPressed: () => _showAdjustStockDialog(product),
                              tooltip: 'Detailed Adjust',
                              constraints: const BoxConstraints(),
                              padding: EdgeInsets.zero,
                            ),
                          ],
                        ),
                      ),
                    );
                  },
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
