import 'package:hive/hive.dart';

part 'offline_action.g.dart';

@HiveType(typeId: 1)
enum ActionType {
  @HiveField(0)
  add,
  @HiveField(1)
  edit,
  @HiveField(2)
  delete,
}

@HiveType(typeId: 2)
class OfflineAction extends HiveObject {
  @HiveField(0)
  ActionType type;

  @HiveField(1)
  Map<String, dynamic> data;

  OfflineAction({required this.type, required this.data});
}
