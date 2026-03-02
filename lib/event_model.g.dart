// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'event_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class CachedEventAdapter extends TypeAdapter<CachedEvent> {
  @override
  final int typeId = 0;

  @override
  CachedEvent read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return CachedEvent(
      id: fields[0] as String,
      title: fields[1] as String,
      description: fields[2] as String,
      date: fields[3] as String,
      fingerprint: fields[4] as String?,
      deviceName: fields[5] as String?,
      colorValue: fields[6] as int?,
      startTime: fields[7] as String?,
      endTime: fields[8] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, CachedEvent obj) {
    writer
      ..writeByte(9)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.title)
      ..writeByte(2)
      ..write(obj.description)
      ..writeByte(3)
      ..write(obj.date)
      ..writeByte(4)
      ..write(obj.fingerprint)
      ..writeByte(5)
      ..write(obj.deviceName)
      ..writeByte(6)
      ..write(obj.colorValue)
      ..writeByte(7)
      ..write(obj.startTime)
      ..writeByte(8)
      ..write(obj.endTime);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CachedEventAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
