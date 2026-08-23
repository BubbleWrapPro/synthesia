package com.synthesia.synthesia

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity: FlutterActivity() {
    private val CHANNEL = "com.synthesia.midi"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "playMidiNote" -> {
                    // Mobile MIDI playback handled in Dart via flutter_midi_pro
                    result.success(null)
                }
                "stopMidiNote" -> {
                    result.success(null)
                }
                "setWindowTitle" -> {
                    // Title update not applicable on Android
                    result.success(null)
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }
}
