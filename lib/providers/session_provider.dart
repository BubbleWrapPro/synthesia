import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_selector/file_selector.dart';
import '../models/note_model.dart';
import 'package:flutter/services.dart';
import 'package:dart_midi_pro/dart_midi_pro.dart';
import 'package:flutter_midi_pro/flutter_midi_pro.dart';

enum AppMode { edit, play }

class SessionProvider with ChangeNotifier {

  // --- CONFIGURATION MIDI ---
  static const MethodChannel _midiChannel = MethodChannel('com.synthesia.midi');
  final MidiPro _midiPro = MidiPro();
  bool _isCustomSf2LoadedOnWindows = false;
  int _currentSfId = 1;
  bool _isMidiProInitialized = false;

  SessionProvider() {
    _initMidiListener();
    _loadSoundFont();
  }

  Future<void> _ensureMidiProInitialized() async {
    if (!_isMidiProInitialized) {
      try {
        await _midiPro.init();
        _isMidiProInitialized = true;
      } catch (e) {
        debugPrint("Error initializing MidiPro: $e");
      }
    }
  }

  Future<void> _loadSoundFont() async {
    if (Platform.isWindows) {
      debugPrint("Windows: Using default system MIDI synth (Microsoft GS Wavetable Synth)");
      _currentSoundFontName = "Windows GS Synth";
      _isCustomSf2LoadedOnWindows = false;
      return;
    }
    try {
      // Default sound for mobile
      await _ensureMidiProInitialized();
      _currentSfId = await _midiPro.loadSoundfontAsset(assetPath: "assets/sounds/Piano_1.sf2");
      _currentSoundFontName = "Piano_1.sf2";
      debugPrint("SoundFont loaded: Piano_1.sf2");
    } catch (e) {
      debugPrint("Error loading default SoundFont: $e");
    }
  }

  Future<void> pickAndLoadSoundFont() async {
    const XTypeGroup typeGroup = XTypeGroup(label: 'SoundFonts', extensions: <String>['sf2']);
    final XFile? file = await openFile(acceptedTypeGroups: [typeGroup]);

    if (file != null) {
      debugPrint("--- LOADING SF2 ---");

      try {
        await _ensureMidiProInitialized();
        if (Platform.isWindows) {
          // Version 4.0.4+ supports absolute paths on Windows via FluidSynth
          _currentSfId = await _midiPro.loadSoundfontFile(filePath: file.path);
          _currentSoundFontName = file.name;
          _isCustomSf2LoadedOnWindows = true;
          debugPrint("Windows: Loaded SF2 via flutter_midi_pro: ${file.path}");
        } else {
          // Mobile: Bytes-based loading via flutter_midi_pro
          final Uint8List bytes = await file.readAsBytes();
          _currentSfId = await _midiPro.loadSoundfontData(data: bytes);
          _currentSoundFontName = file.name;
          debugPrint("Mobile: Loaded SF2 via flutter_midi_pro: ${file.name}");
        }

        notifyListeners();
      } catch (e) {
        debugPrint("Error loading SoundFont: $e");
        _currentSoundFontName = "Load Failed";
        notifyListeners();
      }
    }
  }

  // --- SOUND HELPERS ---
  void _playNote(int midiNote, {int velocity = 100}) {
    if (Platform.isWindows) {
      if (_isCustomSf2LoadedOnWindows) {
        _midiPro.playNote(key: midiNote, velocity: velocity, sfId: _currentSfId);
      } else {
        // Fallback to system synth if no custom SF2 is loaded
        _midiChannel.invokeMethod('playMidiNote', {
          'note': midiNote,
          'velocity': velocity,
        });
      }
    } else {
      _midiPro.playNote(key: midiNote, velocity: velocity, sfId: _currentSfId);
    }
  }

  void _stopNote(int midiNote) {
    if (Platform.isWindows) {
      if (_isCustomSf2LoadedOnWindows) {
        _midiPro.stopNote(key: midiNote, sfId: _currentSfId);
      } else {
        _midiChannel.invokeMethod('stopMidiNote', midiNote);
      }
    } else {
      _midiPro.stopNote(key: midiNote, sfId: _currentSfId);
    }
  }

  /// Kills all active notes and resets MIDI state (Panic Button)
  void panic() {
    debugPrint("MIDI Panic: Stopping all notes...");

    if (Platform.isWindows) {
      if (_isCustomSf2LoadedOnWindows) {
        _midiPro.stopAllNotes(sfId: _currentSfId);
      } else {
        // Manual sweep for Windows System Synth
        for (int i = 0; i < 128; i++) {
          _midiChannel.invokeMethod('stopMidiNote', i);
        }
      }
    } else {
      // Mobile loop
      _midiPro.stopAllNotes(sfId: _currentSfId);
    }

    _activeKeys.clear();
    _isSustainDown = false;
    _sustainedNotes.clear();
    _activeRecordingNotes.clear();
    _lastNoteIdStarted.clear();

    notifyListeners();
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
  String _currentSoundFontName = "Piano_1.sf2"; // [NEW] Nom du SoundFont actif
  bool _isChordMode = false;
  double _defaultHeight = 1.0;
  int _bpm = 60;
  bool _isPlaying = false;
  bool _isPaused = false;
  AppMode _currentMode = AppMode.edit;
  double _playbackPosition = 0.0; // En pixels
  final Set<int> _activeKeys = {};
  bool _injectionDone = false; // [NEW] Flag to track sequencer completion

  // Multi-Pistes [NEW]
  int _currentTrackId = 0;
  final Set<int> _activeTracks = {0, 1, 2, 3, 4, 5, 6, 7, 8, 9}; // Tracks actives pour la lecture

  // Anti-Coupure [NEW] : Stocke l'ID de la dernière note ayant déclenché un son pour chaque touche
  final Map<int, String> _lastNoteIdStarted = {};

  // Option "Silence Automatique"
  // false = Le défilement s'arrête si aucune note n'est pressée (Mode "Pas à pas")
  // true  = Le défilement continue et crée du vide (Mode "Enregistrement continu")
  bool _autoSilence = false;
  bool _showAllTracksInEdit = false; // [NEW] Afficher toutes les pistes en mode édition

  // Variables pour l'animation de lecture (Playback)
  double _animationScrollY = 0.0;
  Timer? _animTimer;
  final List<NoteModel> _fallingNotes = [];
  final double _fallingY = 0.0;
  List<NoteModel> _activeFallingNotes = []; // Pour le playback
  double _editScrollOffset = 0.0; // [NEW] Scroll en mode édition

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
  String get currentSoundFontName => _currentSoundFontName;
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
  double get editScrollOffset => _editScrollOffset; // [NEW]
  bool get autoSilence => _autoSilence;
  bool get showAllTracksInEdit => _showAllTracksInEdit; // [NEW]
  int get currentTrackId => _currentTrackId;
  Set<int> get activeTracks => _activeTracks;

  // --- LOGIQUE MULTI-PISTES ---

  void setCurrentTrackId(int id) {
    _currentTrackId = id;
    notifyListeners();
  }

  void toggleTrack(int trackId) {
    if (_activeTracks.contains(trackId)) {
      _activeTracks.remove(trackId);
    } else {
      _activeTracks.add(trackId);
    }
    notifyListeners();
  }

  /// Retourne la liste des IDs de pistes présents dans la session
  List<int> get availableTracks {
    final tracks = _session.map((n) => n.trackId).toSet().toList();
    tracks.sort();
    return tracks;
  }

  Map<int, double> _getTrackMaxOffsets() {
    Map<int, double> map = {};
    for (var n in _session) {
      if (!_activeTracks.contains(n.trackId)) continue;
      map[n.trackId] = (map[n.trackId] ?? 0.0);
      if (n.currentOffset + n.height > map[n.trackId]!) {
        map[n.trackId] = n.currentOffset + n.height;
      }
    }
    return map;
  }


  // --- LOGIQUE MIDI TEMPS RÉEL (RECORDING) ---

  void setAutoSilence(bool value) {
    _autoSilence = value;
    if (_autoSilence && _currentMode == AppMode.edit) {
      startRecordingLoop();
    }
    notifyListeners();
  }

  void setShowAllTracksInEdit(bool value) {
    _showAllTracksInEdit = value;
    notifyListeners();
  }

  void setMode(AppMode mode) {
    _currentMode = mode;
    _editScrollOffset = 0.0; // [NEW] Reset scroll on mode change
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
    // Stop currently playing sounds to prevent "ghost notes"
    for (var note in _activeFallingNotes) {
      if (!note.isSilence) _stopNote(note.keyIndex + 21);
    }
    _activeFallingNotes.clear();
    _fallingNotes.clear();

    _playbackPosition += amount;
    if (_playbackPosition < 0) _playbackPosition = 0;

    // Calculate max song position
    final trackMaxOffsets = _getTrackMaxOffsets();
    double globalMaxOffset = 0;
    if (trackMaxOffsets.isNotEmpty) {
      globalMaxOffset = trackMaxOffsets.values.fold(0, (a, b) => a > b ? a : b);
    }

    double pixelRatio = screenHeight / 8.0;
    double cascadeHeight = screenHeight * (5.0 / 9.0);
    double maxPos = (globalMaxOffset * pixelRatio) + cascadeHeight; // Total travel
    if (_playbackPosition > maxPos) _playbackPosition = maxPos;

    // Update progress bar (Audible range)
    double songDurationPixels = globalMaxOffset * pixelRatio;
    if (songDurationPixels > 0) {
      _animationScrollY = ((_playbackPosition - cascadeHeight) / songDurationPixels).clamp(0.0, 1.0);
    }

    // Recalculate which notes should be visible at this new position
    _recalculateActiveFallingNotes(screenHeight, trackMaxOffsets);

    // If we are playing and not paused, the timer will pick up from here.
    // Otherwise, we just notify listeners to update the static view.
    notifyListeners();
  }

  void handleScroll(double delta, double screenHeight) {
    if (_currentMode == AppMode.play) {
      seek(delta, screenHeight);
    } else {
      _editScrollOffset += delta;
      if (_editScrollOffset < 0) _editScrollOffset = 0;
      notifyListeners();
    }
  }

  void _recalculateActiveFallingNotes(double screenHeight, Map<int, double> trackMaxOffsets) {
    double cascadeHeight = screenHeight * (5.0 / 9.0);
    double pixelRatio = screenHeight / 8.0;

    _activeFallingNotes.clear();
    _fallingNotes.clear();

    for (var note in _session) {
      if (!_activeTracks.contains(note.trackId)) continue;

      double trackMax = trackMaxOffsets[note.trackId] ?? 0.0;
      double noteStartInSong = (trackMax - (note.currentOffset + note.height)) * pixelRatio;
      double playingEndInSong = (trackMax - (note.currentOffset + note.height - note.playingHeight)) * pixelRatio;

      // If the note is currently active (visually or sonically) at _playbackPosition
      if (noteStartInSong <= _playbackPosition && playingEndInSong > _playbackPosition) {
        final fNote = NoteModel(
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
          trackId: note.trackId,
          velocity: note.velocity,
        );
        _activeFallingNotes.add(fNote);
        _fallingNotes.add(fNote);
      }
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

    // [FIX] Si la note était déjà active ou en "sustain", on la stoppe proprement avant de la rejouer
    if (_activeRecordingNotes.containsKey(keyIndex) || _sustainedNotes.containsKey(keyIndex)) {
      _stopNote(midiNote);
      _sustainedNotes.remove(keyIndex);
      _activeRecordingNotes.remove(keyIndex);
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
      trackId: _currentTrackId, // [NEW] Multi-Piste
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
      // On ne génère du silence que si la session a déjà commencé (au moins une note)
      bool sessionStarted = _session.isNotEmpty;

      if (_activeRecordingNotes.isEmpty && _sustainedNotes.isEmpty && (!_autoSilence || !sessionStarted)) {
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

  void addNote(int keyIndex, bool isBlackKey, double screenHeight) {
    if (_isPlaying) return;

    double pixelRatio = screenHeight / 8.0;
    double insertionOffset = _editScrollOffset / pixelRatio;

    // Ajout manuel "one shot" (ancienne logique, toujours utile pour l'UI)
    double h = _defaultHeight;
    String cId = (_isChordMode && _session.isNotEmpty)
        ? _session.last.chordId
        : DateTime.now().toIso8601String();

    int targetTrackId = _showAllTracksInEdit ? 0 : _currentTrackId;

    NoteModel newNote = NoteModel(
      keyIndex: keyIndex,
      height: h,
      color: isBlackKey ? Colors.blue : Colors.lightGreen,
      chordId: cId,
      fromMidi: false,
      trackId: targetTrackId, // [NEW] Multi-Piste
      currentOffset: insertionOffset,
    );

    // En mode manuel sans accord, on pousse les autres vers le haut
    if (!_isChordMode) {
      for (var note in _session) {
        if (note.trackId == targetTrackId && note.currentOffset >= insertionOffset) {
          note.currentOffset += h;
        }
      }
    }

    _session.add(newNote);
    if (!_isRecording) startRecordingLoop();
    notifyListeners();
  }

  void addSilence(int length, double screenHeight) {
    double pixelRatio = screenHeight / 8.0;
    double insertionOffset = _editScrollOffset / pixelRatio;
    int targetTrackId = _showAllTracksInEdit ? 0 : _currentTrackId;

    for(int i=0; i<length; i++) {
      String cId = "${DateTime.now().toIso8601String()}_$i";
      for (var note in _session) {
        if (note.trackId == targetTrackId && note.currentOffset >= insertionOffset) {
          note.currentOffset += 1.0;
        }
      }
      _session.add(NoteModel(
        keyIndex: -1,
        height: 1.0,
        color: Colors.transparent,
        chordId: cId,
        isSilence: true,
        trackId: targetTrackId, // [NEW]
        currentOffset: insertionOffset,
      ));
    }
    notifyListeners();
  }

  void removeSilence(int length, double screenHeight) {
    double pixelRatio = screenHeight / 8.0;
    double insertionOffset = _editScrollOffset / pixelRatio;
    int targetTrackId = _showAllTracksInEdit ? 0 : _currentTrackId;

    // On cherche le silence le plus proche de l'insertion (commençant à l'insertion)
    for(int i=0; i<length; i++) {
      final idx = _session.lastIndexWhere((n) => n.trackId == targetTrackId && n.isSilence && (n.currentOffset - insertionOffset).abs() < 0.01);
      if (idx != -1) {
        _session.removeAt(idx);
        for (var note in _session) {
          if (note.trackId == targetTrackId && note.currentOffset > insertionOffset) {
            note.currentOffset -= 1.0;
          }
        }
      } else {
        // Fallback : remove from end if nothing at insertion point
        final lastIdx = _session.lastIndexWhere((n) => n.trackId == targetTrackId && n.isSilence);
        if (lastIdx != -1) {
          double off = _session[lastIdx].currentOffset;
          _session.removeAt(lastIdx);
          for (var note in _session) {
            if (note.trackId == targetTrackId && note.currentOffset > off) {
              note.currentOffset -= 1.0;
            }
          }
        }
      }
    }
    notifyListeners();
  }

  void clearSession() {
    _session.clear();
    _currentFileName = "";
    _animationScrollY = 0;
    _editScrollOffset = 0.0; // [NEW]
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
    if (Platform.isWindows) {
      try {
        _midiChannel.invokeMethod('setWindowTitle', windowTitle);
      } catch (e) {
        // debugPrint("Native title update failed: $e");
      }
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
    _injectionDone = false;
    _activeFallingNotes = [];
    _fallingNotes.clear();
    notifyListeners();

    // 1. Moteur physique (Timer de descente)
    double cascadeHeight = screenHeight * (5.0 / 9.0);
    double pixelRatio = screenHeight / 8.0;
      double pixelsPerMs = (pixelRatio * (_bpm / 60.0)) / 1000.0;

      // --- CORRECTION DIRECTION ---
      // Dans Synthesia, les notes avec de grands offsets sont au DEBUT du morceau (plus haut)
      // Les notes avec offset 0 sont à la FIN (présent lors de l'enregistrement)

      // [NEW] Calcul des offsets par piste pour synchronisation au début
      final trackMaxOffsets = _getTrackMaxOffsets();
      double globalMaxOffset = 0;
      if (trackMaxOffsets.isNotEmpty) {
        globalMaxOffset = trackMaxOffsets.values.fold(0, (a, b) => a > b ? a : b);
      }

      // On pré-remplit les notes actives qui sont déjà dans la zone de chute
      _recalculateActiveFallingNotes(screenHeight, trackMaxOffsets);

      _animTimer = Timer.periodic(const Duration(milliseconds: 16), (timer) {
        if (!_isPlaying || _isPaused) {
          timer.cancel();
          return;
        }

        double movement = pixelsPerMs * 16.0;
        double oldPlaybackPos = _playbackPosition;
        _playbackPosition += movement;

        // Update _animationScrollY as a normalized progress (Audible range)
        double songDurationPixels = globalMaxOffset * pixelRatio;
        if (songDurationPixels > 0) {
          _animationScrollY = ((_playbackPosition - cascadeHeight) / songDurationPixels).clamp(0.0, 1.0);
        }

      // 1. Déclencher les nouvelles notes de la session
      bool anyNoteLeftToInject = false;
      for (var note in _session) {
        if (!_activeTracks.contains(note.trackId)) continue; // [NEW] Filtrage multi-pistes

        double trackMax = trackMaxOffsets[note.trackId] ?? 0.0;
        double noteStartInSong = (trackMax - (note.currentOffset + note.height)) * pixelRatio;
        
        if (noteStartInSong > _playbackPosition) {
          anyNoteLeftToInject = true;
        }

        // Si la note doit commencer dans cette frame
        if (noteStartInSong >= oldPlaybackPos && noteStartInSong < _playbackPosition) {
          if (!note.isSilence) {
            final fallingNote = NoteModel(
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
              trackId: note.trackId, // [NEW] Multi-Piste
              velocity: note.velocity,
            );
            _activeFallingNotes.add(fallingNote);
            _fallingNotes.add(fallingNote); 
          }
        }
      }

      _injectionDone = !anyNoteLeftToInject;

      // 2. Faire descendre les notes actives
      for (var note in _activeFallingNotes) {
        double oldOffset = note.currentOffset;
        note.currentOffset -= movement;

        // Déclenchement du son à l'impact (offset 0 + _fallingY)
        if (oldOffset >= _fallingY && note.currentOffset < _fallingY && !note.isSilence) {
          _playNote(note.keyIndex + 21, velocity: note.velocity);
          _lastNoteIdStarted[note.keyIndex] = note.id; 
        }
      }

      // 3. Nettoyage
      _activeFallingNotes.removeWhere((n) {
        bool soundFinished = n.currentOffset + (n.playingHeight * pixelRatio) < _fallingY;
        if (soundFinished && !n.isSilence) {
          // [NEW] On ne coupe le son que si c'est bien CETTE instance qui a démarré le son en dernier
          // Cela évite de couper une note identique qui vient de redémarrer (overlapping)
          if (_lastNoteIdStarted[n.keyIndex] == n.id) {
            _stopNote(n.keyIndex + 21);
          }
          _fallingNotes.remove(n);
        }
        return soundFinished;
      });

      // Fin du morceau : Plus rien à injecter et plus de notes actives
      if (_injectionDone && _activeFallingNotes.isEmpty) {
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
    _animationScrollY = 0.0;
    for (var note in _activeFallingNotes) {
      if (!note.isSilence) {
        _stopNote(note.keyIndex + 21);
      }
    }
    _activeFallingNotes.clear();
    _fallingNotes.clear();
    _lastNoteIdStarted.clear();
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

    double diff = newH - note.height;

    // Mise à jour de la note elle-même
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
        trackId: note.trackId, // [NEW]
        velocity: note.velocity
    );

    // Décaler les notes "précédentes" (celles qui ont été ajoutées avant et sont donc plus haut)
    // On se base sur currentOffset car c'est lui qui définit la position verticale.
    if (!_isPlaying) {
      for (var otherNote in _session) {
        if (otherNote.trackId == _currentTrackId && // [NEW]
            otherNote.id != note.id && otherNote.currentOffset > note.currentOffset) {
          otherNote.currentOffset += diff;
        }
      }
    }

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
          if (noteToBelittle.trackId == _currentTrackId && // [NEW]
              noteToBelittle.currentOffset > note.currentOffset) {
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
        int trackId = t; // [NEW] Utiliser l'index de la piste MIDI comme trackId
        _activeTracks.add(trackId); // [NEW] Activer la piste par défaut lors de l'import
        
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
                _finalizeMidiNote(noteData, absoluteTime, ppq, currentBpm, rawNotes, trackId);
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
              // [FIX] Si la note est déjà active, on la finalise avant d'en commencer une nouvelle
              if (activeNotes.containsKey(currentNote)) {
                _finalizeMidiNote(activeNotes[currentNote]!, absoluteTime, ppq, currentBpm, rawNotes, trackId);
              }
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
                  _finalizeMidiNote(noteData, absoluteTime, ppq, currentBpm, rawNotes, trackId);
                }
                activeNotes.remove(currentNote);
              }
            }
          }
        }
        
        // Finaliser les notes restées ouvertes à la fin de la piste
        for (var noteData in notesWaitingForSustain) {
          _finalizeMidiNote(noteData, absoluteTime, ppq, currentBpm, rawNotes, trackId);
        }
        for (var noteData in activeNotes.values) {
          _finalizeMidiNote(noteData, absoluteTime, ppq, currentBpm, rawNotes, trackId);
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

  void _finalizeMidiNote(Map<String, dynamic> noteData, int endTime, int ppq, int bpm, List<NoteModel> targetList, int trackId) {
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
        trackId: trackId, // [NEW]
        velocity: velocity,
        currentOffset: 0.0,
      ));
    }
  }



}
