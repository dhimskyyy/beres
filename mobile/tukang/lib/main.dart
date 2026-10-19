import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:beres_shared/beres_shared.dart';
import 'features/auth/tukang_login_screen.dart';
import 'features/profile/tukang_onboarding_screen.dart';
import 'features/home/tukang_home_screen.dart';
import 'features/kyc/tukang_kyc_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await SupabaseClientService.initialize(
      supabaseUrl: AppEnvironment.supabaseUrl,
      supabaseAnonKey: AppEnvironment.supabaseAnonKey,
    );
  } catch (_) {}
  runApp(const ProviderScope(child: BeresTukangApp()));
}

final _router = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(path: '/', builder: (context, state) => const TukangLoginScreen()),
    GoRoute(
      path: '/onboarding',
      builder: (context, state) {
        final tukangId = state.extra as String? ?? 'default';
        return TukangOnboardingScreen(tukangId: tukangId);
      },
    ),
    GoRoute(
      path: '/home',
      builder: (context, state) => const TukangHomeScreen(),
    ),
    GoRoute(
      path: '/kyc',
      builder: (context, state) {
        final tukangId = state.extra as String? ?? 'me';
        return TukangKycScreen(tukangId: tukangId);
      },
    ),
  ],
);

class BeresTukangApp extends StatelessWidget {
  const BeresTukangApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Beres Mitra Tukang',
      theme: AppTheme.lightTheme,
      routerConfig: _router,
      debugShowCheckedModeBanner: false,
    );
  }
}
