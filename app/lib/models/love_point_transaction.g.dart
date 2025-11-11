// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'love_point_transaction.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class LovePointTransactionAdapter extends TypeAdapter<LovePointTransaction> {
  @override
  final int typeId = 3;

  @override
  LovePointTransaction read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return LovePointTransaction(
      id: fields[0] as String,
      amount: fields[1] as int,
      reason: fields[2] as String,
      timestamp: fields[3] as DateTime,
      relatedId: fields[4] as String?,
      multiplier: fields[5] == null ? 1 : fields[5] as int,
    );
  }

  @override
  void write(BinaryWriter writer, LovePointTransaction obj) {
    writer
      ..writeByte(6)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.amount)
      ..writeByte(2)
      ..write(obj.reason)
      ..writeByte(3)
      ..write(obj.timestamp)
      ..writeByte(4)
      ..write(obj.relatedId)
      ..writeByte(5)
      ..write(obj.multiplier);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LovePointTransactionAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
