import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:synthesia/models/style_config.dart';
import 'package:synthesia/providers/style_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('StyleProvider Tests', () {
    test('Initial config is default', () async {
      final provider = StyleProvider();
      await provider.initializationDone;
      expect(provider.currentConfig.name, 'Défaut');
      expect(provider.savedConfigs, isEmpty);
    });

    test('getColorForNote respects DifferentiationMode', () async {
      final provider = StyleProvider();
      await provider.initializationDone;

      // Mode blackWhite (default)
      // Index 0 (A0) is white key -> colorA (lightGreen)
      // Index 1 (A#0) is black key -> colorB (blue)
      provider.currentConfig = StyleConfig(
        name: 'BW',
        mode: DifferentiationMode.blackWhite,
        colorA: Colors.green,
        colorB: Colors.blue,
      );
      expect(provider.getColorForNote(0), Colors.green);
      expect(provider.getColorForNote(1), Colors.blue);

      // Mode none -> always colorA
      provider.currentConfig = StyleConfig(
        name: 'None',
        mode: DifferentiationMode.none,
        colorA: Colors.red,
        colorB: Colors.blue,
      );
      expect(provider.getColorForNote(0), Colors.red);
      expect(provider.getColorForNote(1), Colors.red);

      // Mode split -> splitKey = 39
      provider.currentConfig = StyleConfig(
        name: 'Split',
        mode: DifferentiationMode.split,
        splitKey: 39,
        colorA: Colors.amber,
        colorB: Colors.purple,
      );
      expect(provider.getColorForNote(38), Colors.amber);
      expect(provider.getColorForNote(39), Colors.purple);

      // Mode byTrack
      provider.currentConfig = StyleConfig(
        name: 'Track',
        mode: DifferentiationMode.byTrack,
        trackColors: {0: Colors.cyan, 1: Colors.pink},
      );
      expect(provider.getColorForNote(0, trackId: 0), Colors.cyan);
      expect(provider.getColorForNote(0, trackId: 1), Colors.pink);
      expect(provider.getColorForNote(0, trackId: 99), Colors.lightGreen); // fallback

      // Mode gradient -> returns Colors.white
      provider.currentConfig = StyleConfig(
        name: 'Gradient',
        mode: DifferentiationMode.gradient,
      );
      expect(provider.getColorForNote(0), Colors.white);
    });

    test('Saving, applying and deleting configs', () async {
      final provider = StyleProvider();
      await provider.initializationDone;

      final config1 = StyleConfig(name: 'MyStyle1', colorA: Colors.indigo);
      provider.currentConfig = config1;

      await provider.saveCurrentConfig('MyStyle1');
      expect(provider.savedConfigs.length, 1);
      expect(provider.savedConfigs.first.name, 'MyStyle1');

      final config2 = StyleConfig(name: 'MyStyle2', colorA: Colors.teal);
      provider.currentConfig = config2;
      await provider.saveCurrentConfig('MyStyle2');
      expect(provider.savedConfigs.length, 2);

      await provider.deleteConfig(config1);
      expect(provider.savedConfigs.length, 1);
      expect(provider.savedConfigs.first.name, 'MyStyle2');
    });
  });
}
