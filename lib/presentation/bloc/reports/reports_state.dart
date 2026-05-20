abstract class ReportsState {}

class ReportsInitial extends ReportsState {}
class ReportsLoading extends ReportsState {}

class DailyReportLoaded extends ReportsState {
  final double totalSales;
  final int transactionCount;
  final List<dynamic> topProducts;
  final Map<String, Map<String, dynamic>> paymentBreakdown;
  
  DailyReportLoaded({
    required this.totalSales,
    required this.transactionCount,
    required this.topProducts,
    required this.paymentBreakdown,
  });
}

class SalesSummaryLoaded extends ReportsState {
  final double totalRevenue;
  final Map<DateTime, double> revenueByDay;
  final List<dynamic> recentTransactions;
  
  SalesSummaryLoaded({
    required this.totalRevenue,
    required this.revenueByDay,
    required this.recentTransactions,
  });
}

class ReportsError extends ReportsState {
  final String message;
  ReportsError(this.message);
}
