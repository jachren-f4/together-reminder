// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'cooldown_status.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class CooldownStatusAdapter extends TypeAdapter<CooldownStatus> {
  @override
  final int typeId = 33;

  @override
  CooldownStatus read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return CooldownStatus(
      canPlay: fields[0] as bool,
      remainingInBatch: fields[1] as int,
      cooldownEndsAt: fields[2] as DateTime?,
      cooldownRemainingMs: fields[3] as int?,
    );
  }

  @override
  void write(BinaryWriter writer, CooldownStatus obj) {
    writer
      ..writeByte(4)
      ..writeByte(0)
      ..write(obj.canPlay)
      ..writeByte(1)
      ..write(obj.remainingInBatch)
      ..writeByte(2)
      ..write(obj.cooldownEndsAt)
      ..writeByte(3)
      ..write(obj.cooldownRemainingMs);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CooldownStatusAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class CooldownCollectionAdapter extends TypeAdapter<CooldownCollection> {
  @override
  final int typeId = 34;

  @override
  CooldownCollection read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return CooldownCollection(
      classicQuiz: fields[0] as CooldownStatus?,
      affirmationQuiz: fields[1] as CooldownStatus?,
      youOrMe: fields[2] as CooldownStatus?,
      linked: fields[3] as CooldownStatus?,
      wordsearch: fields[4] as CooldownStatus?,
      lastSyncedAt: fields[5] as DateTime?,
    );
  }

  @override
  void write(BinaryWriter writer, CooldownCollection obj) {
    writer
      ..writeByte(6)
      ..writeByte(0)
      ..write(obj.classicQuiz)
      ..writeByte(1)
      ..write(obj.affirmationQuiz)
      ..writeByte(2)
      ..write(obj.youOrMe)
      ..writeByte(3)
      ..write(obj.linked)
      ..writeByte(4)
      ..write(obj.wordsearch)
      ..writeByte(5)
      ..write(obj.lastSyncedAt);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CooldownCollectionAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
