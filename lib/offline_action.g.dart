// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'offline_action.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class OfflineActionAdapter extends TypeAdapter<OfflineAction> {
  @override
  final int typeId = 2;

  @override
  OfflineAction read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return OfflineAction(
      type: fields[0] as ActionType,
      data: (fields[1] as Map).cast<String, dynamic>(),
    );
  }

  @override
  void write(BinaryWriter writer, OfflineAction obj) {
    writer
      ..writeByte(2)
      ..writeByte(0)
      ..write(obj.type)
      ..writeByte(1)
      ..write(obj.data);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is OfflineActionAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class ActionTypeAdapter extends TypeAdapter<ActionType> {
  @override
  final int typeId = 1;

  @override
  ActionType read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return ActionType.add;
      case 1:
        return ActionType.edit;
      case 2:
        return ActionType.delete;
      default:
        return ActionType.add;
    }
  }

  @override
  void write(BinaryWriter writer, ActionType obj) {
    switch (obj) {
      case ActionType.add:
        writer.writeByte(0);
        break;
      case ActionType.edit:
        writer.writeByte(1);
        break;
      case ActionType.delete:
        writer.writeByte(2);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ActionTypeAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
