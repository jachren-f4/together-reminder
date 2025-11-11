// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'badge.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class BadgeAdapter extends TypeAdapter<Badge> {
  @override
  final int typeId = 6;

  @override
  Badge read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Badge(
      id: fields[0] as String,
      name: fields[1] as String,
      emoji: fields[2] as String,
      description: fields[3] as String,
      earnedAt: fields[4] as DateTime,
      category: fields[5] as String,
    );
  }

  @override
  void write(BinaryWriter writer, Badge obj) {
    writer
      ..writeByte(6)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.emoji)
      ..writeByte(3)
      ..write(obj.description)
      ..writeByte(4)
      ..write(obj.earnedAt)
      ..writeByte(5)
      ..write(obj.category);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BadgeAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
