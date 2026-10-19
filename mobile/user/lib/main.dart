import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:beres_shared/beres_shared.dart';
import 'features/auth/login_screen.dart';
import 'features/home/user_home_screen.dart';
import 'features/jobs/job_create_screen.dart';
import 'features/jobs/job_detail_and_bids_screen.dart';
import 'features/notifications/notifications_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await SupabaseClientService.initialize(
      supabaseUrl: AppEnvironment.supabaseUrl,
      supabaseAnonKey: AppEnvironment.supabaseAnonKey,
    );
  } catch (_) {}
  runApp(const ProviderScope(child: BeresUserApp()));
}

final _router = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(path: '/', builder: (context, state) => const UserLoginScreen()),
    GoRoute(path: '/home', builder: (context, state) => const UserHomeScreen()),
    GoRoute(
      path: '/jobs/create',
      builder: (context, state) {
        final job = state.extra as Job?;
        return JobCreateScreen(existingJob: job);
      },
    ),
    GoRoute(
      path: '/jobs/:id',
      builder: (context, state) {
        final jobId = state.pathParameters['id']!;
        return JobDetailAndBidsScreen(jobId: jobId);
      },
    ),
    GoRoute(
      path: '/notifications',
      builder: (context, state) => const NotificationsScreen(),
    ),
  ],
);

class BeresUserApp extends StatelessWidget {
  const BeresUserApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Beres Customer',
      theme: AppTheme.lightTheme,
      routerConfig: _router,
      debugShowCheckedModeBanner: false,
    );
  }
}
