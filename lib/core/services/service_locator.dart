import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:get_it/get_it.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:drift/drift.dart' show Value, InsertMode;
import '../../data/databases/app_database.dart';
import 'local_storage_service.dart';
import 'printer_service.dart';
import 'sync_service.dart';
import 'background_sync_service.dart';
import 'analytics_service.dart';
import '../../domain/repositories/product_repository.dart';
import '../../data/repositories/product_repository_impl.dart';
import '../../domain/repositories/sale_repository.dart';
import '../../data/repositories/sale_repository_impl.dart';
import '../../domain/repositories/inventory_repository.dart';
import '../../data/repositories/inventory_repository_impl.dart';
import '../../domain/repositories/user_repository.dart';
import '../../data/repositories/user_repository_impl.dart';
import '../../domain/repositories/sync_repository.dart';
import '../../data/repositories/sync_repository_impl.dart';
import '../../domain/repositories/settings_repository.dart';
import '../../data/repositories/settings_repository_impl.dart';
import '../../domain/usecases/sales/create_sale_usecase.dart';
import '../../domain/usecases/sales/void_sale_usecase.dart';
import '../../domain/usecases/inventory/adjust_stock_usecase.dart';
import '../../presentation/bloc/auth/auth_bloc.dart';
import '../../presentation/bloc/sale/sale_bloc.dart';
import '../../presentation/bloc/reports/reports_bloc.dart';

final sl = GetIt.instance;

Future<void> initServiceLocator() async {
  // Wait for shared preferences
  final sharedPreferences = await SharedPreferences.getInstance();
  sl.registerLazySingleton(() => sharedPreferences);
  
  // Database
  sl.registerLazySingleton<AppDatabase>(() => AppDatabase());
  
  // Register Core Services
  sl.registerLazySingleton<LocalStorageService>(() => LocalStorageService(sl()));
  sl.registerLazySingleton<PrinterService>(() => PrinterService());
  sl.registerLazySingleton<SyncService>(() => SyncService(sl()));
  sl.registerLazySingleton<BackgroundSyncService>(() => BackgroundSyncService());
  sl.registerLazySingleton<AnalyticsService>(() => AnalyticsService(sl()));
  
  // Register Repositories
  sl.registerLazySingleton<ProductRepository>(() => ProductRepositoryImpl(sl()));
  sl.registerLazySingleton<SaleRepository>(() => SaleRepositoryImpl(sl()));
  sl.registerLazySingleton<InventoryRepository>(() => InventoryRepositoryImpl(sl()));
  sl.registerLazySingleton<UserRepository>(() => UserRepositoryImpl(sl(), sl()));
  sl.registerLazySingleton<SyncRepository>(() => SyncRepositoryImpl(sl()));
  sl.registerLazySingleton<SettingsRepository>(() => SettingsRepositoryImpl(sl()));
  
  // Register Use Cases
  sl.registerLazySingleton<CreateSaleUseCase>(
      () => CreateSaleUseCase(sl<SaleRepository>(), sl<InventoryRepository>(), sl<UserRepository>()));
  sl.registerLazySingleton<VoidSaleUseCase>(
      () => VoidSaleUseCase(sl<SaleRepository>()));
  sl.registerLazySingleton<AdjustStockUseCase>(
      () => AdjustStockUseCase(sl<InventoryRepository>()));

  // Register BLoCs
  sl.registerFactory<AuthBloc>(() => AuthBloc(sl<UserRepository>()));
  sl.registerFactory<SaleBloc>(() => SaleBloc(sl<CreateSaleUseCase>(), sl<SettingsRepository>()));
  sl.registerFactory<ReportsBloc>(() => ReportsBloc(sl<AnalyticsService>()));

  // Seed default admin user if database is empty
  await _seedDefaultAdmin(sl<AppDatabase>());
  await _seedDefaultProducts(sl<AppDatabase>());
}

String _hashPassword(String password) {
  final bytes = utf8.encode(password);
  return sha256.convert(bytes).toString();
}

Future<void> _seedDefaultAdmin(AppDatabase db) async {
  final now = DateTime.now().millisecondsSinceEpoch;

  final userCount = await db.select(db.users).get();
  if (userCount.isNotEmpty) return;

  final defaultPasswordHash = _hashPassword('password');

  // Insert default users only if the database is empty
  await db.into(db.users).insert(UsersCompanion.insert(
    id: 'user_admin_001',
    email: 'admin@smartpos.com',
    role: 'admin',
    passwordHash: defaultPasswordHash,
    createdAt: Value(now),
    updatedAt: Value(now),
    syncStatus: const Value('pending'),
  ), mode: InsertMode.insertOrIgnore);

  await db.into(db.users).insert(UsersCompanion.insert(
    id: 'user_cashier_001',
    email: 'cashier@smartpos.com',
    role: 'cashier',
    passwordHash: defaultPasswordHash,
    createdAt: Value(now),
    updatedAt: Value(now),
    syncStatus: const Value('pending'),
  ), mode: InsertMode.insertOrIgnore);
}

Future<void> _seedDefaultProducts(AppDatabase db) async {
  final now = DateTime.now().millisecondsSinceEpoch;

  final productCount = await db.select(db.products).get();
  if (productCount.isNotEmpty) return;

  final defaultProducts = [
    {
      'id': 'prod_coffee_001',
      'sku': 'COFFEE-01',
      'name': 'Premium Coffee Beans',
      'sellingPrice': 18.50,
      'costPrice': 10.00,
      'taxRate': 0.08,
      'barcode': '1111111111111',
      'quantity': 45.0,
      'reorderLevel': 10.0,
    },
    {
      'id': 'prod_tea_002',
      'sku': 'TEA-02',
      'name': 'Organic Green Tea',
      'sellingPrice': 6.20,
      'costPrice': 3.00,
      'taxRate': 0.05,
      'barcode': '2222222222222',
      'quantity': 8.0,
      'reorderLevel': 15.0, // Low stock!
    },
    {
      'id': 'prod_cookie_003',
      'sku': 'COOKIE-03',
      'name': 'Chocolate Chip Cookie',
      'sellingPrice': 3.50,
      'costPrice': 1.50,
      'taxRate': 0.0,
      'barcode': '3333333333333',
      'quantity': 150.0,
      'reorderLevel': 20.0,
    },
    {
      'id': 'prod_bread_004',
      'sku': 'BREAD-04',
      'name': 'Artisanal Sourdough Bread',
      'sellingPrice': 7.00,
      'costPrice': 3.50,
      'taxRate': 0.05,
      'barcode': '4444444444444',
      'quantity': 0.0,
      'reorderLevel': 5.0, // Out of stock!
    },
    {
      'id': 'prod_cleaner_005',
      'sku': 'CLEAN-05',
      'name': 'Espresso Machine Cleaner',
      'sellingPrice': 25.00,
      'costPrice': 15.00,
      'taxRate': 0.10,
      'barcode': '5555555555555',
      'quantity': 12.0,
      'reorderLevel': 5.0,
    },
  ];

  for (final p in defaultProducts) {
    // Seed product
    await db.into(db.products).insert(ProductsCompanion.insert(
      id: p['id'] as String,
      sku: p['sku'] as String,
      name: p['name'] as String,
      sellingPrice: p['sellingPrice'] as double,
      costPrice: p['costPrice'] as double,
      taxRate: Value(p['taxRate'] as double),
      barcode: Value(p['barcode'] as String),
      createdAt: Value(now),
      updatedAt: Value(now),
      syncStatus: const Value('pending'),
    ), mode: InsertMode.insertOrIgnore);

    // Seed matching inventory item
    await db.into(db.inventory).insert(InventoryCompanion.insert(
      productId: p['id'] as String,
      quantityOnHand: Value(p['quantity'] as double),
      reorderLevel: Value(p['reorderLevel'] as double),
      createdAt: Value(now),
      updatedAt: Value(now),
      syncStatus: const Value('pending'),
    ), mode: InsertMode.insertOrIgnore);
  }
}
