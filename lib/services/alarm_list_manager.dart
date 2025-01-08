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
  final List<Hub> hubs = [];
  final Map<String, bool> enabledHubs = {};

  AlarmListManager();

  Function? reloadAllMethod;

  BuildContext? context;


  Future loadAllFromStorage() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    String alarms = prefs.getString("alarms") ?? "[]";
    String tokens = prefs.getString("tokens") ?? "[]";
    String shockers = prefs.getString("shockers") ?? "[]";
    String hubs = prefs.getString("hubs") ?? "[]";
    List<dynamic> alarmsList = jsonDecode(alarms);
    List<dynamic> tokensList = jsonDecode(tokens);
    List<dynamic> shockersList = jsonDecode(shockers);
    List<dynamic> hubsList = jsonDecode(hubs);
    for (var alarm in alarmsList) {
      _alarms.add(ObservableAlarmBase.fromJson(alarm));
    }
    for (var token in tokensList) {
      _tokens.add(Token.fromJson(token));
    }
    for (var hub in hubsList) {
      this.hubs.add(Hub.fromJson(hub));
    }
    for (var shocker in shockersList) {
      Shocker s = Shocker.fromJson(shocker);
      for(var hub in this.hubs) {
        if(s.hubId == hub.id) {
          s.hubReference = hub;
          hub.apiTokenId = s.apiTokenId;
        }
      }
      this.shockers.add(s);
    }
    updateHubList();
    rebuildAlarmShockers();
    if(reloadAllMethod != null) {
      reloadAllMethod!();
    }
  }

  void updateHubList() {
    for (var hub in hubs) {
      enabledHubs.putIfAbsent(hub.id, () => true);
    }
    for(var hub in enabledHubs.keys.toList()) {
      if(hubs.indexWhere((element) => element.id == hub) == -1) {
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
    bool foundNew = false;
    while (!foundNew) {
      foundNew = true;
      for (var alarm in getAlarms()) {
        print(alarm.id);
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
    List<Hub> hubs = [];
    List<Token> tokensCopy = this._tokens.toList(); // create a copy
    for(var token in tokensCopy) {
      OpenShockClient client = OpenShockClient();
      token.name = await client.getNameForToken(token);
      DeviceContainer devices = await client.GetShockersForToken(token);
      // add shockers without duplicates
      for(var hub in devices.hubs) {
        if(hubs.indexWhere((element) => element.id == hub.id) == -1) {
          hubs.add(hub);
        }
      }
      for(var shocker in devices.shockers) {
        if(shockers.indexWhere((element) => element.id == shocker.id) == -1) {
          shockers.add(shocker);
        }
      }
    }
    this.shockers.clear();
    this.shockers.addAll(shockers);
    this.hubs.clear();
    this.hubs.addAll(hubs);
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

  List<Token> getTokens() {
    return _tokens;
  }

  void saveShockers() async {
    updateHubList();
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    prefs.setString("shockers", jsonEncode(shockers));
    prefs.setString("hubs", jsonEncode(hubs));
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


  Future<String?> renameHub(Hub hub, String text) {
    return OpenShockClient().renameHub(hub, text, this);
  }

  Future<List<ShockerLog>> getShockerLogs(Shocker shocker) {
    return OpenShockClient().getShockerLogs(shocker, this);
  }

  Future<List<OpenShockShare>> getShockerShares(Shocker shocker) {
    return OpenShockClient().getShockerShares(shocker, this);
  }

  Future<List<OpenShockShareCode>> getShockerShareCodes(Shocker shocker) {
    return OpenShockClient().getShockerShareCodes(shocker, this);
  }

  Future<String?> deleteShareCode(OpenShockShareCode shareCode) {
    return OpenShockClient().deleteShareCode(shareCode, this);
  }



  Token? getAnyUserToken() {
    for(var token in getTokens()) {
      if(token.isSession && token.name.isNotEmpty) {
        return token;
      }
    }
  }

  bool hasValidAccount() {
    return getAnyUserToken() != null;
  }

  Future<String?> redeemShareCode(String code) {
    return OpenShockClient().redeemShareCode(code, this);
  }

  Future<List<OpenShockDevice>> getDevices() async {
    List<OpenShockDevice> devices = [];
    for(var token in getTokens()) {
      devices.addAll(await OpenShockClient().getDevices(token));
    }
    return devices;
  }

  Future<String?> addShocker(String name, int rfId, String shockerType, OpenShockDevice? device) {
    return OpenShockClient().addShocker(name, rfId, shockerType, device, this);
  }

  Future<String?> deleteShocker(Shocker shocker) {
    return OpenShockClient().deleteShocker(shocker, this);
  }

  Future<String?> deleteShare(OpenShockShare share) {
    return OpenShockClient().deleteShare(share, this);
    }

  Hub? getHub(String hubId) {
    for(var hub in hubs) {
      if(hub.id == hubId) {
        return hub;
      }
    }
  }

  Future<String?> deleteHub(Hub hub) {
    return OpenShockClient().deleteHub(hub, this);
  }

  Future<PairCode> getPairCode(String hubId) {
    return getPairCodeViaHub(getHub(hubId)!);
  }

  Future<PairCode> getPairCodeViaHub(Hub hub) {
    return OpenShockClient().getPairCode(hub, this);
  }

  Future<CreatedHub> addHub(String name) {
    return OpenShockClient().addHub(name, this);
  }
}