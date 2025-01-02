import 'package:flutter/material.dart';
import 'screens/home.dart';
import 'stores/alarm_store.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'services/alarm_list_manager.dart';

void main() {
  runApp(const MyApp());
}

AlarmList list = AlarmList();

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {

    AlarmListManager manager = AlarmListManager(list);
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        scaffoldBackgroundColor: Color.fromRGBO(25, 12, 38, 1),
      ),
      home: Observer(builder: (context) {
        /*
        AlarmStatus status = AlarmStatus();

        if (status.isAlarm) {
          final id = status.alarmId;
          final alarm =
              list.alarms.firstWhereOrNull((alarm) => alarm.id == id)!;

          MediaHandler mediaHandler = MediaHandler();

          mediaHandler.changeVolume(alarm);
          mediaHandler.playMusic(alarm);
          Wakelock.enable();

          return AlarmScreen(alarm: alarm, mediaHandler: mediaHandler);
        }
        */
        return ScreenSelector(manager: manager);
      }));
  }
}