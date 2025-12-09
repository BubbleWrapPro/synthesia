import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/session_provider.dart';

class CascadeView extends StatelessWidget {
  const CascadeView({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final session = Provider.of<SessionProvider>(context).session;
          final screenHeight = MediaQuery.of(context).size.height;

          // Ratio: 1 unit height = 1/8 of Screen Height
          final double pixelRatio = screenHeight / 8.0;
          final double whiteKeyWidth = constraints.maxWidth / 52;

          List<Widget> tiles = [];

          // Draw Octave Dividers (Grey lines)
          for(int i=1; i<8; i++) {
            tiles.add(Positioned(
              left: (i * 7 * whiteKeyWidth) + (2 * whiteKeyWidth), // Rough approx of octaves
              top: 0, bottom: 0,
              child: Container(width: 1, color: Colors.grey),
            ));
          }

          // Draw Notes
          for (var note in session) {
            if (note.isSilence) continue;

            // Calculate X position
            // We need to re-calculate the exact position similar to keyboard
            // Note: This duplicates logic. Ideally, move "getKeyPos" to a util class.
            double leftPos = _getKeyLeftPos(note.keyIndex, whiteKeyWidth);
            double width = _isBlackKey(note.keyIndex) ? whiteKeyWidth * 0.6 : whiteKeyWidth;

            // Calculate Y position (Bottom Up)
            // Offset * Ratio
            double bottomPos = note.currentOffset * pixelRatio;
            double height = note.height * pixelRatio;

            // If "Jouer" is active, logic might invert to Top-Down,
            // but for "Construction", it's bottom up.

            tiles.add(Positioned(
              left: leftPos,
              bottom: bottomPos,
              height: height,
              width: width,
              child: Container(
                decoration: BoxDecoration(
                  color: note.color,
                  border: Border.all(color: Colors.white30),
                ),
                child: InkWell(
                  onTap: () {
                    // Open Edit Dialog (Duration/Color)
                    _showEditDialog(context, note);
                  },
                ),
              ),
            ));
          }

          return Stack(children: tiles);
        },
      ),
    );
  }

  // Simplified helper for demo (needs full logic from Step 4)
  double _getKeyLeftPos(int index, double whiteW) {
    int whiteCount = 0;
    for(int i=0; i<index; i++) {
      if(!_isBlackKey(i)) whiteCount++;
    }
    if(!_isBlackKey(index)) return whiteCount * whiteW;
    return (whiteCount * whiteW) - (whiteW * 0.3); // Center on line
  }

  bool _isBlackKey(int index) {
    int n = (index + 9) % 12;
    return [1, 3, 6, 8, 10].contains(n);
  }

  void _showEditDialog(BuildContext context, dynamic note) {
    showDialog(context: context, builder: (_) => AlertDialog(
      title: Text("Modifier la tuile"),
      content: Text("Feature à implémenter: Changer durée/couleur"),
    ));
  }
}