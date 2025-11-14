// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'quiz_progression_state.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class QuizProgressionStateAdapter extends TypeAdapter<QuizProgressionState> {
  @override
  final int typeId = 19;

  @override
  QuizProgressionState read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return QuizProgressionState(
      coupleId: fields[0] as String,
      currentTrack: fields[1] as int,
      currentPosition: fields[2] as int,
      completedQuizzes: (fields[3] as Map).cast<String, bool>(),
      createdAt: fields[4] as DateTime,
      lastCompletedAt: fields[5] as DateTime?,
      totalQuizzesCompleted: fields[6] == null ? 0 : fields[6] as int,
      hasCompletedAllTracks: fields[7] == null ? false : fields[7] as bool,
    );
  }

  @override
  void write(BinaryWriter writer, QuizProgressionState obj) {
    writer
      ..writeByte(8)
      ..writeByte(0)
      ..write(obj.coupleId)
      ..writeByte(1)
      ..write(obj.currentTrack)
      ..writeByte(2)
      ..write(obj.currentPosition)
      ..writeByte(3)
      ..write(obj.completedQuizzes)
      ..writeByte(4)
      ..write(obj.createdAt)
      ..writeByte(5)
      ..write(obj.lastCompletedAt)
      ..writeByte(6)
      ..write(obj.totalQuizzesCompleted)
      ..writeByte(7)
      ..write(obj.hasCompletedAllTracks);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is QuizProgressionStateAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
