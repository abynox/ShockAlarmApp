import 'package:mobx/mobx.dart';

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


class ObservableAlarmBase with Store {
  int id;

  @observable
  String name;

  @observable
  int hour;

  @observable
  int minute;

  @observable
  bool monday;

  @observable
  bool tuesday;

  @observable
  bool wednesday;

  @observable
  bool thursday;

  @observable
  bool friday;

  @observable
  bool saturday;

  @observable
  bool sunday;

  @observable
  bool active;

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
      "active": active
    };
  }

  static ObservableAlarmBase fromJson(alarm) {
    return ObservableAlarmBase(
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
  }
}