import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_selector/file_selector.dart';
import '../models/note_model.dart';

class SessionProvider with ChangeNotifier {
  // Plus de variable Audio !

  // State
  List<NoteModel> _session = [];
  bool _isChordMode = false;
  double _defaultHeight = 1.0;
  int _bpm = 60;
  bool _isPlaying = false;

  // Animation: Ce décalage va augmenter pour faire descendre les tuiles
  double _animationScrollY = 0.0;

  List<NoteModel> get session => _session;
  bool get isChordMode => _isChordMode;
  bool get isPlaying => _isPlaying;
  double get defaultHeight => _defaultHeight;
  double get animationScrollY => _animationScrollY;

  // --- ACTIONS ---

  // 1. Interactions du clavier: Add Note
  void addNote(int keyIndex, bool isBlackKey) {
    if (_isPlaying) return;

    double h = _defaultHeight;
    String cId = (_isChordMode && _session.isNotEmpty)
        ? _session.last.chordId
        : DateTime.now().toIso8601String();

    NoteModel newNote = NoteModel(
      keyIndex: keyIndex,
      height: h,
      color: isBlackKey ? Colors.blue : Colors.lightGreen,
      chordId: cId,
    );

    if (!_isChordMode) {
      for (var note in _session) {
        note.currentOffset += h;
      }
    }

    _session.add(newNote);
    // playKeySound(keyIndex); // SUPPRIMÉ
    notifyListeners();
  }

  // 2. Silence
  // (Gardez addSilence, removeSilence, clearSession, toggleChordMode, setDefaultHeight, setBpm)
  void clearSession() { _session.clear(); _animationScrollY = 0; notifyListeners(); }
  void toggleChordMode() { _isChordMode = !_isChordMode; notifyListeners(); }
  void setDefaultHeight(double h) { _defaultHeight = h; notifyListeners(); }
  void setBpm(int bpm) { _bpm = bpm.clamp(30, 240); notifyListeners(); }

  void addSilence(int length) {
    for(int i=0; i<length; i++) {
      String cId = DateTime.now().toIso8601String() + "_$i";
      for (var note in _session) { note.currentOffset += 1.0; }
      _session.add(NoteModel(keyIndex: -1, height: 1.0, color: Colors.transparent, chordId: cId, isSilence: true));
    }
    notifyListeners();
  }

  // 3. Supprimer un silence
  void removeSilence(int length) {
    if (_session.isEmpty || !_session.last.isSilence) return;
    for(int i=0; i<length; i++) {
      if (_session.isNotEmpty && _session.last.isSilence) {
        _session.removeLast();
        for (var note in _session) { note.currentOffset -= 1.0; }
      }
    }
    notifyListeners();
  }


  // Update logic for Edit Dialog
  void updateNote(NoteModel note, double newHeight, Color newColor) {
    int index = _session.indexOf(note);
    if (index == -1) return;

    // Create new note with updated values
    NoteModel updated = NoteModel(
      keyIndex: note.keyIndex,
      height: newHeight,
      color: newColor,
      chordId: note.chordId,
      isSilence: note.isSilence,
      currentOffset: note.currentOffset, // Keep position
    );

    _session[index] = updated;

    // If height changed, we might need to shift notes above it?
    // The README doesn't specify "Update shifts others", but "Cascade" usually implies stacking.
    // For simplicity of the requested features, we update in place.
    // Ideally: Difference = newHeight - oldHeight. Shift all notes > index by Difference.
    double diff = newHeight - note.height;
    if (diff != 0) {
      for(int i = 0; i < index; i++) { // Notes "above" are usually earlier in list if added sequentially?
        // Wait, the list is ordered by creation time.
        // In this app, "Adding" pushes OLD notes up.
        // So notes [0...index-1] are visually ABOVE this note.
        _session[i].currentOffset += diff;
      }
    }

    notifyListeners();
  }

  void deleteNote(NoteModel note) {
    int index = _session.indexOf(note);
    if (index == -1) return;

    // Logic: If we delete a note, should the ones above fall down?
    // Yes, to close the gap.
    double closedGap = note.height;

    _session.removeAt(index);

    // Shift notes that were "pushed up" by this note back down.
    // These are notes created BEFORE this one (indices 0 to index-1).
    for(int i = 0; i < index; i++) {
      _session[i].currentOffset -= closedGap;
    }

    notifyListeners();
  }

  // 7. Jouer la musique
  Timer? _animTimer;

  void playMusic(double screenHeight) {
    if (_session.isEmpty || _isPlaying) return;

    _isPlaying = true;
    _animationScrollY = 0.0; // On commence du haut (ou bas selon logique)

    // Logique: Les notes sont stockées avec un 'currentOffset' qui représente leur position Y empilée.
    // Pour les faire "tomber", on doit déplacer tout le monde vers le bas.
    // Cependant, dans votre logique de construction, '0' est le bas (clavier).
    // Quand on joue, les notes doivent partir du haut et descendre.

    // Simplification visuelle : On va dire que _animationScrollY se soustrait à la position.
    // On veut faire descendre les tuiles, donc on va DECREMENTER leur position apparente ?
    // Non, les tuiles sont construites en empilement (Bottom-Up).
    // Pour les jouer, on veut que cet empilement descende sous le clavier.
    // Donc on va réduire leur "Bottom position" virtuelle.

    // Calcul de la vitesse en pixels/ms
    // BPM = Battements par minute.
    // Hauteur 1 = 1 temps.
    // Hauteur en pixels = (screenHeight / 8).
    // Donc Vitesse (pixels/sec) = (screenHeight / 8) * (BPM / 60).

    double pixelsPerSecond = (screenHeight / 8.0) * (_bpm / 60.0);
    double pixelsPerTick = pixelsPerSecond / 60.0; // Pour 60 FPS environ

    _animTimer?.cancel();
    _animTimer = Timer.periodic(Duration(milliseconds: 16), (timer) {
      _animationScrollY += pixelsPerTick;

      // Condition d'arrêt : La dernière note (la plus haute) a disparu
      // La hauteur totale de la pile est l'offset de la première note (la plus haute dans la pile)
      double totalHeight = _session.isEmpty ? 0 : (_session.first.currentOffset + _session.first.height) * (screenHeight / 8.0);

      if (_animationScrollY > totalHeight + screenHeight) {
        stopMusic();
      }

      notifyListeners();
    });
  }

  void stopMusic() {
    _isPlaying = false;
    _animTimer?.cancel();
    _animationScrollY = 0.0; // Reset
    notifyListeners();
  }


  // --- SAUVEGARDE & IMPORT (Gardez votre code corrigé ici) ---
  // Copiez ici le code saveToFile/importFile de l'étape précédente avec file_selector et le fix JSON .value
  Future<void> saveToFile() async {
    const XTypeGroup typeGroup = XTypeGroup(label: 'JSON files', extensions: <String>['json']);
    final FileSaveLocation? result = await getSaveLocation(suggestedName: 'ma_musique.json', acceptedTypeGroups: [typeGroup]);
    if (result != null) {
      final File file = File(result.path);
      String jsonStr = jsonEncode(_session.map((e) => e.toJson()).toList());
      await file.writeAsString(jsonStr);
    }
  }

  Future<void> importFile() async {
    const XTypeGroup typeGroup = XTypeGroup(label: 'JSON files', extensions: <String>['json']);
    final XFile? file = await openFile(acceptedTypeGroups: <XTypeGroup>[typeGroup]);
    if (file != null) {
      String content = await file.readAsString();
      try {
        List<dynamic> jsonList = jsonDecode(content);
        _session = jsonList.map((e) => NoteModel.fromJson(e)).toList();
        notifyListeners();
      } catch (e) { print(e); }
    }
  }
}