import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:firebase_core/firebase_core.dart';
import 'core/services/service_locator.dart';
import 'presentation/themes/app_theme.dart';
import 'presentation/bloc/auth/auth_bloc.dart';
import 'presentation/bloc/sale/sale_bloc.dart';
import 'presentation/bloc/reports/reports_bloc.dart';
import 'presentation/pages/auth/login_page.dart';
import 'core/routes/app_router.dart';

import 'core/services/background_sync_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp();
  } catch (e) {
    debugPrint('Firebase initialization skipped or failed (config not loaded yet): $e');
  }
  await initServiceLocator();
  
  try {
    final syncService = sl<BackgroundSyncService>();
    await syncService.initialize();
    syncService.registerPeriodicSync();
  } catch (e) {
    debugPrint('Failed to initialize BackgroundSyncService: $e');
  }

  runApp(const SmartPOSApp());
}

class SmartPOSApp extends StatelessWidget {
  const SmartPOSApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider<AuthBloc>(
          create: (context) => sl<AuthBloc>(),
        ),
        BlocProvider<SaleBloc>(
          create: (context) => sl<SaleBloc>(),
        ),
        BlocProvider<ReportsBloc>(
          create: (context) => sl<ReportsBloc>(),
        ),
      ],
      child: MaterialApp.router(
        title: 'SmartPOS',
        theme: AppTheme.lightTheme,
        routerConfig: appRouter,
      ),
    );
  }
}
