// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'quiz_expansion.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class QuizFormatAdapter extends TypeAdapter<QuizFormat> {
  @override
  final int typeId = 13;

  @override
  QuizFormat read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return QuizFormat(
      id: fields[0] as String,
      name: fields[1] as String,
      description: fields[2] as String,
      isUnlocked: fields[3] as bool,
      unlockRequirements: (fields[4] as Map).cast<String, dynamic>(),
      baseLP: fields[5] as int,
      questionCount: fields[6] as int,
      timeLimit: fields[7] as int?,
      emoji: fields[8] as String,
    );
  }

  @override
  void write(BinaryWriter writer, QuizFormat obj) {
    writer
      ..writeByte(9)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.description)
      ..writeByte(3)
      ..write(obj.isUnlocked)
      ..writeByte(4)
      ..write(obj.unlockRequirements)
      ..writeByte(5)
      ..write(obj.baseLP)
      ..writeByte(6)
      ..write(obj.questionCount)
      ..writeByte(7)
      ..write(obj.timeLimit)
      ..writeByte(8)
      ..write(obj.emoji);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is QuizFormatAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class QuizCategoryAdapter extends TypeAdapter<QuizCategory> {
  @override
  final int typeId = 14;

  @override
  QuizCategory read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return QuizCategory(
      id: fields[0] as String,
      name: fields[1] as String,
      emoji: fields[2] as String,
      tier: fields[3] as int,
      isUnlocked: fields[4] as bool,
      questionsCompleted: fields[5] as int,
      totalQuestions: fields[6] as int,
      avgMatchRate: fields[7] == null ? 0.0 : fields[7] as double,
    );
  }

  @override
  void write(BinaryWriter writer, QuizCategory obj) {
    writer
      ..writeByte(8)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.emoji)
      ..writeByte(3)
      ..write(obj.tier)
      ..writeByte(4)
      ..write(obj.isUnlocked)
      ..writeByte(5)
      ..write(obj.questionsCompleted)
      ..writeByte(6)
      ..write(obj.totalQuestions)
      ..writeByte(7)
      ..write(obj.avgMatchRate);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is QuizCategoryAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class QuizStreakAdapter extends TypeAdapter<QuizStreak> {
  @override
  final int typeId = 15;

  @override
  QuizStreak read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return QuizStreak(
      type: fields[0] as String,
      currentStreak: fields[1] as int,
      longestStreak: fields[2] as int,
      lastCompletedDate: fields[3] as DateTime,
      totalCompleted: fields[4] == null ? 0 : fields[4] as int,
    );
  }

  @override
  void write(BinaryWriter writer, QuizStreak obj) {
    writer
      ..writeByte(5)
      ..writeByte(0)
      ..write(obj.type)
      ..writeByte(1)
      ..write(obj.currentStreak)
      ..writeByte(2)
      ..write(obj.longestStreak)
      ..writeByte(3)
      ..write(obj.lastCompletedDate)
      ..writeByte(4)
      ..write(obj.totalCompleted);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is QuizStreakAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class QuizDailyPulseAdapter extends TypeAdapter<QuizDailyPulse> {
  @override
  final int typeId = 16;

  @override
  QuizDailyPulse read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return QuizDailyPulse(
      id: fields[0] as String,
      questionId: fields[1] as String,
      availableDate: fields[2] as DateTime,
      subjectUserId: fields[3] as String,
      answers: (fields[4] as Map?)?.cast<String, int>(),
      bothAnswered: fields[5] as bool,
      lpAwarded: fields[6] == null ? 0 : fields[6] as int,
      completedAt: fields[7] as DateTime?,
      isMatch: fields[8] == null ? false : fields[8] as bool,
    );
  }

  @override
  void write(BinaryWriter writer, QuizDailyPulse obj) {
    writer
      ..writeByte(9)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.questionId)
      ..writeByte(2)
      ..write(obj.availableDate)
      ..writeByte(3)
      ..write(obj.subjectUserId)
      ..writeByte(4)
      ..write(obj.answers)
      ..writeByte(5)
      ..write(obj.bothAnswered)
      ..writeByte(6)
      ..write(obj.lpAwarded)
      ..writeByte(7)
      ..write(obj.completedAt)
      ..writeByte(8)
      ..write(obj.isMatch);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is QuizDailyPulseAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
