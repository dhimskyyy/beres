import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:beres_tukang/main.dart';

void main() {
  testWidgets('BeresTukangApp smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: BeresTukangApp(),
      ),
    );
    expect(find.text('Beres Mitra Tukang v1.4.0'), findsOneWidget);
  });
}
