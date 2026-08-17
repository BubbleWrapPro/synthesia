import 'package:flutter/material.dart';

enum DifferentiationMode { none, blackWhite, split, byTrack, gradient }

class StyleConfig {
  final String name;
  final DifferentiationMode mode;
  final int splitKey;
  final Color colorA; // Primary / White / Left
  final Color colorB; // Secondary / Black / Right
  final Map<int, Color> trackColors; // [NEW] Mode par piste
  final bool darkenBlackKeysByTrack; // [NEW] Assombrir les touches noires en mode piste
  
  final List<Color> gradientColors;
  final double gradientAngle; // In degrees

  StyleConfig({
    required this.name,
    this.mode = DifferentiationMode.blackWhite,
    this.splitKey = 39, // Middle C (approx)
    this.colorA = Colors.lightGreen,
    this.colorB = Colors.blue,
    this.trackColors = const {},
    this.darkenBlackKeysByTrack = false,
    this.gradientColors = const [Colors.purple, Colors.blue],
    this.gradientAngle = 0.0,
  });

  Map<String, dynamic> toJson() => {
    'name': name,
    'mode': mode.index,
    'splitKey': splitKey,
    'colorA': colorA.toARGB32(),
    'colorB': colorB.toARGB32(),
    'trackColors': trackColors.map((k, v) => MapEntry(k.toString(), v.toARGB32())),
    'darkenBlackKeysByTrack': darkenBlackKeysByTrack,
    'gradientColors': gradientColors.map((c) => c.toARGB32()).toList(),
    'gradientAngle': gradientAngle,
  };

  factory StyleConfig.fromJson(Map<String, dynamic> json) {
    return StyleConfig(
      name: json['name'],
      mode: DifferentiationMode.values[json['mode']],
      splitKey: json['splitKey'],
      colorA: Color(json['colorA']),
      colorB: Color(json['colorB']),
      trackColors: (json['trackColors'] as Map?)?.map((k, v) => MapEntry(int.parse(k), Color(v))) ?? {},
      darkenBlackKeysByTrack: json['darkenBlackKeysByTrack'] ?? false,
      gradientColors: (json['gradientColors'] as List?)
          ?.map((c) => Color(c as int))
          .toList() ?? const [Colors.purple, Colors.blue],
      gradientAngle: (json['gradientAngle'] as num?)?.toDouble() ?? 0.0,
    );
  }

  StyleConfig copyWith({
    String? name,
    DifferentiationMode? mode,
    int? splitKey,
    Color? colorA,
    Color? colorB,
    Map<int, Color>? trackColors,
    bool? darkenBlackKeysByTrack,
    List<Color>? gradientColors,
    double? gradientAngle,
  }) {
    return StyleConfig(
      name: name ?? this.name,
      mode: mode ?? this.mode,
      splitKey: splitKey ?? this.splitKey,
      colorA: colorA ?? this.colorA,
      colorB: colorB ?? this.colorB,
      trackColors: trackColors ?? this.trackColors,
      darkenBlackKeysByTrack: darkenBlackKeysByTrack ?? this.darkenBlackKeysByTrack,
      gradientColors: gradientColors ?? this.gradientColors,
      gradientAngle: gradientAngle ?? this.gradientAngle,
    );
  }
}
