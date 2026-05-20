# SmartPOS Seamless Quick Checkout Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Create a seamless, one-tap "Quick Checkout" flow directly from the active cart interface (the sidebar in `SalePage` and the bottom checkout section in `CartPage`), bypassing multiple navigation steps (Cart Page -> Payment Page) and instantly printing/displaying the transaction receipt.

**Architecture:** Wrap both the main `SalePage` (large screen layout) and `CartPage` (mobile layout) in `BlocListener<SaleBloc, SaleState>` widgets to listen for `SaleComplete` and `SaleError` states. Integrate a new, premium `QuickCheckoutPanel` component into the sidebars/cart sheets to let cashiers tap exact cash, card, EcoCash, or smart dynamic dollar bills to instantly complete checkouts without leaving their active context.

**Tech Stack:** Flutter, Dart, `flutter_bloc` state management, standard GoRouter routing.

---

### Task 1: Create the Reusable QuickCheckoutPanel Component

**Files:**
- Create: `lib/presentation/widgets/sales/quick_checkout_panel.dart`
- Test: `test/presentation/widgets/quick_checkout_panel_test.dart`

**Step 1: Write the failing test**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartpos/presentation/bloc/sale/sale_bloc.dart';
import 'package:smartpos/presentation/bloc/sale/sale_event.dart';
import 'package:smartpos/presentation/bloc/sale/sale_state.dart';
import 'package:smartpos/presentation/widgets/sales/quick_checkout_panel.dart';

class StubSaleBloc extends Bloc<SaleEvent, SaleState> implements SaleBloc {
  final SaleState stubState;
  final List<SaleEvent> addedEvents = [];

  StubSaleBloc(this.stubState) : super(stubState) {
    on<SaleEvent>((event, emit) {
      addedEvents.add(event);
    });
  }
}

void main() {
  late StubSaleBloc stubSaleBloc;
  late SaleInProgress testState;

  setUp(() {
    testState = const SaleInProgress(
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

    // Verify smart bill denominations for total 23
    expect(find.text('+$50'), findsOneWidget);
    expect(find.text('+$100'), findsOneWidget);
  });

  testWidgets('should dispatch ProcessPayment when quick buttons are tapped', (tester) async {
    await tester.pumpWidget(createWidgetUnderTest());

    await tester.tap(find.text('Exact Cash'));
    await tester.pump();

    final lastEvent = stubSaleBloc.addedEvents.last as ProcessPayment;
    expect(lastEvent.paymentMethod, 'cash');
    expect(lastEvent.amountTendered, 23.0);
  });
}
```

**Step 2: Run test to verify it fails**

Run: `flutter test test/presentation/widgets/quick_checkout_panel_test.dart`
Expected: Compilation failure or missing target file.

**Step 3: Write minimal implementation**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../bloc/sale/sale_bloc.dart';
import '../../bloc/sale/sale_event.dart';
import '../../bloc/sale/sale_state.dart';

class QuickCheckoutPanel extends StatelessWidget {
  final SaleInProgress state;

  const QuickCheckoutPanel({super.key, required this.state});

  List<double> _getQuickCashOptions(double total) {
    final List<double> bills = [1.0, 2.0, 5.0, 10.0, 20.0, 50.0, 100.0];
    final options = <double>[];
    
    // Add dynamic rounding bill suggestions
    if (total > 0 && total % 1 != 0) {
      options.add(total.ceilToDouble());
    }
    
    for (final bill in bills) {
      if (bill > total) {
        options.add(bill);
      }
    }
    
    if (total > 100) {
      options.add(((total / 50).ceil() * 50).toDouble());
      options.add(((total / 100).ceil() * 100).toDouble());
    }

    return options.toSet().toList()..sort();
  }

  @override
  Widget build(BuildContext context) {
    final total = state.total;
    final cashOptions = _getQuickCashOptions(total);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        const Divider(height: 24, thickness: 0.8),
        Row(
          children: [
            const Icon(Icons.bolt, color: Colors.amber, size: 16),
            const SizedBox(width: 6),
            Text(
              'SEAMLESS QUICK CHECKOUT',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 11,
                color: Colors.grey.shade600,
                letterSpacing: 0.8,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        
        // Horizontal grid of exact payment options
        Row(
          children: [
            Expanded(
              child: _buildQuickMethodCard(
                context: context,
                label: 'Exact Cash',
                icon: Icons.money,
                color: Colors.green,
                onPressed: () {
                  context.read<SaleBloc>().add(ProcessPayment('cash', total));
                },
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildQuickMethodCard(
                context: context,
                label: 'Quick Card',
                icon: Icons.credit_card,
                color: Colors.indigo,
                onPressed: () {
                  context.read<SaleBloc>().add(ProcessPayment('card', total));
                },
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildQuickMethodCard(
                context: context,
                label: 'EcoCash',
                icon: Icons.phone_android,
                color: Colors.amber,
                onPressed: () {
                  context.read<SaleBloc>().add(ProcessPayment('mobile', total));
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        
        // Cash bill recommendations
        if (cashOptions.isNotEmpty) ...[
          Text(
            'TENDER CASH SUGGESTIONS',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 10,
              color: Colors.grey.shade500,
              letterSpacing: 0.6,
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 38,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: cashOptions.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final amount = cashOptions[index];
                final change = amount - total;
                return ActionChip(
                  avatar: const Icon(Icons.attach_money, size: 14, color: Colors.green),
                  label: Text(
                    '+\$${amount.toStringAsFixed(0)}',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.green),
                  ),
                  tooltip: change > 0 ? 'Change due: \$${change.toStringAsFixed(2)}' : 'Exact cash',
                  backgroundColor: Colors.green.shade50,
                  side: BorderSide(color: Colors.green.shade200, width: 0.8),
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
                  onPressed: () {
                    context.read<SaleBloc>().add(ProcessPayment('cash', amount));
                  },
                );
              },
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildQuickMethodCard({
    required BuildContext context,
    required String label,
    required IconData icon,
    required MaterialColor color,
    required VoidCallback onPressed,
  }) {
    return Material(
      color: color.shade50,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: color.shade200, width: 0.8),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: color.shade800, size: 22),
              const SizedBox(height: 6),
              Text(
                label,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 11,
                  color: color.shade900,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
```

**Step 4: Run test to verify it passes**

Run: `flutter test test/presentation/widgets/quick_checkout_panel_test.dart`
Expected: PASS

**Step 5: Commit**

```bash
git add lib/presentation/widgets/sales/quick_checkout_panel.dart test/presentation/widgets/quick_checkout_panel_test.dart
git commit -m "feat: add reusable QuickCheckoutPanel component and widget tests"
```

---

### Task 2: Implement Quick Checkout Listening & Sidebar Wire-up in SalePage

**Files:**
- Modify: `lib/presentation/pages/sales/sale_page.dart:80-95` (Add `BlocListener` and Quick Checkout panel in `_CartSidebar`)

**Step 1: Write the failing test**

```dart
// Modifying existing sale page tests to assert the quick checkout panel rendering in wide sidebar
```
Since standard widget tests verify overall catalog layout, we'll manually integrate the changes and verify through the compilation/running check.

**Step 2: Implement changes in `sale_page.dart`**

Modify: `lib/presentation/pages/sales/sale_page.dart`

1. Wrap the Scaffold body or root widget in `BlocListener<SaleBloc, SaleState>` around line 80:

```dart
    return BlocListener<SaleBloc, SaleState>(
      listener: (context, state) {
        if (state is SaleComplete) {
          context.go(
            '/sale/receipt',
            extra: {
              'saleId': state.saleId,
              'change': state.change,
            },
          );
        } else if (state is SaleError) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.message),
              backgroundColor: Colors.redAccent,
            ),
          );
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('POS Checkout'),
          actions: [
```

2. Inside `_CartSidebar` component, replace lines 530-550 with:

```dart
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Total',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      Text('\$${state.total.toStringAsFixed(2)}',
                          style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 20,
                              color: Colors.blue)),
                    ],
                  ),
                  const SizedBox(height: 10),
                  // Insert Reusable Quick Checkout Panel
                  QuickCheckoutPanel(state: state),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      context.go('/sale/cart');
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      elevation: 0,
                    ),
                    child: const Text('PROCEED TO WIZARD CHECKOUT', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 0.5, fontSize: 12)),
                  ),
```

3. Ensure imports are resolved:
```dart
import '../../widgets/sales/quick_checkout_panel.dart';
```

**Step 3: Run the test suite and verify no syntax/compilation errors**

Run: `flutter test`
Expected: PASS

**Step 4: Commit**

```bash
git add lib/presentation/pages/sales/sale_page.dart
git commit -m "feat: integrate QuickCheckoutPanel and complete sale listener into POS SalePage"
```

---

### Task 3: Implement Quick Checkout Listening & Footer Panel in CartPage

**Files:**
- Modify: `lib/presentation/pages/sales/cart_page.dart:45-208` (Add Listener, integrate `QuickCheckoutPanel` into CartPage checkout block)

**Step 1: Implement changes in `cart_page.dart`**

Modify: `lib/presentation/pages/sales/cart_page.dart`

1. Wrap the Scaffold body/content inside `BlocListener<SaleBloc, SaleState>`:

```dart
      body: BlocListener<SaleBloc, SaleState>(
        listener: (context, state) {
          if (state is SaleComplete) {
            context.go(
              '/sale/receipt',
              extra: {
                'saleId': state.saleId,
                'change': state.change,
              },
            );
          } else if (state is SaleError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(state.message), backgroundColor: Colors.redAccent),
            );
          }
        },
        child: BlocBuilder<SaleBloc, SaleState>(
          builder: (context, state) {
```

2. Inside the bottom container where the "Total" is displayed, insert `QuickCheckoutPanel` under the "Total" and above the standard "PROCEED TO PAYMENT" button:

```dart
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Total',
                            style: TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 20)),
                        Text(
                          '\$${state.total.toStringAsFixed(2)}',
                          style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 20,
                              color: Colors.blue),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    // Quick checkout options for mobile cart
                    QuickCheckoutPanel(state: state),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () {
                        context.go('/sale/payment');
                      },
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: const Text('PROCEED TO WIZARD PAYMENT'),
                    ),
```

3. Ensure import is added:
```dart
import '../../widgets/sales/quick_checkout_panel.dart';
```

**Step 2: Run all unit tests**

Run: `flutter test`
Expected: PASS

**Step 3: Commit**

```bash
git add lib/presentation/pages/sales/cart_page.dart
git commit -m "feat: enable QuickCheckoutPanel and checkout completion listening inside mobile CartPage"
```
