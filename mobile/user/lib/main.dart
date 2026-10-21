import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:beres_shared/beres_shared.dart';

import 'features/auth/login_screen.dart';
import 'features/auth/register_screen.dart';
import 'features/home/user_home_screen.dart';
import 'features/jobs/job_create_screen.dart';
import 'features/jobs/job_detail_and_bids_screen.dart';
import 'features/notifications/notifications_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await SupabaseClientService.initialize(
      supabaseUrl: AppEnvironment.supabaseUrl,
      supabaseAnonKey: AppEnvironment.supabaseAnonKey,
    );
  } catch (_) {
    // Allow running in test/offline preview mode
  }

  runApp(const ProviderScope(child: BeresUserApp()));
}

final _router = GoRouter(
  initialLocation: '/login',
  routes: [
    GoRoute(
      path: '/login',
      builder: (context, state) => const UserLoginScreen(),
    ),
    GoRoute(
      path: '/register',
      builder: (context, state) => const UserRegisterScreen(),
    ),
    GoRoute(path: '/home', builder: (context, state) => const UserHomeScreen()),
    GoRoute(
      path: '/jobs/create',
      builder: (context, state) => const JobCreateScreen(),
    ),
    GoRoute(
      path: '/jobs/:jobId',
      builder: (context, state) {
        final jobId = state.pathParameters['jobId'] ?? '';
        return JobDetailAndBidsScreen(jobId: jobId);
      },
    ),
    GoRoute(
      path: '/notifications',
      builder: (context, state) => const UserNotificationsScreen(),
    ),
  ],
);

class BeresUserApp extends StatelessWidget {
  const BeresUserApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Beres — Panggil Tukang Tanpa Ribet',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.userTheme,
      routerConfig: _router,
    );
  }
}
