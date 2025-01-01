import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';

import '../stores/alarm_store.dart';

class EditAlarmTime extends StatefulWidget {
  final ObservableAlarmBase alarm;

  const EditAlarmTime({Key? key, required this.alarm}) : super(key: key);

  @override
  State<StatefulWidget> createState() => EditAlarmTimeState(alarm);
}

class EditAlarmTimeState extends State<EditAlarmTime> {
  final ObservableAlarmBase alarm;
  
  EditAlarmTimeState(this.alarm);

  @override
  Widget build(BuildContext context) {
    return Center(
      child: GestureDetector(
        child: Observer(builder: (context) {
          final hours = alarm.hour.toString().padLeft(2, '0');
          final minutes = alarm.minute.toString().padLeft(2, '0');
          return Text(
            '$hours:$minutes',
            style: TextStyle(fontSize: 36),
          );
        }),
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
          });
        },
      ),
    );
  }
}
