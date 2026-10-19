import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:beres_shared/beres_shared.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    const ProviderScope(
      child: BeresTukangApp(),
    ),
  );
}

final _router = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) => const TukangHomeScreen(),
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

class TukangHomeScreen extends ConsumerWidget {
  const TukangHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Beres Mitra'),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: AppColors.tukangBadgeBg,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Icon(
                  Icons.construction_outlined,
                  size: 40,
                  color: AppColors.safetyOrange,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Beres Mitra Tukang v1.4.0',
                style: AppTypography.headingLarge,
              ),
              const SizedBox(height: 8),
              Text(
                'Platform Kerja Transparan & Bebas Potongan Komisi',
                style: AppTypography.bodyMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              ElevatedButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.work_outline),
                label: const Text('Buka Bursa Kerja'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.safetyOrange,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
