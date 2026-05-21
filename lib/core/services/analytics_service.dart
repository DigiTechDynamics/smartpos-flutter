import 'package:logger/logger.dart';
import '../../data/databases/app_database.dart';
import 'package:drift/drift.dart';

class ProductSales {
  final Product product;
  final double quantitySold;
  final double revenue;
  final double profitMargin;
  final int salesCount;
  final double averagePrice;

  ProductSales({
    required this.product,
    required this.quantitySold,
    required this.revenue,
    required this.profitMargin,
    required this.salesCount,
    required this.averagePrice,
  });
}

class InventoryAnalysis {
  final int totalItems;
  final double totalValue;
  final int lowStockCount;

  InventoryAnalysis({
    required this.totalItems,
    required this.totalValue,
    required this.lowStockCount,
  });
}

class AnalyticsService {
  final AppDatabase db;
  final Logger _logger = Logger();

  AnalyticsService(this.db);

  Future<double> getTotalSales(DateTime start, DateTime end) async {
    final query = db.select(db.sales)
      ..where((tbl) => tbl.createdAt.isBetweenValues(
        start.millisecondsSinceEpoch, 
        end.millisecondsSinceEpoch
      ) & tbl.paymentMethod.equals('void').not());
    final sales = await query.get();
    return sales.fold<double>(0.0, (sum, sale) => sum + sale.total);
  }

  Future<Map<String, Map<String, dynamic>>> getSalesByPaymentMethod(DateTime start, DateTime end) async {
    final query = db.select(db.sales)
      ..where((tbl) => tbl.createdAt.isBetweenValues(
        start.millisecondsSinceEpoch, 
        end.millisecondsSinceEpoch
      ) & tbl.paymentMethod.equals('void').not());
    final sales = await query.get();
    
    final breakdown = <String, Map<String, dynamic>>{};
    for (final sale in sales) {
      final method = sale.paymentMethod;
      final existing = breakdown.putIfAbsent(method, () => {'amount': 0.0, 'count': 0});
      existing['amount'] = (existing['amount'] as double) + sale.total;
      existing['count'] = (existing['count'] as int) + 1;
    }
    return breakdown;
  }

  Future<List<ProductSales>> getTopProducts(DateTime start, DateTime end, {int limit = 10}) async {
    // Select all sales within range
    final salesQuery = db.select(db.sales)
      ..where((tbl) => tbl.createdAt.isBetweenValues(
        start.millisecondsSinceEpoch, 
        end.millisecondsSinceEpoch
      ) & tbl.paymentMethod.equals('void').not());
    final sales = await salesQuery.get();
    if (sales.isEmpty) return [];

    final saleIds = sales.map((s) => s.id).toList();

    // Select all sale items for these sales
    final itemsQuery = db.select(db.saleItems)
      ..where((tbl) => tbl.saleId.isIn(saleIds));
    final items = await itemsQuery.get();

    // Map productId -> list of sale items
    final itemGroups = <String, List<SaleItem>>{};
    for (final item in items) {
      itemGroups.putIfAbsent(item.productId, () => []).add(item);
    }

    // Load products details
    final productIds = itemGroups.keys.toList();
    if (productIds.isEmpty) return [];

    final productsQuery = db.select(db.products)
      ..where((tbl) => tbl.id.isIn(productIds));
    final products = await productsQuery.get();
    final productMap = {for (final p in products) p.id: p};

    final productSalesList = <ProductSales>[];
    itemGroups.forEach((productId, itemInstances) {
      final product = productMap[productId];
      if (product != null) {
        final totalQty = itemInstances.fold<double>(0.0, (sum, i) => sum + i.quantity);
        final totalRevenue = itemInstances.fold<double>(0.0, (sum, i) => sum + (i.quantity * i.unitPrice));
        final cost = totalQty * product.costPrice;
        final profitMargin = totalRevenue > 0 ? (totalRevenue - cost) / totalRevenue : 0.0;

        productSalesList.add(ProductSales(
          product: product,
          quantitySold: totalQty,
          revenue: totalRevenue,
          profitMargin: profitMargin,
          salesCount: itemInstances.length,
          averagePrice: itemInstances.fold<double>(0.0, (sum, i) => sum + i.unitPrice) / itemInstances.length,
        ));
      }
    });

    // Sort by revenue descending
    productSalesList.sort((a, b) => b.revenue.compareTo(a.revenue));
    return productSalesList.take(limit).toList();
  }

  Future<InventoryAnalysis> getInventoryMetrics() async {
    final items = await db.select(db.inventory).get();
    final products = await db.select(db.products).get();
    final productMap = {for (final p in products) p.id: p};

    int totalItems = items.length;
    int lowStockCount = items.where((i) => i.quantityOnHand <= i.reorderLevel).length;

    double totalValue = 0.0;
    for (final item in items) {
      final prod = productMap[item.productId];
      if (prod != null) {
        totalValue += item.quantityOnHand * prod.costPrice;
      }
    }

    return InventoryAnalysis(
      totalItems: totalItems,
      totalValue: totalValue,
      lowStockCount: lowStockCount,
    );
  }

  Future<List<Product>> getLowStockItems() async {
    final query = db.select(db.inventory)
      ..where((tbl) => tbl.quantityOnHand.isSmallerOrEqual(tbl.reorderLevel));
    final lowStock = await query.get();
    
    if (lowStock.isEmpty) return [];
    
    final productIds = lowStock.map((i) => i.productId).toList();
    final productsQuery = db.select(db.products)
      ..where((tbl) => tbl.id.isIn(productIds));
      
    return await productsQuery.get();
  }

  Future<Map<DateTime, double>> getSalesByDay(DateTime start, DateTime end) async {
    final query = db.select(db.sales)
      ..where((tbl) => tbl.createdAt.isBetweenValues(
        start.millisecondsSinceEpoch, 
        end.millisecondsSinceEpoch
      ) & tbl.paymentMethod.equals('void').not());
    final sales = await query.get();

    final salesByDay = <DateTime, double>{};
    
    // Initialize days in the range to 0.0
    var current = DateTime(start.year, start.month, start.day);
    final last = DateTime(end.year, end.month, end.day);
    while (current.isBefore(last) || current.isAtSameMomentAs(last)) {
      salesByDay[current] = 0.0;
      current = current.add(const Duration(days: 1));
    }

    for (final sale in sales) {
      final saleDate = DateTime.fromMillisecondsSinceEpoch(sale.createdAt);
      final dayKey = DateTime(saleDate.year, saleDate.month, saleDate.day);
      if (salesByDay.containsKey(dayKey)) {
        salesByDay[dayKey] = salesByDay[dayKey]! + sale.total;
      } else {
        salesByDay[dayKey] = sale.total;
      }
    }
    return salesByDay;
  }

  Future<Map<String, dynamic>> getDailySummary(DateTime date) async {
    final startOfDay = DateTime(date.year, date.month, date.day);
    final endOfDay = DateTime(date.year, date.month, date.day, 23, 59, 59);
    
    final query = db.select(db.sales)
      ..where((tbl) => tbl.createdAt.isBetweenValues(
        startOfDay.millisecondsSinceEpoch, 
        endOfDay.millisecondsSinceEpoch
      ) & tbl.paymentMethod.equals('void').not());
    final sales = await query.get();
    
    final totalSales = sales.fold<double>(0.0, (sum, sale) => sum + sale.total);
    final count = sales.length;

    // Get payment breakdown
    final paymentBreakdown = <String, Map<String, dynamic>>{};
    for (final sale in sales) {
      final method = sale.paymentMethod;
      final existing = paymentBreakdown.putIfAbsent(method, () => {'amount': 0.0, 'count': 0});
      existing['amount'] = (existing['amount'] as double) + sale.total;
      existing['count'] = (existing['count'] as int) + 1;
    }

    // Get top products for the day
    final topProds = await getTopProducts(startOfDay, endOfDay, limit: 5);
    final topProductsList = topProds.map((ps) => {
      'name': ps.product.name,
      'sold': '${ps.quantitySold.toInt()} units',
      'sales': '\$${ps.revenue.toStringAsFixed(2)}',
    }).toList();
    
    return {
      'total_sales': totalSales,
      'transaction_count': count,
      'payment_breakdown': paymentBreakdown,
      'top_products': topProductsList,
    };
  }
}
