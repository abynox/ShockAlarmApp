import 'dart:convert';

import 'package:shock_alarm_app/services/alarm_list_manager.dart';
import 'package:http/http.dart' as http;
import '../main.dart';
import '../stores/alarm_store.dart';

abstract class AlarmManager {
  AlarmManagerType? type;
  Future deleteAlarm(Alarm alarm);
  Future scheduleAlarms(List<Alarm> alarms);
  Future<ErrorContainer<List<Alarm>>> getAlarms();
  Future<ErrorContainer<List<AlarmTone>>> getAlarmsTones();
  Future<bool> saveAlarm(Alarm alarm);
}

class AndroidAlarmManager implements AlarmManager {
  @override
  AlarmManagerType? type = AlarmManagerType.android;
  
  @override
  Future scheduleAlarms(List<Alarm> alarms) async {
    for (var alarm in alarms) {
      if (alarm.active) {
        await alarm.schedule(AlarmListManager.getInstance());
      }
    }
  }

  @override
  Future deleteAlarm(Alarm alarm) async {
    
  }

  @override
  Future<ErrorContainer<List<Alarm>>> getAlarms() async {
    return ErrorContainer([], null);
  }

  
  @override
  Future<ErrorContainer<List<AlarmTone>>> getAlarmTones() async {
    return ErrorContainer([], null);
  }

  @override
  Future<bool> saveAlarm(Alarm alarm) async {
    // Alarms are saved automatically, nothing has to be done here
    return true;
  }
  
  @override
  Future<ErrorContainer<List<AlarmTone>>> getAlarmsTones() async {
    // TODO: implement getAlarmsTones
    return ErrorContainer([], null);
  }
}

class AlarmServerAlarmManager implements AlarmManager {
  @override
  AlarmManagerType? type = AlarmManagerType.server;

  @override
  Future scheduleAlarms(List<Alarm> alarms) async {
    
  }

  @override
  Future deleteAlarm(Alarm alarm) async {
    Token? userToken = AlarmListManager.getInstance().getAlarmServerUserToken();
    if(userToken == null) {
      return;
    }
    var response = await AlarmServerClient().DeleteRequest(userToken, "/api/v1/alarms/", jsonEncode(alarm.toAlarmServerAlarm(userToken.userId)));
    if(response.statusCode == 200) {
      return;
    }
  }

  @override
  Future<ErrorContainer<List<Alarm>>> getAlarms() async {
    Token? userToken = AlarmListManager.getInstance().getAlarmServerUserToken();
    if(userToken == null) {
      return ErrorContainer([], "Token is invalid.");
    }
    ErrorContainer<List<Alarm>> alarms = await AlarmServerClient().getAlarms(userToken);
    // ToDo: Decide on where to put the alarm syncing with server. Also make sure alarms are uploaded correctly
    return alarms;
  }

  @override
  Future<ErrorContainer<List<AlarmTone>>> getAlarmsTones() async {
    Token? userToken = AlarmListManager.getInstance().getAlarmServerUserToken();
    if(userToken == null) {
      return ErrorContainer([], "Token is invalid.");
    }

     AlarmServerClient().getAlarms(userToken);
    // ToDo: Get alarm tones from the server
    return ErrorContainer([], null);
  }

  @override
  Future<bool> saveAlarm(Alarm alarm) async {
    Token? userToken = AlarmListManager.getInstance().getAlarmServerUserToken();
    if(userToken == null) {
      return false;
    }
    var response = await AlarmServerClient().PostRequest(userToken, "/api/v1/alarms", jsonEncode(alarm.toAlarmServerAlarm(userToken.userId)));
    if(response.statusCode == 200) {
      return true;
    }
    return false;
  }
}

enum AlarmManagerType {
  android,
  server
}

class ErrorContainer<T> {
  T? value;
  String? error;
  ErrorContainer(this.value, this.error);
}

class AlarmServerClient {
  Future<ErrorContainer<Token>> loginOrRegister(String serverAddress, String username, String password, bool register) async {
    Token t = Token(DateTime.now().microsecondsSinceEpoch, "", server: serverAddress);
    t.tokenType = TokenType.alarmserver;
    var response = await PostRequest(t, "/api/v1/user/${register ? "register" : "login"}", jsonEncode({"Username": username, "Password": password}));
    if (response.statusCode != 200) {
      return ErrorContainer(null, response.body);
    }
    t.isSession = true;
    t.token = jsonDecode(response.body)["SessionId"];
    response = await GetRequest(t, "/api/v1/user/me");
    if (response.statusCode != 200) {
      return ErrorContainer(null, response.body);
    }
    var user = jsonDecode(response.body);
    t.name = user["Username"];
    return ErrorContainer(t, null);
  }

  Future<ErrorContainer<Token>> addOpenShockTokenToAccount(Token? alarmServerToken, Token? openShockToken) async {
    if(alarmServerToken == null) {
      return ErrorContainer(null, "Token is invalid.");
    }
    var response = await PostRequest(alarmServerToken, "/api/v1/tokens", jsonEncode({"Token": openShockToken?.token, "Server": openShockToken?.server}));
    if (response.statusCode != 200) {
      return ErrorContainer(null, response.body);
    }
    var tokens = jsonDecode(response.body);
    alarmServerToken.userId = tokens["CreatedId"];
    return ErrorContainer(alarmServerToken, null);
  }

  Future<ErrorContainer<Token>> populateTokenForAccount(Token? t) async {
    if(t == null) {
      return ErrorContainer(null, "Token is invalid.");
    }
    var response = await GetRequest(t, "/api/v1/tokens");
    if (response.statusCode != 200) {
      return ErrorContainer(null, response.body);
    }
    var tokens = jsonDecode(response.body);
    for (var token in tokens) {
      t.userId = token["Id"];
    }
    return ErrorContainer(t, null);
  }

  Future<ErrorContainer<List<Alarm>>> getAlarms(Token? t) async {
    print("FUCK");
    if(t == null) {
      return ErrorContainer<List<Alarm>>(null, "Token is invalid.");
    }
    var response = await GetRequest(t, "/api/v1/alarms");
    if(response.statusCode != 200) {
      return ErrorContainer(null, response.body);
    }
    print(response.body);
    var alarms = jsonDecode(response.body);
    List<Alarm> decodedAlarms = [];
    for(var a in alarms) {
      // now decode every single alarm
      decodedAlarms.add(Alarm.fromAlarmServerAlarm(a));
    }
    return ErrorContainer(decodedAlarms, null);
  }

  Future<http.Response> GetRequest(Token t, String path) {
    var url = Uri.parse(t.server + path);
    return http.get(url, headers: {
      "Authorization": "Bearer ${t.token}",
      'User-Agent': GetUserAgent(),
    });
  }

  Future<http.Response> PostRequest(Token t, String path, String body) {
    var url = Uri.parse(t.server + path);
    return http.post(url, headers: {
      "Authorization": "Bearer ${t.token}",
      "Content-Type": "application/json",
      'User-Agent': GetUserAgent(),
    }, body: body);
  }

  Future<http.Response> DeleteRequest(Token t, String path, String body) {
    var url = Uri.parse(t.server + path);
    return http.delete(url, headers: {
      "Authorization": "Bearer ${t.token}",
      "Content-Type": "application/json",
      'User-Agent': GetUserAgent(),
    }, body: body);
  }
}