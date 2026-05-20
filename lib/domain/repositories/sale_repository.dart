import '../../data/databases/app_database.dart';

abstract class SaleRepository {
  Future<Sale> create(Sale sale, List<SaleItem> items, Payment payment);
  Future<List<Sale>> getAll({int limit = 20, int offset = 0});
  Future<Sale?> getById(String id);
  Future<void> voidSale(String saleId, String reason);
  Future<List<Sale>> getSalesByDateRange(DateTime from, DateTime to);
  Future<bool> sync();
}
