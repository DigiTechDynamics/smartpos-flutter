import 'package:flutter_test/flutter_test.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:smartpos/presentation/bloc/reports/reports_bloc.dart';
import 'package:smartpos/presentation/bloc/reports/reports_event.dart';
import 'package:smartpos/presentation/bloc/reports/reports_state.dart';
import 'package:smartpos/core/services/analytics_service.dart';
import 'package:smartpos/data/databases/app_database.dart';

class MockAnalyticsService implements AnalyticsService {
  bool getDailySummaryShouldFail = false;
  Map<String, dynamic>? dummySummary;

  @override
  AppDatabase get db => throw UnimplementedError();

  @override
  Future<double> getTotalSales(DateTime start, DateTime end) async => 0.0;

  @override
  Future<Map<String, Map<String, dynamic>>> getSalesByPaymentMethod(
      DateTime start, DateTime end) async => {};

  @override
  Future<List<ProductSales>> getTopProducts(DateTime start, DateTime end,
      {int limit = 10}) async => [];

  @override
  Future<InventoryAnalysis> getInventoryMetrics() async =>
      InventoryAnalysis(totalItems: 0, totalValue: 0.0, lowStockCount: 0);

  @override
  Future<List<Product>> getLowStockItems() async => [];

  @override
  Future<Map<DateTime, double>> getSalesByDay(
      DateTime start, DateTime end) async => {};

  @override
  Future<Map<String, dynamic>> getDailySummary(DateTime date) async {
    if (getDailySummaryShouldFail) throw Exception('Summary failed');
    return dummySummary ?? {
      'total_sales': 120.5,
      'transaction_count': 5,
    };
  }
}

void main() {
  late MockAnalyticsService mockAnalyticsService;

  setUp(() {
    mockAnalyticsService = MockAnalyticsService();
  });

  blocTest<ReportsBloc, ReportsState>(
    'should emit [ReportsLoading, DailyReportLoaded] when LoadDailyReport is successful',
    build: () => ReportsBloc(mockAnalyticsService),
    act: (bloc) => bloc.add(LoadDailyReport(DateTime.now())),
    expect: () => [
      isA<ReportsLoading>(),
      isA<DailyReportLoaded>(),
    ],
    verify: (bloc) {
      final state = bloc.state as DailyReportLoaded;
      expect(state.totalSales, 120.5);
      expect(state.transactionCount, 5);
    },
  );

  blocTest<ReportsBloc, ReportsState>(
    'should emit [ReportsLoading, ReportsError] when LoadDailyReport fails',
    build: () => ReportsBloc(mockAnalyticsService),
    setUp: () => mockAnalyticsService.getDailySummaryShouldFail = true,
    act: (bloc) => bloc.add(LoadDailyReport(DateTime.now())),
    expect: () => [
      isA<ReportsLoading>(),
      isA<ReportsError>(),
    ],
    verify: (bloc) {
      final state = bloc.state as ReportsError;
      expect(state.message, contains('Summary failed'));
    },
  );

  blocTest<ReportsBloc, ReportsState>(
    'should emit [ReportsLoading, ReportsError] when LoadSalesSummary cannot access db',
    build: () => ReportsBloc(mockAnalyticsService),
    act: (bloc) => bloc.add(LoadSalesSummary(DateTime.now(), DateTime.now())),
    expect: () => [
      isA<ReportsLoading>(),
      isA<ReportsError>(),
    ],
  );
}
