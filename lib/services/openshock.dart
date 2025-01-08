import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shock_alarm_app/services/alarm_list_manager.dart';
import '../stores/alarm_store.dart';
import 'dart:convert';

class DeviceContainer {
  List<Hub> hubs;
  List<Shocker> shockers;

  DeviceContainer(this.hubs, this.shockers);
}

class OpenShockClient {
  Future<DeviceContainer> GetShockersForToken(Token t) async {
    var response = await GetRequest(t, "/1/shockers/own");
    List<Shocker> shockers = [];
    List<Hub> hubs = [];

    if (response.statusCode == 200) {
      OpenShockDevicesData deviceData = OpenShockDevicesData.fromJson(jsonDecode(response.body));
      for (var element in deviceData.data!) {
        Hub h = Hub.fromOpenShockDevice(element);
        h.isOwn = true;
        h.apiTokenId = t.id;
        hubs.add(h);
        for (var shocker in element.shockers) {
          Shocker s = Shocker.fromOpenShockShocker(shocker);
          s.hubReference = h;
          s.hubId = element.id;
          s.isOwn = true;
          s.apiTokenId = t.id;
          shockers.add(s);
        }
      }
    }

    response = await GetRequest(t, "/1/shockers/shared");
    if (response.statusCode == 200) {
      OpenShockContainerData deviceData = OpenShockContainerData.fromJson(jsonDecode(response.body));
      for (var element in deviceData.data!) {
        for(var device in element.devices) {
          Hub h = Hub.fromOpenShockDevice(device);
          h.apiTokenId = t.id;
          hubs.add(h);
          for (var shocker in device.shockers) {
            Shocker s = Shocker.fromOpenShockShocker(shocker);
            s.hubReference = h;
            s.hubId = device.id;
            s.apiTokenId = t.id;
            shockers.add(s);
          }
        }
      }
    }

    return DeviceContainer(hubs, shockers);
  }

  static getIconForControlType(ControlType type, {Color? color}) {
    IconData icon = Icons.stop;
    switch(type) {
      case ControlType.stop:
        icon = Icons.stop;
        break;
      case ControlType.shock:
        icon = Icons.flash_on;
        break;
      case ControlType.vibrate:
        icon = Icons.vibration;
        break;
      case ControlType.sound:
        icon = Icons.volume_up;
        break;
      case ControlType.live:
        icon = Icons.wifi_tethering;
        break;
    }
    return Icon(icon, color: color);
  }


  Future<http.Response> GetRequest(Token t, String path) {
    var url = Uri.parse(t.server + path);
    return http.get(url, headers: {
      if(t.isSession) "Cookie": "openShockSession=${t.token}"
      else "OpenShockToken": t.token,
    });
  }

  Future<http.Response> PostRequest(Token t, String path, String body) {
    var url = Uri.parse(t.server + path);
    return http.post(url, headers: {
      if(t.isSession) "Cookie": "openShockSession=${t.token}"
      else "OpenShockToken": t.token,
      "Content-Type": "application/json"
    }, body: body);
  }

  Future<http.Response> PatchRequest(Token t, String path, String body) {
    var url = Uri.parse(t.server + path);
    return http.patch(url, headers: {
      if(t.isSession) "Cookie": "openShockSession=${t.token}"
      else "OpenShockToken": t.token,
      "Content-Type": "application/json"
    }, body: body);
  }

  Future<http.Response> DeleteRequest(Token t, String path, String body) {
    var url = Uri.parse(t.server + path);
    return http.delete(url, headers: {
      if(t.isSession) "Cookie": "openShockSession=${t.token}"
      else "OpenShockToken": t.token,
      "Content-Type": "application/json"
    }, body: body);
  }

  Future setPauseStateOfShocker(Shocker s, AlarmListManager manager, bool paused) async {
    Token? t = manager.getToken(s.apiTokenId);
    if(t == null) return;
    String body = jsonEncode({
      "pause": paused
    });
    var response = await PostRequest(t, "/1/shockers/${s.id}/pause", body);
    if(response.statusCode == 200) {
      s.paused = paused;
      manager.saveTokens();
      manager.reloadAllMethod!();
    }
  }

  Future<bool> sendControls(Token t, List<Control> list, {String customName = "ShockAlarm"}) async {
    String body = jsonEncode({
      "shocks": list.map((e) => e.toJson()).toList(),
      "customName": customName
    });
    var response = await PostRequest(t, "/2/shockers/control", body);
    return response.statusCode == 200;
  }

  Future<String> getNameForToken(Token t) async {
    var request = GetRequest(t, "/1/users/self");
    var response = await request;
    String name = "Unknown";
    if(response.statusCode == 200) {
      var data = jsonDecode(response.body);
      name = data["data"]["name"];
    }
    request = GetRequest(t, "/1/tokens/self");
    response = await request;
    String tokenName = "";
    if(response.statusCode == 200) {
      var data = jsonDecode(response.body);
      tokenName = data["name"];
    }
    return t.isSession ? "$name" : "$name ($tokenName)";
  }

  Future<Token?> login(String serverAddress, String email, String password, AlarmListManager manager) async {
    if(serverAddress.endsWith("/")) {
      serverAddress = serverAddress.substring(0, serverAddress.length - 1);
    }
    var response = await http.post(Uri.parse("$serverAddress/1/account/login"), body: jsonEncode({
      "password": password,
      "email": email
    }), headers: {
      "Content-Type": "application/json"
    });
    Token? token;
    if(response.statusCode == 200) {
      response.headers["set-cookie"]?.split(";").forEach((element) {
        if(element.startsWith("openShockSession=")) {
          var sessionId = element.substring("openShockSession=".length);
          token = Token(DateTime.now().millisecondsSinceEpoch, sessionId, server: serverAddress, isSession: true);
        }
      });
    }
    return token;
  }

  Future<String?> renameShocker(Shocker shocker, String text, AlarmListManager manager) async {
    Token? t = manager.getToken(shocker.apiTokenId);
    if(t == null) {
      return Future.value("Token not found");
    }
    var response = await GetRequest(t, "/1/shockers/${shocker.id}");

    if(response.statusCode != 200) {
      return "${response.statusCode} - failed to get shocker";
    }
    // replace name of response
    var responseBody = jsonDecode(response.body)["data"];
    responseBody["name"] = text;
    String body = jsonEncode(responseBody);

    response = await PatchRequest(t, "/1/shockers/${shocker.id}", body);
    if(response.statusCode == 200) {
      shocker.name = text;
      manager.saveTokens();
      return null;
    }
    return getErrorCode(response, "Failed to rename shocker");
  }


  Future<String?> renameHub(Hub hub, String text, AlarmListManager manager) async {
    Token? t = manager.getToken(hub.apiTokenId);
    if(t == null) {
      return Future.value("Token not found");
    } 
    var response = await GetRequest(t, "/1/devices/${hub.id}");

    if(response.statusCode != 200) {
      return "${response.statusCode} - failed to get hub";
    }
    // replace name of response
    var responseBody = jsonDecode(response.body)["data"];
    responseBody["name"] = text;
    String body = jsonEncode(responseBody);

    response = await PatchRequest(t, "/1/devices/${hub.id}", body);
    if(response.statusCode == 200) {
      hub.name = text;
      manager.saveTokens();
      return null;
    }
    return getErrorCode(response, "Failed to rename shocker");
  }

  Future<List<ShockerLog>> getShockerLogs(Shocker shocker, AlarmListManager manager) async {
    Token? t = manager.getToken(shocker.apiTokenId);
    if(t == null) {
      return [];
    }
    var response = await GetRequest(t, "/1/shockers/${shocker.id}/logs");
    if(response.statusCode == 200) {
      List<ShockerLog> logs = [];
      var data = jsonDecode(response.body);
      for(var log in data["data"]) {
        logs.add(ShockerLog.fromJson(log));
      }
      return logs;
    }
    return [];
  }

  Future<List<OpenShockShare>> getShockerShares(Shocker shocker, AlarmListManager manager) async {
    Token? t = manager.getToken(shocker.apiTokenId);
    if(t == null) {
      return [];
    }
    var response = await GetRequest(t, "/1/shockers/${shocker.id}/shares");
    if(response.statusCode == 200) {
      List<OpenShockShare> shares = [];
      var data = jsonDecode(response.body);
      for(var share in data["data"]) {
        OpenShockShare s = OpenShockShare.fromJson(share);
        s.shockerReference = shocker;
        shares.add(s);
      }
      return shares;
    }
    return [];
  }

  Future<List<OpenShockShareCode>> getShockerShareCodes(Shocker shocker, AlarmListManager manager) async {
    Token? t = manager.getToken(shocker.apiTokenId);
    if(t == null) {
      return [];
    }
    var response = await GetRequest(t, "/1/shockers/${shocker.id}/shareCodes");
    if(response.statusCode == 200) {
      List<OpenShockShareCode> codes = [];
      var data = jsonDecode(response.body);
      for(var code in data["data"]) {
        OpenShockShareCode shareCode = OpenShockShareCode.fromJson(code);
        shareCode.shockerReference = shocker;
        codes.add(shareCode);
      }
      return codes;
    }
    return [];
  }

  Future<String?> setPauseStateOfShare(OpenShockShare share, AlarmListManager manager, bool pause) async {
    if(share.shockerReference == null) return "Shocker not found";
    Shocker s = share.shockerReference!;
    Token? t = manager.getToken(s.apiTokenId);
    if(t == null) return "Token not found";
    String body = jsonEncode({
      "pause": pause
    });
    var response = await PostRequest(t, "/1/shockers/${s.id}/shares/${share.sharedWith.id}/pause", body);
    if(response.statusCode == 200) {
      share.paused = pause;
      return null;
    }
    return getErrorCode(response, "Failed to set pause state");
  }

  Future<String?> setLimitsOfShare(OpenShockShare share, OpenShockShareLimits limits, AlarmListManager manager) async {
    if(share.shockerReference == null) return "Shocker not found";
    Shocker s = share.shockerReference!;
    Token? t = manager.getToken(s.apiTokenId);
    if(t == null) return "Token not found";
    String body = jsonEncode(limits.toJson());
    var response = await PatchRequest(t, "/1/shockers/${s.id}/shares/${share.sharedWith.id}", body);
    if(response.statusCode == 200) {
      share.limits = limits.limits;
      share.permissions = limits.permissions;
      return null;
    }
    return getErrorCode(response, "Failed to set limits");
  }

  Future<String?> addShare(Shocker shocker, OpenShockShareLimits limits, AlarmListManager manager) async {
    Token? t = manager.getToken(shocker.apiTokenId);
    if(t == null) return "Token not found";
    String body = jsonEncode(limits.toJson());
    return getErrorCode(await PostRequest(t, "/1/shockers/${shocker.id}/shares", body), "Failed to create share");
  }

  Future<String?> deleteShareCode(OpenShockShareCode shareCode, AlarmListManager alarmListManager) async {
    if(shareCode.shockerReference == null) return "Shocker not found";
    Shocker s = shareCode.shockerReference!;
    Token? t = alarmListManager.getToken(s.apiTokenId);
    if(t == null) return "Token not found";
    return getErrorCode(await DeleteRequest(t, "/1/shares/code/${shareCode.id}", ""), "Failed to delete share code");
  }

  Future<String?> redeemShareCode(String code, AlarmListManager alarmListManager) async {
    // first get a valid token
    Token? t;
    alarmListManager.getTokens().forEach((element) {
      if(element.isSession) {
        t = element;
      }
    });
    if(t == null) {
      return "No valid session token found";
    }
    return getErrorCode(await PostRequest(t!, "/1/shares/code/${code}", ""), "Failed to redeem share code. Did you copy it correctly?");
  }

  Future<List<OpenShockDevice>> getDevices(Token t) async {
    var response = await GetRequest(t, "/1/devices");
    List<OpenShockDevice> devices = [];
    if(response.statusCode == 200) {
      jsonDecode(response.body)["data"].forEach((element) {
        OpenShockDevice device = OpenShockDevice.fromJson(element);
        device.apiTokenReference = t;
        devices.add(device);
      });
    }
    return devices;
  }

  String? getErrorCode(var response, String defaultError) {
    if(response.statusCode == 200) {
      return null;
    }
    try{
      var data = jsonDecode(response.body);
      if(data["message"] != null) {
        return "${response.statusCode} - ${data["message"]}";
      }
    } catch (e) {

    }
    return "${response.statusCode} - $defaultError";
  }

  Future<String?> addShocker(String name, int rfId, String shockerType, OpenShockDevice? device, AlarmListManager alarmListManager) async {
    if(device == null) return "No device selected";
    Token? t = device.apiTokenReference;
    if(t == null) return "Token not found";
    String body = jsonEncode({
      "name": name,
      "rfId": rfId,
      "model": shockerType,
      "device": device.id
    });
    var response = await PostRequest(t, "/1/shockers", body);
    if(response.statusCode == 201) {
      return null;
    }
    return getErrorCode(response, "Failed to create shocker");
  }

  Future<String?> deleteShocker(Shocker shocker, AlarmListManager alarmListManager) async {
    Token? t = alarmListManager.getToken(shocker.apiTokenId);
    if(t == null) return "Token not found";
    var response = await DeleteRequest(t, "/1/shockers/${shocker.id}", "");
    if(response.statusCode == 200) {
      alarmListManager.shockers.remove(shocker);
      alarmListManager.saveShockers();
    }
    return getErrorCode(response, "Failed to delete shocker");
  }

  Future<String?> deleteShare(OpenShockShare share, AlarmListManager alarmListManager) async {
    if(share.shockerReference == null) return "Shocker not found";
    Shocker s = share.shockerReference!;
    Token? t = alarmListManager.getToken(s.apiTokenId);
    if(t == null) return "Token not found";
    return getErrorCode(await DeleteRequest(t, "/1/shockers/${s.id}/shares/${share.sharedWith.id}", ""), "Failed to delete share");
  }

  Future<String?> deleteHub(Hub hub, AlarmListManager alarmListManager) async {
    Token? t = alarmListManager.getToken(hub.apiTokenId);
    if(t == null) return Future.value("Token not found");
    return getErrorCode(await DeleteRequest(t, "/1/devices/${hub.id}", ""), "Failed to delete hub");
  }

  Future<PairCode> getPairCode(Hub hub, AlarmListManager alarmListManager) async {
    Token? t = alarmListManager.getToken(hub.apiTokenId);
    if(t == null) return PairCode("Token not found", null);
    var response = await GetRequest(t, "/1/devices/${hub.id}/pair");
    if(response.statusCode == 200) {
      return PairCode.fromJson(jsonDecode(response.body));
    }
    return PairCode(getErrorCode(response, "Failed to get pair code"), null);
  }

  Future<CreatedHub> addHub(String name, AlarmListManager manager) async {
    Token? t = manager.getAnyUserToken();
    if(t == null) return CreatedHub(null, "No valid token found");
    var response = await PostRequest(t, "/1/devices", "");
    if(response.statusCode != 201) {
      return CreatedHub(null, getErrorCode(response, "Failed to create hub"));
    }
    CreatedHub hub = CreatedHub(response.body.replaceAll("\"", ""), null);
    // now we need to rename it
    Hub h = Hub()
      ..name = name
      ..id = hub.hubId!
      ..isOwn = true
      ..apiTokenId = t.id;
    hub.error = await renameHub(h, name, manager);
    return hub;
  }
}

class CreatedHub {
  String? hubId;
  String? error;

  CreatedHub(this.hubId, this.error);
}

class PairCode {
  String? code;
  String? error;

  PairCode(this.error, this.code);

  PairCode.fromJson(Map<String, dynamic> json) {
    code = json["data"];
  }
}

enum ControlType {
  stop,
  shock,
  vibrate,
  sound,
  live 
}

class OpenShockShareCode {
  String id = "";
  DateTime createdOn = DateTime.now();
  Shocker? shockerReference;

  OpenShockShareCode.fromJson(Map<String, dynamic> json) {
    id = json["id"];
    createdOn = DateTime.parse(json["createdOn"]);
  }
}

class OpenShockShareLimits {
  OpenShockShockerLimits limits = OpenShockShockerLimits();
  OpenShockShockerPermissions permissions = OpenShockShockerPermissions();

  OpenShockShareLimits();

  dynamic toJson() {
    return {
      "limits": {
        "intensity": limits.intensity,
        "duration": limits.duration
      },
      "permissions": {
        "shock": permissions.shock,
        "vibrate": permissions.vibrate,
        "sound": permissions.sound,
        "live": permissions.live
      }
    };
  }

  OpenShockShareLimits.from(OpenShockShare share) {
    limits.duration = share.limits.duration;
    limits.intensity = share.limits.intensity;
    permissions.shock = share.permissions.shock;
    permissions.vibrate = share.permissions.vibrate;
    permissions.sound = share.permissions.sound;
    permissions.live = share.permissions.live;
  }
}

class Control {
  String id = "";
  bool exclusive = true;
  int duration = 0;
  int intensity = 0;
  ControlType type = ControlType.stop;

  toJson() {
    String type = "";
    switch(this.type) {
      case ControlType.stop:
        type = "Stop";
        break;
      case ControlType.shock:
        type = "Shock";
        break;
      case ControlType.vibrate:
        type = "Vibrate";
        break;
      case ControlType.sound:
        type = "Sound";
        break;
      case ControlType.live:
        type = "Live";
        break;
    } 
    return {
      "id": id,
      "exclusive": exclusive,
      "duration": duration,
      "intensity": intensity,
      "type": type
    };
  }
}

class ShockerLog {
  String id = "";
  DateTime createdOn = DateTime.now();
  ControlType type = ControlType.shock;
  OpenShockUser controlledBy = OpenShockUser();
  int intensity = 0;
  int duration = 0;

  ShockerLog.fromJson(Map<String, dynamic> json) {
    id = json["id"];
    createdOn = DateTime.parse(json["createdOn"]);
    switch(json["type"]) {
      case "Shock":
        type = ControlType.shock;
        break;
      case "Vibrate":
        type = ControlType.vibrate;
        break;
      case "Sound":
        type = ControlType.sound;
        break;
      case "Stop":
        type = ControlType.stop;
        break;
    }
    controlledBy.id = json["controlledBy"]["id"];
    controlledBy.name = json["controlledBy"]["name"];
    controlledBy.image = json["controlledBy"]["image"];
    controlledBy.customName = json["controlledBy"]["customName"];
    intensity = json["intensity"];
    duration = json["duration"];
  }

  String getName() {
    return controlledBy.customName != null ? "${controlledBy.customName} [${controlledBy.name}]" : controlledBy.name;
  }
}

class OpenShockUser {
  String id = "";
  String name = "";
  String image = "";
  String? customName;
}

class Hub {
  String name = "";
  String id = "";
  bool isOwn = false;
  int apiTokenId = 0;

  Hub();

  Hub.fromOpenShockDevice(OpenShockDevice device) {
    name = device.name;
    id = device.id;
  }

  Hub.fromJson(Map<String, dynamic> json) {
    name = json["name"];
    id = json["id"];
    isOwn = json["isOwn"];
    if(json["apiTokenId"] != null)
      apiTokenId = json["apiTokenId"];
  }

  Map<String, dynamic> toJson() {
    return {
      "name": name,
      "id": id,
      "isOwn": isOwn,
      "apiTokenId": apiTokenId
    };
  }
}

class Shocker {
  Shocker() {}
  
  String id = "";
  String name = "";
  String hubId = "";
  Hub? hubReference;
  int apiTokenId = 0;
  bool paused = false;
  bool shockAllowed = true;
  bool vibrateAllowed = true;
  bool soundAllowed = true;
  int durationLimit = 30000;
  int intensityLimit = 100;
  bool isOwn = false;
  

  Shocker.fromOpenShockShocker(OpenShockShocker shocker) {
    id = shocker.id;
    name = shocker.name;
    paused = shocker.isPaused;
    if(shocker.permissions != null) {
      shockAllowed = shocker.permissions!.shock;
      vibrateAllowed = shocker.permissions!.vibrate;
      soundAllowed = shocker.permissions!.sound;
    }
    if(shocker.limits != null) {
      durationLimit = shocker.limits!.duration ?? 30000;
      intensityLimit = shocker.limits!.intensity ?? 100;
    }
  }

  Map<String, dynamic> toJson() {
    return {
      "id": id,
      "name": name,
      "hubId": hubId,
      "hubReference": hubReference?.toJson(),
      "apiTokenId": apiTokenId,
      "paused": paused,
      "shockAllowed": shockAllowed,
      "vibrateAllowed": vibrateAllowed,
      "soundAllowed": soundAllowed,
      "durationLimit": durationLimit,
      "intensityLimit": intensityLimit,
      "isOwn": isOwn
    };
  }

  static Shocker fromJson(shocker) {
    Shocker s = Shocker();
    s.id = shocker["id"];
    s.name = shocker["name"];
    if(shocker["hubId"] != null)
      s.hubId = shocker["hubId"];
    s.apiTokenId = shocker["apiTokenId"];
    s.paused = shocker["paused"];
    s.shockAllowed = shocker["shockAllowed"];
    s.vibrateAllowed = shocker["vibrateAllowed"];
    s.soundAllowed = shocker["soundAllowed"];
    s.durationLimit = shocker["durationLimit"];
    s.intensityLimit = shocker["intensityLimit"];
    if(shocker["isOwn"] != null)
      s.isOwn = shocker["isOwn"];
    return s;
  }

  String getIdentifier() {
    return "$id-$apiTokenId-${paused}-${shockAllowed}-${vibrateAllowed}-${soundAllowed}-${durationLimit}-${intensityLimit}";
  }
}


class OpenShockDevicesData
{
    List<OpenShockDevice>? data;

    OpenShockDevicesData.fromJson(Map<String, dynamic> json)
    {
        if (json['data'] != null)
        {
            data = [];
            json['data'].forEach((v) {
                data!.add(OpenShockDevice.fromJson(v));
            });
        }
    }
}

class OpenShockContainerData
{
    List<OpenShockDevicesContainer>? data;

    OpenShockContainerData.fromJson(Map<String, dynamic> json)
    {
        if (json['data'] != null)
        {
            data = [];
            json['data'].forEach((v) {
                data!.add(OpenShockDevicesContainer.fromJson(v));
            });
        }
    }
}

class OpenShockDevicesContainer
{
    List<OpenShockDevice> devices = [];

    OpenShockDevicesContainer.fromJson(Map<String, dynamic> json)
    {
        if (json['devices'] != null)
        {
            json['devices'].forEach((v) {
                devices.add(OpenShockDevice.fromJson(v));
            });
        }
    }
}

class OpenShockDevice
{
    String name = "";
    String id = "";
    List<OpenShockShocker> shockers = [];
    
    Token? apiTokenReference;

    OpenShockDevice.fromJson(Map<String, dynamic> json)
    {
      name = json['name'];
      id = json['id'];
      if (json['shockers'] != null)
      {
        json['shockers'].forEach((v) {
            shockers.add(OpenShockShocker.fromJson(v));
        });
      }
    }
    
    Map<String, dynamic> toJson() {
      return {
        "name": name,
        "id": id
      };
    }
}

class OpenShockShocker
{
    String name = "";
    String id = "";
    bool isPaused = false;
    bool? isDisabled = false;
    OpenShockShockerLimits? limits;
    OpenShockShockerPermissions? permissions;

    OpenShockShocker.fromJson(Map<String, dynamic> json)
    {
        name = json['name'];
        id = json['id'];
        isPaused = json['isPaused'];
        isDisabled = json['isDisabled'];
        if (json['limits'] != null)
        {
            limits = OpenShockShockerLimits();
            limits!.intensity = json['limits']['intensity'];
            limits!.duration = json['limits']['duration'];
        }
        if (json['permissions'] != null)
        {
            permissions = OpenShockShockerPermissions();
            permissions!.shock = json['permissions']['shock'];
            permissions!.vibrate = json['permissions']['vibrate'];
            permissions!.sound = json['permissions']['sound'];
        }
    }
}

class OpenShockShare {
  OpenShockUser sharedWith = OpenShockUser();
  DateTime createdOn = DateTime.now();
  OpenShockShockerPermissions permissions = OpenShockShockerPermissions();
  OpenShockShockerLimits limits = OpenShockShockerLimits();
  bool paused = false;
  Shocker? shockerReference;

  OpenShockShare();

  OpenShockShare.fromJson(Map<String, dynamic> json) {
    sharedWith.id = json["sharedWith"]["id"];
    sharedWith.name = json["sharedWith"]["name"];
    sharedWith.image = json["sharedWith"]["image"];
    createdOn = DateTime.parse(json["createdOn"]);
    permissions.shock = json["permissions"]["shock"];
    permissions.vibrate = json["permissions"]["vibrate"];
    permissions.sound = json["permissions"]["sound"];
    permissions.live = json["permissions"]["live"];
    limits.intensity = json["limits"]["intensity"];
    limits.duration = json["limits"]["duration"];
    paused = json["paused"];
  }
}

class OpenShockShockerLimits
{
    int? intensity = 100;
    int? duration = 30000;
}

class OpenShockShockerPermissions
{
    bool shock = true;
    bool vibrate = true;
    bool sound = true;
    bool live = false;
}