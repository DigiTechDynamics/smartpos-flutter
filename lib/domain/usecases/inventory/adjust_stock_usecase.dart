import '../../repositories/inventory_repository.dart';

class StockAdjustmentParams {
  final String productId;
  final double quantityChange;
  final String reason;
  final String notes;

  StockAdjustmentParams({
    required this.productId,
    required this.quantityChange,
    required this.reason,
    this.notes = '',
  });
}

class AdjustStockUseCase {
  final InventoryRepository repository;

  AdjustStockUseCase(this.repository);

  Future<void> execute(StockAdjustmentParams params, String userId) async {
    if (params.quantityChange == 0) {
      throw Exception('Quantity change cannot be zero');
    }

    await repository.adjustStock(
      params.productId, 
      params.quantityChange, 
      params.reason, 
      userId,
    );
  }
}
