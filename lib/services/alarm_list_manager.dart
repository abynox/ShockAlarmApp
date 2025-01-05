import 'package:flutter/material.dart';
import 'package:shock_alarm_app/services/openshock.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';

import '../stores/alarm_store.dart';
import 'dart:convert';


class AlarmListManager {
  final List<ObservableAlarmBase> _alarms = [];
  final List<Shocker> shockers = [];
  final List<Token> _tokens = [];

  final Map<String, bool> enabledHubs = {};

  AlarmListManager();

  Function? reloadAllMethod;

  BuildContext? context;


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
    for(var hub in enabledHubs.keys.toList()) {
      if(hubs.indexWhere((element) => element == hub) == -1) {
        enabledHubs.remove(hub);
      }
    }
  }

  void rescheduleAlarms() async {
    for (var alarm in _alarms) {
      if (alarm.active) {
        await alarm.schedule(this);
      }
    }
  }

  int getNewAlarmId() {
    int id = 0;
    bool foundNew = true;
    while (!foundNew) {
      foundNew = true;
      for (var alarm in _alarms) {
        if (alarm.id == id) {
          id++;
          foundNew = false;
          break;
        }
      }
    }
    return id;
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
    rebuildAlarmShockers();
    rescheduleAlarms();
    saveAlarms();
  }

  Future updateShockerStore() async {
    List<Shocker> shockers = [];
    List<Token> tokensCopy = this._tokens.toList(); // create a copy
    for(var token in tokensCopy) {
      OpenShockClient client = OpenShockClient();
      token.name = await client.getNameForToken(token);
      List<Shocker> s = await client.GetShockersForToken(token);
      // add shockers without duplicates
      for(var shocker in s) {
        if(shockers.indexWhere((element) => element.id == shocker.id) == -1) {
          shockers.add(shocker);
        }
      }
    }
    this.shockers.clear();
    this.shockers.addAll(shockers);
    saveShockers();
    saveTokens();
    updateHubList();
    rebuildAlarmShockers();
    reloadAllMethod!();
  }

  void saveToken(Token token) async {
    final index = _tokens.indexWhere((findToken) => token.id == findToken.id);
    if (index == -1) {
      _tokens.add(token);
    } else {
      _tokens[index] = token;
    }
    saveTokens();
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
          }
        }
      }
    }
  }

  List<ObservableAlarmBase> getAlarms() {
    return _alarms;
  }

  getTokens() {
    return _tokens;
  }

  void saveShockers() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    prefs.setString("shockers", jsonEncode(shockers));
  }

  void saveAlarms() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    prefs.setString("alarms", jsonEncode(_alarms));
  }

  void saveTokens() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    prefs.setString("tokens", jsonEncode(_tokens));
  }

  void deleteToken(Token token) {
    _tokens.removeWhere((findToken) => token.id == findToken.id);
    saveTokens();
  }

  Token? getToken(int id) {
    return _tokens.firstWhere((findToken) => id == findToken.id);
  }

  Future<String?> sendShock(ControlType type, Shocker shocker, int currentIntensity, int currentDuration, {String customName = "ShockAlarm"}) async {
    Control control = Control();
    control.intensity = currentIntensity;
    control.duration = currentDuration;
    control.type = type;
    control.id = shocker.id;
    control.exclusive = true;
    Token? t = getToken(shocker.apiTokenId);
    if(t == null) {
      return "Token not found";
    }
    print("Sending ${type} to ${shocker.name} with intensity $currentIntensity and duration $currentDuration");
    OpenShockClient client = OpenShockClient();
    return await client.sendControls(t, [control], customName: customName) ? null : "Failed to send shock, is your token still valid?";
  }

  Future<bool> login(String serverAddress, String email, String password) async {
    Token? session = await OpenShockClient().login(serverAddress, email, password, this);
    if(session != null) {
      saveToken(session);
    }
    return session != null;
  }

  Future<String?> renameShocker(Shocker shocker, String text) {
    return OpenShockClient().renameShocker(shocker, text, this);
  }

  Future<List<ShockerLog>> getShockerLogs(Shocker shocker) {
    return OpenShockClient().getShockerLogs(shocker, this);
  }
}