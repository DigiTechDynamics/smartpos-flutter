import '../../data/databases/app_database.dart';

abstract class ProductRepository {
  Future<List<Product>> getAll({int limit = 20, int offset = 0});
  Future<List<Product>> search(String query);
  Future<Product?> getById(String id);
  Future<void> add(Product product);
  Future<void> updateProduct(Product product);
  Future<bool> sync();
}
