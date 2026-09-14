# Synthesia

[🇬🇧 English](#english) | [🇫🇷 Français](#français)

---

<a name="english"></a>
## 🇬🇧 English Version

A custom Flutter-based piano learning and recording interface with MIDI support, high-quality SoundFont playback, and advanced visualization.

## 🎹 Overview
Synthesia is an interactive 88-key piano application designed for creating, recording, and replaying "waterfall" style note cascades. It bridges the gap between manual note-by-note creation and real-time MIDI recording, offering a highly customizable visual experience for musicians and developers alike.

Built with **Flutter**, it runs seamlessly on both **Windows** (for advanced MIDI recording and piano connection) and **Android** (for portable practice).

---

## 📦 Releases & Distribution
You can find the latest stable versions on the [GitHub Releases](https://github.com/Thomas/synthesia/releases) page:

- **[Android v1.0.0](https://github.com/Thomas/synthesia/releases/tag/android-v1.0.0)**: Download the `.apk` for Android devices.
- **[Windows v1.0.0](https://github.com/Thomas/synthesia/releases/tag/windows-v1.0.0)**: Download the signed `.msix` installer for Windows. *Recommended for connecting physical digital pianos via USB/MIDI.*

---

## ✨ Key Features
- **88-Key Piano Interface**: Responsive keyboard with dynamic color feedback and MIDI input mapping.
- **Dual Creation Modes**:
    - **MIDI Recording**: Connect a digital piano (USB/MIDI) to record notes in real-time. Supports automatic chord detection and smart silence handling.
    - **Manual Editing**: Add, modify, or delete notes and silences manually via the UI or keyboard shortcuts.
- **High-Quality Audio Engine**:
    - **SoundFont Support**: Load custom `.sf2` files for realistic instrument sounds (Grand Piano included by default).
    - **Windows Native Synth**: Uses the Microsoft GS Wavetable Synth by default on Windows for low-latency feedback.
- **Dynamic Waterfall Visualization**: A smooth "cascade" view that renders notes with synchronized animations, adjustable height, and BPM control.
- **Advanced Styling System**:
    - **Coloring Modes**: Differentiation by key type (Black/White), split-point (Left/Right hand), or **Track ID**.
    - **Track Isolation**: Choose to show only the current track or all tracks simultaneously.
    - **Persistence**: Save and load custom style configurations (themes) using `shared_preferences`.
- **Session Management**: Full support for importing and exporting sessions as JSON files for later editing or playback.

## 🛠 Tech Stack
- **Framework**: [Flutter](https://flutter.dev) (Dart `^3.9.2`)
- **Audio**: `flutter_midi_pro` (FluidSynth-based playback) & `dart_midi_pro` (MIDI Parser).
- **State Management**: [Provider](https://pub.dev/packages/provider).
- **Persistence**: `shared_preferences` for application settings and style configs.
- **Packaging & Distribution**: `msix` package configured via `msix_config` in `pubspec.yaml` to generate signed Windows `.msix` installers.

## 🚀 Getting Started

### Prerequisites
- Flutter SDK (Dart `^3.9.2`)
- A MIDI-compatible device (Optional, but highly recommended for recording)

### Installation & Building Releases
1. **Clone the repository**:
   ```bash
   git clone https://github.com/Thomas/synthesia.git
   cd synthesia
   ```
2. **Install dependencies**:
   ```bash
   flutter pub get
   ```
3. **Run the application**:
   ```bash
   # For Windows
   flutter run -d windows
   
   # For Android
   flutter run -d android
   ```

## ⌨️ Keyboard Shortcuts
Maximize your productivity with these built-in shortcuts:

| Shortcut | Action |
|----------|--------|
| **Playback & System** | |
| `P` | Toggle Play/Stop music |
| `Esc` | **Panic Button**: Stop all active MIDI notes |
| `Ctrl + M` | Re-initialize MIDI connection |
| `Ctrl + F` | Load a custom SoundFont (`.sf2`) |
| **File Operations** | |
| `Ctrl + S` | Save current session to file |
| `Ctrl + O` | Import session file |
| `Ctrl + Del`| Clear entire session |
| **Edition** | |
| `A` | Toggle Chord Mode (Manual edit) |
| `Space` | Add 1 unit of silence |
| `Backspace`| Remove last unit of silence |
| `Del` | Delete the last recorded/added note |
| `V` | Toggle "Show All Tracks" in edit mode |
| `U` | Toggle Auto-Silence detection |
| **Styling** | |
| `T` | Open Style Customization Menu |

---

<a name="français"></a>
## 🇫🇷 Version Française

Une interface personnalisée de lecture et d'enregistrement de piano basée sur Flutter, avec prise en charge MIDI, lecture SoundFont haute qualité et visualisation avancée.

## 🎹 Présentation
Synthesia est une application interactive de piano à 88 touches conçue pour créer, enregistrer et rejouer des cascades de notes de type "waterfall". Elle fait le pont entre la création manuelle note par note et l'enregistrement MIDI en temps réel.

Développée avec **Flutter**, elle fonctionne sur **Windows** (idéal pour la connexion de pianos numériques et l'enregistrement MIDI) et **Android** (pour la pratique nomade).

---

## 📦 Versions & Distribution
Vous trouverez les dernières versions stables sur la page [GitHub Releases](https://github.com/Thomas/synthesia/releases) :

- **[Android v1.0.0](https://github.com/Thomas/synthesia/releases/tag/android-v1.0.0)** : Téléchargez l'APK pour Android.
- **[Windows v1.0.0](https://github.com/Thomas/synthesia/releases/tag/windows-v1.0.0)** : Téléchargez l'installateur `.msix` signé pour Windows. *Recommandé pour relier un piano numérique en USB/MIDI.*

---

## ✨ Fonctionnalités Clés
- **Clavier 88 touches** : Clavier réactif avec retour couleur dynamique et mapping MIDI.
- **Modes de Création Multiples** :
    - **Enregistrement MIDI** : Branchez un piano (USB/MIDI) pour enregistrer en direct avec détection d'accords et gestion des silences.
    - **Édition Manuelle** : Ajoutez, modifiez ou supprimez des notes et silences via l'interface ou les raccourcis clavier.
- **Moteur Audio Haute Qualité** :
    - **SoundFont (.sf2)** : Chargez vos propres banques de sons (Grand Piano inclus par défaut).
- **Visualisation Waterfall Dynamique** : Vue en cascade fluide avec animations synchronisées et réglage BPM.
- **Système de Style Avancé** : Personnalisation des couleurs par type de touche, main (gauche/droite) ou ID de piste avec persistance (`shared_preferences`).
- **Gestion de Sessions** : Importation et exportation de sessions au format JSON.

## 🛠 Stack Technique
- **Framework** : [Flutter](https://flutter.dev) (Dart `^3.9.2`)
- **Audio** : `flutter_midi_pro` & `dart_midi_pro`.
- **État** : [Provider](https://pub.dev/packages/provider).
- **Packaging & Distribution** : Package `msix` configuré via `msix_config` dans `pubspec.yaml` pour générer des installeurs Windows `.msix` signés.

## 🚀 Prise en Main

### Prérequis
- Flutter SDK (Dart `^3.9.2`)
- Appareil compatible MIDI (Optionnel)

### Installation & Génération des Builds
1. **Cloner le dépôt** :
   ```bash
   git clone https://github.com/Thomas/synthesia.git
   cd synthesia
   ```
2. **Installer les dépendances** :
   ```bash
   flutter pub get
   ```
3. **Script de build automatisé** :
   ```bash
   # Pour Windows
   flutter run -d windows
   
   # Pour Android
   flutter run -d android
   ```

## ⌨️ Raccourcis Clavier Principaux
| Raccourci | Action |
|---|---|
| `P` | Lecture / Pause |
| `Esc` | Bouton d'urgence (Couper toutes les notes MIDI) |
| `Ctrl + M` | Réinitialiser la connexion MIDI |
| `Ctrl + F` | SoundFont (`.sf2`) |
| `Ctrl + S` | Sauvegarder la session |
| `Ctrl + O` | Importer une session |
| `T` | Menu de personnalisation des styles |

---

## 📜 Licence
Distribué sous licence **CC0 1.0 Universal (Public Domain)**. Voir le fichier `LICENSE`.

---
*Développé avec ❤️ pour les musiciens.*
