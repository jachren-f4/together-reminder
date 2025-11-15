// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'quiz_question.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class QuizQuestionAdapter extends TypeAdapter<QuizQuestion> {
  @override
  final int typeId = 4;

  @override
  QuizQuestion read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return QuizQuestion(
      id: fields[0] as String,
      question: fields[1] as String,
      options: (fields[2] as List).cast<String>(),
      correctAnswerIndex: fields[3] as int,
      category: fields[4] as String,
      difficulty: fields[5] == null ? 1 : fields[5] as int,
      tier: fields[6] == null ? 1 : fields[6] as int,
      isSeasonal: fields[7] == null ? false : fields[7] as bool,
      seasonalTheme: fields[8] as String?,
      timesAsked: fields[9] == null ? 0 : fields[9] as int,
      avgMatchRate: fields[10] == null ? 0.0 : fields[10] as double,
      questionType:
          fields[11] == null ? 'multiple_choice' : fields[11] as String,
    );
  }

  @override
  void write(BinaryWriter writer, QuizQuestion obj) {
    writer
      ..writeByte(12)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.question)
      ..writeByte(2)
      ..write(obj.options)
      ..writeByte(3)
      ..write(obj.correctAnswerIndex)
      ..writeByte(4)
      ..write(obj.category)
      ..writeByte(5)
      ..write(obj.difficulty)
      ..writeByte(6)
      ..write(obj.tier)
      ..writeByte(7)
      ..write(obj.isSeasonal)
      ..writeByte(8)
      ..write(obj.seasonalTheme)
      ..writeByte(9)
      ..write(obj.timesAsked)
      ..writeByte(10)
      ..write(obj.avgMatchRate)
      ..writeByte(11)
      ..write(obj.questionType);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is QuizQuestionAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
