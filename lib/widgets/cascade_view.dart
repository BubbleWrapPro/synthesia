import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:provider/provider.dart';
import '../providers/session_provider.dart';
import '../providers/style_provider.dart';
import '../models/note_model.dart';
import '../models/style_config.dart';

class CascadeView extends StatelessWidget {
  const CascadeView({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<SessionProvider>(context);
    final style = Provider.of<StyleProvider>(context);
    final double screenHeight = MediaQuery.of(context).size.height;
    final config = style.currentConfig;

    return Listener(
      onPointerSignal: (pointerSignal) {
        if (pointerSignal is PointerScrollEvent) {
          provider.handleScroll(pointerSignal.scrollDelta.dy, screenHeight);
        }
      },
      child: LayoutBuilder(
        builder: (context, constraints) {
          return GestureDetector(
            onTapDown: provider.isPlaying ? null : (details) {
              _handleTap(context, details.localPosition, constraints, provider, style, screenHeight);
            },
            child: RepaintBoundary(
              child: CustomPaint(
                size: Size(constraints.maxWidth, constraints.maxHeight),
                painter: CascadeViewPainter(
                  provider: provider,
                  style: style,
                  config: config,
                  screenHeight: screenHeight,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  void _handleTap(BuildContext context, Offset localPos, BoxConstraints constraints, SessionProvider provider, StyleProvider style, double screenHeight) {
    final double whiteKeyWidth = constraints.maxWidth / 52;
    final double blackKeyWidth = whiteKeyWidth * 0.6;
    final double pixelRatio = screenHeight / 8.0;

    final session = provider.session;
    List<NoteModel> notesToCheck = session.where((n) => provider.showAllTracksInEdit || n.trackId == provider.currentTrackId).toList();

    for (var note in notesToCheck) {
      if (note.isSilence) continue;

      bool isBlack = _isBlackKey(note.keyIndex);
      double width = isBlack ? blackKeyWidth : whiteKeyWidth;
      double left = _calculateLeftPos(note.keyIndex, whiteKeyWidth, blackKeyWidth);
      double height = note.height * pixelRatio;

      double bottomPos = (note.currentOffset * pixelRatio) - provider.editScrollOffset;
      
      // Rect from bottom-left corner
      Rect rect = Rect.fromLTWH(left, constraints.maxHeight - bottomPos - height, width, height);

      if (rect.contains(localPos)) {
        _showEditDialog(context, provider, note);
        return;
      }
    }
  }

  double _calculateLeftPos(int keyIndex, double whiteW, double blackW) {
    int whiteKeyCount = 0;
    for(int i=0; i<keyIndex; i++) {
      if(!_isBlackKey(i)) whiteKeyCount++;
    }
    if (!_isBlackKey(keyIndex)) {
      return whiteKeyCount * whiteW;
    } else {
      return (whiteKeyCount * whiteW) - (blackW / 2);
    }
  }

  bool _isBlackKey(int index) {
    int n = (index + 9) % 12;
    return [1, 3, 6, 8, 10].contains(n);
  }

  void _showEditDialog(BuildContext context, SessionProvider prov, NoteModel note) {
    final heightCtrl = TextEditingController(text: note.height.toString());

    showDialog(context: context, builder: (_) => AlertDialog(
      title: const Text("Modifier la note"),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: heightCtrl,
            decoration: const InputDecoration(labelText: "Durée (Hauteur)"),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
          ),
          const SizedBox(height: 20),
          const Text("Couleur:"),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _colorBtn(context, note, Colors.green, prov),
              _colorBtn(context, note, Colors.blue, prov),
              _colorBtn(context, note, Colors.red, prov),
              _colorBtn(context, note, Colors.yellow, prov),
            ],
          ),
          if (note.overrideColor != null)
            TextButton(
              onPressed: () {
                prov.updateNote(note, note.height, null);
                Navigator.pop(context);
              },
              child: const Text("Réinitialiser la couleur"),
            ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () {
            prov.deleteNote(note); 
            Navigator.pop(context);
          },
          child: const Text("Supprimer", style: TextStyle(color: Colors.red)),
        ),
        TextButton(
          onPressed: () {
            double? newH = double.tryParse(heightCtrl.text);
            if(newH != null) prov.updateNote(note, newH, note.overrideColor);
            Navigator.pop(context);
          },
          child: const Text("Valider"),
        ),
      ],
    ));
  }

  Widget _colorBtn(BuildContext ctx, NoteModel note, Color c, SessionProvider prov) {
    return GestureDetector(
      onTap: () {
        prov.updateNote(note, note.height, c);
        Navigator.pop(ctx);
      },
      child: CircleAvatar(backgroundColor: c, radius: 15),
    );
  }
}

class CascadeViewPainter extends CustomPainter {
  final SessionProvider provider;
  final StyleProvider style;
  final StyleConfig config;
  final double screenHeight;

  CascadeViewPainter({
    required this.provider,
    required this.style,
    required this.config,
    required this.screenHeight,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Clip the canvas to ensure notes are only seen within this widget's bounds
    // (This is naturally handled by CustomPaint but explicit clip ensures it)
    canvas.clipRect(Offset.zero & size);
    
    // Fill background
    canvas.drawRect(Offset.zero & size, Paint()..color = Colors.black);

    final double whiteKeyWidth = size.width / 52;
    final double blackKeyWidth = whiteKeyWidth * 0.6;
    final double pixelRatio = screenHeight / 8.0;

    // 1. Draw Grid Lines
    final Paint gridPaint = Paint()..color = Colors.grey..strokeWidth = 1.0;
    for(int i=1; i<8; i++) {
      double cPos = (2 * whiteKeyWidth) + ((i - 1) * 7 * whiteKeyWidth);
      canvas.drawLine(Offset(cPos, 0), Offset(cPos, size.height), gridPaint);
    }

    // 2. Prepare Notes
    List<NoteModel> notesToDraw = provider.isPlaying 
        ? provider.activeFallingNotes 
        : provider.session.where((n) => provider.showAllTracksInEdit || n.trackId == provider.currentTrackId).toList();

    // Separate notes for gradient vs solid
    List<Rect> maskedRects = [];
    List<MapEntry<Rect, Color>> unmaskedRects = [];

    for (var note in notesToDraw) {
      if (note.isSilence) continue;

      bool isBlack = _isBlackKey(note.keyIndex);
      double width = isBlack ? blackKeyWidth : whiteKeyWidth;
      double left = _calculateLeftPos(note.keyIndex, whiteKeyWidth, blackKeyWidth);
      double height = note.height * pixelRatio;

      double bottomPos = provider.isPlaying
          ? note.currentOffset 
          : (note.currentOffset * pixelRatio) - provider.editScrollOffset;

      if (bottomPos > size.height || bottomPos + height < 0) continue;

      // Note coordinates: Flutter canvas (0,0) is top-left.
      // bottomPos is distance from bottom.
      Rect rect = Rect.fromLTWH(left, size.height - bottomPos - height, width, height);

      bool hasOverride = note.overrideColor != null;
      if (config.mode == DifferentiationMode.gradient && !hasOverride) {
        maskedRects.add(rect);
      } else {
        Color noteColor = note.overrideColor ?? style.getColorForNote(note.keyIndex, trackId: note.trackId);
        unmaskedRects.add(MapEntry(rect, noteColor));
      }
    }

    // 3. Draw Masked (Gradient) Notes
    if (maskedRects.isNotEmpty) {
      Paint gradientPaint = Paint()..style = PaintingStyle.fill;
      double angleRad = (config.gradientAngle - 90) * 3.14159 / 180;
      gradientPaint.shader = LinearGradient(
        begin: Alignment(math.cos(angleRad + 3.14159), math.sin(angleRad + 3.14159)),
        end: Alignment(math.cos(angleRad), math.sin(angleRad)),
        colors: config.gradientColors,
      ).createShader(Offset.zero & size);

      for (var rect in maskedRects) {
        _drawNoteTile(canvas, rect, gradientPaint);
      }
    }

    // 4. Draw Unmasked (Solid/Local Gradient) Notes
    for (var entry in unmaskedRects) {
      Paint notePaint = Paint()..style = PaintingStyle.fill;
      Color noteColor = entry.value;
      
      notePaint.shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          noteColor.withValues(alpha: 0.9),
          noteColor,
          noteColor.withValues(alpha: 0.85),
        ],
        stops: const [0.0, 0.4, 1.0],
      ).createShader(entry.key);

      _drawNoteTile(canvas, entry.key, notePaint);
    }
  }

  void _drawNoteTile(Canvas canvas, Rect rect, Paint paint) {
    RRect rRect = RRect.fromRectAndRadius(rect, const Radius.circular(1.5));
    canvas.drawRRect(rRect, paint);

    // Border
    Paint borderPaint = Paint()
      ..color = Colors.white24
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.5;
    canvas.drawRRect(rRect, borderPaint);

    // Bottom Bar (ensure separation)
    Paint barPaint = Paint()..color = Colors.black.withValues(alpha: 0.8)..style = PaintingStyle.fill;
    // Bottom bar is 2px at the bottom of the note
    Rect barRect = Rect.fromLTWH(rect.left, rect.bottom - 2.0, rect.width, 2.0);
    canvas.drawRect(barRect, barPaint);
  }

  double _calculateLeftPos(int keyIndex, double whiteW, double blackW) {
    int whiteKeyCount = 0;
    for(int i=0; i<keyIndex; i++) {
      if(!_isBlackKey(i)) whiteKeyCount++;
    }
    if (!_isBlackKey(keyIndex)) {
      return whiteKeyCount * whiteW;
    } else {
      return (whiteKeyCount * whiteW) - (blackW / 2);
    }
  }

  bool _isBlackKey(int index) {
    int n = (index + 9) % 12;
    return [1, 3, 6, 8, 10].contains(n);
  }

  @override
  bool shouldRepaint(covariant CascadeViewPainter oldDelegate) {
    return true; // Simplified for robustness, RepaintBoundary handles optimization
  }
}