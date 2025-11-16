// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'you_or_me.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class YouOrMeQuestionAdapter extends TypeAdapter<YouOrMeQuestion> {
  @override
  final int typeId = 20;

  @override
  YouOrMeQuestion read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return YouOrMeQuestion(
      id: fields[0] as String,
      prompt: fields[1] as String,
      content: fields[2] as String,
      category: fields[3] as String,
    );
  }

  @override
  void write(BinaryWriter writer, YouOrMeQuestion obj) {
    writer
      ..writeByte(4)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.prompt)
      ..writeByte(2)
      ..write(obj.content)
      ..writeByte(3)
      ..write(obj.category);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is YouOrMeQuestionAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class YouOrMeAnswerAdapter extends TypeAdapter<YouOrMeAnswer> {
  @override
  final int typeId = 21;

  @override
  YouOrMeAnswer read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return YouOrMeAnswer(
      questionId: fields[0] as String,
      questionPrompt: fields[1] as String,
      questionContent: fields[2] as String,
      answerValue: fields[3] as bool,
      answeredAt: fields[4] as DateTime,
    );
  }

  @override
  void write(BinaryWriter writer, YouOrMeAnswer obj) {
    writer
      ..writeByte(5)
      ..writeByte(0)
      ..write(obj.questionId)
      ..writeByte(1)
      ..write(obj.questionPrompt)
      ..writeByte(2)
      ..write(obj.questionContent)
      ..writeByte(3)
      ..write(obj.answerValue)
      ..writeByte(4)
      ..write(obj.answeredAt);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is YouOrMeAnswerAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class YouOrMeSessionAdapter extends TypeAdapter<YouOrMeSession> {
  @override
  final int typeId = 22;

  @override
  YouOrMeSession read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return YouOrMeSession(
      id: fields[0] as String,
      userId: fields[1] as String,
      partnerId: fields[2] as String,
      questId: fields[3] as String?,
      questions: (fields[4] as List).cast<YouOrMeQuestion>(),
      answers: (fields[5] as Map?)?.map((dynamic k, dynamic v) =>
          MapEntry(k as String, (v as List).cast<YouOrMeAnswer>())),
      status: fields[6] as String,
      createdAt: fields[7] as DateTime,
      completedAt: fields[8] as DateTime?,
      lpEarned: fields[9] as int?,
      coupleId: fields[10] as String,
      initiatedBy: fields[11] as String,
      subjectUserId: fields[12] as String,
    );
  }

  @override
  void write(BinaryWriter writer, YouOrMeSession obj) {
    writer
      ..writeByte(13)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.userId)
      ..writeByte(2)
      ..write(obj.partnerId)
      ..writeByte(3)
      ..write(obj.questId)
      ..writeByte(4)
      ..write(obj.questions)
      ..writeByte(5)
      ..write(obj.answers)
      ..writeByte(6)
      ..write(obj.status)
      ..writeByte(7)
      ..write(obj.createdAt)
      ..writeByte(8)
      ..write(obj.completedAt)
      ..writeByte(9)
      ..write(obj.lpEarned)
      ..writeByte(10)
      ..write(obj.coupleId)
      ..writeByte(11)
      ..write(obj.initiatedBy)
      ..writeByte(12)
      ..write(obj.subjectUserId);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is YouOrMeSessionAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
