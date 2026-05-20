import '../../repositories/sale_repository.dart';
import '../../../data/databases/app_database.dart';

class GetSalesParams {
  final int page;
  final int limit;
  final DateTime? startDate;
  final DateTime? endDate;

  GetSalesParams({this.page = 1, this.limit = 50, this.startDate, this.endDate});
}

class GetSalesUseCase {
  final SaleRepository repository;

  GetSalesUseCase(this.repository);

  Future<List<Sale>> execute(GetSalesParams params) async {
    final offset = (params.page - 1) * params.limit;
    
    if (params.startDate != null && params.endDate != null) {
      return await repository.getSalesByDateRange(params.startDate!, params.endDate!);
    }
    
    return await repository.getAll(limit: params.limit, offset: offset);
  }
}
