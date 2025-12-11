#include "flutter_window.h"

#include <optional>

#include "flutter/generated_plugin_registrant.h"

#include <mmsystem.h> // Required for MIDI API


// 1. The Callback (Adapted from Freepiano's midi_input_callback)
// Freepiano uses a callback to process MIM_DATA. We do the same but post it to the UI thread.
void CALLBACK FlutterWindow::MidiInProc(HMIDIIN hMidiIn, UINT wMsg, DWORD_PTR dwInstance, DWORD_PTR dwParam1, DWORD_PTR dwParam2) {
if (wMsg == MIM_DATA) {
FlutterWindow* window = reinterpret_cast<FlutterWindow*>(dwInstance);
// MIDI callbacks run on a background thread.
// We must PostMessage to the main UI thread to safely talk to Flutter.
PostMessage(window->GetHandle(), WM_MIDI_DATA, dwParam1, dwParam2);
}
}


// 2. Start MIDI (Adapted from Freepiano's midi_open_inputs)
void FlutterWindow::StartMidiInput() {
    int numDevs = midiInGetNumDevs();
    if (numDevs > 0) {
        // Open the first available device (0) for simplicity
        // Freepiano iterates all devices, but here we just grab the first one.
        MMRESULT result = midiInOpen(&hMidiIn, 0, (DWORD_PTR)MidiInProc, (DWORD_PTR)this, CALLBACK_FUNCTION);
        if (result == MMSYSERR_NOERROR) {
            midiInStart(hMidiIn);
        }
    }
}

FlutterWindow::FlutterWindow(const flutter::DartProject& project)
    : project_(project) {}

FlutterWindow::~FlutterWindow() {}

bool FlutterWindow::OnCreate() {
  if (!Win32Window::OnCreate()) {
    return false;
  }

  RECT frame = GetClientArea();

  // The size here must match the window dimensions to avoid unnecessary surface
  // creation / destruction in the startup path.
  flutter_controller_ = std::make_unique<flutter::FlutterViewController>(
      frame.right - frame.left, frame.bottom - frame.top, project_);
  // Ensure that basic setup of the controller was successful.
  if (!flutter_controller_->engine() || !flutter_controller_->view()) {
    return false;
  }
  RegisterPlugins(flutter_controller_->engine());
  SetChildContent(flutter_controller_->view()->GetNativeWindow());

  channel_ = std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
          flutter_controller_->engine()->messenger(), "com.synthesia.midi",
          &flutter::StandardMethodCodec::GetInstance());

  // Start listening to the Piano
  StartMidiInput();

  SetChildContent(flutter_controller_->view()->GetNativeWindow());


  flutter_controller_->engine()->SetNextFrameCallback([&]() {
    this->Show();
  });

  // Flutter can complete the first frame before the "show window" callback is
  // registered. The following call ensures a frame is pending to ensure the
  // window is shown. It is a no-op if the first frame hasn't completed yet.
  flutter_controller_->ForceRedraw();

  return true;
}

void FlutterWindow::OnDestroy() {
  if (flutter_controller_) {
    flutter_controller_ = nullptr;
  }

  Win32Window::OnDestroy();
}

LRESULT
FlutterWindow::MessageHandler(HWND hwnd, UINT const message,
                              WPARAM const wparam,
                              LPARAM const lparam) noexcept {
  if (message == WM_MIDI_DATA) {
    DWORD midiData = (DWORD)wparam;
    int status = midiData & 0xFF;
    int note = (midiData >> 8) & 0xFF;
    int velocity = (midiData >> 16) & 0xFF;

    // Freepiano Logic: Check for Note ON (0x90) and Velocity > 0
    if ((status & 0xF0) == 0x90 && velocity > 0) {
        channel_->InvokeMethod("onNoteOn", std::make_unique<flutter::EncodableValue>(note));
    }
    // Détection Note OFF (Relâchement)
    // En MIDI, NoteOff peut être 0x80 OU NoteOn(0x90) avec vélocité 0
    else if ((status & 0xF0) == 0x80 || ((status & 0xF0) == 0x90 && velocity == 0)) {
        channel_->InvokeMethod("onNoteOff", std::make_unique<flutter::EncodableValue>(note));
    }

  }



  // Give Flutter, including plugins, an opportunity to handle window messages.
  if (flutter_controller_) {
    std::optional<LRESULT> result =
        flutter_controller_->HandleTopLevelWindowProc(hwnd, message, wparam,
                                                      lparam);
    if (result) {
      return *result;
    }
  }

  switch (message) {
    case WM_FONTCHANGE:
      flutter_controller_->engine()->ReloadSystemFonts();
      break;
  }



  return Win32Window::MessageHandler(hwnd, message, wparam, lparam);
}


