import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../presentation/pages/auth/login_page.dart';
import '../../presentation/pages/auth/password_reset_page.dart';
import '../../presentation/pages/main_screen.dart';
import '../../presentation/pages/sales/sale_page.dart';
import '../../presentation/pages/sales/cart_page.dart';
import '../../presentation/pages/sales/payment_page.dart';
import '../../presentation/pages/sales/receipt_page.dart';
import '../../presentation/pages/inventory/inventory_page.dart';
import '../../presentation/pages/reports/reports_page.dart';
import '../../presentation/pages/reports/daily_report_page.dart';
import '../../presentation/pages/reports/sales_summary_page.dart';
import '../../presentation/pages/settings/settings_page.dart';
import '../../presentation/pages/settings/store_settings_page.dart';
import '../../presentation/pages/settings/printer_settings_page.dart';
import '../../presentation/pages/settings/app_settings_page.dart';
import '../../presentation/pages/settings/user_management_page.dart';

final GlobalKey<NavigatorState> _rootNavigatorKey = GlobalKey<NavigatorState>();
final GlobalKey<NavigatorState> _shellNavigatorKey = GlobalKey<NavigatorState>();

final GoRouter appRouter = GoRouter(
  navigatorKey: _rootNavigatorKey,
  initialLocation: '/login',
  routes: [
    GoRoute(
      path: '/login',
      builder: (context, state) => const LoginPage(),
    ),
    GoRoute(
      path: '/password_reset',
      builder: (context, state) => const PasswordResetPage(),
    ),
    ShellRoute(
      navigatorKey: _shellNavigatorKey,
      builder: (context, state, child) {
        return MainScreen(child: child);
      },
      routes: [
        GoRoute(
          path: '/sale',
          builder: (context, state) => const SalePage(),
          routes: [
            GoRoute(
              path: 'cart',
              parentNavigatorKey: _rootNavigatorKey,
              builder: (context, state) => const CartPage(),
            ),
            GoRoute(
              path: 'payment',
              parentNavigatorKey: _rootNavigatorKey,
              builder: (context, state) => const PaymentPage(),
            ),
            GoRoute(
              path: 'receipt',
              parentNavigatorKey: _rootNavigatorKey,
              builder: (context, state) {
                final extra = state.extra as Map<String, dynamic>?;
                return ReceiptPage(
                  saleId: extra?['saleId'] ?? '',
                  change: extra?['change'] ?? 0.0,
                );
              },
            ),
          ],
        ),
        GoRoute(
          path: '/inventory',
          builder: (context, state) => const InventoryPage(),
        ),
        GoRoute(
          path: '/reports',
          builder: (context, state) => const ReportsPage(),
          routes: [
            GoRoute(
              path: 'daily',
              parentNavigatorKey: _rootNavigatorKey,
              builder: (context, state) => const DailyReportPage(),
            ),
            GoRoute(
              path: 'summary',
              parentNavigatorKey: _rootNavigatorKey,
              builder: (context, state) => const SalesSummaryPage(),
            ),
          ],
        ),
        GoRoute(
          path: '/settings',
          builder: (context, state) => const SettingsPage(),
          routes: [
            GoRoute(
              path: 'store',
              parentNavigatorKey: _rootNavigatorKey,
              builder: (context, state) => const StoreSettingsPage(),
            ),
            GoRoute(
              path: 'printer',
              parentNavigatorKey: _rootNavigatorKey,
              builder: (context, state) => const PrinterSettingsPage(),
            ),
            GoRoute(
              path: 'app',
              parentNavigatorKey: _rootNavigatorKey,
              builder: (context, state) => const AppSettingsPage(),
            ),
            GoRoute(
              path: 'users',
              parentNavigatorKey: _rootNavigatorKey,
              builder: (context, state) => const UserManagementPage(),
            ),
          ],
        ),
      ],
    ),
  ],
);
