import '../../repositories/sale_repository.dart';

class VoidSaleParams {
  final String saleId;
  final String reason;

  VoidSaleParams({required this.saleId, required this.reason});
}

class VoidSaleUseCase {
  final SaleRepository repository;

  VoidSaleUseCase(this.repository);

  Future<void> execute(VoidSaleParams params) async {
    await repository.voidSale(params.saleId, params.reason);
  }
}
