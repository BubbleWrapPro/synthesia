import 'package:flutter/material.dart';

class NoteModel {
  final int keyIndex;       // 0 to 87 (Which piano key)
  double height;      // Duration/Height of the rect
  final Color color;        // Green (white key) or Blue (black key)
  final String chordId;     // To group notes in "Mode Accord"
  final bool isSilence;     // Special flag for Silence

  // Mutable for playback animation (current Y position)
  double currentOffset;

  NoteModel({
    required this.keyIndex,
    required this.height,
    required this.color,
    required this.chordId,
    this.isSilence = false,
    this.currentOffset = 0.0,
  });

  // Convert to JSON for "Sauvegarder"
  Map<String, dynamic> toJson() => {
    'keyIndex': keyIndex,
    'height': height,
    'color': color.value,
    'chordId': chordId,
    'isSilence': isSilence,
  };

  // Create from JSON for "Importer"
  factory NoteModel.fromJson(Map<String, dynamic> json) {
    return NoteModel(
      keyIndex: json['keyIndex'],
      height: json['height'],
      color: Color(json['color']),
      chordId: json['chordId'],
      isSilence: json['isSilence'] ?? false,
    );
  }
}