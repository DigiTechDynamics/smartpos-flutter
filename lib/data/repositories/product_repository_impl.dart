import '../../domain/repositories/product_repository.dart';
import '../databases/app_database.dart';
import 'package:drift/drift.dart';

class ProductRepositoryImpl implements ProductRepository {
  final AppDatabase db;
  
  ProductRepositoryImpl(this.db);

  @override
  Future<List<Product>> getAll({int limit = 20, int offset = 0}) async {
    final query = db.select(db.products)
      ..limit(limit, offset: offset);
    return await query.get();
  }

  @override
  Future<List<Product>> search(String queryStr) async {
    final query = db.select(db.products)
      ..where((tbl) => tbl.name.like('%$queryStr%') | tbl.sku.like('%$queryStr%') | tbl.barcode.equals(queryStr));
    return await query.get();
  }

  @override
  Future<Product?> getById(String id) async {
    final query = db.select(db.products)..where((tbl) => tbl.id.equals(id));
    return await query.getSingleOrNull();
  }

  @override
  Future<void> add(Product product) async {
    await db.into(db.products).insert(product);
    await _queueSync(product.id, 'insert');
  }

  @override
  Future<void> updateProduct(Product product) async {
    await db.update(db.products).replace(product);
    await _queueSync(product.id, 'update');
  }

  @override
  Future<bool> sync() async {
    // Sync logic will be implemented in sync repository
    return true;
  }
  
  Future<void> _queueSync(String recordId, String action) async {
    await db.into(db.syncQueue).insert(
      SyncQueueCompanion.insert(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        targetTable: 'products',
        recordId: recordId,
        action: action,
      )
    );
  }
}
