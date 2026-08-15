import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/session_provider.dart';
import '../providers/style_provider.dart';
import '../models/note_model.dart';

class CascadeView extends StatelessWidget {
  const CascadeView({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final provider = Provider.of<SessionProvider>(context);
          final style = Provider.of<StyleProvider>(context);
          final session = provider.session;
          final config = style.currentConfig;

          // Geometry constants matching PianoKeyboard
          final double whiteKeyWidth = constraints.maxWidth / 52;
          final double blackKeyWidth = whiteKeyWidth * 0.6;
          final double screenHeight = MediaQuery.of(context).size.height;
          final double pixelRatio = screenHeight / 8.0;

          List<Widget> tiles = [];

          // 1. Draw Grid Lines (Octave separators)
          // Octave width = 7 white keys
          for(int i=1; i<8; i++) {
            // Simplification: Just draw lines every 7 * whiteKeyWidth starting after A0/B0
            // Ideally, align with C1, C2, etc.
            double cPos = (2 * whiteKeyWidth) + ((i -1) * 7 * whiteKeyWidth);

            tiles.add(Positioned(
              left: cPos, top: 0, bottom: 0,
              child: Container(width: 1, color: Colors.grey),
            ));
          }

          // 2. Draw Notes
          List<NoteModel> notesToDraw = session;
          List<Widget> maskedNotes = [];
          List<Widget> unmaskedNotes = [];
          List<Widget> bottomBars = [];

          for (var note in notesToDraw) {
            // Silence logic: only show in Edit mode
            if (note.isSilence && provider.currentMode != AppMode.edit) continue;

            bool isBlack = _isBlackKey(note.keyIndex);
            double width = isBlack ? blackKeyWidth : whiteKeyWidth;
            double left = _calculateLeftPos(note.keyIndex, whiteKeyWidth, blackKeyWidth);
            double height = note.height * pixelRatio;

            // SCROLLING LOGIC: Subtract playbackPosition from currentOffset
            double bottomPos = (note.currentOffset - provider.playbackPosition) * pixelRatio;

            // Optimization: don't draw if outside screen
            if (bottomPos > constraints.maxHeight) continue;
            if (bottomPos + height < 0) continue;

            bool hasOverride = note.overrideColor != null;
            Color noteColor = note.isSilence 
                ? Colors.grey.withValues(alpha: 0.2) 
                : (note.overrideColor ?? style.getColorForNote(note.keyIndex));

            final noteTile = Positioned(
              left: left,
              bottom: bottomPos,
              width: width,
              height: height,
              child: GestureDetector(
                onTap: provider.isPlaying ? null : () => _showEditDialog(context, provider, note),
                child: Container(
                  decoration: BoxDecoration(
                    color: noteColor,
                    gradient: (config.useGradient && !hasOverride && !note.isSilence) ? null : LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        noteColor.withValues(alpha: 0.9),
                        noteColor,
                        noteColor.withValues(alpha: 0.85),
                      ],
                      stops: const [0.0, 0.4, 1.0],
                    ),
                    border: Border.all(
                      color: note.isSilence ? Colors.white10 : Colors.white24, 
                      width: 0.5,
                      style: note.isSilence ? BorderStyle.solid : BorderStyle.solid,
                    ),
                    borderRadius: BorderRadius.circular(1.5),
                  ),
                  child: note.isSilence 
                    ? const Center(child: Icon(Icons.music_off, size: 12, color: Colors.white24))
                    : null,
                ),
              ),
            );

            // Separate notes for masking
            if (config.useGradient && !hasOverride && !note.isSilence) {
              maskedNotes.add(noteTile);
            } else {
              unmaskedNotes.add(noteTile);
            }

            // Always add a bottom bar (except for silence)
            if (!note.isSilence) {
              bottomBars.add(Positioned(
                left: left,
                bottom: bottomPos,
                width: width,
                child: IgnorePointer(
                  child: Container(
                    height: 2.0,
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.8),
                      borderRadius: const BorderRadius.vertical(bottom: Radius.circular(1.5)),
                    ),
                  ),
                ),
              ));
            }
          }

          Widget maskedLayer = Stack(children: maskedNotes);

          if (config.useGradient && maskedNotes.isNotEmpty) {
            double angleRad = (config.gradientAngle - 90) * 3.14159 / 180;
            maskedLayer = ShaderMask(
              shaderCallback: (bounds) {
                return LinearGradient(
                  begin: Alignment(math.cos(angleRad + 3.14159), math.sin(angleRad + 3.14159)),
                  end: Alignment(math.cos(angleRad), math.sin(angleRad)),
                  colors: config.gradientColors,
                ).createShader(bounds);
              },
              blendMode: BlendMode.srcIn,
              child: maskedLayer,
            );
          }

          tiles.add(Positioned.fill(child: Stack(children: [
            maskedLayer,
            ...unmaskedNotes,
            ...bottomBars,
          ])));

          return Stack(children: tiles);
        },
      ),
    );
  }

  // Exact logic to match PianoKeyboard
  double _calculateLeftPos(int keyIndex, double whiteW, double blackW) {
    int whiteKeyCount = 0;
    for(int i=0; i<keyIndex; i++) {
      if(!_isBlackKey(i)) whiteKeyCount++;
    }

    if (!_isBlackKey(keyIndex)) {
      return whiteKeyCount * whiteW;
    } else {
      // Black keys are centered on the line between two white keys
      // Shift left by half a black key width relative to the "gap"
      return (whiteKeyCount * whiteW) - (blackW / 2);
    }
  }

  bool _isBlackKey(int index) {
    int n = (index + 9) % 12;
    return [1, 3, 6, 8, 10].contains(n);
  }

  // README: "Un clic ouvre une interface permettant de modifier la durée, la couleur, ou de la supprimer"
  void _showEditDialog(BuildContext context, SessionProvider prov, NoteModel note) {
    final heightCtrl = TextEditingController(text: note.height.toString());

    showDialog(context: context, builder: (_) => AlertDialog(
      title: Text("Modifier la note"),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: heightCtrl,
            decoration: InputDecoration(labelText: "Durée (Hauteur)"),
            keyboardType: TextInputType.numberWithOptions(decimal: true),
          ),
          SizedBox(height: 20),
          Text("Couleur:"),
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
          child: Text("Supprimer", style: TextStyle(color: Colors.red)),
        ),
        TextButton(
          onPressed: () {
            double? newH = double.tryParse(heightCtrl.text);
            if(newH != null) prov.updateNote(note, newH, note.overrideColor);
            Navigator.pop(context);
          },
          child: Text("Valider"),
        ),
      ],
    ));
  }

  Widget _colorBtn(BuildContext ctx, NoteModel note, Color c, SessionProvider prov) {
    return GestureDetector(
      onTap: () {
        prov.updateNote(note, note.height, c);
        Navigator.pop(ctx); // Close after color pick? Or stay open.
      },
      child: CircleAvatar(backgroundColor: c, radius: 15),
    );
  }
}