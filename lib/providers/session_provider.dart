import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_midi/flutter_midi.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import '../models/note_model.dart';

class SessionProvider with ChangeNotifier {
  final FlutterMidi flutterMidi = FlutterMidi();

  // State
  List<NoteModel> _session = []; // The list of notes
  bool _isChordMode = false;
  double _defaultHeight = 1.0;   // User input height ratio
  int _bpm = 60;
  bool _isPlaying = false;

  // Getters
  List<NoteModel> get session => _session;
  bool get isChordMode => _isChordMode;
  bool get isPlaying => _isPlaying;
  double get defaultHeight => _defaultHeight;

  // Initialize Audio
  Future<void> loadSoundFont() async {
    // Ensure you have a .sf2 file in assets
    final ByteData byte = await rootBundle.load('assets/sounds/Piano.sf2');
    flutterMidi.prepare(sf2: byte);
  }

  // --- ACTIONS ---

  // 1. Interactions du clavier: Add Note
  void addNote(int keyIndex, bool isBlackKey) {
    if (_isPlaying) return; // Disable editing while playing

    double h = _defaultHeight;
    // Logic: In chord mode, use the SAME chord ID as the last note.
    // Otherwise, generate a new ID (using timestamp).
    String cId = (_isChordMode && _session.isNotEmpty)
        ? _session.last.chordId
        : DateTime.now().toIso8601String();

    NoteModel newNote = NoteModel(
      keyIndex: keyIndex,
      height: h,
      color: isBlackKey ? Colors.blue : Colors.lightGreen,
      chordId: cId,
    );

    // Logic: "Les tuiles existantes remontent"
    // If NOT in chord mode, shift previous notes up by this note's height.
    if (!_isChordMode) {
      for (var note in _session) {
        note.currentOffset += h;
      }
    }

    _session.add(newNote);
    playKeySound(keyIndex); // Instant feedback
    notifyListeners();
  }

  // 2. Silence
  void addSilence(int length) {
    for(int i=0; i<length; i++) {
      // Create invisible tile of height 1
      String cId = DateTime.now().toIso8601String() + "_$i";

      // Shift existing
      for (var note in _session) {
        note.currentOffset += 1.0;
      }

      _session.add(NoteModel(
        keyIndex: -1, // No key
        height: 1.0,
        color: Colors.transparent,
        chordId: cId,
        isSilence: true,
      ));
    }
    notifyListeners();
  }

  // 3. Supprimer un silence
  void removeSilence(int length) {
    if (_session.isEmpty || !_session.last.isSilence) {
      // Should show error in UI, but we return here for safety
      return;
    }
    // Remove last X silences
    for(int i=0; i<length; i++) {
      if (_session.isNotEmpty && _session.last.isSilence) {
        _session.removeLast();
        // Shift others back down? README doesn't specify, but implies undoing the "remontent".
        for (var note in _session) {
          note.currentOffset -= 1.0;
        }
      }
    }
    notifyListeners();
  }

  // 4. Effacer
  void clearSession() {
    _session.clear();
    notifyListeners();
  }

  // 5. Mode Accord Toggle
  void toggleChordMode() {
    _isChordMode = !_isChordMode;
    notifyListeners();
  }

  // 6. Set Height
  void setDefaultHeight(double h) {
    _defaultHeight = h;
    notifyListeners();
  }

  void setBpm(int bpm) {
    _bpm = bpm.clamp(30, 240);
    notifyListeners();
  }

  // 7. Jouer la musique
  Future<void> playMusic(double screenHeight) async {
    if (_session.isEmpty) return;

    _isPlaying = true;
    notifyListeners();

    // "Fait disparaitre toutes les tuiles" - We reset offsets to top of screen
    double startY = screenHeight; // Start above visual area

    // We need to group by Chord ID to play them together
    // Or simple iteration. README says: "Lis les tuiles existantes dans l'ordre"

    // Simplification for the cascade animation:
    // We will simulate the "falling" by iterating notes and waiting.

    for (var note in _session) {
      if (!_isPlaying) break; // Stop if cancelled

      // Visual: Note falls.
      // Audio: Play when it "hits" keyboard.

      // Calculate duration based on BPM
      // BPM is beats per minute.
      int msDuration = (60000 / _bpm * note.height).round();

      if (!note.isSilence) {
        playKeySound(note.keyIndex);
      }

      // Wait for the duration of this note (or chord) before playing next
      // *Note: Real chord logic would require grouping, here we play sequentially strictly*
      // If it's a chord, the README says "tuiles d'un même accord... glissent".
      // Since we store strict order, we just wait.

      // If next note has SAME chordId, we don't wait (play simultaneously)
      int nextIndex = _session.indexOf(note) + 1;
      bool isNextChordPart = nextIndex < _session.length &&
          _session[nextIndex].chordId == note.chordId;

      if (!isNextChordPart) {
        await Future.delayed(Duration(milliseconds: msDuration));
      }
    }

    _isPlaying = false;
    notifyListeners();
  }

  void playKeySound(int keyIndex) {
    if (keyIndex >= 0) {
      flutterMidi.playMidiNote(midi: keyIndex + 21); // MIDI 21 is A0 (first piano key)
    }
  }

  // 8. Sauvegarder & Importer (Basic File I/O)
  Future<void> saveToFile() async {
    String? path = await FilePicker.platform.saveFile(
      dialogTitle: 'Sauvegarder la session',
      fileName: 'ma_musique.json',
    );
    if (path != null) {
      File file = File(path);
      String jsonStr = jsonEncode(_session.map((e) => e.toJson()).toList());
      await file.writeAsString(jsonStr);
    }
  }

  Future<void> importFile() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles();
    if (result != null) {
      File file = File(result.files.single.path!);
      String content = await file.readAsString();
      List<dynamic> jsonList = jsonDecode(content);
      _session = jsonList.map((e) => NoteModel.fromJson(e)).toList();
      notifyListeners();
    }
  }
}