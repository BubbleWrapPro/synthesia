import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/session_provider.dart';
import '../providers/style_provider.dart';
import '../models/style_config.dart';

class PianoKeyboard extends StatelessWidget {
  const PianoKeyboard({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<SessionProvider>(context);
    final style = Provider.of<StyleProvider>(context);
    final config = style.currentConfig;
    final screenHeight = MediaQuery.of(context).size.height;

    return LayoutBuilder(
      builder: (context, constraints) {
        final double whiteKeyWidth = constraints.maxWidth / 52;
        final double blackKeyWidth = whiteKeyWidth * 0.6;
        final double blackKeyHeight = constraints.maxHeight * 0.6;

        return GestureDetector(
          onTapDown: (details) {
            _handleTap(context, details.localPosition, constraints.maxWidth, constraints.maxHeight, provider);
          },
          child: CustomPaint(
            size: Size(constraints.maxWidth, constraints.maxHeight),
            painter: PianoKeyboardPainter(
              provider: provider,
              style: style,
              config: config,
              screenHeight: screenHeight,
              whiteKeyWidth: whiteKeyWidth,
              blackKeyWidth: blackKeyWidth,
              blackKeyHeight: blackKeyHeight,
            ),
          ),
        );
      },
    );
  }

  void _handleTap(BuildContext context, Offset localPos, double width, double height, SessionProvider provider) {
    final double whiteKeyWidth = width / 52;
    final double blackKeyWidth = whiteKeyWidth * 0.6;
    final double blackKeyHeight = height * 0.6;

    int? hitIndex;

    // Check black keys first (they are on top)
    if (localPos.dy <= blackKeyHeight) {
      int whiteKeyCounter = 0;
      for (int i = 0; i < 88; i++) {
        bool isBlack = _isBlackKey(i);
        if (isBlack) {
          double left = (whiteKeyCounter * whiteKeyWidth) - (blackKeyWidth / 2);
          Rect rect = Rect.fromLTWH(left, 0, blackKeyWidth, blackKeyHeight);
          if (rect.contains(localPos)) {
            hitIndex = i;
            break;
          }
        } else {
          whiteKeyCounter++;
        }
      }
    }

    // Check white keys if no black key was hit
    if (hitIndex == null) {
      int whiteKeyCounter = 0;
      for (int i = 0; i < 88; i++) {
        bool isBlack = _isBlackKey(i);
        if (!isBlack) {
          double left = whiteKeyCounter * whiteKeyWidth;
          Rect rect = Rect.fromLTWH(left, 0, whiteKeyWidth, height);
          if (rect.contains(localPos)) {
            hitIndex = i;
            break;
          }
          whiteKeyCounter++;
        }
      }
    }

    if (hitIndex != null) {
      provider.addNote(hitIndex, _isBlackKey(hitIndex), MediaQuery.of(context).size.height);
    }
  }

  bool _isBlackKey(int index) {
    int n = (index + 9) % 12;
    return [1, 3, 6, 8, 10].contains(n);
  }
}

class PianoKeyboardPainter extends CustomPainter {
  final SessionProvider provider;
  final StyleProvider style;
  final StyleConfig config;
  final double screenHeight;
  final double whiteKeyWidth;
  final double blackKeyWidth;
  final double blackKeyHeight;

  PianoKeyboardPainter({
    required this.provider,
    required this.style,
    required this.config,
    required this.screenHeight,
    required this.whiteKeyWidth,
    required this.blackKeyWidth,
    required this.blackKeyHeight,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final Paint whitePaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    final Paint blackPaint = Paint()
      ..color = Colors.black
      ..style = PaintingStyle.fill;
    final Paint borderPaint = Paint()
      ..color = Colors.black
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.5;

    // 1. Draw White Keys Base
    int whiteKeyCounter = 0;
    for (int i = 0; i < 88; i++) {
      if (!_isBlackKey(i)) {
        double left = whiteKeyCounter * whiteKeyWidth;
        Rect rect = Rect.fromLTWH(left, 0, whiteKeyWidth, size.height);
        _drawKey(canvas, rect, whitePaint, borderPaint, 4);
        whiteKeyCounter++;
      }
    }

    // 2. Draw Black Keys Base
    whiteKeyCounter = 0;
    for (int i = 0; i < 88; i++) {
      if (_isBlackKey(i)) {
        double left = (whiteKeyCounter * whiteKeyWidth) - (blackKeyWidth / 2);
        Rect rect = Rect.fromLTWH(left, 0, blackKeyWidth, blackKeyHeight);
        _drawKey(canvas, rect, blackPaint, borderPaint, 4);
      } else {
        whiteKeyCounter++;
      }
    }

    // 3. Draw Active Overlays
    _drawActiveOverlays(canvas, size);
  }

  void _drawKey(Canvas canvas, Rect rect, Paint fillPaint, Paint borderPaint, double radius) {
    RRect rRect = RRect.fromRectAndCorners(
      rect,
      bottomLeft: Radius.circular(radius),
      bottomRight: Radius.circular(radius),
    );
    canvas.drawRRect(rRect, fillPaint);
    canvas.drawRRect(rRect, borderPaint);
  }

  void _drawActiveOverlays(Canvas canvas, Size size) {
    List<MapEntry<int, Rect>> activeWhiteKeys = [];
    List<MapEntry<int, Rect>> activeBlackKeys = [];

    int whiteKeyCounter = 0;
    for (int i = 0; i < 88; i++) {
      bool isBlack = _isBlackKey(i);
      Color? activeColor = _getActiveColor(i);

      if (activeColor != null) {
        if (isBlack) {
          double left = (whiteKeyCounter * whiteKeyWidth) - (blackKeyWidth / 2);
          activeBlackKeys.add(MapEntry(i, Rect.fromLTWH(left, 0, blackKeyWidth, blackKeyHeight)));
        } else {
          double left = whiteKeyCounter * whiteKeyWidth;
          activeWhiteKeys.add(MapEntry(i, Rect.fromLTWH(left, 0, whiteKeyWidth, size.height)));
        }
      }

      if (!isBlack) whiteKeyCounter++;
    }

    if (activeWhiteKeys.isEmpty && activeBlackKeys.isEmpty) return;

    // Apply Gradient Shader if needed
    Shader? shader;
    if (config.mode == DifferentiationMode.gradient) {
      double angleRad = (config.gradientAngle - 90) * 3.14159 / 180;
      shader = LinearGradient(
        begin: Alignment(math.cos(angleRad + 3.14159), math.sin(angleRad + 3.14159)),
        end: Alignment(math.cos(angleRad), math.sin(angleRad)),
        colors: config.gradientColors,
      ).createShader(Offset.zero & size);
    }

    // Draw White Overlays
    for (var entry in activeWhiteKeys) {
      _drawOverlay(canvas, entry.value, _getActiveColor(entry.key)!, shader);
    }

    // Draw Black Overlays
    for (var entry in activeBlackKeys) {
      _drawOverlay(canvas, entry.value, _getActiveColor(entry.key)!, shader);
    }
  }

  void _drawOverlay(Canvas canvas, Rect rect, Color color, Shader? globalShader) {
    Paint paint = Paint()..style = PaintingStyle.fill;
    
    if (globalShader != null) {
      paint.shader = globalShader;
    } else {
      paint.shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          color.withValues(alpha: 0.9),
          color,
          color.withValues(alpha: 0.85),
        ],
        stops: const [0.0, 0.4, 1.0],
      ).createShader(rect);
    }

    RRect rRect = RRect.fromRectAndCorners(
      rect,
      bottomLeft: Radius.circular(4),
      bottomRight: Radius.circular(4),
    );
    canvas.drawRRect(rRect, paint);

    // Border for active key
    Paint borderPaint = Paint()
      ..color = Colors.white24
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.5;
    canvas.drawRRect(rRect, borderPaint);
  }

  Color? _getActiveColor(int index) {
    if (provider.activeKeys.contains(index)) {
      return style.getColorForNote(index, trackId: provider.currentTrackId);
    }

    if (provider.isPlaying) {
      final double pixelRatio = screenHeight / 8.0; 
      for (var note in provider.activeFallingNotes) {
        if (note.keyIndex == index) {
          double noteTop = note.currentOffset + (note.height * pixelRatio);
          if (note.currentOffset <= 0 && noteTop >= 0) {
            return note.overrideColor ?? style.getColorForNote(index, trackId: note.trackId);
          }
        }
      }
    }
    return null;
  }

  bool _isBlackKey(int index) {
    int n = (index + 9) % 12;
    return [1, 3, 6, 8, 10].contains(n);
  }

  @override
  bool shouldRepaint(covariant PianoKeyboardPainter oldDelegate) => true;
}