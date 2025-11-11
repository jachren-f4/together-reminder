// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'ladder_session.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class LadderSessionAdapter extends TypeAdapter<LadderSession> {
  @override
  final int typeId = 9;

  @override
  LadderSession read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return LadderSession(
      id: fields[0] as String,
      wordPairId: fields[1] as String,
      startWord: fields[2] as String,
      endWord: fields[3] as String,
      wordChain: (fields[4] as List).cast<String>(),
      status: fields[5] as String,
      createdAt: fields[6] as DateTime,
      completedAt: fields[7] as DateTime?,
      currentTurn: fields[8] as String,
      language: fields[9] as String,
      lpEarned: fields[10] == null ? 0 : fields[10] as int,
      optimalSteps: fields[11] as int?,
      yieldedBy: fields[12] as String?,
      yieldedAt: fields[13] as DateTime?,
      yieldCount: fields[14] == null ? 0 : fields[14] as int,
      lastAction: fields[15] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, LadderSession obj) {
    writer
      ..writeByte(16)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.wordPairId)
      ..writeByte(2)
      ..write(obj.startWord)
      ..writeByte(3)
      ..write(obj.endWord)
      ..writeByte(4)
      ..write(obj.wordChain)
      ..writeByte(5)
      ..write(obj.status)
      ..writeByte(6)
      ..write(obj.createdAt)
      ..writeByte(7)
      ..write(obj.completedAt)
      ..writeByte(8)
      ..write(obj.currentTurn)
      ..writeByte(9)
      ..write(obj.language)
      ..writeByte(10)
      ..write(obj.lpEarned)
      ..writeByte(11)
      ..write(obj.optimalSteps)
      ..writeByte(12)
      ..write(obj.yieldedBy)
      ..writeByte(13)
      ..write(obj.yieldedAt)
      ..writeByte(14)
      ..write(obj.yieldCount)
      ..writeByte(15)
      ..write(obj.lastAction);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LadderSessionAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
