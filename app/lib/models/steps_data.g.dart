// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'steps_data.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class StepsDayAdapter extends TypeAdapter<StepsDay> {
  @override
  final int typeId = 27;

  @override
  StepsDay read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return StepsDay(
      dateKey: fields[0] as String,
      userSteps: fields[1] as int,
      partnerSteps: fields[2] as int,
      lastSync: fields[3] as DateTime,
      partnerLastSync: fields[4] as DateTime?,
      claimed: fields[5] == null ? false : fields[5] as bool,
      earnedLP: fields[6] == null ? 0 : fields[6] as int,
      claimExpiresAt: fields[7] as DateTime?,
      claimedByUserId: fields[8] as String?,
      overlayShownAt: fields[9] as DateTime?,
    );
  }

  @override
  void write(BinaryWriter writer, StepsDay obj) {
    writer
      ..writeByte(10)
      ..writeByte(0)
      ..write(obj.dateKey)
      ..writeByte(1)
      ..write(obj.userSteps)
      ..writeByte(2)
      ..write(obj.partnerSteps)
      ..writeByte(3)
      ..write(obj.lastSync)
      ..writeByte(4)
      ..write(obj.partnerLastSync)
      ..writeByte(5)
      ..write(obj.claimed)
      ..writeByte(6)
      ..write(obj.earnedLP)
      ..writeByte(7)
      ..write(obj.claimExpiresAt)
      ..writeByte(8)
      ..write(obj.claimedByUserId)
      ..writeByte(9)
      ..write(obj.overlayShownAt);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StepsDayAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class StepsConnectionAdapter extends TypeAdapter<StepsConnection> {
  @override
  final int typeId = 28;

  @override
  StepsConnection read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return StepsConnection(
      isConnected: fields[0] == null ? false : fields[0] as bool,
      connectedAt: fields[1] as DateTime?,
      partnerConnected: fields[2] == null ? false : fields[2] as bool,
      partnerConnectedAt: fields[3] as DateTime?,
      permissionDenied: fields[4] == null ? false : fields[4] as bool,
    );
  }

  @override
  void write(BinaryWriter writer, StepsConnection obj) {
    writer
      ..writeByte(5)
      ..writeByte(0)
      ..write(obj.isConnected)
      ..writeByte(1)
      ..write(obj.connectedAt)
      ..writeByte(2)
      ..write(obj.partnerConnected)
      ..writeByte(3)
      ..write(obj.partnerConnectedAt)
      ..writeByte(4)
      ..write(obj.permissionDenied);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StepsConnectionAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
