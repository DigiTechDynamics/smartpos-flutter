import '../../repositories/inventory_repository.dart';

class CheckStockParams {
  final String productId;
  final double quantity;

  CheckStockParams({required this.productId, required this.quantity});
}

class StockCheckResult {
  final bool available;
  final double current;
  final double reorder;

  StockCheckResult({required this.available, required this.current, required this.reorder});
}

class CheckStockUseCase {
  final InventoryRepository repository;

  CheckStockUseCase(this.repository);

  Future<StockCheckResult> execute(CheckStockParams params) async {
    final stock = await repository.getStock(params.productId);
    
    if (stock == null) {
      return StockCheckResult(available: false, current: 0, reorder: 0);
    }
    
    return StockCheckResult(
      available: stock.quantityOnHand >= params.quantity,
      current: stock.quantityOnHand,
      reorder: stock.reorderLevel,
    );
  }
}
