import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:synthesia/models/note_model.dart';

void main() {
  group('NoteModel Tests', () {
    test('NoteModel initialization and id generation', () {
      final note = NoteModel(
        keyIndex: 10,
        height: 1.0,
        color: Colors.green,
        chordId: 'test_chord',
      );

      expect(note.keyIndex, 10);
      expect(note.height, 1.0);
      expect(note.playingHeight, 1.0);
      expect(note.color, Colors.green);
      expect(note.chordId, 'test_chord');
      expect(note.id, isNotEmpty);
    });

    test('NoteModel JSON serialization/deserialization', () {
      final note = NoteModel(
        keyIndex: 20,
        height: 2.5,
        playingHeight: 3.0,
        color: Colors.blue,
        overrideColor: Colors.red,
        chordId: 'chord_123',
        isSilence: false,
        fromMidi: true,
        velocity: 80,
      );

      final json = note.toJson();
      final fromJson = NoteModel.fromJson(json);

      expect(fromJson.id, note.id);
      expect(fromJson.keyIndex, note.keyIndex);
      expect(fromJson.height, note.height);
      expect(fromJson.playingHeight, note.playingHeight);
      expect(fromJson.color.toARGB32(), note.color.toARGB32());
      expect(fromJson.overrideColor?.toARGB32(), note.overrideColor?.toARGB32());
      expect(fromJson.chordId, note.chordId);
      expect(fromJson.isSilence, note.isSilence);
      expect(fromJson.fromMidi, note.fromMidi);
      expect(fromJson.velocity, note.velocity);
    });

    test('NoteModel equality based on id', () {
      final note1 = NoteModel(id: '1', keyIndex: 0, height: 1.0, color: Colors.green, chordId: 'A');
      final note2 = NoteModel(id: '1', keyIndex: 5, height: 2.0, color: Colors.blue, chordId: 'B');
      final note3 = NoteModel(id: '2', keyIndex: 0, height: 1.0, color: Colors.green, chordId: 'A');

      expect(note1 == note2, isTrue);
      expect(note1 == note3, isFalse);
      expect(note1.hashCode, note2.hashCode);
    });
  });
}
