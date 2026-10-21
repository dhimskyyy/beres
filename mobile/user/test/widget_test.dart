import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:beres_user/main.dart';

void main() {
  testWidgets('BeresUserApp smoke test renders login', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const ProviderScope(child: BeresUserApp()));
    expect(find.text('Masuk sebagai Pelanggan'), findsOneWidget);
    expect(find.text('Daftar Sekarang'), findsOneWidget);
  });
}
