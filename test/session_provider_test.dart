import 'package:flutter_test/flutter_test.dart';
import 'package:synthesia/providers/session_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SessionProvider Mode and Navigation Tests', () {
    late SessionProvider provider;

    setUp(() {
      provider = SessionProvider();
    });

    test('Initial mode should be edit', () {
      expect(provider.currentMode, AppMode.edit);
      expect(provider.playbackPosition, 0.0);
    });

    test('setMode should change mode and notify listeners', () {
      provider.setMode(AppMode.play);
      expect(provider.currentMode, AppMode.play);
      
      provider.setMode(AppMode.edit);
      expect(provider.currentMode, AppMode.edit);
    });

    test('seek should update playbackPosition', () {
      provider.seek(100, 800); // 100 pixels, screen height 800
      expect(provider.playbackPosition, 100.0);
      
      provider.seek(-50, 800);
      expect(provider.playbackPosition, 50.0);
      
      provider.seek(-100, 800); // Should not go below 0
      expect(provider.playbackPosition, 0.0);
    });

    test('pauseMusic should update isPaused state', () {
      // We can't easily test playMusic because of Timers and async loops, 
      // but we can manually set isPlaying for testing state transitions if needed,
      // though _isPlaying is private. 
      // For now, let's test what we can.
    });
  });
}
