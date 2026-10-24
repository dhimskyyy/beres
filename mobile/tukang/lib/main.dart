import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:beres_shared/beres_shared.dart';

import 'features/auth/tukang_login_screen.dart';
import 'features/auth/tukang_register_screen.dart';
import 'features/home/tukang_home_screen.dart';
import 'features/profile/tukang_onboarding_screen.dart';
import 'features/kyc/tukang_kyc_screen.dart';
import 'features/job_portal/job_portal_screen.dart';
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

  runApp(const ProviderScope(child: BeresTukangApp()));
}

final _router = GoRouter(
  initialLocation: '/splash',
  routes: [
    GoRoute(
      path: '/splash',
      builder: (context, state) => BeresSplash(
        tagline: 'Aplikasi Mitra Tukang',
        onFinished: () {
          try {
            final user = SupabaseClientService.instance.currentUser;
            if (user != null) {
              context.go('/home');
            } else {
              context.go('/login');
            }
          } catch (_) {
            context.go('/login');
          }
        },
      ),
    ),
    GoRoute(
      path: '/login',
      builder: (context, state) => const TukangLoginScreen(),
    ),
    GoRoute(
      path: '/register',
      builder: (context, state) => const TukangRegisterScreen(),
    ),
    GoRoute(
      path: '/home',
      builder: (context, state) => const TukangHomeScreen(),
    ),
    GoRoute(
      path: '/onboarding',
      builder: (context, state) {
        final userId = SupabaseClientService.instance.currentUser?.id ?? 'me';
        return TukangOnboardingScreen(tukangId: userId);
      },
    ),
    GoRoute(
      path: '/kyc',
      builder: (context, state) {
        final userId = SupabaseClientService.instance.currentUser?.id ?? 'me';
        return TukangKycScreen(tukangId: userId);
      },
    ),
    GoRoute(
      path: '/job-portal',
      builder: (context, state) => const JobPortalScreen(),
    ),
    GoRoute(
      path: '/notifications',
      builder: (context, state) => const TukangNotificationsScreen(),
    ),
  ],
);

class BeresTukangApp extends StatelessWidget {
  const BeresTukangApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Beres Mitra — Aplikasi Tukang',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.tukangTheme,
      routerConfig: _router,
    );
  }
}
