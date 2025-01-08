import 'package:flutter/material.dart';
import 'package:shock_alarm_app/services/alarm_list_manager.dart';

import '../stores/alarm_store.dart';

class EditAlarmTime extends StatefulWidget {
  final ObservableAlarmBase alarm;
  final AlarmListManager manager;


  const EditAlarmTime({Key? key, required this.alarm, required this.manager}) : super(key: key);

  @override
  State<StatefulWidget> createState() => EditAlarmTimeState(alarm, manager);
}

class EditAlarmTimeState extends State<EditAlarmTime> {
  final ObservableAlarmBase alarm;
  final AlarmListManager manager;
  
  EditAlarmTimeState(this.alarm, this.manager);

  @override
  Widget build(BuildContext context) {
    final hours = alarm.hour.toString().padLeft(2, '0');
    final minutes = alarm.minute.toString().padLeft(2, '0');
    ThemeData t = Theme.of(context);
    return Center(
      child: GestureDetector(
        child:
          Text(
            '$hours:$minutes',
            style: t.textTheme.displayMedium
          ),
        onTap: () async {
          final time = await showTimePicker(
            context: context,
            initialTime: TimeOfDay(hour: alarm.hour, minute: alarm.minute),
          );

          if (time == null) {
            return;
          }
          setState(() {
            alarm.hour = time.hour;
            alarm.minute = time.minute;
            manager.saveAlarm(alarm);
          });
        },
      ),
    );
  }
}
