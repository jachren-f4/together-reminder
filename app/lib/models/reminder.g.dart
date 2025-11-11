// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'reminder.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class ReminderAdapter extends TypeAdapter<Reminder> {
  @override
  final int typeId = 0;

  @override
  Reminder read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Reminder(
      id: fields[0] as String,
      type: fields[1] as String,
      from: fields[2] as String,
      to: fields[3] as String,
      text: fields[4] as String,
      timestamp: fields[5] as DateTime,
      scheduledFor: fields[6] as DateTime,
      status: fields[7] as String,
      snoozedUntil: fields[8] as DateTime?,
      createdAt: fields[9] as DateTime,
      category: fields[10] == null ? 'reminder' : fields[10] as String,
    );
  }

  @override
  void write(BinaryWriter writer, Reminder obj) {
    writer
      ..writeByte(11)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.type)
      ..writeByte(2)
      ..write(obj.from)
      ..writeByte(3)
      ..write(obj.to)
      ..writeByte(4)
      ..write(obj.text)
      ..writeByte(5)
      ..write(obj.timestamp)
      ..writeByte(6)
      ..write(obj.scheduledFor)
      ..writeByte(7)
      ..write(obj.status)
      ..writeByte(8)
      ..write(obj.snoozedUntil)
      ..writeByte(9)
      ..write(obj.createdAt)
      ..writeByte(10)
      ..write(obj.category);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ReminderAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
