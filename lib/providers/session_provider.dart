import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter_midi_command/flutter_midi_command.dart';
import '../models/note_model.dart';

class SessionProvider with ChangeNotifier {
  SessionProvider() {
    initMidi();
  }

  // State
  List<NoteModel> _session = [];
  bool _isChordMode = false;
  double _defaultHeight = 1.0;
  int _bpm = 60;
  bool _isPlaying = false;
  final Set<int> _activeKeys = {};

  // Animation
  Timer? _animTimer;
  StreamSubscription? _midiSubscription;

  List<NoteModel> get session => _session;
  bool get isChordMode => _isChordMode;
  bool get isPlaying => _isPlaying;
  double get defaultHeight => _defaultHeight;
  int get bpm => _bpm;
  Set<int> get activeKeys => _activeKeys;


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

  void clearSession() { _session.clear(); stopMusic(); notifyListeners(); }
  void toggleChordMode() { _isChordMode = !_isChordMode; notifyListeners(); }
  void setDefaultHeight(double h) { _defaultHeight = h; notifyListeners(); }
  void setBpm(int bpm) { _bpm = bpm.clamp(30, 240); notifyListeners(); }

  // --- MIDI LOGIC ---

  bool _isBlackKey(int index) {
    int n = (index + 9) % 12;
    return [1, 3, 6, 8, 10].contains(n);
  }

  void initMidi() async {
    MidiCommand midiCommand = MidiCommand();

    // Auto-connect to all available devices
    List<MidiDevice>? devices = await midiCommand.devices;
    if (devices != null) {
      for (var device in devices) {
        await midiCommand.connectToDevice(device);
      }
    }

    // We listen to all incoming data from all connected devices
    _midiSubscription?.cancel();
    _midiSubscription = midiCommand.onMidiDataReceived?.listen((packet) {
      final data = packet.data;
      if (data.length < 3) return;

      int status = data[0] & 0xF0;
      int note = data[1];
      int velocity = data[2];

      int keyIndex = note - 21;
      if (keyIndex < 0 || keyIndex >= 88) return;

      if (status == 0x90 && velocity > 0) {
        // Note On
        _activeKeys.add(keyIndex);
        Future.microtask(() => addNote(keyIndex, _isBlackKey(keyIndex)));
      } else if (status == 0x80 || (status == 0x90 && velocity == 0)) {
        // Note Off
        _activeKeys.remove(keyIndex);
        notifyListeners();
      }
    });
  }

  @override
  void dispose() {
    _midiSubscription?.cancel();
    _animTimer?.cancel();
    super.dispose();
  }

  // --- LOGIQUE JOUER ---
  List<NoteModel> _activeFallingNotes = [];
  List<NoteModel> get activeFallingNotes => _activeFallingNotes;

  // --- NOUVELLE LOGIQUE FLUIDE ---

  void playMusic(double screenHeight) async {
    if (_session.isEmpty || _isPlaying) return;

    _isPlaying = true;
    _activeFallingNotes = []; // Liste des notes en train de tomber
    notifyListeners();

    // La hauteur de la CascadeView est 6/9 de l'écran (flex 6 sur 9)
    double cascadeViewHeight = screenHeight * (6.0 / 9.0);
    // pixelRatio définit la hauteur d'une unité (1.0 height = 1/8 de l'écran)
    double pixelRatio = screenHeight / 8.0;

    // Vitesse : Pixels par milliseconde
    // Formule : (Hauteur d'1 temps en px) * (BPM / 60) / 1000 ms
    // À 60 BPM, la note parcourt son "pixelRatio" en 1000ms.
    double pixelsPerMs = (pixelRatio * (_bpm / 60.0)) / 1000.0;

    bool injectionDone = false;

    _animTimer?.cancel();
    _animTimer = Timer.periodic(const Duration(milliseconds: 16), (timer) {
      // Si l'utilisateur a arrêté manuellement
      if (!_isPlaying) {
        timer.cancel();
        return;
      }

      // Faire descendre toutes les notes actives
      // On utilise une copie de la liste pour éviter les erreurs de modification concurrente
      final notes = List<NoteModel>.from(_activeFallingNotes);
      for (var note in notes) {
        note.currentOffset -= (pixelsPerMs * 16.0);
      }

      // Nettoyage : Supprimer les notes qui sont passées sous le clavier (offset + hauteur < 0)
      _activeFallingNotes.removeWhere((n) => n.currentOffset + (n.height * pixelRatio) < 0);

      // Si l'injection est finie et que tout est tombé, on arrête proprement
      if (injectionDone && _activeFallingNotes.isEmpty) {
        _isPlaying = false;
        timer.cancel();
      }

      notifyListeners();
    });

    // Injecteur de notes
    for (int i = 0; i < _session.length; i++) {
      if (!_isPlaying) break;

      final note = _session[i];

      // On crée une copie pour l'animation
      NoteModel fallingNote = NoteModel(
        keyIndex: note.keyIndex,
        height: note.height,
        color: note.color,
        chordId: note.chordId,
        isSilence: note.isSilence,
        currentOffset: cascadeViewHeight, // Départ au sommet de la vue
      );

      if (!fallingNote.isSilence) {
        _activeFallingNotes.add(fallingNote);
      }

      // Délai avant la prochaine note : (60000 / BPM) * HauteurNote
      // À 60 BPM, une note de hauteur 1.0 dure exactement 1000ms.
      int durationMs = ((60000 / _bpm) * note.height).round();

      // Gestion des ACCORDS : si la suivante a le même ID, on l'injecte simultanément
      bool isNextChordPart = (i + 1 < _session.length) && (_session[i + 1].chordId == note.chordId);

      if (!isNextChordPart) {
        await Future.delayed(Duration(milliseconds: durationMs));
      }
    }

    injectionDone = true;
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