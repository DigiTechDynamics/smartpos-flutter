import 'package:flutter_test/flutter_test.dart';
import 'package:smartpos/domain/usecases/sales/create_sale_usecase.dart';
import 'package:smartpos/domain/repositories/sale_repository.dart';
import 'package:smartpos/domain/repositories/inventory_repository.dart';
import 'package:smartpos/data/databases/app_database.dart';

class MockSaleRepository implements SaleRepository {
  Sale? lastSale;
  List<SaleItem>? lastItems;
  Payment? lastPayment;
  bool shouldFail = false;

  @override
  Future<Sale> create(Sale sale, List<SaleItem> items, Payment payment) async {
    if (shouldFail) throw Exception('Database error');
    lastSale = sale;
    lastItems = items;
    lastPayment = payment;
    return sale;
  }

  @override
  Future<List<Sale>> getAll({int limit = 20, int offset = 0}) async => [];

  @override
  Future<Sale?> getById(String id) async => null;

  @override
  Future<List<Sale>> getSalesByDateRange(DateTime from, DateTime to) async => [];

  @override
  Future<bool> sync() async => true;

  @override
  Future<void> voidSale(String saleId, String reason) async {}
}

class MockInventoryRepository implements InventoryRepository {
  List<Map<String, dynamic>> adjustments = [];

  @override
  Future<void> adjustStock(String productId, double quantityChange, String reason, String userId) async {
    adjustments.add({
      'productId': productId,
      'quantityChange': quantityChange,
      'reason': reason,
      'userId': userId,
    });
  }

  @override
  Future<List<InventoryItem>> getLowStockItems() async => [];

  @override
  Future<InventoryItem?> getStock(String productId) async => null;

  @override
  Future<bool> sync() async => true;
}

void main() {
  late MockSaleRepository mockSaleRepository;
  late MockInventoryRepository mockInventoryRepository;
  late CreateSaleUseCase useCase;

  setUp(() {
    mockSaleRepository = MockSaleRepository();
    mockInventoryRepository = MockInventoryRepository();
    useCase = CreateSaleUseCase(mockSaleRepository, mockInventoryRepository);
  });

  test('should successfully create a sale and adjust inventory when items are in cart', () async {
    final params = CreateSaleParams(
      items: [
        CartItem(productId: 'prod1', quantity: 2.0, unitPrice: 15.0),
        CartItem(productId: 'prod2', quantity: 1.0, unitPrice: 20.0),
      ],
      paymentMethod: 'cash',
      discountAmount: 5.0,
    );

    final sale = await useCase.execute(params);

    expect(sale.id, isNotEmpty);
    // subtotal = (2 * 15) + (1 * 20) = 50.0
    expect(sale.subtotal, 50.0);
    // tax = 50.0 * 0.15 = 7.5
    expect(sale.tax, 7.5);
    // total = 50.0 + 7.5 - 5.0 = 52.5
    expect(sale.total, 52.5);

    // Verify Repository calls
    expect(mockSaleRepository.lastSale, isNotNull);
    expect(mockSaleRepository.lastSale!.total, 52.5);
    expect(mockSaleRepository.lastItems!.length, 2);
    expect(mockSaleRepository.lastPayment!.method, 'cash');

    // Verify Inventory adjustments
    expect(mockInventoryRepository.adjustments.length, 2);
    expect(mockInventoryRepository.adjustments[0]['productId'], 'prod1');
    expect(mockInventoryRepository.adjustments[0]['quantityChange'], -2.0);
    expect(mockInventoryRepository.adjustments[1]['productId'], 'prod2');
    expect(mockInventoryRepository.adjustments[1]['quantityChange'], -1.0);
  });

  test('should throw an exception when items list is empty', () async {
    final params = CreateSaleParams(
      items: [],
      paymentMethod: 'card',
    );

    expect(() => useCase.execute(params), throwsException);
  });
}
