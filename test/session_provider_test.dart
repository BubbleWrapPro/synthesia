import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:synthesia/providers/session_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('com.synthesia.midi'),
      (MethodCall methodCall) async {
        return null;
      },
    );
  });

  group('SessionProvider Comprehensive Tests', () {
    late SessionProvider provider;

    setUp(() {
      provider = SessionProvider();
    });

    test('Initial state values', () {
      expect(provider.currentMode, AppMode.edit);
      expect(provider.playbackPosition, 0.0);
      expect(provider.isPlaying, false);
      expect(provider.isPaused, false);
      expect(provider.isChordMode, false);
      expect(provider.bpm, 60);
      expect(provider.defaultHeight, 1.0);
      expect(provider.autoSilence, false);
      expect(provider.showAllTracksInEdit, false);
      expect(provider.currentTrackId, 0);
      expect(provider.activeTracks, containsAll([0, 1, 2, 3, 4, 5, 6, 7, 8, 9]));
      expect(provider.session, isEmpty);
      expect(provider.currentFileName, isEmpty);
    });

    test('Mode switching', () {
      provider.setMode(AppMode.play);
      expect(provider.currentMode, AppMode.play);

      provider.setMode(AppMode.edit);
      expect(provider.currentMode, AppMode.edit);
      expect(provider.editScrollOffset, 0.0);
    });

    test('BPM and Default Height setters', () {
      provider.setBpm(120);
      expect(provider.bpm, 120);

      // Clamping test
      provider.setBpm(10);
      expect(provider.bpm, 30);
      provider.setBpm(300);
      expect(provider.bpm, 240);

      provider.setDefaultHeight(2.5);
      expect(provider.defaultHeight, 2.5);
    });

    test('Chord Mode toggle and Auto Silence / Track View flags', () {
      expect(provider.isChordMode, false);
      provider.toggleChordMode();
      expect(provider.isChordMode, true);

      expect(provider.autoSilence, false);
      provider.setAutoSilence(true);
      expect(provider.autoSilence, true);

      expect(provider.showAllTracksInEdit, false);
      provider.setShowAllTracksInEdit(true);
      expect(provider.showAllTracksInEdit, true);
    });

    test('Track Management', () {
      provider.setCurrentTrackId(3);
      expect(provider.currentTrackId, 3);

      provider.toggleTrack(3);
      expect(provider.activeTracks.contains(3), false);

      provider.toggleTrack(3);
      expect(provider.activeTracks.contains(3), true);
    });

    test('Note operations: addNote, updateNote, deleteNote, clearSession', () async {
      // Add note manually (screenHeight = 800)
      provider.addNote(39, false, 800.0);
      expect(provider.session.length, 1);
      final note1 = provider.session.first;
      expect(note1.keyIndex, 39);
      expect(note1.height, 1.0);

      // Add second note in normal mode (should push first note up)
      provider.addNote(41, false, 800.0);
      expect(provider.session.length, 2);
      final note2 = provider.session.last;
      expect(note2.keyIndex, 41);

      // Update note
      provider.updateNote(note2, 3.0, Colors.red);
      expect(provider.session.last.height, 3.0);
      expect(provider.session.last.overrideColor, Colors.red);

      // Delete note
      provider.deleteNote(note1);
      expect(provider.session.contains(note1), false);

      // Clear session
      provider.clearSession();
      await Future.delayed(const Duration(milliseconds: 50));
      expect(provider.session, isEmpty);
      expect(provider.currentFileName, isEmpty);
    });

    test('Silence operations: addSilence and removeSilence', () async {
      provider.addSilence(2, 800.0);
      expect(provider.session.length, 2);
      expect(provider.session.every((n) => n.isSilence), true);

      provider.removeSilence(1, 800.0);
      expect(provider.session.length, 1);

      provider.clearSession();
      await Future.delayed(const Duration(milliseconds: 50));
    });

    test('Seek and handleScroll', () {
      provider.seek(150, 800.0);
      expect(provider.playbackPosition, 150.0);

      provider.seek(-200, 800.0);
      expect(provider.playbackPosition, 0.0); // clamped at 0

      // In edit mode, handleScroll changes editScrollOffset
      provider.setMode(AppMode.edit);
      provider.handleScroll(50.0, 800.0);
      expect(provider.editScrollOffset, 50.0);

      provider.handleScroll(-100.0, 800.0);
      expect(provider.editScrollOffset, 0.0); // clamped at 0
    });

    test('Panic resets state', () {
      provider.addNote(39, false, 800.0);
      provider.panic();
      expect(provider.activeKeys, isEmpty);
    });
  });
}
