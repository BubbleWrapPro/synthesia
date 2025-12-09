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

  // NOUVELLES VARIABLES D'ANIMATION
  // Au lieu de bouger tout le monde, on bouge seulement un groupe de notes actif
  final List<NoteModel> _fallingNotes = []; // Les notes qui tombent actuellement
  final double _fallingY = 0.0; // Leur position verticale

  List<NoteModel> get session => _session;
  bool get isChordMode => _isChordMode;
  bool get isPlaying => _isPlaying;
  double get defaultHeight => _defaultHeight;
  int get bpm => _bpm;
  double get animationScrollY => _animationScrollY;

  // Getters pour la vue
  List<NoteModel> get fallingNotes => _fallingNotes;
  double get fallingY => _fallingY;


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
  List<NoteModel> _activeFallingNotes = [];
  List<NoteModel> get activeFallingNotes => _activeFallingNotes;

  // --- NOUVELLE LOGIQUE FLUIDE ---

  void playMusic(double screenHeight) async {
    if (_session.isEmpty || _isPlaying) return;

    _isPlaying = true;
    _activeFallingNotes = []; // Liste des notes en train de tomber
    notifyListeners();

    // 1. Démarrer le moteur physique (le Timer qui fait tout descendre)
    // Hauteur de la vue cascade (5/9 de l'écran)
    double cascadeHeight = screenHeight * (5.0 / 9.0);
    double pixelRatio = screenHeight / 8.0;

    // Vitesse : Pixels par milliseconde
    // Formule : (Hauteur d'1 temps en px) * (BPM / 60) / 1000 ms
    double pixelsPerMs = (pixelRatio * (_bpm / 60.0)) / 1000.0;

    // Le Timer tourne à 60fps (toutes les 16ms)
    _animTimer?.cancel();
    _animTimer = Timer.periodic(const Duration(milliseconds: 16), (timer) {
      if (_activeFallingNotes.isEmpty && !_isPlaying) {
        timer.cancel();
        return;
      }

      // Faire descendre toutes les notes actives
      // On modifie une propriété temporaire 'currentOffset' qu'on détourne pour servir de position Y
      // ATTENTION : Pour l'affichage, currentOffset servira ici de "Bottom Position"
      for (var note in _activeFallingNotes) {
        note.currentOffset -= (pixelsPerMs * 16.0); // Elle descend
      }

      // Nettoyage : Supprimer les notes qui sont passées sous le clavier
      _activeFallingNotes.removeWhere((n) => n.currentOffset + (n.height * pixelRatio) < 0);

      notifyListeners();
    });

    // 2. L'Injecteur de notes (Le chef d'orchestre)
    // On parcourt la session dans l'ordre d'enregistrement (0 = première note jouée)
    // Contrairement à la vue statique, ici on veut jouer 0, puis 1, puis 2...

    for (var note in _session) {
      if (!_isPlaying) break;

      // Créer une COPIE de la note pour l'animation (pour ne pas casser la sauvegarde)
      NoteModel fallingNote = NoteModel(
        keyIndex: note.keyIndex,
        height: note.height,
        color: note.color,
        chordId: note.chordId,
        isSilence: note.isSilence,
        // Position de départ : Tout en haut de la cascade
        currentOffset: cascadeHeight,
      );

      // Ajouter à la liste visible
      if (!fallingNote.isSilence) {
        _activeFallingNotes.add(fallingNote);
      }

      // CALCUL DU DELAI AVANT LA PROCHAINE NOTE
      // C'est ici que la magie opère. On attend la DUREE de la note actuelle.
      // Durée en ms = (60000 / BPM) * HauteurNote
      int durationMs = ((60000 / _bpm) * note.height).round();

      // Gestion des ACCORDS : Si la prochaine note a le même ID, on n'attend pas !
      int currentIndex = _session.indexOf(note);
      int nextIndex = currentIndex + 1;
      bool isNextChordPart = false;
      if (nextIndex < _session.length) {
        if (_session[nextIndex].chordId == note.chordId) {
          isNextChordPart = true;
        }
      }

      if (!isNextChordPart) {
        await Future.delayed(Duration(milliseconds: durationMs));
      }
    }

    // Fin de la chanson, mais on laisse les dernières notes finir de tomber
    await Future.delayed(Duration(seconds: 5)); // Marge de sécurité
    stopMusic();
  }

  void stopMusic() {
    _isPlaying = false;
    _activeFallingNotes.clear();
    _animTimer?.cancel();
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

    if (_isPlaying) return;

    double h = note.height;
    bool wasChord = false;

    if (!_isChordMode) {
      for (var otherNotes in _session) {
        if (otherNotes.chordId == note.chordId) {
          wasChord = true;
          break;
        }
      }
      if (!wasChord) {
        for (var noteToBelittle in _session) {
          if (noteToBelittle.currentOffset > note.currentOffset) {
            noteToBelittle.currentOffset -= h;
          }
        }
      }
    }




    notifyListeners();

  }
}