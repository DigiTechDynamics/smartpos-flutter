import 'package:flutter_test/flutter_test.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:smartpos/presentation/bloc/sale/sale_bloc.dart';
import 'package:smartpos/presentation/bloc/sale/sale_event.dart';
import 'package:smartpos/presentation/bloc/sale/sale_state.dart';
import 'package:smartpos/domain/usecases/sales/create_sale_usecase.dart';
import 'package:smartpos/data/databases/app_database.dart';
import 'package:smartpos/domain/repositories/sale_repository.dart';
import 'package:smartpos/domain/repositories/inventory_repository.dart';
import 'package:smartpos/domain/repositories/user_repository.dart';
import 'package:smartpos/domain/repositories/settings_repository.dart';

class MockSettingsRepository implements SettingsRepository {
  final Map<String, String> _settings = {'tax_rate': '15.0'};

  @override
  Future<String?> getSetting(String key) async => _settings[key];

  @override
  Future<void> saveSetting(String key, String value) async {
    _settings[key] = value;
  }

  @override
  Future<Map<String, String>> getAllSettings() async => _settings;
}

class MockCreateSaleUseCase implements CreateSaleUseCase {
  bool executeShouldFail = false;
  CreateSaleParams? lastParams;

  @override
  SaleRepository get saleRepository => throw UnimplementedError();

  @override
  InventoryRepository get inventoryRepository => throw UnimplementedError();

  @override
  UserRepository get userRepository => throw UnimplementedError();

  @override
  Future<Sale> execute(CreateSaleParams params) async {
    if (executeShouldFail) throw Exception('Checkout error');
    lastParams = params;
    final subtotal = params.items.fold(0.0, (sum, item) => sum + (item.quantity * item.unitPrice));
    final tax = subtotal * 0.15;
    return Sale(
      id: 'sale_123',
      saleNumber: 'SALE-123',
      subtotal: subtotal,
      tax: tax,
      discount: params.discountAmount,
      total: subtotal + tax - params.discountAmount,
      paymentMethod: params.payments.length > 1 ? 'split' : params.payments.first.method,
      userId: 'user_1',
      createdAt: DateTime.now().millisecondsSinceEpoch,
      updatedAt: DateTime.now().millisecondsSinceEpoch,
      syncStatus: 'pending',
    );
  }
}

void main() {
  late MockCreateSaleUseCase mockCreateSaleUseCase;
  late MockSettingsRepository mockSettingsRepository;
  late Product testProduct1;
  late Product testProduct2;

  setUp(() {
    mockCreateSaleUseCase = MockCreateSaleUseCase();
    mockSettingsRepository = MockSettingsRepository();
    testProduct1 = Product(
      id: 'prod1',
      sku: 'sku1',
      name: 'Product 1',
      sellingPrice: 10.0,
      costPrice: 5.0,
      taxRate: 0.0,
      createdAt: DateTime.now().millisecondsSinceEpoch,
      updatedAt: DateTime.now().millisecondsSinceEpoch,
      syncStatus: 'pending',
    );
    testProduct2 = Product(
      id: 'prod2',
      sku: 'sku2',
      name: 'Product 2',
      sellingPrice: 20.0,
      costPrice: 10.0,
      taxRate: 0.0,
      createdAt: DateTime.now().millisecondsSinceEpoch,
      updatedAt: DateTime.now().millisecondsSinceEpoch,
      syncStatus: 'pending',
    );
  });

  blocTest<SaleBloc, SaleState>(
    'should emit [SaleInProgress] with correct calculations when adding product to cart',
    build: () => SaleBloc(mockCreateSaleUseCase, mockSettingsRepository),
    act: (bloc) => bloc.add(AddItemToCart(testProduct1, 2.0)),
    expect: () => [
      isA<SaleInProgress>(),
    ],
    verify: (bloc) {
      final state = bloc.state as SaleInProgress;
      expect(state.cartItems.length, 1);
      expect(state.subtotal, 20.0);
      expect(state.tax, 3.0);
      expect(state.total, 23.0);
    },
  );

  blocTest<SaleBloc, SaleState>(
    'should emit [SaleInProgress, SaleInitial] when adding then clearing cart',
    build: () => SaleBloc(mockCreateSaleUseCase, mockSettingsRepository),
    act: (bloc) => bloc
      ..add(AddItemToCart(testProduct1, 1.0))
      ..add(ClearCart()),
    expect: () => [
      isA<SaleInProgress>(),
      isA<SaleInitial>(),
    ],
  );

  blocTest<SaleBloc, SaleState>(
    'should emit [SaleInProgress] with updated quantity when adding existing product',
    build: () => SaleBloc(mockCreateSaleUseCase, mockSettingsRepository),
    act: (bloc) => bloc
      ..add(AddItemToCart(testProduct1, 1.0))
      ..add(AddItemToCart(testProduct1, 2.0)),
    expect: () => [
      isA<SaleInProgress>(),
      isA<SaleInProgress>(),
    ],
    verify: (bloc) {
      final state = bloc.state as SaleInProgress;
      expect(state.cartItems.length, 1);
      expect(state.cartItems[0].quantity, 3.0);
      expect(state.subtotal, 30.0);
    },
  );

  blocTest<SaleBloc, SaleState>(
    'should emit [SaleInProgress] showing correct total discount and total when discount applied',
    build: () => SaleBloc(mockCreateSaleUseCase, mockSettingsRepository),
    act: (bloc) => bloc
      ..add(AddItemToCart(testProduct2, 1.0))
      ..add(ApplyDiscount(5.0)),
    expect: () => [
      isA<SaleInProgress>(),
      isA<SaleInProgress>(),
    ],
    verify: (bloc) {
      final state = bloc.state as SaleInProgress;
      expect(state.discountAmount, 5.0);
      // subtotal = 20, tax = 3, total = 20 + 3 - 5 = 18
      expect(state.total, 18.0);
    },
  );

  blocTest<SaleBloc, SaleState>(
    'should emit [SaleComplete] when ProcessPayment is successful',
    build: () => SaleBloc(mockCreateSaleUseCase, mockSettingsRepository),
    act: (bloc) => bloc
      ..add(AddItemToCart(testProduct1, 2.0)) // total = 20 + 3 = 23
      ..add(ProcessPayment([SalePaymentInput(method: 'cash', amount: 25.0)])),
    expect: () => [
      isA<SaleInProgress>(),
      isA<SaleComplete>(),
    ],
    verify: (bloc) {
      final state = bloc.state as SaleComplete;
      expect(state.saleId, 'sale_123');
      expect(state.change, 2.0);
    },
  );

  blocTest<SaleBloc, SaleState>(
    'should emit [SaleError, SaleInProgress] when tendered amount is less than total',
    build: () => SaleBloc(mockCreateSaleUseCase, mockSettingsRepository),
    act: (bloc) => bloc
      ..add(AddItemToCart(testProduct1, 2.0)) // total = 23
      ..add(ProcessPayment([SalePaymentInput(method: 'cash', amount: 20.0)])),
    expect: () => [
      isA<SaleInProgress>(),
      isA<SaleError>(),
      isA<SaleInProgress>(),
    ],
    verify: (bloc) {
      expect(bloc.state, isA<SaleInProgress>());
    },
  );
}
