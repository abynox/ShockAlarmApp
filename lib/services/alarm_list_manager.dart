import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shock_alarm_app/services/openshock.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';
import 'package:shock_alarm_app/services/openshockws.dart';
import 'package:signalr_core/signalr_core.dart';

import '../stores/alarm_store.dart';
import 'dart:convert';

class Settings {
  bool showRandomDelay = true;
  bool useRangeSliderForRandomDelay = true;
  bool useRangeSliderForIntensity = false;
  bool useRangeSliderForDuration = false;

  bool disableHubFiltering = true;

  bool allowTokenEditing = false;
  bool useHttpShocking = false;

  bool useGroupedShockerSelection = false;

  int alarmToneRepeatDelayMs = 1500;

  int maxAlarmLengthSeconds = 60;

  ThemeMode theme = ThemeMode.system;


  Settings();

  Settings.fromJson(Map<String, dynamic> json) {
    if(json["showRandomDelay"] != null)
      showRandomDelay = json["showRandomDelay"];
    if(json["useRangeSliderForRandomDelay"] != null)
      useRangeSliderForRandomDelay = json["useRangeSliderForRandomDelay"];
    if(json["useRangeSliderForIntensity"] != null)
      useRangeSliderForIntensity = json["useRangeSliderForIntensity"];
    if(json["useRangeSliderForDuration"] != null)
      useRangeSliderForDuration = json["useRangeSliderForDuration"];
    if(json["disableHubFiltering"] != null)
      disableHubFiltering = json["disableHubFiltering"];
    if(json["allowTokenEditing"] != null)
      allowTokenEditing = json["allowTokenEditing"];
    if(json["useHttpShocking"] != null)
      useHttpShocking = json["useHttpShocking"];
    if(json["useGroupedShockerSelection"] != null)
      useGroupedShockerSelection = json["useGroupedShockerSelection"];
    if(json["theme"] != null)
      theme = ThemeMode.values[json["theme"]];
  }

  Map<String, dynamic> toJson() {
    return {
      "showRandomDelay": showRandomDelay,
      "useRangeSliderForRandomDelay": useRangeSliderForRandomDelay,
      "useRangeSliderForIntensity": useRangeSliderForIntensity,
      "useRangeSliderForDuration": useRangeSliderForDuration,
      "disableHubFiltering": disableHubFiltering,
      "allowTokenEditing": allowTokenEditing,
      "useHttpShocking": useHttpShocking,
      "useGroupedShockerSelection": useGroupedShockerSelection,
      "theme": theme.index
    };
  }
}

class AlarmListManager {
  final List<Alarm> _alarms = [];
  final List<Shocker> shockers = [];
  final List<Token> _tokens = [];
  final List<Hub> hubs = [];
  final List<String> onlineHubs = [];
  final List<AlarmTone> alarmTones = [];
  List<OpenShockShareLink>? shareLinks;
  final Map<String, bool> enabledHubs = {};
  Settings settings = Settings();
  OpenShockWS? ws;
  static AlarmListManager? instance;

  ControlsContainer controls = ControlsContainer();

  AlarmListManager();

  Function? reloadAllMethod;

  BuildContext? context;

  List<String> selectedShockers = [];

  bool delayVibrationEnabled = false;

  static AlarmListManager getInstance() {
    return instance!;
  }


  Future loadAllFromStorage() async {
    instance = this;
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    String alarms = prefs.getString("alarms") ?? "[]";
    String tokens = prefs.getString("tokens") ?? "[]";
    String shockers = prefs.getString("shockers") ?? "[]";
    String hubs = prefs.getString("hubs") ?? "[]";
    String settings = prefs.getString("settings") ?? "{}";
    String alarmTones = prefs.getString("alarmTones") ?? "[]";
    List<dynamic> alarmsList = jsonDecode(alarms);
    List<dynamic> tokensList = jsonDecode(tokens);
    List<dynamic> shockersList = jsonDecode(shockers);
    List<dynamic> hubsList = jsonDecode(hubs);
    List<dynamic> alarmTonesList = jsonDecode(alarmTones);
    this.settings = Settings.fromJson(jsonDecode(settings));
    if(kIsWeb) this.settings.useHttpShocking = true;
    for (var alarm in alarmsList) {
      _alarms.add(Alarm.fromJson(alarm));
    }
    for (var token in tokensList) {
      print("Adding token");
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
    for (var alarmTone in alarmTonesList) {
      this.alarmTones.add(AlarmTone.fromJson(alarmTone));
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

  void saveSettings() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    prefs.setString("settings", jsonEncode(settings));
    reloadAllMethod?.call();
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
        if (alarm.id == id) {
          id++;
          foundNew = false;
          break;
        }
      }
    }
    return id;
  }
  int getNewToneId() {
    int id = 0;
    bool foundNew = false;
    while (!foundNew) {
      foundNew = true;
      for (var tone in alarmTones) {
        if (tone.id == id) {
          id++;
          foundNew = false;
          break;
        }
      }
    }
    return id;
  }

  saveAlarm(Alarm alarm) async {
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
      await client.setInfoOfToken(token);
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

  void deleteAlarm(Alarm alarm) {
    _alarms.removeWhere((findAlarm) => alarm.id == findAlarm.id);
    saveAlarms();
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

  List<Alarm> getAlarms() {
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

  Future saveTokens() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    prefs.setString("tokens", jsonEncode(_tokens));
  }

  Future saveAlarmTones() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    prefs.setString("alarmTones", jsonEncode(alarmTones));
  }

  Future<String?> deleteToken(Token token) async {
    String? error;
    if(token.isSession) {
      // Invalidate session
      error = await OpenShockClient().logout(token);
      if(error != null) return error;
    }
    _tokens.removeWhere((findToken) => token.id == findToken.id);
    await saveTokens();
    return error;
  }

  Token? getToken(int id) {
    return _tokens.firstWhere((findToken) => id == findToken.id);
  }

  Future<String?> sendShock(ControlType type, Shocker shocker, int currentIntensity, int currentDuration, {String customName = "ShockAlarm", bool useWs = true}) async {
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
    return await client.sendControls(t, [control], this, customName: customName, useWs: !settings.useHttpShocking && useWs) ? null : "Failed to send shock, is your token still valid?";
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
      if(token.name.isNotEmpty) {
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

  Map<String?, List<ShockerLog>> availableShockerLogs = {};
  Function? reloadShockerLogs;

  Function()? reloadShareLinksMethod;

  Function()? onRefresh;

  Future startWS(Token t, {bool stopExisting = true}) async {
    if(ws != null) {
      if(!stopExisting) return;
      await ws!.stopConnection();
    }
    ws = OpenShockWS(t);
    await ws!.startConnection();
    ws?.addMessageHandler("DeviceStatus", (List<dynamic>? list) {
      if(list == null) return;
      deviceStatusHandler(list);
    });
    ws?.addMessageHandler("Log", (List<dynamic>? list) {
      if(list == null) return;
      OpenShockUser user = OpenShockUser.fromJson(list[0]);
      for(Map<String, dynamic> shocker in list[1]){
        WSShockerLog wslog = WSShockerLog.fromJson(shocker);
        ShockerLog log = ShockerLog.fromWs(wslog, user);
        log.shockerReference = shockers.firstWhere((element) => element.id == wslog.shocker?.id);
        availableShockerLogs.putIfAbsent(log.shockerReference?.id, () => []).add(log);
      }
      if(reloadShockerLogs != null) {
        reloadShockerLogs!();
      }
    });
  }

  void deviceStatusHandler(List<dynamic> args) {
    for(var arg in args[0]) {
      OpenShockDevice d = OpenShockDevice.fromJson(arg);
      if(d.online && !onlineHubs.contains(d.device)) {
        onlineHubs.add(d.device);
      } else {
        onlineHubs.remove(d.device);
      }
    }
    print(onlineHubs);
    reloadAllMethod!();
  }

  Future<String?> sendControls(List<Control> controls, {String customName = "ShockAlarm", bool useWs = true}) async {
    Map<int, List<Control>> controlsByToken = {};
    for(var control in controls) {
      controlsByToken.putIfAbsent(control.apiTokenId, () => []).add(control);
    }
    OpenShockClient client = OpenShockClient();
    for(var token in getTokens()) {
      if(controlsByToken.containsKey(token.id)) {
        if(!await client.sendControls(token, controlsByToken[token.id]!, this, customName: customName, useWs: !settings.useHttpShocking && useWs)) {
          return "Failed to send shock to at least 1 shocker, is your token still valid?";
        }
      }
    }
    return null;
  }

  Future<dynamic> startAnyWS() async {
    for(var token in getTokens()) {
      return await startWS(token, stopExisting: false);
    }
  }

  void saveTone(AlarmTone tone) {
    // sort components by time
    tone.components.sort((a, b) => a.time.compareTo(b.time));
    final index = alarmTones.indexWhere((findTone) => tone.id == findTone.id);
    if (index == -1) {
      alarmTones.add(tone);
    } else {
      alarmTones[index] = tone;
    }
    saveAlarmTones();
  }

  void deleteTone(AlarmTone tone) {
    alarmTones.removeWhere((findTone) => tone.id == findTone.id);
    saveAlarmTones();
  }

  AlarmTone? getTone(int id) {
    for(var tone in alarmTones) {
      if(tone.id == id) {
        return tone;
      }
    }
    return null;
  }

  Future<bool> loginToken(String serverAddress, String token) async {
    Token tokentoken = Token(DateTime.now().millisecondsSinceEpoch, token, server: serverAddress, isSession: false);
    OpenShockClient client = OpenShockClient();
    bool worked = await client.setInfoOfToken(tokentoken);
    if(worked) {
      saveToken(tokentoken);
    }
    return worked;
  }

  Future<List<OpenShockShareLink>> getShareLinks() async {
    List<OpenShockShareLink> links = [];
    OpenShockClient client = OpenShockClient();
    for(Token token in getTokens()) {
      links.addAll(await client.getShareLinks(token));
    }
    return links;
  }

  Future<String?> deleteShareLink(OpenShockShareLink shareLink) async {
    OpenShockClient client = OpenShockClient();
    return client.deleteShareLink(shareLink);
  }

  Future<OpenShockShareLink?> getShareLink(OpenShockShareLink shareLink) async {
    OpenShockClient client = OpenShockClient();
    return client.getShareLink(shareLink.tokenReference!, shareLink.id);
  }

  Future<String?> addShockerToShareLink(Shocker? selectedShocker, OpenShockShareLink openShockShareLink) {
    OpenShockClient client = OpenShockClient();
    return client.addShockerToShareLink(selectedShocker!, openShockShareLink);
  }

  Future<PairCode> createShareLink(String shareLinkName, DateTime dateTime) async {
    OpenShockClient client = OpenShockClient();
    Token? token = getAnyUserToken();
    if(token == null) return PairCode("No token found", null);
    return client.createShareLink(token, shareLinkName, dateTime);
  }

  void savePageIndex(int index) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    prefs.setInt("page", index);
  }

  Future<int> getPageIndex() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getInt("page") ?? -1;
  }


  Shocker getSelectedShockerLimits() {
    Shocker limitedShocker = Shocker();
    limitedShocker.durationLimit = 300;
    limitedShocker.intensityLimit = 0;
    limitedShocker.shockAllowed = false;
    limitedShocker.soundAllowed = false;
    limitedShocker.vibrateAllowed = false;
    for (Shocker s in shockers.where((x) {
      return selectedShockers.contains(x.id);
    })) {
      if (s.durationLimit > limitedShocker.durationLimit) {
        limitedShocker.durationLimit = s.durationLimit;
      }
      if (s.intensityLimit > limitedShocker.intensityLimit) {
        limitedShocker.intensityLimit = s.intensityLimit;
      }
      if (s.shockAllowed) {
        limitedShocker.shockAllowed = true;
      }
      if (s.soundAllowed) {
        limitedShocker.soundAllowed = true;
      }
      if (s.vibrateAllowed) {
        limitedShocker.vibrateAllowed = true;
      }
    }
    return limitedShocker;
  }

  Iterable<Shocker> getSelectedShockers() {
    return shockers.where((x) {
      return selectedShockers.contains(x.id);
    });
  }
}