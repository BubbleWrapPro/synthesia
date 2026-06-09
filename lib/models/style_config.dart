import 'package:flutter/material.dart';

enum DifferentiationMode { none, blackWhite, split }

class StyleConfig {
  final String name;
  final DifferentiationMode mode;
  final int splitKey;
  final Color colorA; // Primary / White / Left
  final Color colorB; // Secondary / Black / Right
  
  final bool useGradient;
  final List<Color> gradientColors;
  final double gradientAngle; // In degrees

  StyleConfig({
    required this.name,
    this.mode = DifferentiationMode.blackWhite,
    this.splitKey = 39, // Middle C (approx)
    this.colorA = Colors.lightGreen,
    this.colorB = Colors.blue,
    this.useGradient = false,
    this.gradientColors = const [Colors.purple, Colors.blue],
    this.gradientAngle = 0.0,
  });

  Map<String, dynamic> toJson() => {
    'name': name,
    'mode': mode.index,
    'splitKey': splitKey,
    'colorA': colorA.toARGB32(),
    'colorB': colorB.toARGB32(),
    'useGradient': useGradient,
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
      useGradient: json['useGradient'] ?? false,
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
    bool? useGradient,
    List<Color>? gradientColors,
    double? gradientAngle,
  }) {
    return StyleConfig(
      name: name ?? this.name,
      mode: mode ?? this.mode,
      splitKey: splitKey ?? this.splitKey,
      colorA: colorA ?? this.colorA,
      colorB: colorB ?? this.colorB,
      useGradient: useGradient ?? this.useGradient,
      gradientColors: gradientColors ?? this.gradientColors,
      gradientAngle: gradientAngle ?? this.gradientAngle,
    );
  }
}
