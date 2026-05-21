import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../domain/usecases/sales/create_sale_usecase.dart';
import 'sale_event.dart';
import 'sale_state.dart';

class SaleBloc extends Bloc<SaleEvent, SaleState> {
  final CreateSaleUseCase createSaleUseCase;
  
  List<CartItem> _cartItems = [];
  double _discountAmount = 0;
  final List<List<CartItem>> _parkedSales = [];

  SaleBloc(this.createSaleUseCase) : super(SaleInitial()) {
    on<AddItemToCart>(_onAddItem);
    on<RemoveItemFromCart>(_onRemoveItem);
    on<UpdateItemQuantity>(_onUpdateQuantity);
    on<ApplyDiscount>(_onApplyDiscount);
    on<ProcessPayment>(_onProcessPayment);
    on<ClearCart>(_onClearCart);
    on<ParkSale>(_onParkSale);
    on<RestoreParkedSale>(_onRestoreParkedSale);
  }

  void _onAddItem(AddItemToCart event, Emitter<SaleState> emit) {
    final existingIndex = _cartItems.indexWhere((item) => item.productId == event.product.id);
    if (existingIndex >= 0) {
      _cartItems[existingIndex] = CartItem(
        productId: event.product.id,
        quantity: _cartItems[existingIndex].quantity + event.quantity,
        unitPrice: event.product.sellingPrice,
        productName: event.product.name,
        productSku: event.product.sku,
      );
    } else {
      _cartItems.add(CartItem(
        productId: event.product.id,
        quantity: event.quantity,
        unitPrice: event.product.sellingPrice,
        productName: event.product.name,
        productSku: event.product.sku,
      ));
    }
    _emitInProgress(emit);
  }

  void _onRemoveItem(RemoveItemFromCart event, Emitter<SaleState> emit) {
    _cartItems.removeWhere((item) => item.productId == event.productId);
    _emitInProgress(emit);
  }

  void _onUpdateQuantity(UpdateItemQuantity event, Emitter<SaleState> emit) {
    if (event.quantity <= 0) {
      _cartItems.removeWhere((item) => item.productId == event.productId);
    } else {
      final index = _cartItems.indexWhere((item) => item.productId == event.productId);
      if (index >= 0) {
        _cartItems[index] = CartItem(
          productId: event.productId,
          quantity: event.quantity,
          unitPrice: _cartItems[index].unitPrice,
          productName: _cartItems[index].productName,
          productSku: _cartItems[index].productSku,
        );
      }
    }
    _emitInProgress(emit);
  }

  void _onApplyDiscount(ApplyDiscount event, Emitter<SaleState> emit) {
    _discountAmount = event.discountAmount;
    _emitInProgress(emit);
  }

  Future<void> _onProcessPayment(ProcessPayment event, Emitter<SaleState> emit) async {
    final subtotal = _cartItems.fold(0.0, (sum, item) => sum + (item.quantity * item.unitPrice));
    final tax = subtotal * 0.15;
    final total = subtotal + tax - _discountAmount;

    if (event.amountTendered < total && event.paymentMethod == 'cash') {
      emit(SaleError('Amount tendered is less than total'));
      _emitInProgress(emit); // Revert to cart
      return;
    }

    try {
      final sale = await createSaleUseCase.execute(CreateSaleParams(
        items: _cartItems,
        paymentMethod: event.paymentMethod,
        discountAmount: _discountAmount,
      ));
      
      final change = event.amountTendered >= total ? event.amountTendered - total : 0.0;
      
      // Clear cart
      _cartItems.clear();
      _discountAmount = 0;
      
      emit(SaleComplete(sale.id, change));
    } catch (e) {
      emit(SaleError(e.toString()));
      _emitInProgress(emit);
    }
  }

  void _onClearCart(ClearCart event, Emitter<SaleState> emit) {
    _cartItems.clear();
    _discountAmount = 0;
    emit(SaleInitial(parkedSales: List.from(_parkedSales)));
  }

  void _onParkSale(ParkSale event, Emitter<SaleState> emit) {
    if (_cartItems.isNotEmpty) {
      _parkedSales.add(List.from(_cartItems));
      _cartItems.clear();
      _discountAmount = 0;
    }
    emit(SaleInitial(parkedSales: List.from(_parkedSales)));
  }

  void _onRestoreParkedSale(RestoreParkedSale event, Emitter<SaleState> emit) {
    if (event.index >= 0 && event.index < _parkedSales.length) {
      // If we currently have an active cart, swap them (park current, restore selected)
      if (_cartItems.isNotEmpty) {
        final current = List<CartItem>.from(_cartItems);
        _cartItems = _parkedSales[event.index];
        _parkedSales[event.index] = current;
      } else {
        _cartItems = _parkedSales.removeAt(event.index);
      }
      _emitInProgress(emit);
    }
  }

  void _emitInProgress(Emitter<SaleState> emit) {
    if (_cartItems.isEmpty) {
      emit(SaleInitial(parkedSales: List.from(_parkedSales)));
      return;
    }
    
    final subtotal = _cartItems.fold(0.0, (sum, item) => sum + (item.quantity * item.unitPrice));
    final tax = subtotal * 0.15;
    final total = subtotal + tax - _discountAmount;

    emit(SaleInProgress(
      cartItems: List.from(_cartItems),
      subtotal: subtotal,
      tax: tax,
      discountAmount: _discountAmount,
      total: total,
      parkedSales: List.from(_parkedSales),
    ));
  }
}
