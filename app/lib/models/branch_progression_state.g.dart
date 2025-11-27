// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'branch_progression_state.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class BranchProgressionStateAdapter
    extends TypeAdapter<BranchProgressionState> {
  @override
  final int typeId = 26;

  @override
  BranchProgressionState read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return BranchProgressionState(
      coupleId: fields[0] as String,
      activityTypeIndex: fields[1] as int,
      currentBranch: fields[2] == null ? 0 : fields[2] as int,
      totalCompletions: fields[3] == null ? 0 : fields[3] as int,
      maxBranches: fields[4] == null ? 2 : fields[4] as int,
      lastCompletedAt: fields[5] as DateTime?,
      createdAt: fields[6] as DateTime?,
    );
  }

  @override
  void write(BinaryWriter writer, BranchProgressionState obj) {
    writer
      ..writeByte(7)
      ..writeByte(0)
      ..write(obj.coupleId)
      ..writeByte(1)
      ..write(obj.activityTypeIndex)
      ..writeByte(2)
      ..write(obj.currentBranch)
      ..writeByte(3)
      ..write(obj.totalCompletions)
      ..writeByte(4)
      ..write(obj.maxBranches)
      ..writeByte(5)
      ..write(obj.lastCompletedAt)
      ..writeByte(6)
      ..write(obj.createdAt);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BranchProgressionStateAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
