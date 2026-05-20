abstract class ReportsEvent {}

class LoadDailyReport extends ReportsEvent {
  final DateTime date;
  LoadDailyReport(this.date);
}

class LoadSalesSummary extends ReportsEvent {
  final DateTime startDate;
  final DateTime endDate;
  LoadSalesSummary(this.startDate, this.endDate);
}
