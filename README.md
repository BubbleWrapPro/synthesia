# Synthesia

A custom Flutter-based piano learning and recording interface with MIDI support.

## 🎹 Overview
Synthesia is an interactive 88-key piano application designed for creating, recording, and replaying "waterfall" style note cascades. It bridges the gap between manual note-by-note creation and real-time MIDI recording, offering a highly customizable visual experience for musicians and developers alike.

## ✨ Key Features
- **88-Key Piano Interface**: Responsive keyboard with dynamic color feedback and MIDI input mapping.
- **Dual Creation Modes**:
    - **MIDI Recording**: Connect a digital piano to record notes in real-time with automatic chord detection and smart silence handling (Windows only)
    - **Manual Editing**: Add, modify, or delete notes and silences manually via the UI.
- **Dynamic Waterfall Visualization**: A smooth "cascade" view that renders notes with depth, borders, and synchronized animations.
- **Advanced Styling System**:
    - **Differentiation Modes**: Color notes by key type (Black/White), split-point (Left/Right hand), or use solid colors.
    - **Global Textures**: Apply interactive, rotatable gradients across the entire waterfall view using `ShaderMask`.
    - **Per-Note Overrides**: Manually color individual notes to highlight specific passages or melodies.
- **Session Management**: Full support for importing and exporting sessions as JSON files.
- **Playback Engine**: Replay your recordings with synchronized visual key-press feedback on the virtual piano.

## 🛠 Tech Stack
- **Framework**: [Flutter](https://flutter.dev) (Cross-platform)
- **State Management**: [Provider](https://pub.dev/packages/provider)
- **Persistence**: `shared_preferences` for application settings and style configs.
- **File I/O**: `file_selector` and `path_provider` for robust document management.
- **MIDI Integration**: Native `MethodChannel` for high-performance device communication.

## 🚀 Getting Started

### Prerequisites
- Flutter SDK (latest stable version)
- A MIDI-compatible device (Optional, for recording features)

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
   flutter run
   ```

## ⌨️ Keyboard Shortcuts
Maximize your productivity with these built-in shortcuts:

| Shortcut | Action |
|----------|--------|
| `P` | Toggle Play/Stop music |
| `Ctrl + S` | Save current session to file |
| `Ctrl + O` | Import session file |
| `Ctrl + Del`| Clear entire session |
| `A` | Toggle Chord Mode (Manual edit) |
| `Space` | Add 1 unit of silence |
| `Backspace`| Remove last unit of silence |
| `T` | Open Style Customization Menu |

## 🎨 Architecture
The project follows a modular, reactive architecture using the Provider pattern:

- **Models**: 
    - `NoteModel`: Core data structure for notes, including timing, pitch, and styling.
    - `StyleConfig`: Defines global coloring rules, gradients, and differentiation modes.
- **Providers**: 
    - `SessionProvider`: Orchestrates MIDI listeners, recording logic, sequencer playback, and file operations.
    - `StyleProvider`: Manages visual themes and handles the logic for dynamic color assignment.
- **Widgets**:
    - `CascadeView`: Custom painter/stack logic for rendering the waterfall visualization.
    - `PianoKeyboard`: A layered keyboard widget that separates base keys from active visual overlays.
    - `ControlPanel`: The primary interface for real-time settings (BPM, Height, MIDI options).

## 🤝 Contributing
Contributions make the open-source community an amazing place to learn, inspire, and create. Any contributions you make are **greatly appreciated**.

1. Fork the Project
2. Create your Feature Branch (`git checkout -b feature/AmazingFeature`)
3. Commit your Changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the Branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

## 📜 License
Distributed under the **CC0 1.0 Universal (Public Domain)**. See `LICENSE` for the full legal text.

---
*Developed with ❤️ for musicians.*
