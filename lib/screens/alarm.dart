import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../stores/alarm_store.dart';
import '../components/default_container.dart';
import 'package:slide_to_act/slide_to_act.dart';
//import 'package:wakelock/wakelock.dart';

class AlarmScreen extends StatelessWidget {
  final ObservableAlarmBase alarm;

  const AlarmScreen({Key? key, required this.alarm})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    TimeOfDay now = TimeOfDay.now();

    return DefaultContainer(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: <Widget>[
          Center(
            child: Container(
              width: 325,
              height: 325,
              decoration: ShapeDecoration(
                  shape: CircleBorder(
                      side: BorderSide(
                          color: Colors.deepOrange,
                          style: BorderStyle.solid,
                          width: 4))),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: <Widget>[
                  Icon(
                    Icons.alarm,
                    color: Colors.deepOrange,
                    size: 32,
                  ),
                  Text(
                    now.format(context),
                    style: TextStyle(
                        fontSize: 52,
                        fontWeight: FontWeight.w900,
                        color: Colors.white),
                  ),
                  Text(
                    alarm.name,
                    style: TextStyle(color: Colors.white, fontSize: 24),
                  ),
                ],
              ),
            ),
          ),
          ClipRRect(
            borderRadius: BorderRadius.circular(50),
            child: SlideAction(
              height: 80,
              sliderButtonIcon: Icon(
                Icons.chevron_right,
                size: 36,
              ),
              child: Center(
                  child: Text(
                'Turn off alarm!',
                style: TextStyle(fontSize: 26),
              )),
              onSubmit: () async {
                //Wakelock.disable();

                //AlarmStatus().isAlarm = false;
                //AlarmStatus().alarmId = null;
                SystemNavigator.pop();
              },
              innerColor: Colors.deepPurple,
              outerColor: Colors.deepOrangeAccent,
            ),
          )
        ],
      ),
    );
  }
}