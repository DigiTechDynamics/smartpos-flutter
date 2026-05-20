import '../../domain/repositories/inventory_repository.dart';
import '../databases/app_database.dart';
import 'package:drift/drift.dart';

class InventoryRepositoryImpl implements InventoryRepository {
  final AppDatabase db;
  InventoryRepositoryImpl(this.db);

  @override
  Future<InventoryItem?> getStock(String productId) async {
    final query = db.select(db.inventory)..where((tbl) => tbl.productId.equals(productId));
    return await query.getSingleOrNull();
  }

  @override
  Future<void> adjustStock(String productId, double quantityChange, String reason, String userId) async {
    await db.transaction(() async {
      // Create audit/adjustment record
      await db.into(db.stockAdjustments).insert(
        StockAdjustment(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          productId: productId,
          quantityChange: quantityChange,
          reason: reason,
          userId: userId,
          createdAt: DateTime.now().millisecondsSinceEpoch,
          updatedAt: DateTime.now().millisecondsSinceEpoch,
          syncStatus: 'pending',
        ),
      );
      
      // Update inventory table
      final currentStock = await getStock(productId);
      if (currentStock != null) {
        await db.update(db.inventory).replace(
          currentStock.copyWith(quantityOnHand: currentStock.quantityOnHand + quantityChange)
        );
      } else {
        await db.into(db.inventory).insert(
          InventoryItem(
            productId: productId,
            quantityOnHand: quantityChange,
            createdAt: DateTime.now().millisecondsSinceEpoch,
            updatedAt: DateTime.now().millisecondsSinceEpoch,
            syncStatus: 'pending',
            reorderLevel: 0.0,
          )
        );
      }
    });
  }

  @override
  Future<List<InventoryItem>> getLowStockItems() async {
    final query = db.select(db.inventory)
      ..where((tbl) => tbl.quantityOnHand.isSmallerOrEqual(tbl.reorderLevel));
    return await query.get();
  }

  @override
  Future<bool> sync() async {
    return true;
  }
}
