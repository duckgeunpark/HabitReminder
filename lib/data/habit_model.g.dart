// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'habit_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class HabitAdapter extends TypeAdapter<Habit> {
  @override
  final int typeId = 0;

  @override
  Habit read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Habit(
      id: fields[0] as String,
      name: fields[1] as String,
      imagePaths: (fields[2] as List).cast<String>(),
      intervalSeconds: fields[3] as int,
      createdAt: fields[4] as DateTime,
      isActive: fields[5] as bool,
      currentImageIndex: fields[6] as int,
      lastResetTime: fields[7] as DateTime?,
      streakCount: fields[8] as int,
      totalClicks: fields[9] as int,
      imageTimings: (fields[10] as Map?)?.cast<int, int>() ?? const {},
      imageTimingsSeconds: (fields[11] as Map?)?.cast<int, int>() ?? const {},
      clickedImageIndex: fields[12] as int? ?? 0,
      activatedTime: fields[13] as DateTime?,
      totalActiveSeconds: fields[14] as int? ?? 0,
      clickTimes: (fields[15] as List?)?.cast<int>() ?? [],
      clickTimestamps: (fields[16] as List?)?.cast<DateTime>() ?? [],
    );
  }

  @override
  void write(BinaryWriter writer, Habit obj) {
    writer
      ..writeByte(17)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.imagePaths)
      ..writeByte(3)
      ..write(obj.intervalSeconds)
      ..writeByte(4)
      ..write(obj.createdAt)
      ..writeByte(5)
      ..write(obj.isActive)
      ..writeByte(6)
      ..write(obj.currentImageIndex)
      ..writeByte(7)
      ..write(obj.lastResetTime)
      ..writeByte(8)
      ..write(obj.streakCount)
      ..writeByte(9)
      ..write(obj.totalClicks)
      ..writeByte(10)
      ..write(obj.imageTimings)
      ..writeByte(11)
      ..write(obj.imageTimingsSeconds)
      ..writeByte(12)
      ..write(obj.clickedImageIndex)
      ..writeByte(13)
      ..write(obj.activatedTime)
      ..writeByte(14)
      ..write(obj.totalActiveSeconds)
      ..writeByte(15)
      ..write(obj.clickTimes)
      ..writeByte(16)
      ..write(obj.clickTimestamps);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is HabitAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
