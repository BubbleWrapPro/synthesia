import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_selector/file_selector.dart';
import '../models/note_model.dart';
import 'package:flutter/services.dart';
import 'package:dart_midi_pro/dart_midi_pro.dart';
import 'package:flutter_midi/flutter_midi.dart';

enum AppMode { edit, play }

class SessionProvider with ChangeNotifier {

  // --- CONFIGURATION MIDI ---
  static const MethodChannel _midiChannel = MethodChannel('com.synthesia.midi');
  final FlutterMidi _flutterMidi = FlutterMidi();

  SessionProvider() {
    _initMidiListener();
    _loadSoundFont();
  }

  Future<void> _loadSoundFont() async {
    if (Platform.isWindows) {
      debugPrint("Windows: Using system MIDI synth (SF2 ignored for now)");
      return;
    }
    try {
      ByteData byteData = await rootBundle.load("assets/sounds/Piano_1.sf2");
      _flutterMidi.prepare(sf2: byteData, name: "Piano_1.sf2");
      debugPrint("SoundFont loaded: Piano_1.sf2");
    } catch (e) {
      debugPrint("Error loading SoundFont: $e");
    }
  }

  // --- SOUND HELPERS ---
  void _playNote(int midiNote, {int velocity = 100}) {
    if (Platform.isWindows) {
      _midiChannel.invokeMethod('playMidiNote', {
        'note': midiNote,
        'velocity': velocity,
      });
      // Décommentez pour voir le volume des notes
      // debugPrint("Velocity of $midiNote : $velocity");
    } else {
      _flutterMidi.playMidiNote(midi: midiNote);
    }
  }

  void _stopNote(int midiNote) {
    if (Platform.isWindows) {
      _midiChannel.invokeMethod('stopMidiNote', midiNote);
    } else {
      _flutterMidi.stopMidiNote(midi: midiNote);
    }
  }

  void _initMidiListener() {
    _midiChannel.setMethodCallHandler((call) async {
      if (call.method == "onNoteOn") {
        int note;
        int velocity = 100;

        if (call.arguments is int) {
          note = call.arguments as int;
        } else {
          final Map<dynamic, dynamic> args = call.arguments as Map<dynamic, dynamic>;
          note = args['note'] as int;
          velocity = args['velocity'] as int;
        }

        _activeKeys.add(note - 21); // Logic for PianoKeyboard feedback
        _handleMidiNoteOn(note, velocity: velocity);
      } else if (call.method == "onNoteOff") {
        int note = call.arguments as int;
        _activeKeys.remove(note - 21); // Logic for PianoKeyboard feedback
        _handleMidiNoteOff(note);
      } else if (call.method == "onControlChange") {
        final Map<dynamic, dynamic> args = call.arguments as Map<dynamic, dynamic>;
        int controller = args['controller'] as int;
        int value = args['value'] as int;

        if (controller == 64) { // Sustain Pedal
          _handleSustain(value >= 64);
        }
      }
    });
  }

  void initMidi() {
    // This can be used to re-sync or re-init if needed
    _initMidiListener();
    notifyListeners();
  }

  // --- VARIABLES D'ÉTAT ---
  List<NoteModel> _session = [];
  String _currentFileName = ""; // [NEW] Stocke le nom du fichier chargé
  bool _isChordMode = false;
  double _defaultHeight = 1.0;
  int _bpm = 60;
  bool _isPlaying = false;
  bool _isPaused = false;
  AppMode _currentMode = AppMode.edit;
  double _playbackPosition = 0.0; // En pixels
  final Set<int> _activeKeys = {};
  bool _injectionDone = false; // [NEW] Flag to track sequencer completion

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
  bool _isSustainDown = false;
  // On stocke les notes actives par leur keyIndex pour pouvoir les retrouver et les allonger
  final Map<int, NoteModel> _activeRecordingNotes = {};
  // Notes qui continuent de sonner grâce à la pédale de sustain
  final Map<int, NoteModel> _sustainedNotes = {};
  // Volume "en direct" pour calculer la décroissance du sustain
  final Map<int, double> _liveDecayVelocities = {};

  // Variables pour la détection d'accords en temps réel (Fix 1)
  DateTime? _lastMidiNoteTime;
  String _currentMidiChordId = "";

  // --- GETTERS ---
  List<NoteModel> get session => _session;
  String get currentFileName => _currentFileName;
  bool get isChordMode => _isChordMode;
  bool get isPlaying => _isPlaying;
  bool get isPaused => _isPaused;
  AppMode get currentMode => _currentMode;
  double get playbackPosition => _playbackPosition;
  Set<int> get activeKeys => _activeKeys; // [NEW] Expose active keys for PianoKeyboard
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

  void setMode(AppMode mode) {
    _currentMode = mode;
    if (mode == AppMode.edit) {
      stopMusic();
    }
    notifyListeners();
  }

  void pauseMusic() {
    if (!_isPlaying || _isPaused) return;
    _isPaused = true;
    // Arrêter tous les sons en cours
    for (var note in _activeFallingNotes) {
      if (!note.isSilence) {
        _stopNote(note.keyIndex + 21);
      }
    }
    _animTimer?.cancel();
    notifyListeners();
  }

  void resumeMusic(double screenHeight) {
    if (!_isPlaying || !_isPaused) return;
    _isPaused = false;
    playMusic(screenHeight); // playMusic will handle resuming from _playbackPosition
  }

  void restartMusic(double screenHeight) {
    stopMusic();
    _playbackPosition = 0.0;
    playMusic(screenHeight);
  }

  void seek(double amount, double screenHeight) {
    // TODO : fix because it deletes all notes
    // Si on cherche, on doit arrêter les sons en cours pour éviter les notes fantômes
    for (var note in _activeFallingNotes) {
      if (!note.isSilence) _stopNote(note.keyIndex + 21);
    }
    _activeFallingNotes.clear();

    _playbackPosition += amount;
    if (_playbackPosition < 0) _playbackPosition = 0;
    
    // Calcul de l'offset max pour borner le seek en avant
    double maxOffset = 0;
    for (var n in _session) {
      if (n.currentOffset + n.height > maxOffset) maxOffset = n.currentOffset + n.height;
    }
    double pixelRatio = screenHeight / 8.0;
    double maxPos = maxOffset * pixelRatio;
    if (_playbackPosition > maxPos) _playbackPosition = maxPos;

    // Si on est en train de jouer, on relance pour recalculer les positions
    if (_isPlaying && !_isPaused) {
      playMusic(screenHeight);
    } else {
      notifyListeners();
    }
  }

  void _handleMidiNoteOn(int midiNote, {int velocity = 100}) {
    // Jouer le son
    _playNote(midiNote, velocity: velocity);

    // Si ce n'est pas déjà fait, on lance la boucle d'animation d'enregistrement
    if (!_isRecording) startRecordingLoop();

    // 1. Conversion MIDI (21 = A0) vers Index (0..87)
    int keyIndex = midiNote - 21;
    if (keyIndex < 0 || keyIndex > 87) return;

    // Si la note était en "sustain", on la stoppe proprement avant de la rejouer
    if (_sustainedNotes.containsKey(keyIndex)) {
      _stopNote(midiNote);
      _sustainedNotes.remove(keyIndex);
    }

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
      playingHeight: 0.01,
      color: isBlack ? Colors.blue : Colors.lightGreen,
      chordId: _currentMidiChordId, // Utilise l'ID intelligent (Fix 1)
      currentOffset: 0.0, // Elle apparaît tout en bas (le présent)
      fromMidi: true, // [NEW] Marqueur
      velocity: velocity,
    );

    _session.add(newNote);

    // 4. On l'ajoute aux notes "actives" (enfoncées)
    _activeRecordingNotes[keyIndex] = newNote;
    _liveDecayVelocities[keyIndex] = velocity.toDouble();

    notifyListeners();
  }

  void _handleMidiNoteOff(int midiNote) {
    int keyIndex = midiNote - 21;

    if (_isSustainDown) {
      // La note continue de sonner grâce au sustain
      if (_activeRecordingNotes.containsKey(keyIndex)) {
        _sustainedNotes[keyIndex] = _activeRecordingNotes[keyIndex]!;
        _activeRecordingNotes.remove(keyIndex);
      }
    } else {
      _stopNote(midiNote);
      _activeRecordingNotes.remove(keyIndex);
      _sustainedNotes.remove(keyIndex);
      _liveDecayVelocities.remove(keyIndex);
    }
  }

  void _handleSustain(bool down) {
    _isSustainDown = down;
    if (!down) {
      // On relâche la pédale : toutes les notes en sustain s'arrêtent
      _sustainedNotes.forEach((keyIndex, note) {
        _stopNote(keyIndex + 21);
        _liveDecayVelocities.remove(keyIndex);
      });
      _sustainedNotes.clear();
    }
    notifyListeners();
  }

  void startRecordingLoop() {
    if (_isRecording) return;
    _isRecording = true;

    debugPrint("--- DÉBUT BOUCLE ENREGISTREMENT ---");

    // Boucle à ~60 FPS (16ms)
    _recordingTimer = Timer.periodic(const Duration(milliseconds: 16), (timer) {
      // 1. Condition d'arrêt (Pause)
      // Si aucune note n'est maintenue ET que l'option AutoSilence est décochée
      if (_activeRecordingNotes.isEmpty && _sustainedNotes.isEmpty && !_autoSilence) {
        return;
      }

      // Vitesse de défilement (pixels par frame)
      double msPerBeat = 60000.0 / _bpm;
      double speed = 16.0 / msPerBeat;

      // On parcourt toute la session pour mettre à jour les positions/tailles
      for (int i = 0; i < _session.length; i++) {
        NoteModel note = _session[i];

        // Cas 1 : La note est encore enfoncée (Active)
        // Elle doit rester en bas (offset 0) mais grandir (visuel + son)
        if (_activeRecordingNotes.containsValue(note)) {
          note.height += speed;
          note.playingHeight += speed;
          note.currentOffset = 0.0;
        }
        // Cas 2 : La note est en sustain (Relâchée mais pédale enfoncée)
        // Elle monte car physiquement relâchée, mais sa durée sonore (playingHeight) augmente
        // Et sa vélocité diminue progressivement
        else if (_sustainedNotes.containsKey(note.keyIndex) && _sustainedNotes[note.keyIndex] == note) {
          note.playingHeight += speed;
          note.currentOffset += speed;

          // Décroissance du volume (Sustain Decay)
          // On réduit d'environ 1% par frame (arbitraire, ajustable)
          double currentV = _liveDecayVelocities[note.keyIndex] ?? 0;
          if (currentV > 0) {
            double decay = (currentV * 0.01).clamp(0.5, 5.0);
            double newV = (currentV - decay).clamp(0, 127);
            _liveDecayVelocities[note.keyIndex] = newV;

            if (newV <= 0) {
              _stopNote(note.keyIndex + 21);
              _sustainedNotes.remove(note.keyIndex);
              _liveDecayVelocities.remove(note.keyIndex);
            }
          }
        }
        // Cas 3 : La note est relâchée (Inactive)
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
    _sustainedNotes.clear();
    _liveDecayVelocities.clear();
    _isSustainDown = false;
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
      currentOffset: 0.0,
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
    _currentFileName = "";
    _animationScrollY = 0;
    _updateSystemTitle(); // [NEW] Force OS title update
    stopRecordingLoop(); // Sécurité
    notifyListeners();
  }

  void _updateSystemTitle() {
    final String windowTitle = _currentFileName.isEmpty
        ? 'synthesia'
        : 'synthesia - $_currentFileName';

    // 1. Flutter side update (Task switcher, Alt-Tab)
    SystemChrome.setApplicationSwitcherDescription(
      ApplicationSwitcherDescription(
        label: windowTitle,
        primaryColor: Colors.blue.toARGB32(),
      ),
    );

    // 2. Native Windows update (Actual title bar)
    // We use the existing MIDI channel to send a custom command to our C++ code
    try {
      _midiChannel.invokeMethod('setWindowTitle', windowTitle);
    } catch (e) {
      debugPrint("Native title update failed: $e");
    }
  }

  void toggleChordMode() { _isChordMode = !_isChordMode; notifyListeners(); }
  void setDefaultHeight(double h) { _defaultHeight = h; notifyListeners(); }
  void setBpm(int bpm) { _bpm = bpm.clamp(30, 240); notifyListeners(); }


  // --- LOGIQUE JOUER (PLAYBACK) ---

  void playMusic(double screenHeight) {
    if (_session.isEmpty) return;

    // Si on change de mode sans passer par stopMusic()
    if (_currentMode != AppMode.play) {
      _currentMode = AppMode.play;
    }

    // Si on enregistrait, on arrête
    if (_isRecording) stopRecordingLoop();

    // Reset l'injection si on redémarre ou si on cherche
    _animTimer?.cancel();
    
    _isPlaying = true;
    _isPaused = false;
    _activeFallingNotes = [];
    notifyListeners();

    // 1. Moteur physique (Timer de descente)
    double cascadeHeight = screenHeight * (5.0 / 9.0);
    double pixelRatio = screenHeight / 8.0;
    double pixelsPerMs = (pixelRatio * (_bpm / 60.0)) / 1000.0;

    // --- CORRECTION DIRECTION ---
    // Dans Synthesia, les notes avec de grands offsets sont au DEBUT du morceau (plus haut)
    // Les notes avec offset 0 sont à la FIN (présent lors de l'enregistrement)
    
    // Trouver l'offset maximum (le début réel du morceau)
    double maxOffset = 0;
    for (var n in _session) {
      if (n.currentOffset + n.height > maxOffset) {
        maxOffset = n.currentOffset + n.height;
      }
    }

    // On pré-remplit les notes actives qui sont déjà dans la zone de chute
    // On doit inclure les notes qui ont commencé ET celles qui sont sur le point de passer
    for (var note in _session) {
      double noteStartInSong = (maxOffset - (note.currentOffset + note.height)) * pixelRatio;
      double noteEndInSong = (maxOffset - note.currentOffset) * pixelRatio;
      double playingEndInSong = (maxOffset - (note.currentOffset + note.height - note.playingHeight)) * pixelRatio;

      // Si la note est "active" visuellement ou sonorement à _playbackPosition
      if (noteStartInSong <= _playbackPosition && playingEndInSong > _playbackPosition) {
         _activeFallingNotes.add(NoteModel(
          id: note.id,
          keyIndex: note.keyIndex,
          height: note.height,
          playingHeight: note.playingHeight,
          color: note.color,
          overrideColor: note.overrideColor,
          chordId: note.chordId,
          isSilence: note.isSilence,
          currentOffset: cascadeHeight - (_playbackPosition - noteStartInSong),
          fromMidi: note.fromMidi,
          velocity: note.velocity,
        ));
      }
    }

    _animTimer = Timer.periodic(const Duration(milliseconds: 16), (timer) {
      if (!_isPlaying || _isPaused) {
        timer.cancel();
        return;
      }

      double movement = pixelsPerMs * 16.0;
      double oldPlaybackPos = _playbackPosition;
      _playbackPosition += movement;

      // 1. Déclencher les nouvelles notes de la session
      for (var note in _session) {
        double noteStartInSong = (maxOffset - (note.currentOffset + note.height)) * pixelRatio;
        
        // Si la note doit commencer dans cette frame
        if (noteStartInSong >= oldPlaybackPos && noteStartInSong < _playbackPosition) {
          if (!note.isSilence) {
            _activeFallingNotes.add(NoteModel(
              id: note.id,
              keyIndex: note.keyIndex,
              height: note.height,
              playingHeight: note.playingHeight,
              color: note.color,
              overrideColor: note.overrideColor,
              chordId: note.chordId,
              isSilence: note.isSilence,
              currentOffset: cascadeHeight, // Elle commence en haut
              fromMidi: note.fromMidi,
              velocity: note.velocity,
            ));
          }
        }
      }

      // 2. Faire descendre les notes actives
      for (var note in _activeFallingNotes) {
        double oldOffset = note.currentOffset;
        note.currentOffset -= movement;

        // Déclenchement du son à l'impact (offset 0)
        if (oldOffset >= 0 && note.currentOffset < 0 && !note.isSilence) {
          _playNote(note.keyIndex + 21, velocity: note.velocity);
        }
      }

      // 3. Nettoyage
      _activeFallingNotes.removeWhere((n) {
        bool soundFinished = n.currentOffset + (n.playingHeight * pixelRatio) < 0;
        if (soundFinished && !n.isSilence) {
          _stopNote(n.keyIndex + 21);
        }
        return soundFinished;
      });

      // Fin du morceau
      if (_playbackPosition > (maxOffset * pixelRatio) + cascadeHeight) {
        _isPlaying = false;
        timer.cancel();
      }

      notifyListeners();
    });
  }

  void stopMusic() {
    _isPlaying = false;
    _isPaused = false;
    _playbackPosition = 0.0;
    for (var note in _activeFallingNotes) {
      if (!note.isSilence) {
        _stopNote(note.keyIndex + 21);
      }
    }
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
    const XTypeGroup jsonGroup = XTypeGroup(label: 'JSON files', extensions: <String>['json']);
    const XTypeGroup midiGroup = XTypeGroup(label: 'MIDI files', extensions: <String>['mid', 'midi']);

    final XFile? file = await openFile(acceptedTypeGroups: <XTypeGroup>[jsonGroup, midiGroup]);

    if (file != null) {
      String extension = file.name.split('.').last.toLowerCase();

      if (extension == 'json') {
        String content = await file.readAsString();
        try {
          List<dynamic> jsonList = jsonDecode(content);
          List<NoteModel> rawNotes = jsonList.map((e) => NoteModel.fromJson(e)).toList();

          bool isMidiSong = rawNotes.any((n) => n.fromMidi);
          if (isMidiSong) {
            _reconstructMidiOffsets(rawNotes);
          } else {
            _reconstructManualOffsets(rawNotes);
          }

          _session = rawNotes;
          _currentFileName = file.name;
          _updateSystemTitle();
          notifyListeners();
        } catch (e) {
          debugPrint("Erreur import JSON: $e");
        }
      } else if (extension == 'mid' || extension == 'midi') {
        await _importMidiFile(file);
      }
    }
  }

  /// Reconstruit les positions (offsets) en utilisant les timestamps MIDI
  void _reconstructMidiOffsets(List<NoteModel> notes) {
    if (notes.isEmpty) return;

    // Tenter de parser les chordId comme des dates
    List<DateTime?> times = notes.map((n) => DateTime.tryParse(n.chordId)).toList();

    // Si on n'arrive pas à parser les dates, on fallback sur le manuel
    if (times.any((t) => t == null)) {
      _reconstructManualOffsets(notes);
      return;
    }

    // Trier par date pour être sûr de l'ordre chronologique
    // On utilise une liste d'index pour trier en même temps les notes et les dates
    var combined = List.generate(notes.length, (i) => i);
    combined.sort((a, b) => times[a]!.compareTo(times[b]!));

    List<NoteModel> sortedNotes = combined.map((i) => notes[i]).toList();
    List<DateTime> sortedTimes = combined.map((i) => times[i]!).toList();

    notes.clear();
    notes.addAll(sortedNotes);

    DateTime firstTime = sortedTimes[0];
    double msPerBeat = 60000.0 / _bpm;

    // Trouver le moment de fin global pour définir le "bas" du morceau
    double maxEndTimeMs = 0;
    List<double> startTimesMs = [];
    for (int i = 0; i < notes.length; i++) {
      double startMs = sortedTimes[i].difference(firstTime).inMilliseconds.toDouble();
      startTimesMs.add(startMs);
      double endMs = startMs + (notes[i].height * msPerBeat);
      if (endMs > maxEndTimeMs) maxEndTimeMs = endMs;
    }

    // Calculer les offsets : plus la note est au début, plus elle est haute (grand offset)
    for (int i = 0; i < notes.length; i++) {
      double startMs = startTimesMs[i];
      // On veut que la note qui finit en dernier soit à l'offset 0 (ou presque)
      // currentTop = (MaxEnd - Start) / msPerBeat
      double currentTop = (maxEndTimeMs - startMs) / msPerBeat;
      notes[i].currentOffset = currentTop - notes[i].height;
      if (notes[i].currentOffset < 0) notes[i].currentOffset = 0;
    }
  }

  /// Reconstruit les positions par empilement simple (Mode Manuel)
  void _reconstructManualOffsets(List<NoteModel> notes) {
    double accumulatedOffset = 0.0;
    for (int i = notes.length - 1; i >= 0; i--) {
      NoteModel currentNote = notes[i];
      currentNote.currentOffset = accumulatedOffset;

      bool isChordWithNext = false;
      if (i > 0) {
        if (notes[i - 1].chordId == currentNote.chordId) {
          isChordWithNext = true;
        }
      }
      if (!isChordWithNext) {
        accumulatedOffset += currentNote.height;
      }
    }
  }

  // Helpers pour l'édition
  void updateNote(NoteModel note, double newH, Color? newC) {
    int idx = _session.indexOf(note);
    if(idx == -1) return;
    _session[idx] = NoteModel(
        id: note.id,
        keyIndex: note.keyIndex, 
        height: newH, 
        playingHeight: note.playingHeight == note.height ? newH : note.playingHeight,
        color: note.color,
        overrideColor: newC,
        chordId: note.chordId, 
        isSilence: note.isSilence,
        currentOffset: note.currentOffset,
        fromMidi: note.fromMidi,
        velocity: note.velocity
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



  Future<void> _importMidiFile(XFile file) async {
    try {
      final bytes = await file.readAsBytes();
      final parser = MidiParser();
      final parsedMidi = parser.parseMidiFromBuffer(bytes.toList());

      List<NoteModel> rawNotes = [];
      int ppq = parsedMidi.header.ticksPerBeat ?? 120;
      int currentBpm = 120;

      debugPrint("MIDI Header: PPQ=$ppq, Tracks=${parsedMidi.tracks.length}");

      for (int t = 0; t < parsedMidi.tracks.length; t++) {
        var track = parsedMidi.tracks[t];
        int absoluteTime = 0;
        
        // On suit l'état des notes en cours
        // Key: MIDI note number
        // Value: Map avec startTime, velocity, et éventuellement visualDuration
        Map<int, Map<String, dynamic>> activeNotes = {};
        bool isSustainPedalDown = false;
        // Notes dont la touche est relâchée mais qui attendent la fin du sustain
        List<Map<String, dynamic>> notesWaitingForSustain = [];

        for (var event in track) {
          absoluteTime += event.deltaTime;

          if (event is SetTempoEvent) {
            currentBpm = (60000000 / event.microsecondsPerBeat).round();
            _bpm = currentBpm;
            continue;
          }

          if (event is ControllerEvent && event.controllerType == 64) {
            isSustainPedalDown = event.value >= 64;
            if (!isSustainPedalDown) {
              // Fin du sustain : on finalise toutes les notes qui attendaient
              for (var noteData in notesWaitingForSustain) {
                _finalizeMidiNote(noteData, absoluteTime, ppq, currentBpm, rawNotes);
              }
              notesWaitingForSustain.clear();
            }
          }

          int? currentNote;
          int velocity = 100;
          bool isNoteOn = false;
          bool isNoteOff = false;

          if (event is NoteOnEvent) {
            currentNote = event.noteNumber;
            velocity = event.velocity;
            isNoteOn = event.velocity > 0;
            isNoteOff = event.velocity == 0;
          } else if (event is NoteOffEvent) {
            currentNote = event.noteNumber;
            isNoteOff = true;
          }

          if (currentNote != null) {
            if (isNoteOn) {
              activeNotes[currentNote] = {
                'noteNumber': currentNote,
                'startTime': absoluteTime,
                'velocity': velocity,
              };
            } else if (isNoteOff) {
              if (activeNotes.containsKey(currentNote)) {
                var noteData = activeNotes[currentNote]!;
                noteData['visualEndTime'] = absoluteTime;
                
                if (isSustainPedalDown) {
                  notesWaitingForSustain.add(noteData);
                } else {
                  _finalizeMidiNote(noteData, absoluteTime, ppq, currentBpm, rawNotes);
                }
                activeNotes.remove(currentNote);
              }
            }
          }
        }
        
        // Finaliser les notes restées ouvertes à la fin de la piste
        for (var noteData in notesWaitingForSustain) {
          _finalizeMidiNote(noteData, absoluteTime, ppq, currentBpm, rawNotes);
        }
        for (var noteData in activeNotes.values) {
          _finalizeMidiNote(noteData, absoluteTime, ppq, currentBpm, rawNotes);
        }
      }

      if (rawNotes.isNotEmpty) {
        _reconstructMidiOffsets(rawNotes);
        _session = rawNotes;
        _currentFileName = file.name;
        _updateSystemTitle();
        notifyListeners();
      }
    } catch (e) {
      debugPrint("Erreur import fichier MIDI: $e");
    }
  }

  void _finalizeMidiNote(Map<String, dynamic> noteData, int endTime, int ppq, int bpm, List<NoteModel> targetList) {
    int startTime = noteData['startTime'];
    int visualEndTime = noteData['visualEndTime'] ?? endTime;
    int noteNumber = noteData['noteNumber'];
    int velocity = noteData['velocity'];

    double visualHeight = (visualEndTime - startTime) / ppq;
    double playingHeight = (endTime - startTime) / ppq;
    
    if (visualHeight <= 0) visualHeight = 0.05;
    if (playingHeight < visualHeight) playingHeight = visualHeight;

    int keyIndex = noteNumber - 21;
    if (keyIndex >= 0 && keyIndex <= 87) {
      bool isBlack = [1, 3, 6, 8, 10].contains(noteNumber % 12);
      double msPerTick = (60000.0 / bpm) / ppq;
      int startMs = (startTime * msPerTick).round();
      String chordId = DateTime.fromMillisecondsSinceEpoch(startMs).toIso8601String();

      targetList.add(NoteModel(
        keyIndex: keyIndex,
        height: visualHeight,
        playingHeight: playingHeight,
        color: isBlack ? Colors.blue : Colors.lightGreen,
        chordId: chordId,
        fromMidi: true,
        velocity: velocity,
        currentOffset: 0.0,
      ));
    }
  }



}