import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartpos/domain/usecases/sales/create_sale_usecase.dart';
import 'package:smartpos/domain/repositories/settings_repository.dart';
import 'package:smartpos/presentation/bloc/sale/sale_bloc.dart';
import 'package:smartpos/presentation/bloc/sale/sale_event.dart';
import 'package:smartpos/presentation/bloc/sale/sale_state.dart';
import 'package:smartpos/presentation/widgets/sales/quick_checkout_panel.dart';

class MockCreateSaleUseCase implements CreateSaleUseCase {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class MockSettingsRepository implements SettingsRepository {
  @override
  Future<String?> getSetting(String key) async => null;

  @override
  Future<void> saveSetting(String key, String value) async {}

  @override
  Future<Map<String, String>> getAllSettings() async => {};
}

class StubSaleBloc extends SaleBloc {
  final SaleState stubState;
  final List<SaleEvent> addedEvents = [];

  StubSaleBloc(this.stubState)
      : super(MockCreateSaleUseCase(), MockSettingsRepository());

  @override
  SaleState get state => stubState;

  @override
  void add(SaleEvent event) {
    addedEvents.add(event);
  }
}

void main() {
  late StubSaleBloc stubSaleBloc;
  late SaleInProgress testState;

  setUp(() {
    testState = SaleInProgress(
      cartItems: [
        CartItem(
          productId: 'prod1',
          quantity: 2.0,
          unitPrice: 10.0,
          productName: 'Product 1',
          productSku: 'sku1',
        ),
      ],
      subtotal: 20.0,
      tax: 3.0,
      discountAmount: 0.0,
      total: 23.0,
    );
    stubSaleBloc = StubSaleBloc(testState);
  });

  Widget createWidgetUnderTest() {
    return MaterialApp(
      home: Scaffold(
        body: BlocProvider<SaleBloc>.value(
          value: stubSaleBloc,
          child: QuickCheckoutPanel(state: testState),
        ),
      ),
    );
  }

  testWidgets('should render all quick checkout buttons and suggested bills', (tester) async {
    await tester.pumpWidget(createWidgetUnderTest());

    // Verify Title & Panels
    expect(find.text('SEAMLESS QUICK CHECKOUT'), findsOneWidget);
    expect(find.text('Exact Cash'), findsOneWidget);
    expect(find.text('Quick Card'), findsOneWidget);
    expect(find.text('EcoCash'), findsOneWidget);
    expect(find.text('TENDER CASH SUGGESTIONS'), findsOneWidget);

    // Verify smart bill denominations for total 23 (suggests +$50, +$100, etc.)
    expect(find.text('+\$50'), findsOneWidget);
    expect(find.text('+\$100'), findsOneWidget);
  });

  testWidgets('should dispatch ProcessPayment when quick buttons are tapped', (tester) async {
    await tester.pumpWidget(createWidgetUnderTest());

    await tester.tap(find.text('Exact Cash'));
    await tester.pump();

    expect(stubSaleBloc.addedEvents.length, 1);
    final lastEvent = stubSaleBloc.addedEvents.last as ProcessPayment;
    expect(lastEvent.payments.length, 1);
    expect(lastEvent.payments.first.method, 'cash');
    expect(lastEvent.payments.first.amount, 23.0);
  });
}
