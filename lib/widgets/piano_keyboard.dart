import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/session_provider.dart';

class PianoKeyboard extends StatelessWidget {
  const PianoKeyboard({super.key});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Calculate key width based on screen width
        final double whiteKeyWidth = constraints.maxWidth / 52;
        final double blackKeyWidth = whiteKeyWidth * 0.6;
        final double blackKeyHeight = constraints.maxHeight * 0.6;

        List<Widget> keys = [];

        // Music Theory: Pattern of keys in an octave (12 semitones)
        // A0, A#0, B0 | C1, C#1 ... 
        // We iterate 0 to 87.
        int whiteKeyCounter = 0;

        for (int i = 0; i < 88; i++) {
          bool isBlack = _isBlackKey(i);

          if (!isBlack) {
            // Add White Key
            double leftPos = whiteKeyCounter * whiteKeyWidth;
            keys.add(Positioned(
              left: leftPos,
              top: 0,
              bottom: 0,
              width: whiteKeyWidth,
              child: _buildKey(context, i, false),
            ));
            whiteKeyCounter++;
          }
        }

        // Add Black Keys ON TOP (Second loop ensures z-index)
        whiteKeyCounter = 0; // Reset to track position
        for (int i = 0; i < 88; i++) {
          bool isBlack = _isBlackKey(i);
          if (!isBlack) {
            whiteKeyCounter++;
          } else {
            // Black key is positioned on the border of previous white key
            double leftPos = (whiteKeyCounter * whiteKeyWidth) - (blackKeyWidth / 2);
            keys.add(Positioned(
              left: leftPos,
              top: 0,
              height: blackKeyHeight,
              width: blackKeyWidth,
              child: _buildKey(context, i, true),
            ));
          }
        }

        return Container(
          color: Colors.grey[900],
          child: Stack(children: keys),
        );
      },
    );
  }

  Widget _buildKey(BuildContext context, int index, bool isBlack) {
    return Material(
      color: isBlack ? Colors.black : Colors.white,
      shape: RoundedRectangleBorder(
          side: BorderSide(color: Colors.black, width: 0.5),
          borderRadius: BorderRadius.only(
              bottomLeft: Radius.circular(4),
              bottomRight: Radius.circular(4)
          )
      ),
      child: InkWell(
        onTap: () {
          Provider.of<SessionProvider>(context, listen: false).addNote(index, isBlack);
        },
      ),
    );
  }

  // Helper to determine if the Nth key is black (Standard 88 key piano starts at A0)
  bool _isBlackKey(int index) {
    // Indexes of black keys in the first octave (A0, A#0, B0...)
    // A0=0 (White), A#0=1 (Black), B0=2 (White)
    // Then C1=3...
    // Pattern relative to C is: C, C#, D, D#, E, F, F#, G, G#, A, A#, B
    //                           W, B,  W, B,  W, W, B,  W, B,  W, B,  W

    // Offset index by 9 (because A0 is 9 semitones below C1) to align with C-major pattern
    int n = (index + 9) % 12;
    return [1, 3, 6, 8, 10].contains(n);
  }
}