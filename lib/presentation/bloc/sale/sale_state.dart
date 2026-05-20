import '../../../domain/usecases/sales/create_sale_usecase.dart';

abstract class SaleState {}

class SaleInitial extends SaleState {}

class SaleInProgress extends SaleState {
  final List<CartItem> cartItems;
  final double subtotal;
  final double tax;
  final double discountAmount;
  final double total;

  SaleInProgress({
    required this.cartItems,
    required this.subtotal,
    required this.tax,
    required this.discountAmount,
    required this.total,
  });
}

class PaymentPending extends SaleState {
  final double totalDue;
  PaymentPending(this.totalDue);
}

class SaleComplete extends SaleState {
  final String saleId;
  final double change;
  SaleComplete(this.saleId, this.change);
}

class SaleError extends SaleState {
  final String message;
  SaleError(this.message);
}
