import 'package:mobx/src/api/observable_collections.dart';
import 'package:shock_alarm_app/services/openshock.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../stores/alarm_store.dart';
import 'dart:convert';


class AlarmListManager {
  final List<ObservableAlarmBase> _alarms = [];
  final List<Shocker> shockers = [];
  final List<Token> _tokens = [];

  final Map<String, bool> enabledHubs = {};

  AlarmListManager();

  Function? reloadAllMethod;

  Future loadAllFromStorage() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    String alarms = prefs.getString("alarms") ?? "[]";
    String tokens = prefs.getString("tokens") ?? "[]";
    String shockers = prefs.getString("shockers") ?? "[]";
    List<dynamic> alarmsList = jsonDecode(alarms);
    List<dynamic> tokensList = jsonDecode(tokens);
    List<dynamic> shockersList = jsonDecode(shockers);
    for (var alarm in alarmsList) {
      _alarms.add(ObservableAlarmBase.fromJson(alarm));
    }
    for (var token in tokensList) {
      _tokens.add(Token.fromJson(token));
    }
    for (var shocker in shockersList) {
      this.shockers.add(Shocker.fromJson(shocker));
    }
    updateHubList();
    rebuildAlarmShockers();
    if(reloadAllMethod != null) {
      reloadAllMethod!();
    }
  }

  void updateHubList() {
    List<String> hubs = shockers.map((e) => e.hub).toSet().toList();
    for (var hub in hubs) {
      enabledHubs.putIfAbsent(hub, () => true);
    }
  }

  saveAlarm(ObservableAlarmBase alarm) async {
    final index =
        _alarms.indexWhere((findAlarm) => alarm.id == findAlarm.id);
    if (index == -1) {
      print('Adding new alarm');
      _alarms.add(alarm);
    } else {
      _alarms[index] = alarm;
    }
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    rebuildAlarmShockers();
    prefs.setString("alarms", jsonEncode(_alarms));
  }

  Future updateShockerStore() async {
    List<Shocker> shockers = [];
    for(var token in _tokens) {
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
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    prefs.setString("shockers", jsonEncode(shockers));
    updateHubList();
    rebuildAlarmShockers();
  }

  void saveToken(Token token) async {
    final index = _tokens.indexWhere((findToken) => token.id == findToken.id);
    if (index == -1) {
      _tokens.add(token);
    } else {
      _tokens[index] = token;
    }
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    prefs.setString("tokens", jsonEncode(_tokens));
    updateShockerStore();
    //await _storage.writeList(_tokens.tokens);
  }

  void deleteAlarm(ObservableAlarmBase alarm) {
    _alarms.removeWhere((findAlarm) => alarm.id == findAlarm.id);
  }

  void rebuildAlarmShockers() {
    for(var alarm in _alarms) {
      // remove shockers which don't exist
      alarm.shockers.removeWhere((element) => shockers.indexWhere((shocker) => shocker.id == element.shockerId) == -1);
      for(var shocker in shockers) {
        // check if shocker is already present in alarm
        if(alarm.shockers.indexWhere((element) => element.shockerId == shocker.id) == -1) {
          alarm.shockers.add(AlarmShocker()..shockerId = shocker.id);
        }

        // Set reference to shocker
        for(var alarmShocker in alarm.shockers) {
          if(alarmShocker.shockerId == shocker.id) {
            alarmShocker.shockerReference = shocker;
            if(shocker.paused) {
              alarmShocker.enabled = false;
            }
          }
        }
      }
    }
  }

  getAlarms() {
    return _alarms;
  }

  getTokens() {
    return _tokens;
  }

  void deleteToken(Token token) {
    _tokens.removeWhere((findToken) => token.id == findToken.id);
    //await _storage.writeList(_tokens.tokens);
  }

  Token? getToken(int id) {
    return _tokens.firstWhere((findToken) => id == findToken.id);
  }

  void sendShock(ControlType type, Shocker shocker, int currentIntensity, int currentDuration) {
    Control control = Control();
    control.intensity = currentIntensity;
    control.duration = currentDuration;
    control.type = type;
    control.id = shocker.id;
    control.exclusive = true;
    Token? t = getToken(shocker.apiTokenId);
    if(t == null) {
      print("Token not found");
      return;
    }
    OpenShockClient client = OpenShockClient();
    client.sendControls(t, [control]);
  }
}