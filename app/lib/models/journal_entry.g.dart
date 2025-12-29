// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'journal_entry.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class JournalEntryAdapter extends TypeAdapter<JournalEntry> {
  @override
  final int typeId = 30;

  @override
  JournalEntry read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return JournalEntry()
      ..entryId = fields[0] as String
      ..type = fields[1] as JournalEntryType
      ..title = fields[2] as String
      ..completedAt = fields[3] as DateTime
      ..contentId = fields[4] as String?
      ..alignedCount = fields[5] == null ? 0 : fields[5] as int
      ..differentCount = fields[6] == null ? 0 : fields[6] as int
      ..userScore = fields[7] == null ? 0 : fields[7] as int
      ..partnerScore = fields[8] == null ? 0 : fields[8] as int
      ..totalTurns = fields[9] == null ? 0 : fields[9] as int
      ..userHintsUsed = fields[10] == null ? 0 : fields[10] as int
      ..partnerHintsUsed = fields[11] == null ? 0 : fields[11] as int
      ..userPoints = fields[12] == null ? 0 : fields[12] as int
      ..partnerPoints = fields[13] == null ? 0 : fields[13] as int
      ..winnerId = fields[14] as String?
      ..combinedSteps = fields[15] == null ? 0 : fields[15] as int
      ..stepGoal = fields[16] == null ? 0 : fields[16] as int
      ..syncStatus = fields[17] == null ? 'synced' : fields[17] as String;
  }

  @override
  void write(BinaryWriter writer, JournalEntry obj) {
    writer
      ..writeByte(18)
      ..writeByte(0)
      ..write(obj.entryId)
      ..writeByte(1)
      ..write(obj.type)
      ..writeByte(2)
      ..write(obj.title)
      ..writeByte(3)
      ..write(obj.completedAt)
      ..writeByte(4)
      ..write(obj.contentId)
      ..writeByte(5)
      ..write(obj.alignedCount)
      ..writeByte(6)
      ..write(obj.differentCount)
      ..writeByte(7)
      ..write(obj.userScore)
      ..writeByte(8)
      ..write(obj.partnerScore)
      ..writeByte(9)
      ..write(obj.totalTurns)
      ..writeByte(10)
      ..write(obj.userHintsUsed)
      ..writeByte(11)
      ..write(obj.partnerHintsUsed)
      ..writeByte(12)
      ..write(obj.userPoints)
      ..writeByte(13)
      ..write(obj.partnerPoints)
      ..writeByte(14)
      ..write(obj.winnerId)
      ..writeByte(15)
      ..write(obj.combinedSteps)
      ..writeByte(16)
      ..write(obj.stepGoal)
      ..writeByte(17)
      ..write(obj.syncStatus);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is JournalEntryAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class JournalEntryTypeAdapter extends TypeAdapter<JournalEntryType> {
  @override
  final int typeId = 31;

  @override
  JournalEntryType read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return JournalEntryType.classicQuiz;
      case 1:
        return JournalEntryType.affirmationQuiz;
      case 2:
        return JournalEntryType.youOrMe;
      case 3:
        return JournalEntryType.linked;
      case 4:
        return JournalEntryType.wordSearch;
      case 5:
        return JournalEntryType.stepsTogether;
      case 6:
        return JournalEntryType.welcomeQuiz;
      default:
        return JournalEntryType.classicQuiz;
    }
  }

  @override
  void write(BinaryWriter writer, JournalEntryType obj) {
    switch (obj) {
      case JournalEntryType.classicQuiz:
        writer.writeByte(0);
        break;
      case JournalEntryType.affirmationQuiz:
        writer.writeByte(1);
        break;
      case JournalEntryType.youOrMe:
        writer.writeByte(2);
        break;
      case JournalEntryType.linked:
        writer.writeByte(3);
        break;
      case JournalEntryType.wordSearch:
        writer.writeByte(4);
        break;
      case JournalEntryType.stepsTogether:
        writer.writeByte(5);
        break;
      case JournalEntryType.welcomeQuiz:
        writer.writeByte(6);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is JournalEntryTypeAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
