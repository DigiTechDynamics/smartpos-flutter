import '../../domain/repositories/sale_repository.dart';
import '../databases/app_database.dart';
import 'package:drift/drift.dart';

class SaleRepositoryImpl implements SaleRepository {
  final AppDatabase db;
  SaleRepositoryImpl(this.db);

  @override
  Future<Sale> create(Sale sale, List<SaleItem> items, Payment payment) async {
    await db.transaction(() async {
      await db.into(db.sales).insert(sale);
      for (var item in items) {
        await db.into(db.saleItems).insert(item);
      }
      await db.into(db.payments).insert(payment);
      
      // Queue sync
      await db.into(db.syncQueue).insert(
        SyncQueueCompanion.insert(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          targetTable: 'sales',
          recordId: sale.id,
          action: 'insert',
        )
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
    // Implement void logic
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
