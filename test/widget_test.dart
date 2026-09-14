import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:synthesia/main.dart';
import 'package:synthesia/providers/session_provider.dart';
import 'package:synthesia/providers/style_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Synthesia app smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => SessionProvider()),
          ChangeNotifierProvider(create: (_) => StyleProvider()),
        ],
        child: const MyApp(),
      ),
    );

    expect(find.byType(HomeScreen), findsOneWidget);
  });
}
