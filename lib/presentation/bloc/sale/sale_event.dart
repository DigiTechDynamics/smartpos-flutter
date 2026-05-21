import '../../../domain/usecases/sales/create_sale_usecase.dart';
import '../../../data/databases/app_database.dart';

abstract class SaleEvent {}

class AddItemToCart extends SaleEvent {
  final Product product;
  final double quantity;
  AddItemToCart(this.product, this.quantity);
}

class RemoveItemFromCart extends SaleEvent {
  final String productId;
  RemoveItemFromCart(this.productId);
}

class UpdateItemQuantity extends SaleEvent {
  final String productId;
  final double quantity;
  UpdateItemQuantity(this.productId, this.quantity);
}

class ApplyDiscount extends SaleEvent {
  final double discountAmount;
  ApplyDiscount(this.discountAmount);
}

class ProcessPayment extends SaleEvent {
  final List<SalePaymentInput> payments;
  ProcessPayment(this.payments);
}

class ClearCart extends SaleEvent {}

class ParkSale extends SaleEvent {}

class RestoreParkedSale extends SaleEvent {
  final int index;
  RestoreParkedSale(this.index);
}
