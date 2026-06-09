import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'providers/session_provider.dart';
import 'providers/style_provider.dart';
import 'widgets/piano_keyboard.dart';
import 'widgets/cascade_view.dart';
import 'widgets/control_panel.dart';
import 'pages/customization_page.dart';

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
        ChangeNotifierProvider(create: (context) => SessionProvider()),
        ChangeNotifierProvider(create: (context) => StyleProvider()),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Le Consumer ici est vital : il force le rebuild de MaterialApp
    // quand currentFileName change dans le provider.
    return Consumer<SessionProvider>(
      builder: (context, provider, child) {
        final String windowTitle = provider.currentFileName.isEmpty
            ? 'synthesia'
            : 'synthesia - ${provider.currentFileName}';

        return MaterialApp(
          title: windowTitle,
          theme: ThemeData(primarySwatch: Colors.blue),
          // Title widget force la mise à jour au niveau de l'OS (Desktop)
          home: Title(
            title: windowTitle,
            color: Colors.blue,
            child: const HomeScreen(),
          ),
        );
      },
    );
  }
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<SessionProvider>(context); // Listen: true par défaut, OK ici
    final screenHeight = MediaQuery.of(context).size.height;

    return CallbackShortcuts(
      bindings: <ShortcutActivator, VoidCallback>{

        // --- 1. LECTURE (Espace) ---
        const SingleActivator(LogicalKeyboardKey.keyP): () {
          if (provider.isPlaying) {
            provider.stopMusic();
          } else {
            provider.playMusic(screenHeight);
          }
        },

        // --- 2. FICHIER ---
        // Ctrl + S : Sauvegarder
        const SingleActivator(LogicalKeyboardKey.keyS, control: true): () {
          provider.saveToFile();
        },
        // Ctrl + O : Importer
        const SingleActivator(LogicalKeyboardKey.keyO, control: true): () {
          provider.importFile();
        },
        // Ctrl + Delete : Tout Effacer
        const SingleActivator(LogicalKeyboardKey.delete, control: true): () {
          provider.clearSession();
        },

        // --- 3. ÉDITION ---
        // A : Mode Accord
        const SingleActivator(LogicalKeyboardKey.keyA): () {
          provider.toggleChordMode();
        },

        // S : Ajouter Silence (Ajout rapide de 1 unité pour être fluide)
        const SingleActivator(LogicalKeyboardKey.space): () {
          provider.addSilence(1);
        },

        // Backspace : Supprimer Silence (Suppression rapide de 1 unité)
        const SingleActivator(LogicalKeyboardKey.backspace): () {
          provider.removeSilence(1);
        },

        // --- 4. APPARENCE ---
        // T : Ouvrir le Style
        const SingleActivator(LogicalKeyboardKey.keyT): () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const CustomizationPage()),
          );
        },
      },
      child: Focus(
        autofocus: true, // Important pour attraper les événements clavier
        child: Scaffold(
          body: Column(
            children: [
              Expanded(flex: 1, child: ControlPanel()),
              Expanded(flex: 6, child: CascadeView()),
              Expanded(flex: 2, child: PianoKeyboard()),
            ],
          ),
        ),
      ),
    );
  }
}