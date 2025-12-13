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
      startTimeHour: fields[7] as int?,
      startTimeMinute: fields[8] as int?,
      endTimeHour: fields[9] as int?,
      endTimeMinute: fields[10] as int?,
    );
  }

  @override
  void write(BinaryWriter writer, CachedEvent obj) {
    writer
      ..writeByte(11)
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
      ..write(obj.startTimeHour)
      ..writeByte(8)
      ..write(obj.startTimeMinute)
      ..writeByte(9)
      ..write(obj.endTimeHour)
      ..writeByte(10)
      ..write(obj.endTimeMinute);
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
