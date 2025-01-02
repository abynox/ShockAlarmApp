import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/material.dart';
import 'screens/home.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'services/alarm_list_manager.dart';

void main() {
  runApp(MyApp(null));
}

@pragma('vm:entry-point')
void alarmCallback(int id) {
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