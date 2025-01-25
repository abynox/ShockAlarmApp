import 'dart:io';

import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shock_alarm_app/services/alarm_list_manager.dart';
import 'package:shock_alarm_app/services/openshock.dart';
import '../main.dart';

class Token {
  Token(this.id, this.token, {this.server = "https://api.openshock.app", this.name="", this.isSession = false, this.userId = ""});

  int id;

  String token;
  String server;
  bool isSession = false;
  String name = "";
  String userId = "";

  static Token fromJson(token) {
    return Token(token["id"], token["token"], server: token["server"], name: token["name"] ?? "", isSession: token["isSession"] ?? false, userId: token["userId"] ?? "");
  }

  Map<String, dynamic> toJson() {
    return {"id": id, "token": token, "server": server, "name": name, "isSession": isSession, "userId": userId};
  }
}

class AlarmToneComponent {
  int intensity = 25;
  int duration = 1000;
  ControlType? type = ControlType.vibrate;
  int time = 0;

  AlarmToneComponent({this.intensity = 25, this.duration = 1000, this.type = ControlType.vibrate, this.time = 0});

  Map<String, dynamic> toJson() {
    return {
      "intensity": intensity,
      "duration": duration,
      "type": type?.index ?? -1,
      "time": time
    };
  }

  static AlarmToneComponent fromJson(component) {
    return AlarmToneComponent(
      intensity: component["intensity"],
      duration: component["duration"],
      type: component["type"] == -1 ? null : ControlType.values[component["type"]],
      time: component["time"]
    );
  }
}

class AlarmTone {
  int id;
  String name = "";
  List<AlarmToneComponent> components = [];

  AlarmTone({required this.id, required this.name});

  Map<String, dynamic> toJson() {
    return {
      "id": id,
      "name": name,
      "components": components.map((e) => e.toJson()).toList()
    };
  }

  static AlarmTone fromJson(tone) {
    AlarmTone t = AlarmTone(id: tone["id"], name: tone["name"]);
    if(tone["components"] != null)
      t.components = (tone["components"] as List).map((e) => AlarmToneComponent.fromJson(e)).toList();
    return t;
  }
}

class AlarmShocker {
  String shockerId = "";
  int? toneId;
  int intensity = 25;
  int duration = 1000;
  ControlType? type = ControlType.vibrate;
  Shocker? shockerReference;

  bool enabled = false;
  
  Map<String, dynamic> toJson() {
    return {
      "shockerId": shockerId, 
      "toneId": toneId,
      "intensity": intensity,
      "duration": duration,
      "type": type?.index ?? -1,
      "enabled": enabled
    };
  }

  static AlarmShocker fromJson(shocker) {
    return AlarmShocker()
      ..shockerId = shocker["shockerId"]
      ..toneId = shocker["toneId"]
      ..intensity = shocker["intensity"]
      ..duration = shocker["duration"]
      ..type = shocker["type"] == -1 ? null : ControlType.values[shocker["type"]]
      ..enabled = shocker["enabled"];
  }
}

class Alarm {
  int id;
  String name;
  int hour;
  int minute;
  bool monday;
  bool tuesday;
  bool wednesday;
  bool thursday;
  bool friday;
  bool saturday;
  bool sunday;
  bool active;
  bool repeatAlarmsTone = true;
  List<AlarmShocker> shockers = [];

  Alarm(
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

  void trigger(AlarmListManager manager, bool disableIfApplicable) async {
    // ToDo: show notification
    SharedPreferences prefs = await SharedPreferences.getInstance();
    prefs.setBool("alarm$id.active", true);

    FlutterLocalNotificationsPlugin().show(id, name,"Your alarm is firing", NotificationDetails(android: AndroidNotificationDetails("alarms", "Alarms", enableVibration: true, priority: Priority.high, importance: Importance.max, actions: [
      AndroidNotificationAction("stop", "Stop alarm", showsUserInterface: true)
    ])), payload: id.toString());
    DateTime startedAt = DateTime.now();
    var maxDuration = 0;
    bool shouldContinue = repeatAlarmsTone;
    while(shouldContinue) {
      Map<int, List<Control>> controlTimes = {0: []};
      for (var shocker in shockers) {
        if (!shocker.enabled) continue;
        if(shocker.toneId != null) {
          var tone = manager.getTone(shocker.toneId!);
          if(tone != null) {
            for (var component in tone.components) {
              int executionTime = component.time + component.duration;
              if (executionTime > maxDuration) {
                maxDuration = executionTime;
              }
              if(!controlTimes.containsKey(component.time)) {
                controlTimes[component.time] = [];
              }
              Control control = Control();
              control.type = component.type!;
              control.intensity = component.intensity;
              control.duration = component.duration;
              control.id = shocker.shockerId;
              control.apiTokenId = shocker.shockerReference!.apiTokenId;
              controlTimes[component.time]!.add(control);
            }
          }
        } else {
          if (shocker.duration > maxDuration) {
            maxDuration = shocker.duration;
          }
          Control control = Control();
          control.type = shocker.type!;
          control.intensity = shocker.intensity;
          control.duration = shocker.duration;
          control.id = shocker.shockerId;
          control.apiTokenId = shocker.shockerReference!.apiTokenId;
          controlTimes[0]!.add(control);
          // If a shocker is paused the backend will return an error. So we don't need to check if it's paused. Especially as the saved state may not reflect the real paused state.
        }
      }

      int timeTillNow = 0;
      for (var time in controlTimes.keys) {
        print(time);
        print(time- timeTillNow);
        if(time - timeTillNow > 0) await Future.delayed(Duration(milliseconds: time - timeTillNow));
        timeTillNow = time;

        await manager.sendControls(controlTimes[time]??[], customName: name, useWs: false);
      }


      // Wait until all shockers have finished
      await Future.delayed(Duration(milliseconds: maxDuration + manager.settings.alarmToneRepeatDelayMs - timeTillNow));
      print("checking alarm$id.active");
      await prefs.reload();
      shouldContinue = prefs.getBool("alarm$id.active") ?? false;
      print("is $shouldContinue");
      int secondsSinceAlarmStart = DateTime.now().difference(startedAt).inSeconds;
      if(secondsSinceAlarmStart >= manager.settings.maxAlarmLengthSeconds) shouldContinue = false;
    }
    onAlarmStopped(manager);

    if (disableIfApplicable) {
      if(!shouldSchedulePerWeekday()) {
        active = false;
        manager.saveAlarm(this);
      }
    }

  }

  void onAlarmStopped(AlarmListManager manager, {bool needStop = true}) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool("alarm$id.active", false);
    if(needStop) {
      for (var shocker in shockers) {
        if (shocker.enabled) {
          // Stop all shockers
          manager.sendShock(ControlType.stop, shocker.shockerReference!, shocker.intensity, shocker.duration, customName: name, useWs: false);
        }
      }
    }

    FlutterLocalNotificationsPlugin().show(id, name,"Alarm stopped", NotificationDetails(android: AndroidNotificationDetails("alarms", "Alarms", enableVibration: true, priority: Priority.high, importance: Importance.max)), payload: id.toString());

  }

  // Good enough for debugging for now
  @override
  toString() {
    return "active: $active, name: $name, hour: $hour, minute: $minute, days: $days";
  }

  Map<String, dynamic> toJson() {
    return {
      "id": id,
      "name": name,
      "hour": hour,
      "minute": minute,
      "monday": monday,
      "tuesday": tuesday,
      "wednesday": wednesday,
      "thursday": thursday,
      "friday": friday,
      "saturday": saturday,
      "sunday": sunday,
      "active": active,
      "shockers": shockers.map((e) => e.toJson()).toList(),
      "repeatAlarmsTone": repeatAlarmsTone
    };
  }

  static Alarm fromJson(alarm) {
    Alarm a = Alarm(
      id: alarm["id"],
      name: alarm["name"],
      hour: alarm["hour"],
      minute: alarm["minute"],
      monday: alarm["monday"],
      tuesday: alarm["tuesday"],
      wednesday: alarm["wednesday"],
      thursday: alarm["thursday"],
      friday: alarm["friday"],
      saturday: alarm["saturday"],
      sunday: alarm["sunday"],
      active: alarm["active"]);
    if(alarm["shockers"] != null)
      a.shockers = (alarm["shockers"] as List).map((e) => AlarmShocker.fromJson(e)).toList();
    if(alarm["repeatAlarmsTone"] != null)
      a.repeatAlarmsTone = alarm["repeatAlarmsTone"];
    return a;
  }

  bool shouldSchedulePerWeekday() {
    return days.any((element) {
      return element == true;
    });
  }

  schedule(AlarmListManager manager) async {
    if (!shouldSchedulePerWeekday()) {
      // Schedule for next occurrance 
      DateTime now = DateTime.now();
      DateTime nextOccurrance = DateTime(now.year, now.month, now.day, hour, minute);
      if (nextOccurrance.isBefore(now)) {
        nextOccurrance = nextOccurrance.add(Duration(days: 1));
      }

      if(!Platform.isAndroid) {
        ScaffoldMessenger.of(manager.context!).showSnackBar(SnackBar(content: Text("Cannot schedule alarm on linux atm")));
        return;
      }
      try {
        ScaffoldMessenger.of(manager.context!).showSnackBar(SnackBar(content: Text("Scheduled alarm for ${nextOccurrance.toString()}")));
      } catch (e) {
        print("Error: $e");
      }
      AndroidAlarmManager.oneShotAt(nextOccurrance, id, alarmCallback, exact: true, wakeup: true);
    }
  }
}