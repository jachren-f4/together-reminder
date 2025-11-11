// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'partner.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class PartnerAdapter extends TypeAdapter<Partner> {
  @override
  final int typeId = 1;

  @override
  Partner read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Partner(
      name: fields[0] as String,
      pushToken: fields[1] as String,
      pairedAt: fields[2] as DateTime,
      avatarEmoji: fields[3] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, Partner obj) {
    writer
      ..writeByte(4)
      ..writeByte(0)
      ..write(obj.name)
      ..writeByte(1)
      ..write(obj.pushToken)
      ..writeByte(2)
      ..write(obj.pairedAt)
      ..writeByte(3)
      ..write(obj.avatarEmoji);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PartnerAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
