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

class CreateSaleParams {
  final List<CartItem> items;
  final String paymentMethod;
  final double discountAmount;
  final String notes;

  CreateSaleParams({
    required this.items,
    required this.paymentMethod,
    this.discountAmount = 0.0,
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

    double subtotal = params.items.fold(0, (sum, item) => sum + (item.quantity * item.unitPrice));
    double tax = subtotal * 0.15; // 15% VAT placeholder
    double total = subtotal + tax - params.discountAmount;

    final saleId = DateTime.now().millisecondsSinceEpoch.toString();
    final saleNumber = 'SALE-\$saleId';

    final sale = Sale(
      id: saleId,
      saleNumber: saleNumber,
      subtotal: subtotal,
      tax: tax,
      discount: params.discountAmount,
      total: total,
      paymentMethod: params.paymentMethod,
      userId: (await userRepository.getCurrentUser())?.id ?? 'unknown_user',
      createdAt: DateTime.now().millisecondsSinceEpoch,
      updatedAt: DateTime.now().millisecondsSinceEpoch,
      syncStatus: 'pending',
    );

    final payment = Payment(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      saleId: saleId,
      method: params.paymentMethod,
      amount: total,
      createdAt: DateTime.now().millisecondsSinceEpoch,
      updatedAt: DateTime.now().millisecondsSinceEpoch,
      syncStatus: 'pending',
    );

    List<SaleItem> saleItems = params.items.map((item) => SaleItem(
      saleId: saleId,
      productId: item.productId,
      quantity: item.quantity,
      unitPrice: item.unitPrice,
      taxAmount: 0.0,
    )).toList();

    // 1. Create Sale (which atomically updates inventory)
    final createdSale = await saleRepository.create(sale, saleItems, payment);

    return createdSale;
  }
}
