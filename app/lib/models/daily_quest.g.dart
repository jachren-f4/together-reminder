// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'daily_quest.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class DailyQuestAdapter extends TypeAdapter<DailyQuest> {
  @override
  final int typeId = 17;

  @override
  DailyQuest read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return DailyQuest(
      id: fields[0] as String,
      dateKey: fields[1] as String,
      questType: fields[2] as int,
      contentId: fields[3] as String,
      createdAt: fields[4] as DateTime,
      expiresAt: fields[5] as DateTime,
      status: fields[6] as String,
      userCompletions: (fields[7] as Map?)?.cast<String, bool>(),
      lpAwarded: fields[8] as int?,
      completedAt: fields[9] as DateTime?,
      isSideQuest: fields[10] == null ? false : fields[10] as bool,
      sortOrder: fields[11] == null ? 0 : fields[11] as int,
    );
  }

  @override
  void write(BinaryWriter writer, DailyQuest obj) {
    writer
      ..writeByte(12)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.dateKey)
      ..writeByte(2)
      ..write(obj.questType)
      ..writeByte(3)
      ..write(obj.contentId)
      ..writeByte(4)
      ..write(obj.createdAt)
      ..writeByte(5)
      ..write(obj.expiresAt)
      ..writeByte(6)
      ..write(obj.status)
      ..writeByte(7)
      ..write(obj.userCompletions)
      ..writeByte(8)
      ..write(obj.lpAwarded)
      ..writeByte(9)
      ..write(obj.completedAt)
      ..writeByte(10)
      ..write(obj.isSideQuest)
      ..writeByte(11)
      ..write(obj.sortOrder);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DailyQuestAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class DailyQuestCompletionAdapter extends TypeAdapter<DailyQuestCompletion> {
  @override
  final int typeId = 18;

  @override
  DailyQuestCompletion read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return DailyQuestCompletion(
      dateKey: fields[0] as String,
      questsCompleted: fields[1] as int,
      allQuestsCompleted: fields[2] as bool,
      completedAt: fields[3] as DateTime,
      totalLpEarned: fields[4] as int,
      sideQuestsCompleted: fields[5] == null ? 0 : fields[5] as int,
      lastUpdatedAt: fields[6] as DateTime?,
    );
  }

  @override
  void write(BinaryWriter writer, DailyQuestCompletion obj) {
    writer
      ..writeByte(7)
      ..writeByte(0)
      ..write(obj.dateKey)
      ..writeByte(1)
      ..write(obj.questsCompleted)
      ..writeByte(2)
      ..write(obj.allQuestsCompleted)
      ..writeByte(3)
      ..write(obj.completedAt)
      ..writeByte(4)
      ..write(obj.totalLpEarned)
      ..writeByte(5)
      ..write(obj.sideQuestsCompleted)
      ..writeByte(6)
      ..write(obj.lastUpdatedAt);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DailyQuestCompletionAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
