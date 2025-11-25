// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'linked.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class LinkedMatchAdapter extends TypeAdapter<LinkedMatch> {
  @override
  final int typeId = 23;

  @override
  LinkedMatch read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return LinkedMatch(
      matchId: fields[0] as String,
      puzzleId: fields[1] as String,
      status: fields[2] == null ? 'active' : fields[2] as String,
      boardState:
          fields[3] == null ? {} : (fields[3] as Map?)?.cast<String, String>(),
      currentRack:
          fields[4] == null ? [] : (fields[4] as List?)?.cast<String>(),
      currentTurnUserId: fields[5] as String?,
      turnNumber: fields[6] == null ? 1 : fields[6] as int,
      player1Score: fields[7] == null ? 0 : fields[7] as int,
      player2Score: fields[8] == null ? 0 : fields[8] as int,
      player1Vision: fields[9] == null ? 2 : fields[9] as int,
      player2Vision: fields[10] == null ? 2 : fields[10] as int,
      lockedCellCount: fields[11] == null ? 0 : fields[11] as int,
      totalAnswerCells: fields[12] == null ? 0 : fields[12] as int,
      completedAt: fields[13] as DateTime?,
      createdAt: fields[14] as DateTime,
      coupleId: fields[15] as String?,
      player1Id: fields[16] as String?,
      player2Id: fields[17] as String?,
      winnerId: fields[18] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, LinkedMatch obj) {
    writer
      ..writeByte(19)
      ..writeByte(0)
      ..write(obj.matchId)
      ..writeByte(1)
      ..write(obj.puzzleId)
      ..writeByte(2)
      ..write(obj.status)
      ..writeByte(3)
      ..write(obj.boardState)
      ..writeByte(4)
      ..write(obj.currentRack)
      ..writeByte(5)
      ..write(obj.currentTurnUserId)
      ..writeByte(6)
      ..write(obj.turnNumber)
      ..writeByte(7)
      ..write(obj.player1Score)
      ..writeByte(8)
      ..write(obj.player2Score)
      ..writeByte(9)
      ..write(obj.player1Vision)
      ..writeByte(10)
      ..write(obj.player2Vision)
      ..writeByte(11)
      ..write(obj.lockedCellCount)
      ..writeByte(12)
      ..write(obj.totalAnswerCells)
      ..writeByte(13)
      ..write(obj.completedAt)
      ..writeByte(14)
      ..write(obj.createdAt)
      ..writeByte(15)
      ..write(obj.coupleId)
      ..writeByte(16)
      ..write(obj.player1Id)
      ..writeByte(17)
      ..write(obj.player2Id)
      ..writeByte(18)
      ..write(obj.winnerId);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LinkedMatchAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
