import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/session_provider.dart';
import '../providers/style_provider.dart';

class PianoKeyboard extends StatelessWidget {
  const PianoKeyboard({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<SessionProvider>(context);
    final style = Provider.of<StyleProvider>(context);
    final config = style.currentConfig;

    return LayoutBuilder(
      builder: (context, constraints) {
        final double whiteKeyWidth = constraints.maxWidth / 52;
        final double blackKeyWidth = whiteKeyWidth * 0.6;
        final double blackKeyHeight = constraints.maxHeight * 0.6;

        List<Widget> whiteBase = [];
        List<Widget> blackBase = [];
        List<Widget> whiteOverlays = [];
        List<Widget> blackOverlays = [];

        int whiteKeyCounter = 0;
        for (int i = 0; i < 88; i++) {
          bool isBlack = _isBlackKey(i);
          double left;
          double width;
          double? height;

          if (!isBlack) {
            left = whiteKeyCounter * whiteKeyWidth;
            width = whiteKeyWidth;
            whiteKeyCounter++;
          } else {
            // Black key is centered on the line between current white key gap
            left = (whiteKeyCounter * whiteKeyWidth) - (blackKeyWidth / 2);
            width = blackKeyWidth;
            height = blackKeyHeight;
          }

          final keyWidget = Positioned(
            left: left,
            top: 0,
            bottom: height == null ? 0 : null,
            height: height,
            width: width,
            child: _buildBaseKey(context, i, isBlack, provider),
          );

          if (isBlack) {
            blackBase.add(keyWidget);
          } else {
            whiteBase.add(keyWidget);
          }

          // 2. Active Overlay (The "Pressed" visual)
          Color? activeColor = _getActiveColor(i, provider, style);
          if (activeColor != null) {
            final overlayWidget = Positioned(
              left: left,
              top: 0,
              bottom: height == null ? 0 : null,
              height: height,
              width: width,
              child: _buildActiveOverlay(activeColor, config),
            );
            if (isBlack) {
              blackOverlays.add(overlayWidget);
            } else {
              whiteOverlays.add(overlayWidget);
            }
          }
        }

        // Layering: White keys (base + overlay) then Black keys (base + overlay)
        // This ensures black keys are never covered by white keys.
        Widget activeLayer = Stack(children: [...whiteOverlays, ...blackOverlays]);

        // Apply Global Gradient to active layer if enabled
        if (config.useGradient && (whiteOverlays.isNotEmpty || blackOverlays.isNotEmpty)) {
          double angleRad = (config.gradientAngle - 90) * 3.14159 / 180;
          activeLayer = ShaderMask(
            shaderCallback: (bounds) {
              return LinearGradient(
                begin: Alignment(math.cos(angleRad + 3.14159), math.sin(angleRad + 3.14159)),
                end: Alignment(math.cos(angleRad), math.sin(angleRad)),
                colors: config.gradientColors,
              ).createShader(bounds);
            },
            blendMode: BlendMode.srcIn,
            child: activeLayer,
          );
        }

        return Container(
          color: Colors.grey[900],
          child: Stack(
            children: [
              ...whiteBase,
              ...blackBase,
              activeLayer,
            ],
          ),
        );
      },
    );
  }

  Color? _getActiveColor(int index, SessionProvider provider, StyleProvider style) {
    // Priority 1: MIDI / Manual active keys
    if (provider.activeKeys.contains(index)) {
      return style.getColorForNote(index);
    }

    // Priority 2: Playback active notes
    if (provider.isPlaying) {
      final double pixelRatio = 100.0; // Dummy but consistency doesn't strictly need it for color pick
      for (var note in provider.activeFallingNotes) {
        if (note.keyIndex == index) {
          double noteTop = note.currentOffset + (note.height * pixelRatio);
          // Check if hitting keyboard (0)
          // Since we just need the color, the logic is simplified
          if (note.currentOffset <= 0 && noteTop >= 0) {
            return note.overrideColor ?? style.getColorForNote(index);
          }
        }
      }
    }
    return null;
  }

  Widget _buildBaseKey(BuildContext context, int index, bool isBlack, SessionProvider provider) {
    return Material(
      color: isBlack ? Colors.black : Colors.white,
      shape: RoundedRectangleBorder(
          side: const BorderSide(color: Colors.black, width: 0.5),
          borderRadius: const BorderRadius.only(
              bottomLeft: Radius.circular(4),
              bottomRight: Radius.circular(4)
          )
      ),
      child: InkWell(
        onTap: () => provider.addNote(index, isBlack),
      ),
    );
  }

  Widget _buildActiveOverlay(Color color, dynamic config) {
    return Container(
      decoration: BoxDecoration(
        color: color,
        // Replicate tile decoration logic from CascadeView
        gradient: config.useGradient ? null : LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            color.withValues(alpha: 0.9),
            color,
            color.withValues(alpha: 0.85),
          ],
          stops: const [0.0, 0.4, 1.0],
        ),
        border: Border.all(color: Colors.white24, width: 0.5),
        borderRadius: const BorderRadius.only(
            bottomLeft: Radius.circular(4),
            bottomRight: Radius.circular(4)
        ),
      ),
      // Optional: Add the "bottom bar" like in CascadeView?
      // For the keyboard, maybe it's cleaner without it, or at the top.
    );
  }

  bool _isBlackKey(int index) {
    int n = (index + 9) % 12;
    return [1, 3, 6, 8, 10].contains(n);
  }
}