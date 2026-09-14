import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:synthesia/models/note_model.dart';
import 'package:synthesia/models/style_config.dart';

void main() {
  group('NoteModel Tests', () {
    test('Creation and default values', () {
      final note = NoteModel(
        keyIndex: 39,
        height: 1.0,
        color: Colors.lightGreen,
        chordId: 'chord_1',
      );

      expect(note.keyIndex, 39);
      expect(note.height, 1.0);
      expect(note.playingHeight, 1.0);
      expect(note.color, Colors.lightGreen);
      expect(note.chordId, 'chord_1');
      expect(note.isSilence, false);
      expect(note.fromMidi, false);
      expect(note.trackId, 0);
      expect(note.velocity, 100);
      expect(note.currentOffset, 0.0);
      expect(note.id, isNotEmpty);
    });

    test('Json serialization roundtrip', () {
      final note = NoteModel(
        id: 'test_id_123',
        keyIndex: 40,
        height: 2.5,
        playingHeight: 3.0,
        color: Colors.blue,
        overrideColor: Colors.red,
        chordId: 'chord_2',
        isSilence: false,
        fromMidi: true,
        trackId: 1,
        velocity: 110,
        currentOffset: 5.0,
      );

      final json = note.toJson();
      final restored = NoteModel.fromJson(json);

      expect(restored.id, note.id);
      expect(restored.keyIndex, note.keyIndex);
      expect(restored.height, note.height);
      expect(restored.playingHeight, note.playingHeight);
      expect(restored.color.toARGB32(), note.color.toARGB32());
      expect(restored.overrideColor?.toARGB32(), note.overrideColor?.toARGB32());
      expect(restored.chordId, note.chordId);
      expect(restored.isSilence, note.isSilence);
      expect(restored.fromMidi, note.fromMidi);
      expect(restored.trackId, note.trackId);
      expect(restored.velocity, note.velocity);
    });

    test('Equality and hashCode based on id', () {
      final note1 = NoteModel(
        id: 'same_id',
        keyIndex: 39,
        height: 1.0,
        color: Colors.green,
        chordId: 'c1',
      );
      final note2 = NoteModel(
        id: 'same_id',
        keyIndex: 45,
        height: 2.0,
        color: Colors.blue,
        chordId: 'c2',
      );
      final note3 = NoteModel(
        id: 'different_id',
        keyIndex: 39,
        height: 1.0,
        color: Colors.green,
        chordId: 'c1',
      );

      expect(note1, equals(note2));
      expect(note1.hashCode, equals(note2.hashCode));
      expect(note1, isNot(equals(note3)));
    });
  });

  group('StyleConfig Tests', () {
    test('Creation and default values', () {
      final config = StyleConfig(name: 'Test Style');
      expect(config.name, 'Test Style');
      expect(config.mode, DifferentiationMode.blackWhite);
      expect(config.splitKey, 39);
      expect(config.colorA, Colors.lightGreen);
      expect(config.colorB, Colors.blue);
      expect(config.trackColors, isEmpty);
      expect(config.darkenBlackKeysByTrack, false);
      expect(config.gradientColors, hasLength(2));
      expect(config.gradientAngle, 0.0);
    });

    test('Json serialization roundtrip and copyWith', () {
      final config = StyleConfig(
        name: 'Custom',
        mode: DifferentiationMode.byTrack,
        splitKey: 42,
        colorA: Colors.yellow,
        colorB: Colors.orange,
        trackColors: {0: Colors.red, 1: Colors.green},
        darkenBlackKeysByTrack: true,
        gradientColors: [Colors.black, Colors.white],
        gradientAngle: 45.0,
      );

      final json = config.toJson();
      final restored = StyleConfig.fromJson(json);

      expect(restored.name, config.name);
      expect(restored.mode, config.mode);
      expect(restored.splitKey, config.splitKey);
      expect(restored.colorA.toARGB32(), config.colorA.toARGB32());
      expect(restored.colorB.toARGB32(), config.colorB.toARGB32());
      expect(restored.trackColors[0]?.toARGB32(), config.trackColors[0]?.toARGB32());
      expect(restored.darkenBlackKeysByTrack, config.darkenBlackKeysByTrack);
      expect(restored.gradientAngle, config.gradientAngle);

      final copied = config.copyWith(name: 'Copied', splitKey: 50);
      expect(copied.name, 'Copied');
      expect(copied.splitKey, 50);
      expect(copied.mode, config.mode);
    });
  });
}
