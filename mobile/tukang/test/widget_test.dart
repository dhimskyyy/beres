import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:beres_shared/beres_shared.dart';
import 'package:beres_tukang/main.dart';

void main() {
  testWidgets('BeresTukangApp smoke test renders splash and navigates to login', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const ProviderScope(child: BeresTukangApp()));
    expect(find.byType(BeresSplash), findsOneWidget);

    // Animasi splash (2900ms) + delay tahanan akhir (2000ms)
    await tester.pump(const Duration(milliseconds: 3000));
    await tester.pump(const Duration(milliseconds: 2500));
    await tester.pumpAndSettle();

    expect(find.text('Selamat Datang Mitra'), findsOneWidget);
    expect(find.text('Silahkan Masuk ke Akun Mitra Tukang Anda'), findsOneWidget);
    expect(find.text('Daftar Disini'), findsOneWidget);
  });
}
