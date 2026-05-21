import 'package:drift/drift.dart';
import 'connection/shared.dart' as impl;
part 'app_database.g.dart';

// Mixin for common sync fields
mixin SyncMixin on Table {
  IntColumn get createdAt => integer().clientDefault(() => DateTime.now().millisecondsSinceEpoch)();
  IntColumn get updatedAt => integer().clientDefault(() => DateTime.now().millisecondsSinceEpoch)();
  IntColumn get syncedAt => integer().nullable()();
  TextColumn get syncStatus => text().withDefault(const Constant('pending'))(); // pending, synced, error
}

@DataClassName('User')
class Users extends Table with SyncMixin {
  TextColumn get id => text()();
  TextColumn get email => text().unique()();
  TextColumn get role => text()();
  TextColumn get passwordHash => text()();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('Product')
class Products extends Table with SyncMixin {
  TextColumn get id => text()();
  TextColumn get sku => text().unique()();
  TextColumn get name => text()();
  TextColumn get category => text().nullable()();
  TextColumn get imageUrl => text().nullable()();
  RealColumn get sellingPrice => real()();
  RealColumn get costPrice => real()();
  RealColumn get taxRate => real().withDefault(const Constant(0.0))();
  TextColumn get barcode => text().nullable().unique()();
  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('InventoryItem')
class Inventory extends Table with SyncMixin {
  TextColumn get productId => text().references(Products, #id)();
  RealColumn get quantityOnHand => real().withDefault(const Constant(0.0))();
  RealColumn get reorderLevel => real().withDefault(const Constant(0.0))();
  @override
  Set<Column> get primaryKey => {productId};
}

@DataClassName('Sale')
class Sales extends Table with SyncMixin {
  TextColumn get id => text()();
  TextColumn get saleNumber => text().unique()();
  TextColumn get userId => text().references(Users, #id)();
  RealColumn get subtotal => real()();
  RealColumn get tax => real()();
  RealColumn get discount => real().withDefault(const Constant(0.0))();
  RealColumn get total => real()();
  TextColumn get paymentMethod => text()(); // cash, card, mobile
  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('SaleItem')
class SaleItems extends Table {
  TextColumn get saleId => text().references(Sales, #id)();
  TextColumn get productId => text().references(Products, #id)();
  RealColumn get quantity => real()();
  RealColumn get unitPrice => real()();
  RealColumn get taxAmount => real().withDefault(const Constant(0.0))();
  @override
  Set<Column> get primaryKey => {saleId, productId};
}

@DataClassName('Payment')
class Payments extends Table with SyncMixin {
  TextColumn get id => text()();
  TextColumn get saleId => text().references(Sales, #id)();
  TextColumn get method => text()();
  RealColumn get amount => real()();
  TextColumn get referenceNumber => text().nullable()();
  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('StockAdjustment')
class StockAdjustments extends Table with SyncMixin {
  TextColumn get id => text()();
  TextColumn get productId => text().references(Products, #id)();
  RealColumn get quantityChange => real()();
  TextColumn get reason => text()();
  TextColumn get userId => text().references(Users, #id)();
  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('Setting')
class Settings extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();
  @override
  Set<Column> get primaryKey => {key};
}

@DataClassName('SyncQueueItem')
class SyncQueue extends Table {
  TextColumn get id => text()();
  TextColumn get targetTable => text().named('table_name')();
  TextColumn get recordId => text()();
  TextColumn get action => text()(); // insert, update, delete
  TextColumn get status => text().withDefault(const Constant('pending'))();
  IntColumn get createdAt => integer().clientDefault(() => DateTime.now().millisecondsSinceEpoch)();
  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('AuditLogEntry')
class AuditLog extends Table with SyncMixin {
  TextColumn get id => text()();
  TextColumn get userId => text().references(Users, #id)();
  TextColumn get action => text()();
  TextColumn get details => text()();
  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('DevicePairing')
class DevicePairings extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get macAddress => text().unique()();
  TextColumn get type => text()(); // printer, scanner
  @override
  Set<Column> get primaryKey => {id};
}

@DriftDatabase(tables: [
  Users,
  Products,
  Inventory,
  Sales,
  SaleItems,
  Payments,
  StockAdjustments,
  Settings,
  SyncQueue,
  AuditLog,
  DevicePairings,
])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(impl.connect());

  @override
  int get schemaVersion => 1;
}
