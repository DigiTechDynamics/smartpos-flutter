import '../../domain/repositories/sale_repository.dart';
import '../databases/app_database.dart';
import 'package:drift/drift.dart';
import '../../core/services/service_locator.dart';
import '../../domain/repositories/user_repository.dart';

class SaleRepositoryImpl implements SaleRepository {
  final AppDatabase db;
  SaleRepositoryImpl(this.db);

  @override
  Future<Sale> create(Sale sale, List<SaleItem> items, List<Payment> payments) async {
    await db.transaction(() async {
      await db.into(db.sales).insert(sale);
      for (var item in items) {
        await db.into(db.saleItems).insert(item);
        
        // Retrieve current stock level
        final currentStock = await (db.select(db.inventory)
          ..where((tbl) => tbl.productId.equals(item.productId))).getSingleOrNull();
          
        final currentQty = currentStock?.quantityOnHand ?? 0.0;
        
        // Validate that we have sufficient stock for checkout
        if (currentQty < item.quantity) {
          throw Exception('Insufficient stock for product ${item.productId}');
        }
        
        // Deduct stock
        if (currentStock != null) {
          await db.update(db.inventory).replace(
            currentStock.copyWith(
              quantityOnHand: currentQty - item.quantity,
              updatedAt: DateTime.now().millisecondsSinceEpoch,
            ),
          );
        } else {
          // If no inventory record exists, insert one (should theoretically not happen since out of stock check fails above, but acts as a fallback)
          await db.into(db.inventory).insert(
            InventoryItem(
              productId: item.productId,
              quantityOnHand: -item.quantity,
              createdAt: DateTime.now().millisecondsSinceEpoch,
              updatedAt: DateTime.now().millisecondsSinceEpoch,
              syncStatus: 'pending',
              reorderLevel: 0.0,
            ),
          );
        }
        
        // Record stock adjustment / audit log entry
        await db.into(db.stockAdjustments).insert(
          StockAdjustment(
            id: '${sale.id}_${item.productId}_adj',
            productId: item.productId,
            quantityChange: -item.quantity,
            reason: 'sale',
            userId: sale.userId,
            createdAt: DateTime.now().millisecondsSinceEpoch,
            updatedAt: DateTime.now().millisecondsSinceEpoch,
            syncStatus: 'pending',
          ),
        );
      }
      
      for (var payment in payments) {
        await db.into(db.payments).insert(payment);
      }
      
      // Queue sync
      await db.into(db.syncQueue).insert(
        SyncQueueCompanion.insert(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          targetTable: 'sales',
          recordId: sale.id,
          action: 'insert',
        ),
      );
    });
    return sale;
  }

  @override
  Future<List<Sale>> getAll({int limit = 20, int offset = 0}) async {
    final query = db.select(db.sales)..limit(limit, offset: offset);
    return await query.get();
  }

  @override
  Future<Sale?> getById(String id) async {
    final query = db.select(db.sales)..where((tbl) => tbl.id.equals(id));
    return await query.getSingleOrNull();
  }

  @override
  Future<void> voidSale(String saleId, String reason) async {
    final sale = await getById(saleId);
    if (sale == null) {
      throw Exception('Sale not found');
    }
    if (sale.paymentMethod == 'void') {
      throw Exception('Sale is already voided');
    }

    final userRepo = sl<UserRepository>();
    final currentUser = await userRepo.getCurrentUser();
    final activeUserId = currentUser?.id ?? 'unknown_user';

    // Retrieve all sale items
    final itemsQuery = db.select(db.saleItems)..where((tbl) => tbl.saleId.equals(saleId));
    final items = await itemsQuery.get();

    await db.transaction(() async {
      // 1. Update sale paymentMethod to 'void'
      await db.update(db.sales).replace(
        sale.copyWith(
          paymentMethod: 'void',
          updatedAt: DateTime.now().millisecondsSinceEpoch,
          syncStatus: 'pending',
        ),
      );

      // 2. Restore stock and record stock adjustments
      for (var item in items) {
        final currentStock = await (db.select(db.inventory)
          ..where((tbl) => tbl.productId.equals(item.productId))).getSingleOrNull();
        
        final currentQty = currentStock?.quantityOnHand ?? 0.0;
        
        if (currentStock != null) {
          await db.update(db.inventory).replace(
            currentStock.copyWith(
              quantityOnHand: currentQty + item.quantity,
              updatedAt: DateTime.now().millisecondsSinceEpoch,
              syncStatus: 'pending',
            ),
          );
        } else {
          await db.into(db.inventory).insert(
            InventoryItem(
              productId: item.productId,
              quantityOnHand: item.quantity,
              createdAt: DateTime.now().millisecondsSinceEpoch,
              updatedAt: DateTime.now().millisecondsSinceEpoch,
              syncStatus: 'pending',
              reorderLevel: 0.0,
            ),
          );
        }

        // Insert StockAdjustment
        await db.into(db.stockAdjustments).insert(
          StockAdjustment(
            id: 'void_${saleId}_${item.productId}_adj',
            productId: item.productId,
            quantityChange: item.quantity,
            reason: 'voided sale: $reason',
            userId: activeUserId,
            createdAt: DateTime.now().millisecondsSinceEpoch,
            updatedAt: DateTime.now().millisecondsSinceEpoch,
            syncStatus: 'pending',
          ),
        );
      }

      // 3. Log Audit entry
      final auditId = 'void_${saleId}_audit';
      await db.into(db.auditLog).insert(
        AuditLogEntry(
          id: auditId,
          userId: activeUserId,
          action: 'void_sale',
          details: 'Sale $saleId (Total: \$${sale.total.toStringAsFixed(2)}) voided. Reason: $reason',
          createdAt: DateTime.now().millisecondsSinceEpoch,
          updatedAt: DateTime.now().millisecondsSinceEpoch,
          syncStatus: 'pending',
        ),
      );

      // 4. Queue sync
      await db.into(db.syncQueue).insert(
        SyncQueueCompanion.insert(
          id: 'void_' + saleId + '_' + DateTime.now().millisecondsSinceEpoch.toString(),
          targetTable: 'sales',
          recordId: saleId,
          action: 'update',
        ),
      );
    });
  }

  @override
  Future<List<Sale>> getSalesByDateRange(DateTime from, DateTime to) async {
    final query = db.select(db.sales)
      ..where((tbl) => tbl.createdAt.isBetweenValues(
        from.millisecondsSinceEpoch, to.millisecondsSinceEpoch));
    return await query.get();
  }

  @override
  Future<bool> sync() async {
    return true;
  }
}
