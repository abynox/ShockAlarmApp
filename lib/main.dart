import 'dart:io';

import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shock_alarm_app/stores/alarm_store.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'screens/home.dart';
import 'services/alarm_list_manager.dart';
import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';

const String issues_url = "https://github.com/ComputerElite/ShockAlarmApp/issues";

String GetUserAgent() {
  return "ShockAlarm/0.0.10";
}

bool isAndroid() {
  return !kIsWeb && Platform.isAndroid;
}

Future requestPermissions() async{
  if(!isAndroid()) return;
  final status = await Permission.scheduleExactAlarm.status;
  print('Schedule exact alarm permission: $status.');
  if (status.isDenied) {
    print('Requesting schedule exact alarm permission...');
    final res = await Permission.scheduleExactAlarm.request();
    print('Schedule exact alarm permission ${res.isGranted ? '' : 'not'} granted.');
  }
}

void initNotification() async {
  FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();
  // initialise the plugin. app_icon needs to be a added as a drawable resource to the Android head project
  const AndroidInitializationSettings initializationSettingsAndroid =
      AndroidInitializationSettings("monochrome_icon");
  final DarwinInitializationSettings initializationSettingsDarwin =
      DarwinInitializationSettings();
  final LinuxInitializationSettings initializationSettingsLinux =
      LinuxInitializationSettings(
          defaultActionName: 'Open notification');
  final InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsDarwin,
      macOS: initializationSettingsDarwin,
      linux: initializationSettingsLinux);
await flutterLocalNotificationsPlugin.initialize(initializationSettings,
      onDidReceiveNotificationResponse: onDidReceiveNotificationResponse);
    
  flutterLocalNotificationsPlugin.resolvePlatformSpecificImplementation<
      AndroidFlutterLocalNotificationsPlugin>()?.requestNotificationsPermission();
}

void onDidReceiveNotificationResponse(NotificationResponse notificationResponse) async {

  AlarmListManager manager = AlarmListManager();
  await manager.loadAllFromStorage();
  print("Notification received");
  if(notificationResponse.id != null) {
    print("Notification id owo: ${notificationResponse.id}");
  }
  Alarm? alarm;
  manager.getAlarms().forEach((element) {
    if(element.id == notificationResponse.id) {
      alarm = element;
    }
  });
  if(alarm == null) {
    print("Alarm not found");
    return;
  }
  switch(notificationResponse.actionId) {
    case "stop":
      alarm?.onAlarmStopped(manager);
      break;
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  initNotification();
  if(isAndroid()) {
    await AndroidAlarmManager.initialize();
    await requestPermissions();
  }

  runApp(MyApp(null));
}

@pragma('vm:entry-point')
void alarmCallback(int id) async {

  AlarmListManager manager = AlarmListManager();
  initNotification(); 
  await manager.loadAllFromStorage();
  manager.getAlarms().forEach((element) {
    print("Checking alarm");
    if(element.active && id ==element.id) {
      element.trigger(manager, true);
    }
  });
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