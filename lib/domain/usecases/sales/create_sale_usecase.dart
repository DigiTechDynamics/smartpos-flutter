import '../../repositories/sale_repository.dart';
import '../../repositories/inventory_repository.dart';
import '../../repositories/user_repository.dart';
import '../../../data/databases/app_database.dart';

class CartItem {
  final String productId;
  final double quantity;
  final double unitPrice;
  final String productName;
  final String productSku;

  CartItem({
    required this.productId,
    required this.quantity,
    required this.unitPrice,
    this.productName = '',
    this.productSku = '',
  });
}

class SalePaymentInput {
  final String method;
  final double amount;

  SalePaymentInput({required this.method, required this.amount});
}

class CreateSaleParams {
  final List<CartItem> items;
  final List<SalePaymentInput> payments;
  final double discountAmount;
  final double taxRate;
  final String? customerId;
  final String notes;

  CreateSaleParams({
    required this.items,
    required this.payments,
    this.discountAmount = 0.0,
    this.taxRate = 0.0,
    this.customerId,
    this.notes = '',
  });
}

class CreateSaleUseCase {
  final SaleRepository saleRepository;
  final InventoryRepository inventoryRepository;
  final UserRepository userRepository;

  CreateSaleUseCase(this.saleRepository, this.inventoryRepository, this.userRepository);

  Future<Sale> execute(CreateSaleParams params) async {
    if (params.items.isEmpty) {
      throw Exception('Sale must contain at least one item');
    }
    if (params.payments.isEmpty) {
      throw Exception('Sale must contain at least one payment');
    }

    double subtotal = params.items.fold(0, (sum, item) => sum + (item.quantity * item.unitPrice));
    double tax = subtotal * params.taxRate;
    double total = subtotal + tax - params.discountAmount;

    final saleId = DateTime.now().millisecondsSinceEpoch.toString();
    final saleNumber = 'SALE-\$saleId';

    // Summary payment method for the Sale table. 
    // If multiple, set to 'split'.
    String summaryPaymentMethod = params.payments.length > 1 
        ? 'split' 
        : params.payments.first.method;

    final sale = Sale(
      id: saleId,
      saleNumber: saleNumber,
      subtotal: subtotal,
      tax: tax,
      discount: params.discountAmount,
      total: total,
      paymentMethod: summaryPaymentMethod,
      userId: (await userRepository.getCurrentUser())?.id ?? 'unknown_user',
      createdAt: DateTime.now().millisecondsSinceEpoch,
      updatedAt: DateTime.now().millisecondsSinceEpoch,
      syncStatus: 'pending',
    );

    List<Payment> paymentEntities = params.payments.map((p) => Payment(
      id: DateTime.now().millisecondsSinceEpoch.toString() + '_' + p.method,
      saleId: saleId,
      method: p.method,
      amount: p.amount,
      createdAt: DateTime.now().millisecondsSinceEpoch,
      updatedAt: DateTime.now().millisecondsSinceEpoch,
      syncStatus: 'pending',
    )).toList();

    List<SaleItem> saleItems = params.items.map((item) => SaleItem(
      saleId: saleId,
      productId: item.productId,
      quantity: item.quantity,
      unitPrice: item.unitPrice,
      taxAmount: (item.quantity * item.unitPrice) * params.taxRate,
    )).toList();

    // 1. Create Sale (which atomically updates inventory and records all payments)
    final createdSale = await saleRepository.create(sale, saleItems, paymentEntities);

    return createdSale;
  }
}
