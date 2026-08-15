# Plan d'Évolution Majeure - Synthesia v2.0

Ce plan détaille la restructuration profonde du projet pour améliorer la performance, l'interactivité et les fonctionnalités professionnelles (MIDI/Multi-pistes).

## 1. Refactoring et Performance (Le Séquenceur Optimisé)
**Objectif** : Sortir le MIDI du provider et passer à une structure de données indexée par le temps (Curseur).

### Changements :
- **[NEW] MIDI Service** : Créer `MidiService` pour encapsuler `MidiPro`, `FlutterMidi` et les appels natifs.
- **[MODIFY] NoteModel** : Ajouter un champ `startTime` (beat) calculé pour éviter les calculs d'offset relatifs permanents.
- **[MODIFY] SessionProvider** :
    - Séparer la liste des notes en `_fullSession` (données) et `_activeNotes` (playback).
    - Implémenter l'algorithme du **Curseur** pour le playback (complexité $O(1)$ par frame au lieu de $O(N)$).

## 2. Interaction Directe (Drag & Drop et Resizing)
**Objectif** : Permettre l'édition visuelle intuitive des notes dans `CascadeView`.

### Changements :
- **[MODIFY] CascadeView** :
    - Envelopper les tuiles de notes dans des widgets `GestureDetector` avancés.
    - Gérer `onVerticalDragUpdate` pour déplacer une note dans le temps (change son `currentOffset`).
    - Gérer `onHorizontalDragUpdate` pour changer la note (change son `keyIndex`).
    - Ajouter des "poignées" (handles) en haut/bas de la note pour le redimensionnement (`height`).

## 3. Support Multi-pistes
**Objectif** : Gérer les fichiers MIDI complexes avec plusieurs instruments/mains.

### Changements :
- **[MODIFY] NoteModel** : Ajouter un champ `trackIndex` et `trackName`.
- **[MODIFY] SessionProvider** :
    - Stocker une liste de `TrackMetadata`.
    - Ajouter une Map `Map<int, bool> _trackVisibility` pour filtrer le rendu.
- **[MODIFY] ControlPanel** : Ajouter un menu déroulant ou une liste pour cocher/décocher les pistes.

## 4. Export MIDI Standard
**Objectif** : Permettre d'utiliser les créations Synthesia dans d'autres logiciels (DAW).

### Changements :
- **[NEW] MidiExporter** : Utiliser `dart_midi_pro` pour convertir la liste de `NoteModel` en une séquence d'événements `NoteOn` / `NoteOff`.
- **[MODIFY] ControlPanel** : Ajouter un bouton "Exporter en MIDI".

---

## Plan d'Exécution (Étapes)

### Étape 1 : Fondations et MIDI Service
1. Créer `lib/services/midi_service.dart`.
2. Migrer toute la logique `_playNote`, `_stopNote`, `panic` et `loadSoundFont`.
3. Mettre à jour `SessionProvider` pour utiliser ce service.

### Étape 2 : Optimisation du Moteur (Curseur)
1. Modifier `NoteModel` pour inclure `startTime` absolu.
2. Réécrire la boucle `playMusic` dans `SessionProvider` pour utiliser l'indexation par curseur.

### Étape 3 : Édition Visuelle (Drag & Drop)
1. Modifier `CascadeView` pour supporter le déplacement.
2. Implémenter les "poignées" de redimensionnement.

### Étape 4 : Multi-pistes et Export
1. Enrichir l'import MIDI pour capturer les pistes.
2. Créer l'UI de sélection de pistes.
3. Implémenter la logique d'export `.mid`.

---

## User Review Required
> [!IMPORTANT]
> Le passage au multi-pistes modifiera le format JSON de sauvegarde. Une migration automatique sera tentée pour les anciens fichiers, mais ils pourraient perdre les informations de pistes.

**Est-ce que ce plan te convient pour que je commence l'exécution ?**
