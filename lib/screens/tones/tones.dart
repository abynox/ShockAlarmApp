import 'package:flutter/material.dart';
import 'package:shock_alarm_app/components/constrained_container.dart';
import 'package:shock_alarm_app/components/page_padding.dart';
import 'package:shock_alarm_app/screens/tones/tone_item.dart';
import 'package:shock_alarm_app/screens/screen_selector.dart';
import 'package:shock_alarm_app/services/alarm_list_manager.dart';

import '../../stores/alarm_store.dart';

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
    return
    Scaffold(
      appBar: AppBar(
        title: Text('Tones'),
      ),
      body: PagePadding(child: ConstrainedContainer(child: Column(children: [
          Text(
            'Tones',
            style: t.textTheme.headlineMedium,
          ),
          if(manager.alarmTones.isEmpty)
            Text(
                "No tones found",
                style: t.textTheme.headlineSmall
            ),
          Flexible(
            child:  ListView(children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: manager.alarmTones.map((tone) {
                    return ToneItem(tone: tone, manager: manager, onRebuild: onRebuild, key: ValueKey(tone.id));
                  }).toList()
                )
              ],)
          )
        ],),
      )),
      floatingActionButton: FloatingActionButton(onPressed: () {
        final newTone = new AlarmTone(
            id: manager.getNewToneId(),
            name: 'Tone label');
        setState(() {
          manager.saveTone(newTone);
        });
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Tone added'),
          duration: Duration(seconds: 3),
        ));
      }, child: Icon(Icons.add)));
  }
}
