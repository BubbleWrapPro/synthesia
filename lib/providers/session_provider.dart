import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_selector/file_selector.dart';
import '../models/note_model.dart';
import 'package:flutter/services.dart';

class SessionProvider with ChangeNotifier {

  // --- CONFIGURATION MIDI ---
  static const MethodChannel _midiChannel = MethodChannel('com.synthesia.midi');

  SessionProvider() {
    _initMidiListener();
  }

  void _initMidiListener() {
    _midiChannel.setMethodCallHandler((call) async {
      if (call.method == "onNoteOn") {
        _handleMidiNoteOn(call.arguments as int);
      } else if (call.method == "onNoteOff") {
        _handleMidiNoteOff(call.arguments as int);
      }
    });
  }

  // --- VARIABLES D'ÉTAT ---
  List<NoteModel> _session = [];
  bool _isChordMode = false;
  double _defaultHeight = 1.0;
  int _bpm = 120;
  bool _isPlaying = false;

  // Option "Silence Automatique"
  // false = Le défilement s'arrête si aucune note n'est pressée (Mode "Pas à pas")
  // true  = Le défilement continue et crée du vide (Mode "Enregistrement continu")
  bool _autoSilence = false;

  // Variables pour l'animation de lecture (Playback)
  double _animationScrollY = 0.0;
  Timer? _animTimer;
  final List<NoteModel> _fallingNotes = [];
  final double _fallingY = 0.0;
  List<NoteModel> _activeFallingNotes = []; // Pour le playback

  // Variables pour l'enregistrement MIDI temps réel (Recording)
  Timer? _recordingTimer;
  bool _isRecording = false;
  // On stocke les notes actives par leur keyIndex pour pouvoir les retrouver et les allonger
  final Map<int, NoteModel> _activeRecordingNotes = {};

  // Variables pour la détection d'accords en temps réel (Fix 1)
  DateTime? _lastMidiNoteTime;
  String _currentMidiChordId = "";

  // --- GETTERS ---
  List<NoteModel> get session => _session;
  bool get isChordMode => _isChordMode;
  bool get isPlaying => _isPlaying;
  double get defaultHeight => _defaultHeight;
  int get bpm => _bpm;
  double get animationScrollY => _animationScrollY;
  List<NoteModel> get fallingNotes => _fallingNotes;
  double get fallingY => _fallingY;
  List<NoteModel> get activeFallingNotes => _activeFallingNotes;
  bool get autoSilence => _autoSilence;


  // --- LOGIQUE MIDI TEMPS RÉEL (RECORDING) ---

  void setAutoSilence(bool value) {
    _autoSilence = value;
    notifyListeners();
  }

  void _handleMidiNoteOn(int midiNote) {
    // Si ce n'est pas déjà fait, on lance la boucle d'animation d'enregistrement
    if (!_isRecording) startRecordingLoop();

    // 1. Conversion MIDI (21 = A0) vers Index (0..87)
    int keyIndex = midiNote - 21;
    if (keyIndex < 0 || keyIndex > 87) return;

    // 2. Détermination de la couleur
    int semitone = midiNote % 12;
    bool isBlack = [1, 3, 6, 8, 10].contains(semitone); // C#, D#, F#, G#, A#


    // --- LOGIQUE INTELLIGENTE D'ACCORD (FIX 1) ---
    DateTime now = DateTime.now();
    // Si la dernière note a été jouée il y a moins de 70ms, on considère que c'est le même accord
    if (_lastMidiNoteTime != null && now.difference(_lastMidiNoteTime!).inMilliseconds < 120) {
      // On garde le même ID que la note précédente
    } else {
      // Sinon, on crée un nouvel ID d'accord
      _currentMidiChordId = now.toIso8601String();
    }
    _lastMidiNoteTime = now;


    // 3. Création de la nouvelle note
    // Elle commence avec une hauteur minime, elle grandira dans la boucle
    NoteModel newNote = NoteModel(
      keyIndex: keyIndex,
      height: 0.01,
      color: isBlack ? Colors.blue : Colors.lightGreen,
      chordId: DateTime.now().toIso8601String(),
      currentOffset: 0.0, // Elle apparaît tout en bas (le présent)
      fromMidi: true, // [NEW] Marqueur
    );

    _session.add(newNote);

    // 4. On l'ajoute aux notes "actives" (enfoncées)
    _activeRecordingNotes[keyIndex] = newNote;

    notifyListeners();
  }

  void _handleMidiNoteOff(int midiNote) {
    int keyIndex = midiNote - 21;
    // On retire la note des actives : elle arrêtera de grandir et commencera à monter
    _activeRecordingNotes.remove(keyIndex);
  }

  void startRecordingLoop() {
    if (_isRecording) return;
    _isRecording = true;

    debugPrint("--- DÉBUT BOUCLE ENREGISTREMENT ---");

    // Boucle à ~60 FPS (16ms)
    _recordingTimer = Timer.periodic(const Duration(milliseconds: 16), (timer) {
      // 1. Debugging : Voir l'état quand ça devrait s'arrêter
      if (_activeRecordingNotes.isNotEmpty) {
        // Décommenter la ligne suivante si vous voulez voir quelles touches sont bloquées dans la console
        debugPrint("Touches actives: ${_activeRecordingNotes.keys.toList()}");
      }

      // 2. Condition d'arrêt (Pause)
      // Si aucune note n'est maintenue ET que l'option AutoSilence est décochée
      if (_activeRecordingNotes.isEmpty && !_autoSilence) {
        // On ne fait rien (PAUSE), le papier arrête de défiler
        return;
      }

      // Vitesse de défilement (pixels par frame)
      double msPerBeat = 60000.0 / _bpm;
      double speed = 16.0 / msPerBeat;

      // On parcourt toute la session pour mettre à jour les positions/tailles
      for (int i = 0; i < _session.length; i++) {
        NoteModel note = _session[i];

        // Cas 1 : La note est encore enfoncée (Active)
        // Elle doit rester en bas (offset 0) mais grandir
        if (_activeRecordingNotes.containsValue(note)) {

          // Note : Comme 'height' est final dans votre modèle, on doit remplacer l'objet
          // Si vous avez retiré 'final' devant height dans NoteModel, vous pouvez faire note.height += speed;
          NoteModel grownNote = NoteModel(
            keyIndex: note.keyIndex,
            height: note.height + speed, // Elle grandit
            color: note.color,
            chordId: note.chordId,
            isSilence: note.isSilence,
            currentOffset: 0.0, // Reste ancrée en bas
            fromMidi: note.fromMidi,
          );

          _session[i] = grownNote;
          // IMPORTANT : Mettre à jour la référence dans la map des actives aussi
          _activeRecordingNotes[note.keyIndex] = grownNote;

        }
        // Cas 2 : La note est relâchée (Inactive)
        // Elle garde sa taille mais monte vers le haut (le passé)
        else {
          note.currentOffset += speed;
        }
      }
      notifyListeners();
    });
  }

  void stopRecordingLoop() {
    _isRecording = false;
    _recordingTimer?.cancel();
    _activeRecordingNotes.clear();
    notifyListeners();
  }


  // --- ACTIONS MANUELLES (INTERFACE) ---

  void addNote(int keyIndex, bool isBlackKey) {
    if (_isPlaying) return;

    // Ajout manuel "one shot" (ancienne logique, toujours utile pour l'UI)
    double h = _defaultHeight;
    String cId = (_isChordMode && _session.isNotEmpty)
        ? _session.last.chordId
        : DateTime.now().toIso8601String();

    NoteModel newNote = NoteModel(
      keyIndex: keyIndex,
      height: h,
      color: isBlackKey ? Colors.blue : Colors.lightGreen,
      chordId: cId,
      fromMidi: false,
    );

    // En mode manuel sans accord, on pousse les autres vers le haut
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
        for (var note in _session) { note.currentOffset -= 1.0; }
      }
    }
    notifyListeners();
  }

  void clearSession() {
    _session.clear();
    _animationScrollY = 0;
    stopRecordingLoop(); // Sécurité
    notifyListeners();
  }

  void toggleChordMode() { _isChordMode = !_isChordMode; notifyListeners(); }
  void setDefaultHeight(double h) { _defaultHeight = h; notifyListeners(); }
  void setBpm(int bpm) { _bpm = bpm.clamp(30, 240); notifyListeners(); }


  // --- LOGIQUE JOUER (PLAYBACK) ---

  void playMusic(double screenHeight) async {
    if (_session.isEmpty || _isPlaying) return;

    // Si on enregistrait, on arrête
    if (_isRecording) stopRecordingLoop();

    _isPlaying = true;
    _activeFallingNotes = [];
    notifyListeners();

    // 1. Moteur physique (Timer de descente)
    double cascadeHeight = screenHeight * (5.0 / 9.0);
    double pixelRatio = screenHeight / 8.0;
    double pixelsPerMs = (pixelRatio * (_bpm / 60.0)) / 1000.0;

    _animTimer?.cancel();
    _animTimer = Timer.periodic(const Duration(milliseconds: 16), (timer) {
      if (_activeFallingNotes.isEmpty && !_isPlaying) {
        timer.cancel();
        return;
      }

      for (var note in _activeFallingNotes) {
        note.currentOffset -= (pixelsPerMs * 16.0); // Elle descend
      }

      // Nettoyage : Supprimer les notes passées sous le clavier
      _activeFallingNotes.removeWhere((n) => n.currentOffset + (n.height * pixelRatio) < 0);

      notifyListeners();
    });

    // 2. Injecteur de notes (Sequencer)
    for (int i = 0; i < _session.length; i++) {
      if (!_isPlaying) break;

      NoteModel note = _session[i];

      // 1. Lancer la note visuelle
      NoteModel fallingNote = NoteModel(
        keyIndex: note.keyIndex,
        height: note.height,
        color: note.color,
        chordId: note.chordId,
        isSilence: note.isSilence,
        currentOffset: cascadeHeight,
        fromMidi: note.fromMidi,
      );

      if (!fallingNote.isSilence) {
        _activeFallingNotes.add(fallingNote);
      }

      // 2. Calculer le délai avant la PROCHAINE note
      int waitMs = 0;

      if (i + 1 < _session.length) {
        NoteModel nextNote = _session[i + 1];

        // Le "Top" (début chronologique) de la note = offset + height
        double currentTop = note.currentOffset + note.height;
        double nextTop = nextNote.currentOffset + nextNote.height;

        // La différence est le temps qui sépare les deux attaques
        double diffHeight = currentTop - nextTop;

        // Convertir cette distance en millisecondes
        // Durée d'1 unité de hauteur = (60000 / BPM)
        waitMs = ((60000 / _bpm) * diffHeight).round();

        if (waitMs < 0) waitMs = 0; // Sécurité si ordre incorrect
      } else {
        // Dernière note : on attend sa propre durée pour finir proprement
        waitMs = ((60000 / _bpm) * note.height).round();
      }

      if (waitMs > 0) {
        await Future.delayed(Duration(milliseconds: waitMs));
      }
    }

    await Future.delayed(const Duration(seconds: 3));
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
        List<NoteModel> rawNotes = jsonList.map((e) => NoteModel.fromJson(e)).toList();

        // Recalcul des positions pour l'affichage statique "empilé"
        double accumulatedOffset = 0.0;
        for (int i = rawNotes.length - 1; i >= 0; i--) {
          NoteModel currentNote = rawNotes[i];
          currentNote.currentOffset = accumulatedOffset;

          bool isChordWithNext = false;
          if (i > 0) {
            if (rawNotes[i-1].chordId == currentNote.chordId) {
              isChordWithNext = true;
            }
          }
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

  // Helpers pour l'édition
  void updateNote(NoteModel note, double newH, Color newC) {
    int idx = _session.indexOf(note);
    if(idx == -1) return;
    _session[idx] = NoteModel(
        keyIndex: note.keyIndex, height: newH, color: newC,
        chordId: note.chordId, isSilence: note.isSilence,
        currentOffset: note.currentOffset,
        fromMidi: note.fromMidi
    );
    notifyListeners();
  }

  void deleteNote(NoteModel note) {
    _session.remove(note);
    if (_isPlaying) return;

    double h = note.height;
    bool wasChord = false;

    if (!_isChordMode) {
      // Vérification basique si c'était un accord
      for (var otherNotes in _session) {
        if (otherNotes.chordId == note.chordId) {
          wasChord = true;
          break;
        }
      }
      // Si ce n'était pas un accord, on redescend les notes du dessus pour combler le vide
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


  void deleteLastNote(BuildContext context){

    if (_session.isEmpty) {

      // Toast pour avertir l'utilisateur qu'il n'y a pas de notes à supprimer
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Aucune note à effacer.")));

      return;
    }
    deleteNote(_session[_session.length - 1]);

    if (_isPlaying) return;

    notifyListeners();
  }



}