import 'package:mobx/mobx.dart';
import 'package:shock_alarm_app/services/openshock.dart';

class Token with Store {
  Token(this.id, this.token, {this.server = "https://api.openshock.app"});

  int id;

  @observable
  String token;

  @observable
  String server;

  static Token fromJson(token) {
    return Token(token["id"], token["token"], server: token["server"]);
  }

  Map<String, dynamic> toJson() {
    return {"id": id, "token": token, "server": server};
  }
}

class AlarmShocker {
  String shockerId = "";
  String? toneId;
  int intensity = 25;
  int duration = 1000;
  ControlType? type = ControlType.vibrate;
  Shocker? shockerReference;

  bool enabled = false;
  
  Map<String, dynamic> toJson() {
    return {
      "shockerId": shockerId, 
      "toneId": toneId,
      "intensity": intensity,
      "duration": duration,
      "type": type?.index ?? -1,
      "enabled": enabled
    };
  }

  static AlarmShocker fromJson(shocker) {
    return AlarmShocker()
      ..shockerId = shocker["shockerId"]
      ..toneId = shocker["toneId"]
      ..intensity = shocker["intensity"]
      ..duration = shocker["duration"]
      ..type = shocker["type"] == -1 ? null : ControlType.values[shocker["type"]]
      ..enabled = shocker["enabled"];
  }
}

class ObservableAlarmBase with Store {
  int id;
  String name;
  int hour;
  int minute;
  bool monday;
  bool tuesday;
  bool wednesday;
  bool thursday;
  bool friday;
  bool saturday;
  bool sunday;
  bool active;
  List<AlarmShocker> shockers = [];

  ObservableAlarmBase(
      {required this.id,
      required this.name,
      required this.hour,
      required this.minute,
      this.monday = false,
      this.tuesday = false,
      this.wednesday = false,
      this.thursday = false,
      this.friday = false,
      this.saturday = false,
      this.sunday = false,
      required this.active});

  List<bool> get days {
    return [monday, tuesday, wednesday, thursday, friday, saturday, sunday];
  }

  // Good enough for debugging for now
  toString() {
    return "active: $active, name: $name, hour: $hour, minute: $minute, days: $days";
  }

  Map<String, dynamic> toJson() {
    return {
      "id": id,
      "name": name,
      "hour": hour,
      "minute": minute,
      "monday": monday,
      "tuesday": tuesday,
      "wednesday": wednesday,
      "thursday": thursday,
      "friday": friday,
      "saturday": saturday,
      "sunday": sunday,
      "active": active,
      "shockers": shockers.map((e) => e.toJson()).toList()
    };
  }

  static ObservableAlarmBase fromJson(alarm) {
    ObservableAlarmBase a = ObservableAlarmBase(
      id: alarm["id"],
      name: alarm["name"],
      hour: alarm["hour"],
      minute: alarm["minute"],
      monday: alarm["monday"],
      tuesday: alarm["tuesday"],
      wednesday: alarm["wednesday"],
      thursday: alarm["thursday"],
      friday: alarm["friday"],
      saturday: alarm["saturday"],
      sunday: alarm["sunday"],
      active: alarm["active"]);
    if(alarm["shockers"] != null) {
      a.shockers = (alarm["shockers"] as List).map((e) => AlarmShocker.fromJson(e)).toList();
    }
    return a;
  }
}