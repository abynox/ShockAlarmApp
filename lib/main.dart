import 'dart:io';

import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'screens/home.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'services/alarm_list_manager.dart';
import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';

Future requestPermissions() async{
  final status = await Permission.scheduleExactAlarm.status;
  print('Schedule exact alarm permission: $status.');
  if (status.isDenied) {
    print('Requesting schedule exact alarm permission...');
    final res = await Permission.scheduleExactAlarm.request();
    print('Schedule exact alarm permission ${res.isGranted ? '' : 'not'} granted.');
  }
}
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AndroidAlarmManager.initialize();
  await AndroidAlarmManager.oneShot(Duration(seconds: 10), 0, alarmCallback, alarmClock: true);

  await requestPermissions();
  runApp(MyApp(null));
}

@pragma('vm:entry-point')
void alarmCallback(int id) {
  print("Woah");
  WakelockPlus.enable();
  Intent i = 
  runApp(MyApp(id));
}

class MyApp extends StatelessWidget {
  int? alarmId;
  MyApp(this.alarmId);


  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {

    AlarmListManager manager = AlarmListManager();
    manager.loadAllFromStorage();
    return DynamicColorBuilder(builder: (lightColorScheme, darkColorScheme) {
      return MaterialApp(
        title: 'ShockAlarm',
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: lightColorScheme,
        ),
        darkTheme: ThemeData(
          useMaterial3: true,
          colorScheme: darkColorScheme,
        ),
        themeMode: ThemeMode.system,
        home: ScreenSelector(manager: manager)
      );
    });
  }
}