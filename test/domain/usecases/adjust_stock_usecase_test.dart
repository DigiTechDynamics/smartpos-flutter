import 'package:flutter_test/flutter_test.dart';
import 'package:smartpos/domain/usecases/inventory/adjust_stock_usecase.dart';
import 'package:smartpos/domain/repositories/inventory_repository.dart';
import 'package:smartpos/data/databases/app_database.dart';

class MockInventoryRepository implements InventoryRepository {
  String? productId;
  double? quantityChange;
  String? reason;
  String? userId;

  @override
  Future<void> adjustStock(String productId, double quantityChange, String reason, String userId) async {
    this.productId = productId;
    this.quantityChange = quantityChange;
    this.reason = reason;
    this.userId = userId;
  }

  @override
  Future<List<InventoryItem>> getLowStockItems() async => [];

  @override
  Future<InventoryItem?> getStock(String productId) async => null;

  @override
  Future<bool> sync() async => true;
}

void main() {
  late MockInventoryRepository mockInventoryRepository;
  late AdjustStockUseCase useCase;

  setUp(() {
    mockInventoryRepository = MockInventoryRepository();
    useCase = AdjustStockUseCase(mockInventoryRepository);
  });

  test('should successfully adjust stock when quantity change is non-zero', () async {
    final params = StockAdjustmentParams(
      productId: 'prod_123',
      quantityChange: 10.0,
      reason: 'restock',
      notes: 'Initial restock',
    );

    await useCase.execute(params, 'user_abc');

    expect(mockInventoryRepository.productId, 'prod_123');
    expect(mockInventoryRepository.quantityChange, 10.0);
    expect(mockInventoryRepository.reason, 'restock');
    expect(mockInventoryRepository.userId, 'user_abc');
  });

  test('should throw an exception when quantity change is zero', () async {
    final params = StockAdjustmentParams(
      productId: 'prod_123',
      quantityChange: 0.0,
      reason: 'damaged',
    );

    expect(() => useCase.execute(params, 'user_abc'), throwsException);
  });
}
