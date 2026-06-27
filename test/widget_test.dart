import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:atlas/app.dart';

void main() {
  testWidgets('Atlas app smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: AtlasApp()));
    await tester.pump();
    expect(find.byType(ProviderScope), findsOneWidget);
  });
}
