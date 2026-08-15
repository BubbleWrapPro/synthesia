import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:synthesia/providers/session_provider.dart';
import 'package:synthesia/providers/style_provider.dart';
import 'package:synthesia/widgets/piano_keyboard.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PianoKeyboard Widget Tests', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    testWidgets('PianoKeyboard renders 88 keys', (WidgetTester tester) async {
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => SessionProvider()),
            ChangeNotifierProvider(create: (_) => StyleProvider()),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: SizedBox(height: 200, child: PianoKeyboard()),
            ),
          ),
        ),
      );

      // Total keys should be 88. 
      // Base keys are built inside InkWell. 
      // 52 White keys + 36 Black keys = 88
      expect(find.byType(InkWell), findsNWidgets(88));
    });

    testWidgets('Tapping a key adds a note to the provider', (WidgetTester tester) async {
      final sessionProvider = SessionProvider();
      
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: sessionProvider),
            ChangeNotifierProvider(create: (_) => StyleProvider()),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: SizedBox(height: 200, child: PianoKeyboard()),
            ),
          ),
        ),
      );

      // Tap the first key (A0)
      await tester.tap(find.byType(InkWell).first);
      await tester.pump();

      expect(sessionProvider.session.length, 1);
      expect(sessionProvider.session.first.keyIndex, 0);
    });
  });
}
