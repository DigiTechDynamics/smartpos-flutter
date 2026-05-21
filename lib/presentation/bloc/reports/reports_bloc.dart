import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:drift/drift.dart';
import '../../../core/services/analytics_service.dart';
import 'reports_event.dart';
import 'reports_state.dart';

class ReportsBloc extends Bloc<ReportsEvent, ReportsState> {
  final AnalyticsService analyticsService;

  ReportsBloc(this.analyticsService) : super(ReportsInitial()) {
    on<LoadDailyReport>(_onLoadDailyReport);
    on<LoadSalesSummary>(_onLoadSalesSummary);
  }

  Future<void> _onLoadDailyReport(LoadDailyReport event, Emitter<ReportsState> emit) async {
    emit(ReportsLoading());
    try {
      final summary = await analyticsService.getDailySummary(event.date);
      emit(DailyReportLoaded(
        totalSales: summary['total_sales'] ?? 0.0,
        transactionCount: summary['transaction_count'] ?? 0,
        topProducts: summary['top_products'] ?? [],
        paymentBreakdown: Map<String, Map<String, dynamic>>.from(summary['payment_breakdown'] ?? {}),
      ));
    } catch (e) {
      emit(ReportsError(e.toString()));
    }
  }

  Future<void> _onLoadSalesSummary(LoadSalesSummary event, Emitter<ReportsState> emit) async {
    emit(ReportsLoading());
    try {
      final totalRevenue = await analyticsService.getTotalSales(event.startDate, event.endDate);
      final revenueByDay = await analyticsService.getSalesByDay(event.startDate, event.endDate);
      
      // Load recent transactions
      final recentSalesQuery = analyticsService.db.select(analyticsService.db.sales)
        ..where((tbl) => tbl.createdAt.isBetweenValues(
          event.startDate.millisecondsSinceEpoch,
          event.endDate.millisecondsSinceEpoch,
        ))
        ..orderBy([(tbl) => OrderingTerm(expression: tbl.createdAt, mode: OrderingMode.desc)])
        ..limit(10);
      final recentSales = await recentSalesQuery.get();
      final recentTransactions = recentSales.map((s) => {
        'id': s.id,
        'saleNumber': s.saleNumber,
        'date': s.createdAt,
        'total': s.total,
        'method': s.paymentMethod,
      }).toList();

      emit(SalesSummaryLoaded(
        totalRevenue: totalRevenue,
        revenueByDay: revenueByDay,
        recentTransactions: recentTransactions,
      ));
    } catch (e) {
      emit(ReportsError(e.toString()));
    }
  }
}
