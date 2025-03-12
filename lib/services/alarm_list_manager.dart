import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shock_alarm_app/main.dart';
import 'package:shock_alarm_app/services/openshock.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shock_alarm_app/services/openshockws.dart';

import '../stores/alarm_store.dart';
import 'dart:convert';

import 'alarm_manager.dart';

class Settings {
  bool showRandomDelay = true;
  bool useRangeSliderForRandomDelay = true;
  bool useRangeSliderForIntensity = false;
  bool useRangeSliderForDuration = false;

  bool disableHubFiltering = true;

  bool allowTokenEditing = false;
  bool useHttpShocking = false;

  bool useAlarmServer = false;

  bool useGroupedShockerSelection = true;

  int alarmToneRepeatDelayMs = 1500;

  int maxAlarmLengthSeconds = 60;

  ThemeMode theme = ThemeMode.system;

  bool showFirmwareVersion = false;
  bool allowTonesForControls = false;


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
    if(json["useAlarmServer"] != null)
      useAlarmServer = json["useAlarmServer"];
    if(json["disableHubFiltering"] != null)
      disableHubFiltering = json["disableHubFiltering"];
    if(json["allowTokenEditing"] != null)
      allowTokenEditing = json["allowTokenEditing"];
    if(json["useHttpShocking"] != null)
      useHttpShocking = json["useHttpShocking"];
    if(json["useGroupedShockerSelection_1"] != null)
      useGroupedShockerSelection = json["useGroupedShockerSelection_1"]; // _1 added so the default saved value on existing installations gets changed
    if(json["theme"] != null)
      theme = ThemeMode.values[json["theme"]];
    if(json["showFirmwareVersion"] != null)
      showFirmwareVersion = json["showFirmwareVersion"];
    if(json["allowTonesForControls"] != null)
      allowTonesForControls = json["allowTonesForControls"];
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
      "useGroupedShockerSelection_1": useGroupedShockerSelection,
      "theme": theme.index,
      "showFirmwareVersion": showFirmwareVersion,
      "useAlarmServer": useAlarmServer,
      "allowTonesForControls": allowTonesForControls
    };
  }
}

class AlarmListManager {
  final List<Alarm> _alarms = [];
  final List<Shocker> shockers = [];
  final List<Token> _tokens = [];
  final List<Token> _alarmServerTokens = [];
  final List<Hub> hubs = [];
  final List<String> onlineHubs = [];
  final List<AlarmTone> alarmTones = [];
  List<OpenShockShareLink>? shareLinks;
  final Map<String, bool> enabledHubs = {};
  Settings settings = Settings();
  OpenShockWS? ws;
  static AlarmListManager? instance;

  Map<String?, List<ShockerLog>> shockerLog = {};

  ControlsContainer controls = ControlsContainer();

  AlarmListManager() {
    if(isAndroid() && !settings.useAlarmServer) {
      alarmManager = AndroidAlarmManager();
    }
    else {
      alarmManager = AlarmServerAlarmManager();
    }
  }

  Function? reloadAllMethod;

  Function? pageSelectorReloadMethod;

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
    String alarmServerTokens = prefs.getString("alarmServerTokens") ?? "[]";
    String shockers = prefs.getString("shockers") ?? "[]";
    String hubs = prefs.getString("hubs") ?? "[]";
    String settings = prefs.getString("settings") ?? "{}";
    String alarmTones = prefs.getString("alarmTones") ?? "[]";
    String shareLinks = prefs.getString("shareLinks") ?? "[]";
    List<dynamic> alarmsList = jsonDecode(alarms);
    List<dynamic> tokensList = jsonDecode(tokens);
    List<dynamic> alarmServerTokensList = jsonDecode(alarmServerTokens);
    List<dynamic> shockersList = jsonDecode(shockers);
    List<dynamic> hubsList = jsonDecode(hubs);
    List<dynamic> alarmTonesList = jsonDecode(alarmTones);
    List<dynamic> shareLinksList = jsonDecode(shareLinks);
    this.settings = Settings.fromJson(jsonDecode(settings));
    if(kIsWeb) this.settings.useHttpShocking = true;
    for (var alarm in alarmsList) {
      _alarms.add(Alarm.fromJson(alarm));
    }
    for (var token in tokensList) {
      _tokens.add(Token.fromJson(token));
    }
    for (var token in alarmServerTokensList) {
      _alarmServerTokens.add(Token.fromJson(token));
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
    this.shareLinks = [];
    for (var shareLink in shareLinksList) {
      OpenShockShareLink link = OpenShockShareLink.fromJson(shareLink);
      link.tokenReference = getToken(link.tokenId ?? 0);
      this.shareLinks!.add(link);
    }
    updateHubList();
    rebuildAlarmShockers();
    if(reloadAllMethod != null) {
      reloadAllMethod!();
    }
  }

  Token? getTokenByToken(String? token) {
    for(Token t in _tokens) {
      if(t.token == token) return t;
    }
    return null;
  }

  void saveShareLinks() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    prefs.setString("shareLinks", jsonEncode(shareLinks));
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

  AlarmManager? alarmManager;

  void rescheduleAlarms() async {
    await alarmManager?.scheduleAlarms(_alarms);
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

  saveAlarm(Alarm alarm, {bool updateServer = true}) async {
    final index =
        _alarms.indexWhere((findAlarm) => alarm.id == findAlarm.id);
    if (index == -1) {
      print('Adding new alarm');
      _alarms.add(alarm);
    } else {
      _alarms[index] = alarm;
    }
    if(updateServer) alarmManager?.saveAlarm(alarm);
    rebuildAlarmShockers();
    rescheduleAlarms();
    saveAlarms();
  }

  
  Future<bool> updateShockerStore() async {
    List<Shocker> shockers = [];
    List<Hub> hubs = [];
    List<Token> tokensCopy = this._tokens.toList(); // create a copy
    bool tokenExpired = false;
    for(var token in tokensCopy) {
      OpenShockClient client = OpenShockClient();
      if(!await client.setInfoOfToken(token)) {
        tokenExpired = true;
        token.invalidSession = true;
        // if another session of the same account exists remove that one
        for(var otherToken in tokensCopy) {
          if(otherToken.userId == token.userId) {
            _tokens.remove(token);
            tokenExpired = false;
          }
        }
        continue;
      }
      
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
    List<String> newSelected = [];
    for(var shocker in shockers) {
      if(selectedShockers.contains(shocker.id)) {
        newSelected.add(shocker.id);
      }
    }
    selectedShockers = newSelected;
    this.shockers.clear();
    this.shockers.addAll(shockers);
    this.hubs.clear();
    this.hubs.addAll(hubs);
    saveShockers();
    saveTokens();
    updateHubList();
    rebuildAlarmShockers();
    updateShareLinks();
    reloadAllMethod!();
    if(tokenExpired) {
      showSessionExpired();
    }
    if(kIsWeb) updateHubStatusViaHttp();
    return !tokenExpired;
  }

  void showSessionExpired() {
    showDialog(context: navigatorKey.currentContext!, builder: (context) => AlertDialog(title: Text("Session expired"),
      content: Text("Your session has expired. To continue using the app log in again in the settings page."),
      actions: [
        TextButton(onPressed: () {
          Navigator.of(context).pop();
        }, child: Text("Ok"))
      ],
    ));
  }

  Future saveToken(Token token) async {
    final index = _tokens.indexWhere((findToken) => token.id == findToken.id);
    if (index == -1) {
      _tokens.add(token);
    } else {
      _tokens[index] = token;
    }
    await saveTokens();
    await updateShockerStore();
    //await _storage.writeList(_tokens.tokens);
  }

  Future saveAlarmServerToken(Token token) async {
    final index = _alarmServerTokens.indexWhere((findToken) => token.id == findToken.id);
    if (index == -1) {
      _alarmServerTokens.add(token);
    } else {
      _alarmServerTokens[index] = token;
    }
    await saveAlarmServerTokens();
    //await _storage.writeList(_tokens.tokens);
  }

  void deleteAlarm(Alarm alarm) {
    _alarms.removeWhere((findAlarm) => alarm.id == findAlarm.id);
    alarmManager?.deleteAlarm(alarm);
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

  List<Token> getAlarmServerTokens() {
    return _alarmServerTokens;
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

  Future saveAlarmServerTokens() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    prefs.setString("alarmServerTokens", jsonEncode(_alarmServerTokens));
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

  Future deleteAlarmServerToken(Token token) async {
    _alarmServerTokens.removeWhere((findToken) => token.id == findToken.id);
    await saveAlarmServerTokens();
  }

  Token? getToken(int id) {
    for(Token token in _tokens) {
      if(token.id == id) {
        return token;
      }
    }
    return null;
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
      await saveToken(session);
    }
    return session != null;
  }

  Future<ErrorContainer<Token>> alarmServerLogin(String serverAddress, String username, String password, bool register) async {
    ErrorContainer<Token> session = await AlarmServerClient().loginOrRegister(serverAddress, username, password, register);
    if(session.value != null) {
      await saveAlarmServerToken(session.value!);
    }
    return session;
  }

  Future<String?> editShocker(Shocker shocker, OpenShockShocker edit) {
    return OpenShockClient().editShocker(shocker, edit, this);
  }


  Future<String?> renameHub(Hub hub, String text) {
    return OpenShockClient().renameHub(hub, text, this);
  }

  Future<List<ShockerLog>> getShockerLogs(Shocker shocker, {int limit = 100}) async {
    List<ShockerLog> logs = await OpenShockClient().getShockerLogs(shocker, this, 0, limit);
    shockerLog.putIfAbsent(shocker.id, () => []);
    for(ShockerLog l in logs) {
      // only add logs which are not already in the list
      if(shockerLog.containsKey(shocker.id) && shockerLog[shocker.id]!.indexWhere((element) => element.id == l.id) == -1) {
        shockerLog[shocker.id]?.add(l);
      }
    }
    return shockerLog[shocker.id] ?? [];
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
      if(token.invalidSession) continue;
      if(token.name.isNotEmpty) {
        return token;
      }
    }
    return null;
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
    return null;
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

  Function? reloadShockerLogs;

  Function()? reloadShareLinksMethod;

  Function()? onRefresh;

  Future updateHubStatusViaHttp() async {
    for(var hub in hubs) {
      OpenShockClient().getHubStatus(hub).then((OpenShockLCGResponse? res) {
        hub.online = res?.online ?? false;

        if(hub.online && !onlineHubs.contains(hub.id)) {
          onlineHubs.add(hub.id);
        } else {
          onlineHubs.remove(hub.id);
        }
        reloadAllMethod!();
      });
    }
  }

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
        shockerLog.putIfAbsent(log.shockerReference?.id, () => []).add(log);
      }
      if(reloadShockerLogs != null) {
        reloadShockerLogs!();
      }
    });
  }

  void deviceStatusHandler(List<dynamic> args) {
    for(var arg in args[0]) {
      OpenShockDevice d = OpenShockDevice.fromJson(arg);
      for(Hub h in hubs) {
        if(h.id == d.device) {
          h.online = d.online;
          h.firmwareVersion = d.firmwareVersion;
        }
      }
      if(d.online && !onlineHubs.contains(d.device)) {
        onlineHubs.add(d.device);
      } else {
        onlineHubs.remove(d.device);
      }
    }
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

  Future saveTone(AlarmTone tone, {bool updateServer = true}) async {
    // sort components by time
    tone.components.sort((a, b) => a.time.compareTo(b.time));
    final index = alarmTones.indexWhere((findTone) => tone.id == findTone.id);
    if (index == -1) {
      alarmTones.add(tone);
    } else {
      alarmTones[index] = tone;
    }
    if(updateServer) alarmManager?.saveTone(tone);
    saveAlarmTones();
  }

  void deleteTone(AlarmTone tone) {
    alarmTones.removeWhere((findTone) => tone.id == findTone.id);
    alarmManager?.deleteTone(tone);
    saveAlarmTones();
  }

  AlarmTone? getTone(int? id) {
    if(id == null) return null;
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

  Future updateShareLinks() async {
    List<OpenShockShareLink> links = [];
    OpenShockClient client = OpenShockClient();
    for(Token token in getTokens()) {
      links.addAll(await client.getShareLinks(token));
    }
    shareLinks = links;
    saveShareLinks();
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

  Future<String?> setCaptivePortal(Hub hub, bool enable) async {
    Token? token = getToken(hub.apiTokenId);
    return await OpenShockClient().setCaptivePortal(hub, enable, token);
  }

  bool anyAlarmOn() {
    for(var alarm in _alarms) {
      if(alarm.active) {
        return true;
      }
    }
    return false;
  }

  Token? getAlarmServerUserToken() {
    for(var token in _alarmServerTokens) {
      if(token.invalidSession) continue;
      if(token.name.isNotEmpty) {
        return token;
      }
    }
    return null;
  }

  void dialogError(String title, String body) {
    showDialog(context: navigatorKey.currentContext!, builder: (context) => AlertDialog(title: Text(title),
      content: Text(body),
      actions: [
        TextButton(onPressed: () {
          Navigator.of(context).pop();
        }, child: Text("Ok"))
      ],
    ));
  }

  Future addAlarmServerAlarms() async {
    ErrorContainer<List<AlarmTone>> tones = await alarmManager?.getAlarmTones() ?? ErrorContainer([], null);
    if(tones.error != null) {
      dialogError("Failed to get alarm tones", tones.error!);
      return;
    }
    for(var tone in tones.value!) {
      if(tone.id == -1) {
        tone.id = getNewToneId();
      }
      await saveTone(tone);
    }

    ErrorContainer<List<Alarm>> alarms = await alarmManager?.getAlarms() ?? ErrorContainer([], null);
    if(alarms.error != null) {
      dialogError("Failed to get alarms", tones.error!);
      return;
    }
    for(var alarm in alarms.value!) {
      if(alarm.id == -1) {
        alarm.id = getNewAlarmId();
      }
      await saveAlarm(alarm);
    }
  }
}