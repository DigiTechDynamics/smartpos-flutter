import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:drift/drift.dart';
import 'package:logger/logger.dart';
import '../../domain/repositories/sync_repository.dart';
import '../databases/app_database.dart';

class SyncRepositoryImpl implements SyncRepository {
  final AppDatabase db;
  final Logger _logger = Logger();

  SyncRepositoryImpl(this.db);

  @override
  Future<void> queueSyncAction(String tableName, String recordId, String action) async {
    await db.into(db.syncQueue).insert(
      SyncQueueCompanion.insert(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        targetTable: tableName,
        recordId: recordId,
        action: action,
      )
    );
  }

  @override
  Future<void> processSyncQueue() async {
    final pending = await (db.select(db.syncQueue)
          ..where((tbl) => tbl.status.equals('pending')))
        .get();

    if (pending.isEmpty) return;

    try {
      final firestore = FirebaseFirestore.instance;
      final batch = firestore.batch();

      for (var item in pending) {
        final Map<String, dynamic> recordData = await _getLocalRecordData(item.targetTable, item.recordId);
        
        final docRef = firestore.collection(item.targetTable).doc(item.recordId);
        if (item.action == 'delete') {
          batch.delete(docRef);
        } else {
          batch.set(docRef, recordData, SetOptions(merge: true));
        }
      }

      await batch.commit();

      for (var item in pending) {
        await db.update(db.syncQueue).replace(
          item.copyWith(status: 'synced'),
        );
      }
    } catch (e) {
      _logger.e('Failed to process sync queue to Firestore: $e');
    }
  }

  Future<Map<String, dynamic>> _getLocalRecordData(String tableName, String recordId) async {
    final Map<String, dynamic> data = {};
    try {
      if (tableName == 'users') {
        final rec = await (db.select(db.users)..where((t) => t.id.equals(recordId))).getSingleOrNull();
        if (rec != null) {
          data.addAll({
            'id': rec.id,
            'email': rec.email,
            'role': rec.role,
            'isActive': rec.isActive,
            'createdAt': rec.createdAt,
            'updatedAt': rec.updatedAt,
          });
        }
      } else if (tableName == 'products') {
        final rec = await (db.select(db.products)..where((t) => t.id.equals(recordId))).getSingleOrNull();
        if (rec != null) {
          data.addAll({
            'id': rec.id,
            'sku': rec.sku,
            'name': rec.name,
            'sellingPrice': rec.sellingPrice,
            'costPrice': rec.costPrice,
            'taxRate': rec.taxRate,
            'barcode': rec.barcode,
            'createdAt': rec.createdAt,
            'updatedAt': rec.updatedAt,
          });
        }
      } else if (tableName == 'inventory') {
        final rec = await (db.select(db.inventory)..where((t) => t.productId.equals(recordId))).getSingleOrNull();
        if (rec != null) {
          data.addAll({
            'productId': rec.productId,
            'quantityOnHand': rec.quantityOnHand,
            'reorderLevel': rec.reorderLevel,
            'createdAt': rec.createdAt,
            'updatedAt': rec.updatedAt,
          });
        }
      } else if (tableName == 'sales') {
        final rec = await (db.select(db.sales)..where((t) => t.id.equals(recordId))).getSingleOrNull();
        if (rec != null) {
          final items = await (db.select(db.saleItems)..where((t) => t.saleId.equals(recordId))).get();
          data.addAll({
            'id': rec.id,
            'saleNumber': rec.saleNumber,
            'userId': rec.userId,
            'subtotal': rec.subtotal,
            'tax': rec.tax,
            'discount': rec.discount,
            'total': rec.total,
            'paymentMethod': rec.paymentMethod,
            'createdAt': rec.createdAt,
            'updatedAt': rec.updatedAt,
            'items': items.map((i) => {
              'productId': i.productId,
              'quantity': i.quantity,
              'unitPrice': i.unitPrice,
              'taxAmount': i.taxAmount,
            }).toList(),
          });
        }
      } else if (tableName == 'payments') {
        final rec = await (db.select(db.payments)..where((t) => t.id.equals(recordId))).getSingleOrNull();
        if (rec != null) {
          data.addAll({
            'id': rec.id,
            'saleId': rec.saleId,
            'method': rec.method,
            'amount': rec.amount,
            'referenceNumber': rec.referenceNumber,
            'createdAt': rec.createdAt,
            'updatedAt': rec.updatedAt,
          });
        }
      } else if (tableName == 'stock_adjustments') {
        final rec = await (db.select(db.stockAdjustments)..where((t) => t.id.equals(recordId))).getSingleOrNull();
        if (rec != null) {
          data.addAll({
            'id': rec.id,
            'productId': rec.productId,
            'quantityChange': rec.quantityChange,
            'reason': rec.reason,
            'userId': rec.userId,
            'createdAt': rec.createdAt,
            'updatedAt': rec.updatedAt,
          });
        }
      } else if (tableName == 'audit_log') {
        final rec = await (db.select(db.auditLog)..where((t) => t.id.equals(recordId))).getSingleOrNull();
        if (rec != null) {
          data.addAll({
            'id': rec.id,
            'userId': rec.userId,
            'action': rec.action,
            'details': rec.details,
            'createdAt': rec.createdAt,
            'updatedAt': rec.updatedAt,
          });
        }
      }
    } catch (e) {
      _logger.e('Failed to load local DB record details for $tableName:$recordId: $e');
    }
    return data;
  }

  @override
  Future<bool> resolveConflict(String tableName, String recordId, Map<String, dynamic> remoteData) async {
    return true;
  }
}
