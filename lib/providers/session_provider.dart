import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_selector/file_selector.dart';
import '../models/note_model.dart';

class SessionProvider with ChangeNotifier {
  // State
  List<NoteModel> _session = [];
  bool _isChordMode = false;
  double _defaultHeight = 1.0;
  int _bpm = 60;
  bool _isPlaying = false;

  // Animation
  double _animationScrollY = 0.0;
  Timer? _animTimer;

  List<NoteModel> get session => _session;
  bool get isChordMode => _isChordMode;
  bool get isPlaying => _isPlaying;
  double get defaultHeight => _defaultHeight;
  double get animationScrollY => _animationScrollY;

  // --- ACTIONS ---

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

    // Logique: Les tuiles existantes "remontent" pour laisser place à la nouvelle en bas
    if (!_isChordMode) {
      for (var note in _session) {
        note.currentOffset += h;
      }
    }

    _session.add(newNote);
    notifyListeners();
  }

  void addSilence(int length) {
    for(int i=0; i<length; i++) {
      String cId = "${DateTime.now().toIso8601String()}_$i";
      // On pousse tout vers le haut de 1 unité
      for (var note in _session) { note.currentOffset += 1.0; }
      _session.add(NoteModel(keyIndex: -1, height: 1.0, color: Colors.transparent, chordId: cId, isSilence: true));
    }
    notifyListeners();
  }

  void removeSilence(int length) {
    if (_session.isEmpty || !_session.last.isSilence) return;
    for(int i=0; i<length; i++) {
      if (_session.isNotEmpty && _session.last.isSilence) {
        _session.removeLast();
        // On redescend tout le monde
        for (var note in _session) { note.currentOffset -= 1.0; }
      }
    }
    notifyListeners();
  }

  void clearSession() { _session.clear(); _animationScrollY = 0; notifyListeners(); }
  void toggleChordMode() { _isChordMode = !_isChordMode; notifyListeners(); }
  void setDefaultHeight(double h) { _defaultHeight = h; notifyListeners(); }
  void setBpm(int bpm) { _bpm = bpm.clamp(30, 240); notifyListeners(); }

  // --- LOGIQUE JOUER ---

  void playMusic(double screenHeight) {
    if (_session.isEmpty || _isPlaying) return;

    _isPlaying = true;

    // On positionne le scroll tout en haut (négatif) pour que les notes
    // les plus hautes (les premières de la liste) soient hors écran au début.
    // La zone visible fait 5/9 de l'écran.
    double cascadeViewHeight = screenHeight * (5.0 / 9.0);

    // ASTUCE : On commence avec un décalage négatif égal à la hauteur de la vue + la hauteur totale des notes.
    // Comme ça, les notes descendent jusqu'au clavier.
    _animationScrollY = -cascadeViewHeight;

    // Vitesse de chute
    double pixelsPerSecond = (screenHeight / 8.0) * (_bpm / 60.0);
    double pixelsPerTick = pixelsPerSecond / 60.0;

    _animTimer?.cancel();
    _animTimer = Timer.periodic(const Duration(milliseconds: 16), (timer) {
      _animationScrollY += pixelsPerTick;

      // Stop quand la dernière note (la plus haute dans la pile, donc index 0) a passé le bas.
      // Dans notre logique "empilement", la note index 0 est la plus HAUTE visuellement (offset le plus grand).
      // Attendons que son offset redescende à 0.

      double highestNoteOffset = _session.first.currentOffset;
      double pixelOffsetOfHighest = highestNoteOffset * (screenHeight / 8.0);

      // Si le scroll a dépassé la position de la note la plus haute + marge
      if (_animationScrollY > pixelOffsetOfHighest + cascadeViewHeight) {
        stopMusic();
      }

      notifyListeners();
    });
  }

  void stopMusic() {
    _isPlaying = false;
    _animTimer?.cancel();
    _animationScrollY = 0.0;
    notifyListeners();
  }

  // --- SAUVEGARDE & IMPORT ---

  Future<void> saveToFile() async {
    const XTypeGroup typeGroup = XTypeGroup(label: 'JSON files', extensions: <String>['json']);
    final FileSaveLocation? result = await getSaveLocation(suggestedName: 'ma_musique.json', acceptedTypeGroups: [typeGroup]);
    if (result != null) {
      final File file = File(result.path);
      // On sauvegarde juste les données brutes (note, hauteur, couleur)
      // L'offset sera recalculé à l'import
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

        // 1. Charger les notes brutes
        List<NoteModel> rawNotes = jsonList.map((e) => NoteModel.fromJson(e)).toList();

        // 2. RECALCULER LES POSITIONS (Offsets)
        // La logique d'ajout standard est : "La nouvelle note est en bas (0), les anciennes montent".
        // Donc dans la liste sauvegardée [Note1, Note2, Note3] :
        // Note3 (la dernière ajoutée) doit être à 0.
        // Note2 doit être au-dessus de Note3.
        // Note1 doit être au-dessus de Note2.

        double accumulatedOffset = 0.0;

        // On parcourt la liste à l'envers (de la plus récente à la plus ancienne)
        for (int i = rawNotes.length - 1; i >= 0; i--) {
          NoteModel currentNote = rawNotes[i];

          // Appliquer l'offset actuel
          currentNote.currentOffset = accumulatedOffset;

          // Vérifier si la note précédente (i-1) fait partie du même accord
          bool isChordWithNext = false; // "Next" ici veut dire i-1 car on recule
          if (i > 0) {
            if (rawNotes[i-1].chordId == currentNote.chordId) {
              isChordWithNext = true;
            }
          }

          // Si ce n'est pas un accord lié à la note du dessus, on empile
          // (Si c'est un accord, l'accumulatedOffset n'augmente pas pour la prochaine itération)
          if (!isChordWithNext) {
            accumulatedOffset += currentNote.height;
          }
        }

        _session = rawNotes;
        notifyListeners();

      } catch (e) {
        debugPrint("Erreur import: $e");
      }
    }
  }

  // Helpers pour l'édition (si besoin)
  void updateNote(NoteModel note, double newH, Color newC) {
    int idx = _session.indexOf(note);
    if(idx == -1) return;
    // Mise à jour simple (pour l'instant sans recalcul complexe des voisins)
    _session[idx] = NoteModel(
        keyIndex: note.keyIndex, height: newH, color: newC,
        chordId: note.chordId, isSilence: note.isSilence,
        currentOffset: note.currentOffset
    );
    notifyListeners();
  }

  void deleteNote(NoteModel note) {
    // Suppression simple
    _session.remove(note);
    notifyListeners();
  }
}