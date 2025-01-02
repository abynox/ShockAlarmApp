import 'package:shock_alarm_app/services/openshock.dart';

import '../stores/alarm_store.dart';

class AlarmListManager {
  final AlarmList _alarms;
  final List<Shocker> shockers = [];
  final TokenList _tokens = TokenList();
  //final JsonFileStorage _storage = JsonFileStorage();

  AlarmListManager(this._alarms);

  saveAlarm(ObservableAlarmBase alarm) async {
    final index =
        _alarms.alarms.indexWhere((findAlarm) => alarm.id == findAlarm.id);
    if (index == -1) {
      print('Adding new alarm');
      _alarms.alarms.add(alarm);
    } else {
      _alarms.alarms[index] = alarm;
    }
    //await _storage.writeList(_alarms.alarms);
  }

  Future updateShockerStore() async {
    List<Shocker> shockers = [];
    for(var token in _tokens.tokens) {
      OpenShockClient client = OpenShockClient();
      List<Shocker> s = await client.GetShockersForToken(token);
      // add shockers without duplicates
      for(var shocker in s) {
        if(shockers.indexWhere((element) => element.id == shocker.id) == -1) {
          shockers.add(shocker);
          print("Added shocker: " + shocker.name);
        }
      }
    }
    this.shockers.clear();
    this.shockers.addAll(shockers);
    print(this.shockers.length);
  }

  void saveToken(Token token) {
    final index = _tokens.tokens.indexWhere((findToken) => token.id == findToken.id);
    if (index == -1) {
      _tokens.tokens.add(token);
    } else {
      _tokens.tokens[index] = token;
    }
    updateShockerStore();
    //await _storage.writeList(_tokens.tokens);
  }

  void deleteAlarm(ObservableAlarmBase alarm) {
    _alarms.alarms.removeWhere((findAlarm) => alarm.id == findAlarm.id);
    //await _storage.writeList(_alarms.alarms);
  }

  getAlarms() {
    return _alarms.alarms;
  }

  getTokens() {
    return _tokens.tokens;
  }

  void deleteToken(Token token) {
    _tokens.tokens.removeWhere((findToken) => token.id == findToken.id);
    //await _storage.writeList(_tokens.tokens);
  }

  Token? getToken(int id) {
    return _tokens.tokens.firstWhere((findToken) => id == findToken.id);
  }

  void sendShock(ControlType type, Shocker shocker, int currentIntensity, int currentDuration) {
    Control control = Control();
    control.intensity = currentIntensity;
    control.duration = currentDuration;
    control.type = type;
    control.id = shocker.id;
    control.exclusive = true;
    Token? t = getToken(shocker.tokenId);
    if(t == null) {
      print("Token not found");
      return;
    }
    OpenShockClient client = OpenShockClient();
    client.sendControls(t, [control]);
  }
}