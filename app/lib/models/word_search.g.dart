// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'word_search.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class WordSearchFoundWordAdapter extends TypeAdapter<WordSearchFoundWord> {
  @override
  final int typeId = 24;

  @override
  WordSearchFoundWord read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return WordSearchFoundWord(
      word: fields[0] as String,
      foundByUserId: fields[1] as String,
      turnNumber: fields[2] as int,
      positions: fields[3] == null
          ? []
          : (fields[3] as List?)
              ?.map((dynamic e) => (e as Map).cast<String, int>())
              ?.toList(),
      colorIndex: fields[4] == null ? 0 : fields[4] as int,
    );
  }

  @override
  void write(BinaryWriter writer, WordSearchFoundWord obj) {
    writer
      ..writeByte(5)
      ..writeByte(0)
      ..write(obj.word)
      ..writeByte(1)
      ..write(obj.foundByUserId)
      ..writeByte(2)
      ..write(obj.turnNumber)
      ..writeByte(3)
      ..write(obj.positions)
      ..writeByte(4)
      ..write(obj.colorIndex);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WordSearchFoundWordAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class WordSearchMatchAdapter extends TypeAdapter<WordSearchMatch> {
  @override
  final int typeId = 25;

  @override
  WordSearchMatch read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return WordSearchMatch(
      matchId: fields[0] as String,
      puzzleId: fields[1] as String,
      status: fields[2] == null ? 'active' : fields[2] as String,
      foundWords: fields[3] == null
          ? []
          : (fields[3] as List?)?.cast<WordSearchFoundWord>(),
      currentTurnUserId: fields[4] as String?,
      turnNumber: fields[5] == null ? 1 : fields[5] as int,
      wordsFoundThisTurn: fields[6] == null ? 0 : fields[6] as int,
      player1WordsFound: fields[7] == null ? 0 : fields[7] as int,
      player2WordsFound: fields[8] == null ? 0 : fields[8] as int,
      player1Score: fields[16] == null ? 0 : fields[16] as int,
      player2Score: fields[17] == null ? 0 : fields[17] as int,
      player1Hints: fields[9] == null ? 3 : fields[9] as int,
      player2Hints: fields[10] == null ? 3 : fields[10] as int,
      player1Id: fields[11] as String,
      player2Id: fields[12] as String,
      winnerId: fields[13] as String?,
      createdAt: fields[14] as DateTime,
      completedAt: fields[15] as DateTime?,
    );
  }

  @override
  void write(BinaryWriter writer, WordSearchMatch obj) {
    writer
      ..writeByte(18)
      ..writeByte(0)
      ..write(obj.matchId)
      ..writeByte(1)
      ..write(obj.puzzleId)
      ..writeByte(2)
      ..write(obj.status)
      ..writeByte(3)
      ..write(obj.foundWords)
      ..writeByte(4)
      ..write(obj.currentTurnUserId)
      ..writeByte(5)
      ..write(obj.turnNumber)
      ..writeByte(6)
      ..write(obj.wordsFoundThisTurn)
      ..writeByte(7)
      ..write(obj.player1WordsFound)
      ..writeByte(8)
      ..write(obj.player2WordsFound)
      ..writeByte(16)
      ..write(obj.player1Score)
      ..writeByte(17)
      ..write(obj.player2Score)
      ..writeByte(9)
      ..write(obj.player1Hints)
      ..writeByte(10)
      ..write(obj.player2Hints)
      ..writeByte(11)
      ..write(obj.player1Id)
      ..writeByte(12)
      ..write(obj.player2Id)
      ..writeByte(13)
      ..write(obj.winnerId)
      ..writeByte(14)
      ..write(obj.createdAt)
      ..writeByte(15)
      ..write(obj.completedAt);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WordSearchMatchAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
