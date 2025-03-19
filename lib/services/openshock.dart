import 'dart:math';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shock_alarm_app/services/alarm_list_manager.dart';
import 'package:shock_alarm_app/services/alarm_manager.dart';
import '../stores/alarm_store.dart';
import 'dart:convert';
import '../main.dart';

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

  static getIconForControlType(ControlType type, {Color? color, double? size}) {
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
    return Icon(icon, color: color, size: size,);
  }


  Future<http.Response> GetRequest(Token t, String path) {
    var url = Uri.parse(t.server + path);
    return http.get(url, headers: {
      if(t.isSession) "Cookie": "openShockSession=${t.token}"
      else "OpenShockToken": t.token,
      'User-Agent': GetUserAgent(),
    });
  }

  Future<http.Response> PostRequest(Token t, String path, String body) {
    var url = Uri.parse(t.server + path);
    return http.post(url, headers: {
      if(t.isSession) "Cookie": "openShockSession=${t.token}"
      else "OpenShockToken": t.token,
      "Content-Type": "application/json",
      'User-Agent': GetUserAgent(),
    }, body: body);
  }

  Future<http.Response> PatchRequest(Token t, String path, String body) {
    var url = Uri.parse(t.server + path);
    return http.patch(url, headers: {
      if(t.isSession) "Cookie": "openShockSession=${t.token}"
      else "OpenShockToken": t.token,
      "Content-Type": "application/json",
      'User-Agent': GetUserAgent(),
    }, body: body);
  }

  Future<http.Response> DeleteRequest(Token t, String path, String body) {
    var url = Uri.parse(t.server + path);
    return http.delete(url, headers: {
      if(t.isSession) "Cookie": "openShockSession=${t.token}"
      else "OpenShockToken": t.token,
      "Content-Type": "application/json",
      'User-Agent': GetUserAgent(),
    }, body: body);
  }

  Future<String?> setPauseStateOfShocker(Shocker s, AlarmListManager manager, bool paused) async {
    Token? t = manager.getToken(s.apiTokenId);
    if(t == null) return "Token not found";
    String body = jsonEncode({
      "pause": paused
    });
    var response = await PostRequest(t, "/1/shockers/${s.id}/pause", body);
    if(response.statusCode == 200) {
      s.paused = paused;
      manager.saveTokens();
      manager.reloadAllMethod!();
    }
    return getErrorCode(response, "Failed to set pause state");
  }

  Future<ErrorContainer<String>> createApiToken(Token? t, OpenShockApiToken toCreate) async {
    if(t == null) return ErrorContainer(null, "Token not found");
    var response = await PostRequest(t, "/1/tokens", jsonEncode(toCreate.toJson(getValidUntil: true)));
    if(response.statusCode != 200) {
      return ErrorContainer(null, getErrorCode(response, "Failed to create token"));
    }
    String? token = jsonDecode(response.body)["token"];
    return ErrorContainer(token, null);
  }

  Future<bool> sendControls(Token t, List<Control> list, AlarmListManager manager, {String customName = "ShockAlarm", bool useWs = true}) async {
    if(useWs) {
      if(manager.ws == null || manager.ws?.t.id != t.id) {
        await manager.startWS(t);
      }
      return await manager.ws?.sendControls(list, customName) ?? false;
    }
    
    String body = jsonEncode({
      "shocks": list.map((e) => e.toJson()).toList(),
      "customName": customName
    });
    var response = await PostRequest(t, "/2/shockers/control", body);
    return response.statusCode == 200;
  }

  Future<bool> setInfoOfToken(Token t) async {
    var request = GetRequest(t, "/1/users/self");
    var response = await request;
    String name = "Unknown";
    String id = "";
    if(response.statusCode == 401) {
      return false;
    }
    if(response.statusCode == 200) {
      var data = jsonDecode(response.body);
      name = data["data"]["name"];
      id = data["data"]["id"];
    }
    request = GetRequest(t, "/1/tokens/self");
    response = await request;
    String tokenName = "";
    if(response.statusCode == 200) {
      var data = jsonDecode(response.body);
      tokenName = data["name"];
    }
    t.name = t.isSession ? "$name" : "$name ($tokenName)";
    t.userId = id;
    return true;
  }

  Future<Token?> login(String serverAddress, String email, String password, AlarmListManager manager) async {
    if(serverAddress.endsWith("/")) {
      serverAddress = serverAddress.substring(0, serverAddress.length - 1);
    }
    var response = await http.post(Uri.parse("$serverAddress/1/account/login"), body: jsonEncode({
      "password": password,
      "email": email
    }), headers: {
      "Content-Type": "application/json",
      'User-Agent': GetUserAgent(),
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

  Future<OpenShockShocker?> getShockerDetails(Shocker shocker) async {
    Token? t = AlarmListManager.getInstance().getToken(shocker.apiTokenId);
    if(t == null) {
      return null;
    }
    var response = await GetRequest(t, "/1/shockers/${shocker.id}");

    if(response.statusCode != 200) {
      return null;
    }
    // replace name of response
    return OpenShockShocker.fromJson(jsonDecode(response.body)["data"]);
  }

  Future<String?> editShocker(Shocker shocker, OpenShockShocker edit, AlarmListManager manager) async {
    Token? t = manager.getToken(shocker.apiTokenId);
    if(t == null) {
      return "Token not found";
    }
    // replace name of response
    String body = jsonEncode({
      "model": edit.model,
      "rfId": edit.rfId,
      "name": edit.name,
      "device": edit.device
    });

    var response = await PatchRequest(t, "/1/shockers/${shocker.id}", body);
    if(response.statusCode == 200) {
      shocker.name = edit.name;
      manager.saveTokens();
      return null;
    }
    return getErrorCode(response, "Failed to save shocker");
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

  Future<List<ShockerLog>> getShockerLogs(Shocker shocker, AlarmListManager manager, int offset, int limit) async {
    Token? t = manager.getToken(shocker.apiTokenId);
    if(t == null) {
      return [];
    }
    var response = await GetRequest(t, "/1/shockers/${shocker.id}/logs?offset=$offset&limit=$limit");
    if(response.statusCode == 200) {
      List<ShockerLog> logs = [];
      var data = jsonDecode(response.body);
      for(var log in data["data"]) {
        ShockerLog s = ShockerLog.fromJson(log);
        s.shockerReference = shocker;
        logs.add(s);
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
    Token? t = alarmListManager.getAnyUserToken();
    if(t == null) {
      return "No valid session token found";
    }
    return getErrorCode(await PostRequest(t, "/1/shares/code/${code}", ""), "Failed to redeem share code. Did you copy it correctly?");
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
    if(response.statusCode == 401) {
      return "${response.statusCode} - Your session expired. To continue using the app log in again.";
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

  Future<String?> logout(Token token) async {
    var response = await PostRequest(token, "/1/account/logout", "");
    return getErrorCode(response, "Failed to logout");
  }

  Future<List<OpenShockShareLink>> getShareLinks(Token token) async {
    var response = await GetRequest(token, "/1/shares/links");
    List<OpenShockShareLink> links = [];
    if(response.statusCode == 200) {
      jsonDecode(response.body)["data"].forEach((element) {
        OpenShockShareLink link = OpenShockShareLink.fromJson(element, tokenReference: token);
        links.add(link);
      });
    }
    return links;
  }

  Future<OpenShockShareLink?> getShareLink(Token token, String id) async {
    var response = await GetRequest(token, "/1/public/shares/links/$id");
    if(response.statusCode == 200) {
      OpenShockShareLink link = OpenShockShareLink.fromJson(jsonDecode(response.body)["data"] , tokenReference: token);
      return link;
    }
    return null;
  }

  Future<String?> addShockerToShareLink(Shocker shocker, OpenShockShareLink shareLink) async {
    Token? t = shareLink.tokenReference;
    if(t == null) return "Token not found";
    var response = await PostRequest(t, "/1/shares/links/${shareLink.id}/${shocker.id}", "");
    if(response.statusCode == 200) {
      return null;
    }
    return getErrorCode(response, "Failed to add shocker");
  }

  Future<String?> setPauseStateOfShareLinkShocker(OpenShockShareLink shareLink, Shocker shocker, bool paused) async {
    Token? t = shareLink.tokenReference;
    if(t == null) return "Token not found";
    var response = await PostRequest(t, "/1/shares/links/${shareLink.id}/${shocker.id}/pause", jsonEncode({
      "pause": paused
    }));
    if(response.statusCode == 200) {
      return null;
    }
    return getErrorCode(response, "Failed to set pause state");
  }

  Future<String?> removeShockerFromShareLink(OpenShockShareLink shareLink, Shocker shocker) async {
    Token? t = shareLink.tokenReference;
    if(t == null) return "Token not found";
    var response = await DeleteRequest(t, "/1/shares/links/${shareLink.id}/${shocker.id}", "");
    if(response.statusCode == 200) {
      return null;
    }
    return getErrorCode(response, "Failed to remove shocker");
  }

  Future<String?> setLimitsOfShareLinkShocker(OpenShockShareLink shareLink, Shocker shocker, OpenShockShareLimits limits) async {
    Token? t = shareLink.tokenReference;
    if(t == null) return "Token not found";
    var response = await PatchRequest(t, "/1/shares/links/${shareLink.id}/${shocker.id}", jsonEncode(limits.toJson()));
    if(response.statusCode == 200) {
      return null;
    }
    return getErrorCode(response, "Failed to update shocker limits");
  }

  Future<PairCode> createShareLink(Token t, String shareLinkName, DateTime dateTime) async {
    var response = await PostRequest(t, "/1/shares/links", jsonEncode({
      "name": shareLinkName,
      "expiresOn": dateTime.toIso8601String()
    }));
    if(response.statusCode == 200) {
      return PairCode(null, jsonDecode(response.body)['data']);
    }
    return PairCode(getErrorCode(response, "Failed to create share link"), null);
  }

  Future<String?> deleteShareLink(OpenShockShareLink shareLink) async {
    Token? t = shareLink.tokenReference;
    if(t == null) return "Token not found";
    var response = await DeleteRequest(t, "/1/shares/links/${shareLink.id}", "");
    if(response.statusCode == 200) {
      return null;
    }
    return getErrorCode(response, "Failed to delete share link");    
  }

  Future<String?> setCaptivePortal(Hub hub, bool enable, Token? t) async {
    if(AlarmListManager.getInstance().ws == null || AlarmListManager.getInstance().ws?.t.id != t?.id) {
      if(t == null) return "Token not found";
      await AlarmListManager.getInstance().startWS(t);
    }
    return await AlarmListManager.getInstance().ws?.setCaptivePortal(hub, enable);
  }

  Future<OpenShockLCGResponse?> getLCGInfo(Hub hub) async {
    Token? t = AlarmListManager.getInstance().getToken(hub.apiTokenId);
    if(t == null) return null;
    var response = await GetRequest(t, "/1/devices/${hub.id}/lcg");
    if(response.statusCode == 200) {
      return OpenShockLCGResponse.fromJson(jsonDecode(response.body)["data"])..online = true;
    }
    if(response.statusCode == 412) {
      return OpenShockLCGResponse()..online = true;
    }
    // 404 and internal server error means offline
    return OpenShockLCGResponse()..online = false;
  }

  Future<List<OpenShockOTAUpdate>> getOTAUpdateHistory(Hub hub)async {
    Token? t = AlarmListManager.getInstance().getToken(hub.apiTokenId);
    if(t == null) return [];
    var response = await GetRequest(t, "/1/devices/${hub.id}/ota");
    List<OpenShockOTAUpdate> updates = [];
    if(response.statusCode == 200) {
      jsonDecode(response.body)["data"].forEach((element) {
        updates.add(OpenShockOTAUpdate.fromJson(element));
      });
    }
    return updates;
  }

  Future<List<OpenShockApiToken>> getApiTokens(Token token)async {
    var response = await GetRequest(token, "/1/tokens");
    List<OpenShockApiToken> updates = [];
    if(response.statusCode == 200) {
      jsonDecode(response.body).forEach((element) {
        updates.add(OpenShockApiToken.fromJson(element));
      });
    }
    return updates;
  }

  Future<ErrorContainer<bool>> deleteApiToken(Token t, OpenShockApiToken apiToken) async {
    var response = await DeleteRequest(t, "/1/tokens/${apiToken.id}", "");
    if(response.statusCode == 200) {
      return ErrorContainer(true, null);
    }
    return ErrorContainer(null, getErrorCode(response, "Failed to delete token"));
  }

  Future<ErrorContainer<bool>> updateApiToken(Token token, OpenShockApiToken apiToken) async {
    print(jsonEncode(apiToken.toJson()));
    var response = await PatchRequest(token, "/1/tokens/${apiToken.id}", jsonEncode(apiToken.toJson()));
    if(response.statusCode == 200) {
      return ErrorContainer(true, null);
    }
    return ErrorContainer(null, getErrorCode(response, "Failed to update token"));
  }

  Future<ErrorContainer<bool>> deleteSession(Token token, OpenShockUserSession session) async {
    var response = await DeleteRequest(token, "/1/sessions/${session.id}", "");
    if(response.statusCode == 200) {
      return ErrorContainer(true, null);
    }
    return ErrorContainer(null, getErrorCode(response, "Failed to delete session"));
  }

  Future<ErrorContainer<List<OpenShockUserSession>>> getSessions(Token token) async {
    var response = await GetRequest(token, "/1/sessions/");
    if(response.statusCode == 200) {
      List<OpenShockUserSession> sessions = [];
      jsonDecode(response.body).forEach((element) {
        sessions.add(OpenShockUserSession.fromJson(element));
      });
      return ErrorContainer(sessions, null);
    }
    return ErrorContainer(null, getErrorCode(response, "Failed to get session"));
  }
}

class OTAInstallProgress {
  String hubId = "";
  int id = 0;
  int step = 0;
  double progress = 0;
}

class OpenShockOTAUpdate {
  int id = 0;
  String? message;
  DateTime startedAt = DateTime.now();
  String status = "Unknown status";
  String version = "unknown version";

  OpenShockOTAUpdate.fromJson(Map<String, dynamic> json) {
    id = json["id"];
    message = json["message"];
    startedAt = DateTime.parse(json["startedAt"]);
    version = json["version"];
    status = json["status"];
  }
}

List<String> availableApiTokenPermissions = [
  "shockers.use","shockers.pause","shockers.edit","devices.auth","devices.edit"
];

enum OpenShockOtaUpdateStatus {
  Started, Running, Finished, Error, Timeout
}

class OpenShockLCGResponse {
  String? gateway;
  String? country;
  bool online = false;

  OpenShockLCGResponse();

  OpenShockLCGResponse.fromJson(Map<String, dynamic> json) {
    gateway = json["gateway"];
    country = json["country"];
  }

  toJson() {
    return {
      "gateway": gateway,
      "country": country
    };
  }
}

class OpenShockApiToken {
  String? id;
  String name = "";
  List<String> permissions = [];
  DateTime? validUntil;
  DateTime? lastUsed;
  DateTime? createdOn;

  OpenShockApiToken(this.name, this.permissions, this.validUntil);

  toJson({bool getValidUntil = false}) {
    // only contains things which can be updated
    return {
      "name": name,
      "permissions": permissions,
      if(getValidUntil) "validUntil": validUntil?.toIso8601String()
    };
  }

  OpenShockApiToken.fromJson(Map<String, dynamic> json) {
    name = json["name"];
    permissions = List<String>.from(json["permissions"]);
    validUntil = json["validUntil"] == null ? null : DateTime.parse(json["validUntil"]);
    lastUsed = json["lastUsed"] == null ? null : DateTime.parse(json["lastUsed"]);
    createdOn = json["createdOn"] == null ? null : DateTime.parse(json["createdOn"]);
    id = json["id"];
  }
}

class OpenShockUserSession {
  DateTime? created;
  DateTime? expires;
  String? id;
  String? ip;
  DateTime? lastUsed;
  String? userAgent;

  OpenShockUserSession.fromJson(Map<String, dynamic> json) {
    created = json["created"] == null ? null : DateTime.parse(json["created"]);
    expires = json["expires"] == null ? null : DateTime.parse(json["expires"]);
    id = json["id"];
    ip = json["ip"];
    lastUsed = json["lastUsed"] == null ? null : DateTime.parse(json["lastUsed"]);
    userAgent = json["userAgent"];
  }
}

class OpenShockShareLink {
  DateTime createdOn = DateTime.now();
  DateTime? expiresOn;
  OpenShockUser? author;
  String id  = "";
  String name = "";
  List<Shocker> shockers = [];
  Token? tokenReference;
  int? tokenId;

  OpenShockShareLink();
  OpenShockShareLink.fromId(this.id, this.name, this.tokenReference) {
    this.tokenId = tokenReference?.id;
  }

  String getLink() {
    String host = "https://openshock.app";
    if(tokenReference != null) {
      host = tokenReference!.server.replaceAll("//api.", "//");
    }
    if(host.endsWith("/")) {
      host = host.substring(0, host.length - 1);
    } 
    return "$host/s/$id";
  }

  OpenShockShareLink.fromJson(Map<String, dynamic> json, {this.tokenReference}) {
    id = json["id"];
    if(json["createdOn"] != null) {
      createdOn = DateTime.parse(json["createdOn"]);
    }
    if(json["expiresOn"] != null) {
      expiresOn = DateTime.parse(json["expiresOn"]);
    }
    if(json["author"] != null) {
      author = OpenShockUser.fromJson(json["author"]);
    }
    
    if(json["devices"] != null) {
      
      for(var device in json["devices"]) {
        OpenShockDevice d = OpenShockDevice.fromJson(device, tokenReference: tokenReference);
        for(OpenShockShocker s in d.shockers) {
          Shocker shocker = Shocker.fromOpenShockShocker(s);
          shocker.hubId = d.id;
          shocker.hubReference = AlarmListManager.getInstance().getHub(d.id);
          shocker.apiTokenId = tokenReference!.id;
          shockers.add(shocker);
        }
      }
    }
    name = json["name"];
    if(json["tokenId"] != null) {
      tokenId = json["tokenId"];
    }
  }

  toJson() {
    return {
      "id": id,
      "name": name,
      "createdOn": createdOn.toIso8601String(),
      "expiresOn": expiresOn?.toIso8601String(),
      "author": author?.toJson(),
      "tokenId": tokenReference?.id,
    };
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
  stop, // 0
  shock, // 1
  vibrate, // 2
  sound, // 3
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

  static OpenShockShareLimits fromShocker(Shocker shocker) {
    OpenShockShareLimits limits = OpenShockShareLimits();
    limits.limits.duration = shocker.durationLimit;
    limits.limits.intensity = shocker.intensityLimit;
    limits.permissions.shock = shocker.shockAllowed;
    limits.permissions.vibrate = shocker.vibrateAllowed;
    limits.permissions.sound = shocker.soundAllowed;
    return limits;
  }
}

class Control {
  String id = "";
  bool exclusive = true;
  int duration = 0;
  int intensity = 0;
  ControlType type = ControlType.stop;
  int apiTokenId = 0;
  Shocker? shockerReference;

  Control();

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

  toJsonWS() {
    int type = 0;
    switch(this.type) {
      case ControlType.stop:
        type = 0;
        break;
      case ControlType.shock:
        type = 1;
        break;
      case ControlType.vibrate:
        type = 2;
        break;
      case ControlType.sound:
        type = 3;
        break;
      case ControlType.live:
        type = 4;
        break;
    } 
    return {
      "id": id,
      "duration": duration,
      "intensity": intensity,
      "type": type
    };
  }
}

class WSShockerLog {
  OpenShockShocker? shocker;
  ControlType type = ControlType.shock;
  int intensity = 0;
  int duration = 0;
  DateTime executedAt = DateTime.now();

  WSShockerLog.fromJson(Map<String, dynamic> json) {
    type = ControlType.values[json["type"]];
    shocker = OpenShockShocker.fromJson(json["shocker"]);
    intensity = json["intensity"];
    duration = json["duration"];
    executedAt = DateTime.parse(json["executedAt"]);
  }
}

class ShockerLog {
  String id = "";
  DateTime createdOn = DateTime.now();
  ControlType type = ControlType.shock;
  OpenShockUser controlledBy = OpenShockUser();
  int intensity = 0;
  int duration = 0;
  
  Shocker? shockerReference;

  ShockerLog.fromWs(WSShockerLog log, OpenShockUser user) {
    type = log.type;
    controlledBy = user;
    createdOn = log.executedAt;
    intensity = log.intensity;
    duration = log.duration;
  }

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
  String? connectionId;
  String? customName;

  OpenShockUser();

  OpenShockUser.fromJson(Map<String, dynamic> json) {
    id = json["id"];
    name = json["name"];
    image = json["image"];
    if(json["connectionId"] != null)
      connectionId = json["connectionId"];
    customName = json["customName"];
  }
  
  toJson() {
    return {
      "id": id,
      "name": name,
      "image": image,
      "connectionId": connectionId,
      "customName": customName
    };
  }
}

class Hub {
  String name = "";
  String id = "";
  bool isOwn = false;
  bool online = false;
  int apiTokenId = 0;
  String firmwareVersion = "";

  Hub();

  Hub.fromOpenShockDevice(OpenShockDevice device) {
    name = device.name;
    id = device.id;
    firmwareVersion = device.firmwareVersion;
  }

  Hub.fromJson(Map<String, dynamic> json) {
    name = json["name"];
    id = json["id"];
    isOwn = json["isOwn"];
    if(json["apiTokenId"] != null)
      apiTokenId = json["apiTokenId"];
    if(json["firmwareVersion"] != null)
      firmwareVersion = json["firmwareVersion"];
    if(json["online"] != null)
      online = json["online"];
  }

  Map<String, dynamic> toJson() {
    return {
      "name": name,
      "id": id,
      "isOwn": isOwn,
      "apiTokenId": apiTokenId,
      "online": online,
      "firmwareVersion": firmwareVersion
    };
  }

  getIdentifier(AlarmListManager manager) {
    online = manager.onlineHubs.contains(this.id);
    
    return "$id-$apiTokenId-$isOwn-$online";
  }
}

class ControlsContainer {

  RangeValues durationRange;
  RangeValues intensityRange;
  RangeValues delayRange = RangeValues(0, 0);

  String getStringRepresentation(RangeValues values, bool trunance, {String unit = ""}) {
    if(values.end == values.start) {
      return "${trunance ? values.start.toInt() : values.start}${unit}";
    }
    return "${trunance ? values.start.toInt() : values.start}${unit} - ${trunance ? values.end.toInt() : values.end}${unit}";
  }

  void limitTo(int duration, int intensity) {
    durationRange = RangeValues(min(durationRange.start, duration.toDouble()), min(durationRange.end, duration.toDouble()));
    intensityRange = RangeValues(min(intensityRange.start, intensity.toDouble()), min(intensityRange.end, intensity.toDouble()));
    if(!AlarmListManager.getInstance().settings.useRangeSliderForIntensity) {
      intensityRange = RangeValues(intensityRange.start, intensityRange.start);
    }
    if(!AlarmListManager.getInstance().settings.useRangeSliderForDuration) {
      durationRange = RangeValues(durationRange.start, durationRange.start);
    }
  }

  ControlsContainer({this.durationRange = const RangeValues(300, 300), this.intensityRange = const RangeValues(25, 25)});

  void setIntensity(double value) {
    intensityRange = RangeValues(value, value);
  }

  void setDuration(int mapDuration) {
    durationRange = RangeValues(mapDuration.toDouble(), mapDuration.toDouble());
  }

  String getDurationString() {
    RangeValues durationRange = RangeValues(this.durationRange.start / 1000, this.durationRange.end / 1000);
    return getStringRepresentation(durationRange, false, unit: " s");
  }

  static fromInts({required int intensity, required int duration}) {
    return ControlsContainer(durationRange: RangeValues(duration.toDouble(), duration.toDouble()), intensityRange: RangeValues(intensity.toDouble(), intensity.toDouble()));
  }

  int getRandomDuration() {
    if(durationRange.start == durationRange.end) {
      return durationRange.start.toInt();
    }
    return Random().nextInt((durationRange.end - durationRange.start).toInt()) + durationRange.start.toInt();
  }

  int getRandomIntensity() {
    if(intensityRange.start == intensityRange.end) {
      return intensityRange.start.toInt();
    }
    return Random().nextInt((intensityRange.end - intensityRange.start).toInt()) + intensityRange.start.toInt();
  }
}

enum PauseReason {
  shocker,
  share,
  shareLink
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
  bool liveAllowed = true;
  int durationLimit = 30000;
  int intensityLimit = 100;
  bool isOwn = false;
  List<PauseReason> pauseReasons = [];
  ControlsContainer controls = ControlsContainer();
  
  String getPausedLevels() {
    List<String> levels = [];
    if(pauseReasons.contains(PauseReason.shocker)) {
      levels.add("Shocker");
    }
    if(pauseReasons.contains(PauseReason.share)) {
      levels.add("Share");
    }
    if(pauseReasons.contains(PauseReason.shareLink)) {
      levels.add("Share Link");
    }
    return levels.join(", ");
  }

  Shocker.fromOpenShockShocker(OpenShockShocker shocker) {
    id = shocker.id;
    name = shocker.name;

    paused = shocker.isPaused;
    if(shocker.paused != null) {
      if(shocker.paused! & 1 != 0) {
        pauseReasons.add(PauseReason.shocker);
      }
      if(shocker.paused! & 2 != 0) {
        pauseReasons.add(PauseReason.share);
      }
      if(shocker.paused! & 4 != 0) {
        pauseReasons.add(PauseReason.shareLink);
      }
    }

    if(shocker.permissions != null) {
      shockAllowed = shocker.permissions!.shock;
      vibrateAllowed = shocker.permissions!.vibrate;
      soundAllowed = shocker.permissions!.sound;
      liveAllowed = shocker.permissions!.live;
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
      "liveAllowed": liveAllowed,
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
    if(shocker["liveAllowed"] != null)
      s.liveAllowed = shocker["liveAllowed"];
    if(shocker["isOwn"] != null)
      s.isOwn = shocker["isOwn"];
    return s;
  }

  String getIdentifier() {
    return "$id-$apiTokenId-${paused}-${shockAllowed}-${vibrateAllowed}-${liveAllowed}-${soundAllowed}-${durationLimit}-${intensityLimit}-${AlarmListManager.getInstance().settings.useRangeSliderForRandomDelay}-${AlarmListManager.getInstance().settings.useRangeSliderForDuration}-${AlarmListManager.getInstance().settings.useRangeSliderForIntensity}";
  }

  Control getLimitedControls(ControlType type, int intensity, int duration) {
      Control c = Control();
      c.id = this.id;
      c.type = type;
      c.intensity = min(this.intensityLimit, intensity);
      c.duration = min(this.durationLimit, duration);
      c.apiTokenId = this.apiTokenId;
      if(!this.shockAllowed && type == ControlType.shock) {
        c.type = ControlType.vibrate;
      }
      if(!this.vibrateAllowed && type == ControlType.vibrate) {
        c.type = ControlType.stop;
      }
      if(!this.soundAllowed && type == ControlType.sound) {
        c.type = ControlType.stop;
        if(this.vibrateAllowed) {
          c.type = ControlType.vibrate;
        }
      }
      return c;
  }

  void setLimits(OpenShockShareLimits limits) {
    durationLimit = limits.limits.duration ?? 30000;
    intensityLimit = limits.limits.intensity ?? 100;
    shockAllowed = limits.permissions.shock;
    vibrateAllowed = limits.permissions.vibrate;
    soundAllowed = limits.permissions.sound;
    liveAllowed = limits.permissions.live;
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
    String device = "";
    bool online = false;
    String firmwareVersion = "";
    List<OpenShockShocker> shockers = [];
    
    Token? apiTokenReference;

    OpenShockDevice.fromJson(Map<String, dynamic> json, {Token? tokenReference = null})
    {
      if(json['name'] != null)
        name = json['name'];
      if(json['id'] != null)
        id = json['id'];
      if(json['online'] != null)
        online = json['online'];
      if(json['firmwareVersion'] != null)
        firmwareVersion = json['firmwareVersion'];
      if(json['device'] != null)
        device = json['device'];
      if (json['shockers'] != null)
      {
        json['shockers'].forEach((v) {
            shockers.add(OpenShockShocker.fromJson(v));
        });
      }
      apiTokenReference = tokenReference;
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
    int? paused;
    bool? isDisabled = false;
    OpenShockShockerLimits? limits;
    OpenShockShockerPermissions? permissions;

    int? rfId;
    String? device;
    String? model;

    OpenShockShocker();

    OpenShockShocker.fromJson(Map<String, dynamic> json)
    {
        name = json['name'];
        id = json['id'];
        if(json["rfId"] != null)
          rfId = json['rfId'];
        if(json["model"] != null)
          model = json['model'];
        if(json["device"] != null)
          device = json["device"];
        if(json["isPaused"] != null)
          isPaused = json['isPaused'];
        if(json["isDisabled"] != null)
          isDisabled = json['isDisabled'];
        if (json['limits'] != null)
        {
            limits = OpenShockShockerLimits();
            limits!.intensity = json['limits']['intensity'];
            limits!.duration = json['limits']['duration'];
        }
        if(json['paused'] != null)
          paused = json['paused'];
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