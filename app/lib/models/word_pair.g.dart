// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'word_pair.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class WordPairAdapter extends TypeAdapter<WordPair> {
  @override
  final int typeId = 8;

  @override
  WordPair read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return WordPair(
      id: fields[0] as String,
      startWord: fields[1] as String,
      endWord: fields[2] as String,
      language: fields[3] as String,
      difficulty: fields[4] == null ? 'easy' : fields[4] as String,
      optimalSteps: fields[5] as int?,
    );
  }

  @override
  void write(BinaryWriter writer, WordPair obj) {
    writer
      ..writeByte(6)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.startWord)
      ..writeByte(2)
      ..write(obj.endWord)
      ..writeByte(3)
      ..write(obj.language)
      ..writeByte(4)
      ..write(obj.difficulty)
      ..writeByte(5)
      ..write(obj.optimalSteps);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WordPairAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
