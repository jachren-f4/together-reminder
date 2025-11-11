// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'user.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class UserAdapter extends TypeAdapter<User> {
  @override
  final int typeId = 2;

  @override
  User read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return User(
      id: fields[0] as String,
      pushToken: fields[1] as String,
      createdAt: fields[2] as DateTime,
      name: fields[3] as String?,
      lovePoints: fields[4] == null ? 0 : fields[4] as int,
      arenaTier: fields[5] == null ? 1 : fields[5] as int,
      floor: fields[6] == null ? 0 : fields[6] as int,
      lastActivityDate: fields[7] as DateTime?,
    );
  }

  @override
  void write(BinaryWriter writer, User obj) {
    writer
      ..writeByte(8)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.pushToken)
      ..writeByte(2)
      ..write(obj.createdAt)
      ..writeByte(3)
      ..write(obj.name)
      ..writeByte(4)
      ..write(obj.lovePoints)
      ..writeByte(5)
      ..write(obj.arenaTier)
      ..writeByte(6)
      ..write(obj.floor)
      ..writeByte(7)
      ..write(obj.lastActivityDate);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UserAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
