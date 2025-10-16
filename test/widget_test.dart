import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:whoodata/main.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const ProviderScope(child: WhooDataApp()));

    // Pump a few frames to allow initial rendering
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    // Verify that the app bar is present
    expect(find.text('WhooDat(a)?'), findsOneWidget);

    // Verify the FAB is present
    expect(find.text('Fast Add'), findsOneWidget);
  });
}
