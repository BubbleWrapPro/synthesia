import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:synthesia/providers/style_provider.dart';
import 'package:synthesia/models/style_config.dart';

void main() {
  group('StyleProvider Tests', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('Initial config should be default', () async {
      final provider = StyleProvider();
      // Wait for _loadFromPrefs to complete (it's called in constructor)
      await Future.delayed(Duration.zero);
      
      expect(provider.currentConfig.name, 'Défaut');
      expect(provider.currentConfig.mode, DifferentiationMode.blackWhite);
    });

    test('getColorForNote respects black/white mode', () async {
      final provider = StyleProvider();
      await Future.delayed(Duration.zero);
      
      // Index 9 is C1 (White), Index 10 is C#1 (Black) in our 0-87 system 
      // (Simplified check based on _isBlackKey logic in provider)
      // _isBlackKey(0) -> (9%12)=9 -> false (A0)
      // _isBlackKey(1) -> (10%12)=10 -> true (A#0)
      
      provider.currentConfig = provider.currentConfig.copyWith(
        mode: DifferentiationMode.blackWhite,
        colorA: Colors.green,
        colorB: Colors.blue,
      );

      expect(provider.getColorForNote(0), Colors.green); // White key
      expect(provider.getColorForNote(1), Colors.blue);  // Black key
    });

    test('saveCurrentConfig and deleteConfig', () async {
      final provider = StyleProvider();
      await Future.delayed(Duration.zero);

      await provider.saveCurrentConfig('Custom Style');
      expect(provider.savedConfigs.any((c) => c.name == 'Custom Style'), isTrue);

      final configToDelete = provider.savedConfigs.firstWhere((c) => c.name == 'Custom Style');
      await provider.deleteConfig(configToDelete);
      expect(provider.savedConfigs.any((c) => c.name == 'Custom Style'), isFalse);
    });
  });
}
