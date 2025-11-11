// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'memory_flip.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class MemoryPuzzleAdapter extends TypeAdapter<MemoryPuzzle> {
  @override
  final int typeId = 10;

  @override
  MemoryPuzzle read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return MemoryPuzzle(
      id: fields[0] as String,
      createdAt: fields[1] as DateTime,
      expiresAt: fields[2] as DateTime,
      cards: (fields[3] as List).cast<MemoryCard>(),
      status: fields[4] as String,
      totalPairs: fields[5] as int,
      matchedPairs: fields[6] as int,
      completedAt: fields[7] as DateTime?,
      completionQuote: fields[8] as String,
    );
  }

  @override
  void write(BinaryWriter writer, MemoryPuzzle obj) {
    writer
      ..writeByte(9)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.createdAt)
      ..writeByte(2)
      ..write(obj.expiresAt)
      ..writeByte(3)
      ..write(obj.cards)
      ..writeByte(4)
      ..write(obj.status)
      ..writeByte(5)
      ..write(obj.totalPairs)
      ..writeByte(6)
      ..write(obj.matchedPairs)
      ..writeByte(7)
      ..write(obj.completedAt)
      ..writeByte(8)
      ..write(obj.completionQuote);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MemoryPuzzleAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class MemoryCardAdapter extends TypeAdapter<MemoryCard> {
  @override
  final int typeId = 11;

  @override
  MemoryCard read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return MemoryCard(
      id: fields[0] as String,
      puzzleId: fields[1] as String,
      position: fields[2] as int,
      emoji: fields[3] as String,
      pairId: fields[4] as String,
      status: fields[5] as String,
      matchedBy: fields[6] as String?,
      matchedAt: fields[7] as DateTime?,
      revealQuote: fields[8] as String,
    );
  }

  @override
  void write(BinaryWriter writer, MemoryCard obj) {
    writer
      ..writeByte(9)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.puzzleId)
      ..writeByte(2)
      ..write(obj.position)
      ..writeByte(3)
      ..write(obj.emoji)
      ..writeByte(4)
      ..write(obj.pairId)
      ..writeByte(5)
      ..write(obj.status)
      ..writeByte(6)
      ..write(obj.matchedBy)
      ..writeByte(7)
      ..write(obj.matchedAt)
      ..writeByte(8)
      ..write(obj.revealQuote);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MemoryCardAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class MemoryFlipAllowanceAdapter extends TypeAdapter<MemoryFlipAllowance> {
  @override
  final int typeId = 12;

  @override
  MemoryFlipAllowance read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return MemoryFlipAllowance(
      userId: fields[0] as String,
      flipsRemaining: fields[1] as int,
      resetsAt: fields[2] as DateTime,
      totalFlipsToday: fields[3] as int,
      lastFlipAt: fields[4] as DateTime,
    );
  }

  @override
  void write(BinaryWriter writer, MemoryFlipAllowance obj) {
    writer
      ..writeByte(5)
      ..writeByte(0)
      ..write(obj.userId)
      ..writeByte(1)
      ..write(obj.flipsRemaining)
      ..writeByte(2)
      ..write(obj.resetsAt)
      ..writeByte(3)
      ..write(obj.totalFlipsToday)
      ..writeByte(4)
      ..write(obj.lastFlipAt);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MemoryFlipAllowanceAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
