import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:synthesia/providers/session_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const MethodChannel channel = MethodChannel('com.synthesia.midi');

  group('SessionProvider Tests', () {
    late SessionProvider provider;

    setUp(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
        return null;
      });
      provider = SessionProvider();
    });

    test('Initial state is correct', () {
      expect(provider.currentMode, AppMode.edit);
      expect(provider.playbackPosition, 0.0);
      expect(provider.isPlaying, isFalse);
      expect(provider.session, isEmpty);
    });

    test('addNote adds note to session and notifies', () {
      provider.addNote(10, false);
      expect(provider.session.length, 1);
      expect(provider.session.first.keyIndex, 10);
    });

    test('addSilence updates session and offsets', () {
      provider.addNote(10, false); // Offset 0, Height 1.0 (default)
      provider.addSilence(1);      // Should push existing note up and add silence at 0
      
      expect(provider.session.length, 2);
      expect(provider.session.any((n) => n.isSilence), isTrue);
      // Logic: new silence at 0.0, old note pushed by 1.0
      expect(provider.session.firstWhere((n) => !n.isSilence).currentOffset, 1.0);
    });

    test('seek respects boundaries (units)', () {
      provider.addNote(10, false); // Max length is 1.0 beat
      
      provider.seek(0.5);
      expect(provider.playbackPosition, 0.5);
      
      provider.seek(2.0); // Should be capped by song length
      expect(provider.playbackPosition, 1.0);
      
      provider.seek(-5.0); // Should be capped at 0
      expect(provider.playbackPosition, 0.0);
    });

    test('clearSession resets everything', () {
      provider.addNote(10, false);
      provider.setBpm(120);
      provider.clearSession();
      
      expect(provider.session, isEmpty);
      expect(provider.playbackPosition, 0.0);
    });

    test('toggleChordMode changes state', () {
      bool initial = provider.isChordMode;
      provider.toggleChordMode();
      expect(provider.isChordMode, !initial);
    });
  });
}
