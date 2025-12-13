import 'package:hive/hive.dart';

part 'event_model.g.dart';

@HiveType(typeId: 0)
class CachedEvent extends HiveObject {
  @HiveField(0)
  late String id;

  @HiveField(1)
  late String title;

  @HiveField(2)
  late String description;

  @HiveField(3)
  late String date; // store as ISO8601 string

  @HiveField(4)
  String? fingerprint;

  @HiveField(5)
  String? deviceName;

  @HiveField(6)
  int? colorValue;

  CachedEvent({
    required this.id,
    required this.title,
    required this.description,
    required this.date,
    this.fingerprint,
    this.deviceName,
    this.colorValue,
  });
}