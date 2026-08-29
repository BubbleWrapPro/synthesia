# Synthesia

A custom Flutter-based piano learning and recording interface with MIDI support, high-quality SoundFont playback, and advanced visualization.

## 🎹 Overview
Synthesia is an interactive 88-key piano application designed for creating, recording, and replaying "waterfall" style note cascades. It bridges the gap between manual note-by-note creation and real-time MIDI recording, offering a highly customizable visual experience for musicians and developers alike.

Built with **Flutter**, it runs seamlessly on both **Windows** (for advanced MIDI recording and piano connection) and **Android** (for portable practice).

---

## 📦 Releases
You can find the latest stable versions on the [GitHub Releases](https://github.com/Thomas/synthesia/releases) page:

- **[Android v1.0.0](https://github.com/Thomas/synthesia/releases/tag/android-v1.0.0)**: Download the `.apk` for Android devices.
- **[Windows v1.0.0](https://github.com/Thomas/synthesia/releases/tag/windows-v1.0.0)**: Download the `.msix` installer for Windows. *Recommended for connecting physical digital pianos via USB/MIDI.*

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
- **Framework**: [Flutter](https://flutter.dev)
- **Audio**: `flutter_midi_pro` (FluidSynth-based playback) & `dart_midi_pro` (MIDI Parser).
- **State Management**: [Provider](https://pub.dev/packages/provider).
- **Persistence**: `shared_preferences` for application settings and style configs.
- **Packaging**: `msix` for Windows distribution.

## 🚀 Getting Started

### Prerequisites
- Flutter SDK (latest stable version)
- A MIDI-compatible device (Optional, but highly recommended for recording)

### Installation
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

## 📜 License
Distributed under the **CC0 1.0 Universal (Public Domain)**. See `LICENSE` for the full legal text.

---
*Developed with ❤️ for musicians.*
