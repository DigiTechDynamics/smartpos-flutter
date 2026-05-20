import '../../repositories/inventory_repository.dart';
import '../../../data/databases/app_database.dart';

class GetLowStockItemsUseCase {
  final InventoryRepository repository;

  GetLowStockItemsUseCase(this.repository);

  Future<List<InventoryItem>> execute() async {
    return await repository.getLowStockItems();
  }
}
