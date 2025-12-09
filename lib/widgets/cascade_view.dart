import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/session_provider.dart';
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
          final session = provider.session;

          // Geometry constants matching PianoKeyboard
          final double whiteKeyWidth = constraints.maxWidth / 52;
          final double blackKeyWidth = whiteKeyWidth * 0.6;
          final double screenHeight = MediaQuery.of(context).size.height;
          // README: Hauteur utilisateur 1 = 1/8 hauteur écran
          final double pixelRatio = screenHeight / 8.0;

          List<Widget> tiles = [];

          // 1. Draw Grid Lines (Octave separators)
          // Octave width = 7 white keys
          for(int i=1; i<8; i++) {
            // 7 white keys * width + offset for A0, B0 (2 keys)
            double left = (2 * whiteKeyWidth) + ((i - 1) * 7 * whiteKeyWidth);
            if (i == 1) {
              left = 2 * whiteKeyWidth; // Correction for first octave start
            } else {
              left = (2 * whiteKeyWidth) + ((i - 1) * 7 * whiteKeyWidth);
            }

            // Simplification: Just draw lines every 7 * whiteKeyWidth starting after A0/B0
            // Ideally, align with C1, C2, etc.
            double cPos = (2 * whiteKeyWidth) + ((i -1) * 7 * whiteKeyWidth);

            tiles.add(Positioned(
              left: cPos, top: 0, bottom: 0,
              child: Container(width: 1, color: Colors.grey.withOpacity(0.3)),
            ));
          }

          // 2. Draw Notes
          for (var note in session) {
            if (note.isSilence) continue;

            // Accurate Positioning Logic
            bool isBlack = _isBlackKey(note.keyIndex);
            double width = isBlack ? blackKeyWidth : whiteKeyWidth;
            double left = _calculateLeftPos(note.keyIndex, whiteKeyWidth, blackKeyWidth);

            // Bottom-up stacking logic
            double bottomPos = note.currentOffset * pixelRatio;
            double height = note.height * pixelRatio;

            // Hide if scrolled off top (Optimization)
            if (bottomPos > constraints.maxHeight) continue;

            tiles.add(Positioned(
              left: left,
              bottom: bottomPos,
              width: width,
              height: height,
              child: GestureDetector(
                onTap: () => _showEditDialog(context, provider, note),
                child: Container(
                  decoration: BoxDecoration(
                    color: note.color,
                    border: Border.all(color: Colors.white54, width: 0.5),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ));
          }

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
          )
        ],
      ),
      actions: [
        TextButton(
          onPressed: () {
            prov.deleteNote(note); // Helper to be added in Provider
            Navigator.pop(context);
          },
          child: Text("Supprimer", style: TextStyle(color: Colors.red)),
        ),
        TextButton(
          onPressed: () {
            double? newH = double.tryParse(heightCtrl.text);
            if(newH != null) prov.updateNote(note, newH, note.color);
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