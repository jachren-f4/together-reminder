// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'magnet_collection.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class MagnetCollectionAdapter extends TypeAdapter<MagnetCollection> {
  @override
  final int typeId = 32;

  @override
  MagnetCollection read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return MagnetCollection(
      unlockedCount: fields[0] as int,
      nextMagnetId: fields[1] as int?,
      currentLp: fields[2] as int,
      lpForNextMagnet: fields[3] as int,
      lpProgressToNext: fields[4] as int,
      progressPercent: fields[5] as int,
      totalMagnets: fields[6] == null ? 30 : fields[6] as int,
      allUnlocked: fields[7] == null ? false : fields[7] as bool,
      lastSyncedAt: fields[8] as DateTime?,
    );
  }

  @override
  void write(BinaryWriter writer, MagnetCollection obj) {
    writer
      ..writeByte(9)
      ..writeByte(0)
      ..write(obj.unlockedCount)
      ..writeByte(1)
      ..write(obj.nextMagnetId)
      ..writeByte(2)
      ..write(obj.currentLp)
      ..writeByte(3)
      ..write(obj.lpForNextMagnet)
      ..writeByte(4)
      ..write(obj.lpProgressToNext)
      ..writeByte(5)
      ..write(obj.progressPercent)
      ..writeByte(6)
      ..write(obj.totalMagnets)
      ..writeByte(7)
      ..write(obj.allUnlocked)
      ..writeByte(8)
      ..write(obj.lastSyncedAt);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MagnetCollectionAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
