import 'package:flutter/material.dart';
import 'package:shock_alarm_app/components/tone_item.dart';
import 'package:shock_alarm_app/services/alarm_list_manager.dart';

class AlarmToneScreen extends StatefulWidget {
  final AlarmListManager manager;

  AlarmToneScreen(this.manager);
  
  @override
  AlarmToneScreenState createState() => AlarmToneScreenState(manager);
}

class AlarmToneScreenState extends State<AlarmToneScreen> {
  final AlarmListManager manager;

  AlarmToneScreenState(this.manager);

  void onRebuild() {
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    ThemeData t = Theme.of(context);
    return Column(children: [
      Text(
        'Alarm tones',
        style: t.textTheme.headlineMedium,
      ),
      if(manager.alarmTones.isEmpty)
        Text(
            "No alarm tones found",
            style: t.textTheme.headlineSmall
        ),
      Flexible(
        child:  ListView(children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: manager.alarmTones.map((tone) {
                return ToneItem(tone: tone, manager: manager, onRebuild: onRebuild);
              }).toList()
            )
          ],)
      )
    ],);
  }
}
