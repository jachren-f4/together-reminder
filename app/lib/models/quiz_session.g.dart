// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'quiz_session.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class QuizSessionAdapter extends TypeAdapter<QuizSession> {
  @override
  final int typeId = 5;

  @override
  QuizSession read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return QuizSession(
      id: fields[0] as String,
      questionIds: (fields[1] as List).cast<String>(),
      createdAt: fields[2] as DateTime,
      expiresAt: fields[3] as DateTime,
      status: fields[4] as String,
      initiatedBy: fields[9] as String,
      subjectUserId: fields[10] == null ? '' : fields[10] as String,
      formatType: fields[11] as String?,
      answers: (fields[5] as Map?)?.map((dynamic k, dynamic v) =>
          MapEntry(k as String, (v as List).cast<int>())),
      predictions: (fields[12] as Map?)?.map((dynamic k, dynamic v) =>
          MapEntry(k as String, (v as List).cast<int>())),
      alignmentMatches: fields[13] == null ? 0 : fields[13] as int,
      predictionScores: (fields[14] as Map?)?.cast<String, int>(),
      matchPercentage: fields[6] as int?,
      lpEarned: fields[7] as int?,
      completedAt: fields[8] as DateTime?,
    );
  }

  @override
  void write(BinaryWriter writer, QuizSession obj) {
    writer
      ..writeByte(15)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.questionIds)
      ..writeByte(2)
      ..write(obj.createdAt)
      ..writeByte(3)
      ..write(obj.expiresAt)
      ..writeByte(4)
      ..write(obj.status)
      ..writeByte(5)
      ..write(obj.answers)
      ..writeByte(6)
      ..write(obj.matchPercentage)
      ..writeByte(7)
      ..write(obj.lpEarned)
      ..writeByte(8)
      ..write(obj.completedAt)
      ..writeByte(9)
      ..write(obj.initiatedBy)
      ..writeByte(10)
      ..write(obj.subjectUserId)
      ..writeByte(11)
      ..write(obj.formatType)
      ..writeByte(12)
      ..write(obj.predictions)
      ..writeByte(13)
      ..write(obj.alignmentMatches)
      ..writeByte(14)
      ..write(obj.predictionScores);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is QuizSessionAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
