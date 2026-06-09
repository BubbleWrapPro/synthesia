import 'package:flutter/material.dart';

class NoteModel {
  final int keyIndex;       // 0 to 87 (Which piano key)
  double height;            // Duration/Height of the rect
  final Color color;        // Green (white key) or Blue (black key)
  Color? overrideColor;     // [NEW] Individual color override
  final String chordId;     // To group notes in "Mode Accord"
  final bool isSilence;     // Special flag for Silence
  final bool fromMidi;      // [NEW] True if recorded from real device

  // Mutable for playback animation (current Y position)
  double currentOffset;

  NoteModel({
    required this.keyIndex,
    required this.height,
    required this.color,
    this.overrideColor,
    required this.chordId,
    this.isSilence = false,
    this.fromMidi = false, // Default false
    this.currentOffset = 0.0,
  });

  // Convert to JSON
  Map<String, dynamic> toJson() => {
    'keyIndex': keyIndex,
    'height': height,
    'color': color.toARGB32(),
    'overrideColor': overrideColor?.toARGB32(),
    'chordId': chordId,
    'isSilence': isSilence,
    'fromMidi': fromMidi,
  };

  // Create from JSON
  factory NoteModel.fromJson(Map<String, dynamic> json) {
    return NoteModel(
      keyIndex: json['keyIndex'],
      height: json['height'],
      color: Color(json['color']),
      overrideColor: json['overrideColor'] != null ? Color(json['overrideColor']) : null,
      chordId: json['chordId'],
      isSilence: json['isSilence'] ?? false,
      fromMidi: json['fromMidi'] ?? false,
    );
  }
}