import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:barcode_scan2/barcode_scan2.dart';
import '../../../core/services/service_locator.dart';
import '../../../domain/repositories/product_repository.dart';
import '../../../domain/repositories/inventory_repository.dart';
import '../../../data/databases/app_database.dart';
import '../../bloc/sale/sale_bloc.dart';
import '../../bloc/sale/sale_event.dart';
import '../../bloc/sale/sale_state.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import '../../widgets/sales/quick_checkout_panel.dart';
import '../../widgets/common/barcode_scanner_listener.dart';
import 'cart_page.dart';

class SalePage extends StatefulWidget {
  const SalePage({super.key});

  @override
  State<SalePage> createState() => _SalePageState();
}

class _SalePageState extends State<SalePage> {
  final _searchController = TextEditingController();
  List<Product> _allProducts = [];
  Map<String, double> _stockMap = {};
  bool _isLoading = false;
  
  String _selectedCategory = 'All';
  final List<String> _categories = ['All', 'Beverages', 'Snacks', 'Electronics', 'Groceries'];

  List<Product> get _filteredProducts {
    var list = _allProducts;
    if (_selectedCategory != 'All') {
      list = list.where((p) => 
        (p.category?.toLowerCase() == _selectedCategory.toLowerCase()) || 
        (p.category == null && p.name.toLowerCase().contains(_selectedCategory.toLowerCase()))
      ).toList();
    }
    if (_searchController.text.isNotEmpty) {
      final q = _searchController.text.toLowerCase();
      list = list.where((p) => p.name.toLowerCase().contains(q) || p.sku.toLowerCase().contains(q)).toList();
    }
    return list;
  }

  @override
  void initState() {
    super.initState();
    WakelockPlus.enable(); // Keep screen awake during sales
    _loadProducts();
  }

  @override
  void dispose() {
    WakelockPlus.disable();
    _searchController.dispose();
    super.dispose();
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
        _allProducts = products;
        _stockMap = stockMap;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load products: $e')),
      );
    }
  }

  void _onSearchChanged(String query) {
    setState(() {}); // triggers rebuild to use _filteredProducts
  }

  void _handleBarcode(String code) {
    final match = _allProducts.where((p) => p.barcode == code || p.sku == code).firstOrNull;
    if (match != null) {
      final stock = _stockMap[match.id] ?? 0.0;
      final saleState = context.read<SaleBloc>().state;
      double cartQty = 0.0;
      if (saleState is SaleInProgress) {
        cartQty = saleState.cartItems
            .where((item) => item.productId == match.id)
            .map((item) => item.quantity)
            .fold(0.0, (a, b) => a + b);
      }
      if (cartQty + 1.0 > stock) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Cannot add ${match.name}. Insufficient stock (Only ${stock.toStringAsFixed(0)} available)'),
            backgroundColor: Colors.redAccent,
          ),
        );
        return;
      }
      context.read<SaleBloc>().add(AddItemToCart(match, 1.0));
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Added ${match.name} to cart')));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Product not found!'), backgroundColor: Colors.redAccent));
    }
  }

  Future<void> _scanBarcode() async {
    try {
      final result = await BarcodeScanner.scan();
      if (result.type == ResultType.Barcode && result.rawContent.isNotEmpty) {
        _handleBarcode(result.rawContent);
      }
    } catch (e) {
      // User canceled or error
    }
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width > 800;

    return BlocListener<SaleBloc, SaleState>(
      listener: (context, state) {
        if (state is SaleComplete) {
          context.go('/sale/receipt', extra: {
            'saleId': state.saleId,
            'change': state.change,
          });
        } else if (state is SaleError) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.message),
              backgroundColor: Colors.redAccent,
            ),
          );
        }
      },
      child: BarcodeScannerListener(
        onBarcodeScanned: _handleBarcode,
        child: Scaffold(
      appBar: AppBar(
        title: const Text('POS Checkout'),
        actions: [
          BlocBuilder<SaleBloc, SaleState>(
            builder: (context, state) {
              int parkedCount = 0;
              if (state is SaleInitial) parkedCount = state.parkedSales.length;
              if (state is SaleInProgress) parkedCount = state.parkedSales.length;
              
              if (parkedCount == 0) return const SizedBox.shrink();
              
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                child: ActionChip(
                  avatar: const Icon(Icons.restore, size: 16),
                  label: Text('$parkedCount Parked'),
                  backgroundColor: Colors.orange.shade100,
                  onPressed: () {
                    showDialog(context: context, builder: (_) => AlertDialog(
                      title: const Text('Parked Sales'),
                      content: SizedBox(
                        width: 300,
                        child: ListView.builder(
                          shrinkWrap: true,
                          itemCount: parkedCount,
                          itemBuilder: (context, i) {
                            return ListTile(
                              leading: const Icon(Icons.shopping_cart),
                              title: Text('Parked Order #${i + 1}'),
                              trailing: const Icon(Icons.restore, color: Colors.blue),
                              onTap: () {
                                Navigator.pop(context);
                                context.read<SaleBloc>().add(RestoreParkedSale(i));
                              }
                            );
                          }
                        )
                      )
                    ));
                  },
                ),
              );
            }
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadProducts,
          ),
        ],
      ),
      body: Row(
        children: [
          // Left: Product Catalog Grid
          Expanded(
            flex: isWide ? 7 : 10,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                  child: Row(
                    children: [
                      Expanded(
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
                                      _onSearchChanged('');
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
                          onChanged: _onSearchChanged,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.blue.shade100),
                        ),
                        child: IconButton(
                          icon: const Icon(Icons.qr_code_scanner, color: Colors.blue),
                          onPressed: _scanBarcode,
                          tooltip: 'Scan Barcode',
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: _categories.map((cat) {
                        final isSelected = _selectedCategory == cat;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8.0),
                          child: ChoiceChip(
                            label: Text(cat),
                            selected: isSelected,
                            onSelected: (val) {
                              if (val) setState(() => _selectedCategory = cat);
                            },
                            selectedColor: Colors.blue.shade100,
                            labelStyle: TextStyle(
                              color: isSelected ? Colors.blue.shade900 : Colors.black87,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: _isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : _filteredProducts.isEmpty
                          ? const Center(child: Text('No products found'))
                          : GridView.builder(
                              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
                              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: isWide ? 4 : 2,
                                childAspectRatio: isWide ? 0.76 : 0.82,
                                crossAxisSpacing: 12,
                                mainAxisSpacing: 12,
                              ),
                              itemCount: _filteredProducts.length,
                              itemBuilder: (context, index) {
                                final product = _filteredProducts[index];
                                final stock = _stockMap[product.id] ?? 0.0;
                                final isOutOfStock = stock <= 0;
                                final isLowStock = stock > 0 && stock <= 5;

                                return Card(
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    side: BorderSide(
                                      color: isOutOfStock
                                          ? Colors.red.withOpacity(0.2)
                                          : isLowStock
                                              ? Colors.orange.withOpacity(0.2)
                                              : Colors.grey.shade200,
                                      width: 1,
                                    ),
                                  ),
                                  clipBehavior: Clip.antiAlias,
                                  margin: EdgeInsets.zero,
                                  child: InkWell(
                                    onLongPress: () {
                                      if (isOutOfStock) return;
                                      showDialog(
                                        context: context,
                                        builder: (context) {
                                          final qtyCtrl = TextEditingController(text: '1');
                                          return AlertDialog(
                                            title: Text('Add ${product.name} in Bulk'),
                                            content: TextField(
                                              controller: qtyCtrl,
                                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                              decoration: const InputDecoration(labelText: 'Quantity'),
                                              autofocus: true,
                                            ),
                                            actions: [
                                              TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
                                              ElevatedButton(
                                                onPressed: () {
                                                  final q = double.tryParse(qtyCtrl.text) ?? 1.0;
                                                  if (q > 0) {
                                                    final stock = _stockMap[product.id] ?? 0.0;
                                                    final saleState = context.read<SaleBloc>().state;
                                                    double cartQty = 0.0;
                                                    if (saleState is SaleInProgress) {
                                                      cartQty = saleState.cartItems
                                                          .where((item) => item.productId == product.id)
                                                          .map((item) => item.quantity)
                                                          .fold(0.0, (a, b) => a + b);
                                                    }
                                                    if (cartQty + q > stock) {
                                                      ScaffoldMessenger.of(context).showSnackBar(
                                                        SnackBar(
                                                          content: Text('Cannot add $q. Insufficient stock (Only ${(stock - cartQty).toStringAsFixed(0)} more can be added)'),
                                                          backgroundColor: Colors.redAccent,
                                                        ),
                                                      );
                                                      Navigator.pop(context);
                                                      return;
                                                    }
                                                    context.read<SaleBloc>().add(AddItemToCart(product, q));
                                                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Added $q of ${product.name} to order')));
                                                  }
                                                  Navigator.pop(context);
                                                },
                                                child: const Text('Add'),
                                              )
                                            ]
                                          );
                                        }
                                      );
                                    },
                                    onTap: () {
                                      if (isOutOfStock) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(
                                            content: Text('This product is out of stock!'),
                                            backgroundColor: Colors.redAccent,
                                          ),
                                        );
                                        return;
                                      }
                                      final stock = _stockMap[product.id] ?? 0.0;
                                      final saleState = context.read<SaleBloc>().state;
                                      double cartQty = 0.0;
                                      if (saleState is SaleInProgress) {
                                        cartQty = saleState.cartItems
                                            .where((item) => item.productId == product.id)
                                            .map((item) => item.quantity)
                                            .fold(0.0, (a, b) => a + b);
                                      }
                                      if (cartQty + 1.0 > stock) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
                                            content: Text('Cannot add more. Insufficient stock (Only ${stock.toStringAsFixed(0)} available)'),
                                            backgroundColor: Colors.redAccent,
                                          ),
                                        );
                                        return;
                                      }
                                      context.read<SaleBloc>().add(
                                            AddItemToCart(product, 1.0),
                                          );
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text('Added ${product.name} to order'),
                                          duration: const Duration(milliseconds: 500),
                                        ),
                                      );
                                    },
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Expanded(
                                          child: Stack(
                                            children: [
                                              Container(
                                                color: isOutOfStock
                                                    ? Colors.red.shade50.withOpacity(0.4)
                                                    : isLowStock
                                                        ? Colors.orange.shade50.withOpacity(0.4)
                                                        : Colors.blue.shade50.withOpacity(0.5),
                                                width: double.infinity,
                                                child: product.imageUrl != null && product.imageUrl!.isNotEmpty
                                                    ? Image.network(product.imageUrl!, fit: BoxFit.cover, errorBuilder: (c, e, s) => const Icon(Icons.image_not_supported, color: Colors.grey))
                                                    : Center(
                                                        child: CircleAvatar(
                                                          radius: 30,
                                                          backgroundColor: Colors.primaries[product.id.hashCode % Colors.primaries.length].withOpacity(0.2),
                                                          child: Text(
                                                            product.name.substring(0, 1).toUpperCase(),
                                                            style: TextStyle(
                                                              color: Colors.primaries[product.id.hashCode % Colors.primaries.length],
                                                              fontWeight: FontWeight.bold,
                                                              fontSize: 28,
                                                            ),
                                                          ),
                                                        ),
                                                      ),
                                              ),
                                              Positioned(
                                                top: 8,
                                                right: 8,
                                                child: Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                                                  decoration: BoxDecoration(
                                                    color: isOutOfStock
                                                        ? Colors.red.shade100
                                                        : isLowStock
                                                            ? Colors.orange.shade100
                                                            : Colors.green.shade100,
                                                    borderRadius: BorderRadius.circular(6),
                                                  ),
                                                  child: Text(
                                                    isOutOfStock
                                                        ? 'OUT'
                                                        : isLowStock
                                                            ? 'LOW (${stock.toStringAsFixed(0)})'
                                                            : '${stock.toStringAsFixed(0)} left',
                                                    style: TextStyle(
                                                      color: isOutOfStock
                                                          ? Colors.red.shade900
                                                          : isLowStock
                                                              ? Colors.orange.shade900
                                                              : Colors.green.shade900,
                                                      fontWeight: FontWeight.bold,
                                                      fontSize: 10,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        Padding(
                                          padding: const EdgeInsets.all(10.0),
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                product.name,
                                                style: TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 13,
                                                  color: isOutOfStock ? Colors.grey : Colors.black87,
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                '\$${product.sellingPrice.toStringAsFixed(2)}',
                                                style: TextStyle(
                                                  color: isOutOfStock
                                                      ? Colors.grey
                                                      : Colors.blue.shade700,
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 14,
                                                ),
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                'SKU: ${product.sku}',
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  color: Colors.grey.shade500,
                                                ),
                                              ),
                                            ],
                                          ),
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
          ),
          
          // Right: Active Cart Sidebar (Only for wide screens)
          if (isWide)
            Container(
              width: 320,
              decoration: BoxDecoration(
                border: Border(left: BorderSide(color: Colors.grey.shade200)),
              ),
              child: const _CartSidebar(),
            ),
        ],
      ),
      floatingActionButton: !isWide
          ? FloatingActionButton.extended(
              onPressed: () {
                context.go('/sale/cart');
              },
              icon: const Icon(Icons.shopping_cart),
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
              label: BlocBuilder<SaleBloc, SaleState>(
                builder: (context, state) {
                  int count = 0;
                  if (state is SaleInProgress) {
                    count = state.cartItems.length;
                  }
                  return Text('View Cart ($count)');
                },
              ),
            )
          : null,
    ),
      ),
    );
  }
}

class _CartSidebar extends StatelessWidget {
  const _CartSidebar();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SaleBloc, SaleState>(
      builder: (context, state) {
        if (state is! SaleInProgress) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.shopping_cart_outlined, size: 64, color: Colors.grey),
                SizedBox(height: 16),
                Text('Cart is empty', style: TextStyle(color: Colors.grey)),
              ],
            ),
          );
        }

        return Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 20.0),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Current Order',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.pause_circle_outline, color: Colors.orange),
                        tooltip: 'Park Order',
                        onPressed: () {
                          context.read<SaleBloc>().add(ParkSale());
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Sale parked!')));
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_sweep, color: Colors.redAccent),
                        tooltip: 'Clear Cart',
                        onPressed: () {
                          context.read<SaleBloc>().add(ClearCart());
                        },
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.blue.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${state.cartItems.length} items',
                          style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold, fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.separated(
                itemCount: state.cartItems.length,
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                separatorBuilder: (context, index) => Divider(color: Colors.grey.shade100, height: 1),
                itemBuilder: (context, index) {
                  final item = state.cartItems[index];
                  final itemTotal = item.quantity * item.unitPrice;
                  final displayName = item.productName.isNotEmpty ? item.productName : 'Product Item';
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                displayName,
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '\$${item.unitPrice.toStringAsFixed(2)} × ${item.quantity.toStringAsFixed(0)}',
                                style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.remove_circle_outline, size: 18),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              onPressed: () {
                                context.read<SaleBloc>().add(
                                      UpdateItemQuantity(
                                          item.productId, item.quantity - 1),
                                    );
                              },
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 6.0),
                              child: Text(
                                item.quantity.toStringAsFixed(0),
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.add_circle_outline, size: 18),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              onPressed: () {
                                context.read<SaleBloc>().add(
                                      UpdateItemQuantity(
                                          item.productId, item.quantity + 1),
                                    );
                              },
                            ),
                            const SizedBox(width: 8),
                            IconButton(
                              icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 18),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              onPressed: () {
                                context.read<SaleBloc>().add(
                                      RemoveItemFromCart(item.productId),
                                    );
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            Container(
              padding: const EdgeInsets.all(20.0),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 10,
                    offset: const Offset(0, -4),
                  ),
                ],
                border: Border(top: BorderSide(color: Colors.grey.shade200)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Subtotal', style: TextStyle(color: Colors.grey, fontSize: 13)),
                      Text('\$${state.subtotal.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.w600)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('VAT (15%)', style: TextStyle(color: Colors.grey, fontSize: 13)),
                      Text('\$${state.tax.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.w600)),
                    ],
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8.0),
                    child: Divider(),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Total',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      Text('\$${state.total.toStringAsFixed(2)}',
                          style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 20,
                              color: Colors.blue)),
                    ],
                  ),
                  const SizedBox(height: 10),
                  // ⚡ Seamless Quick Checkout Panel
                  QuickCheckoutPanel(state: state),
                  const SizedBox(height: 12),
                  OutlinedButton(
                    onPressed: () {
                      context.go('/sale/cart');
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.blue,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      side: const BorderSide(color: Colors.blue, width: 0.8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text('FULL CHECKOUT WIZARD', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 0.5, fontSize: 12)),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}
