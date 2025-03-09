import 'package:shock_alarm_app/services/alarm_list_manager.dart';

import '../stores/alarm_store.dart';

abstract class AlarmManager {
  AlarmManagerType? type;
  Future deleteAlarm(Alarm alarm);
  Future scheduleAlarms(List<Alarm> alarms);
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
}

class AlarmServerAlarmManager implements AlarmManager {
  @override
  AlarmManagerType? type = AlarmManagerType.server;

  @override
  Future scheduleAlarms(List<Alarm> alarms) async {
    
  }

  @override
  Future deleteAlarm(Alarm alarm) async {
    
  }
}

enum AlarmManagerType {
  android,
  server
}