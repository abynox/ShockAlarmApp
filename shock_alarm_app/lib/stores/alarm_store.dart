import 'package:mobx/mobx.dart';
import 'package:json_annotation/json_annotation.dart';

class AlarmList with Store {
  AlarmList();

  @observable
  ObservableList<ObservableAlarmBase> alarms = ObservableList();

  @action
  void setAlarms(List<ObservableAlarmBase> alarms) {
    this.alarms.clear();
    this.alarms.addAll(alarms);
  }
}

class TokenList with Store {
  TokenList();

  @observable
  ObservableList<Token> tokens = ObservableList();

  @action
  void setTokens(List<Token> tokens) {
    this.tokens.clear();
    this.tokens.addAll(tokens);
  }
}

class Token with Store {
  Token(this.id, this.token);

  int id;

  @observable
  String token;

  @observable
  String server = "https://api.openshock.app";
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
}