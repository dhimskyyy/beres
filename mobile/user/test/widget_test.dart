import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:beres_user/main.dart';

void main() {
  testWidgets('BeresUserApp smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: BeresUserApp(),
      ),
    );
    expect(find.text('Beres Pelanggan v1.4.0'), findsOneWidget);
  });
}
