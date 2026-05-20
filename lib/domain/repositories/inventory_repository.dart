import '../../data/databases/app_database.dart';

abstract class InventoryRepository {
  Future<InventoryItem?> getStock(String productId);
  Future<void> adjustStock(String productId, double quantityChange, String reason, String userId);
  Future<List<InventoryItem>> getLowStockItems();
  Future<bool> sync();
}
