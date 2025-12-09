import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'providers/session_provider.dart';
import 'widgets/piano_keyboard.dart';
import 'widgets/cascade_view.dart';
import 'widgets/control_panel.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // Force Landscape
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => SessionProvider()..loadSoundFont()),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Synthesia Flutter',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Ratios from README:
    // Top 1/9 (Controls), Middle 5/9 (Cascade), Bottom 3/9 (Keyboard)
    return Scaffold(
      body: Column(
        children: [
          Expanded(flex: 1, child: ControlPanel()),
          Expanded(flex: 5, child: CascadeView()),
          Expanded(flex: 3, child: PianoKeyboard()),
        ],
      ),
    );
  }
}