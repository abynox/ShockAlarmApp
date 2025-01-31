import 'dart:io';

import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_background/flutter_background.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shock_alarm_app/stores/alarm_store.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'screens/home.dart';
import 'services/alarm_list_manager.dart';
import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';

const String issues_url = "https://github.com/ComputerElite/ShockAlarmApp/issues";

String GetUserAgent() {
  return "ShockAlarm/0.0.11";
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

void initNotification(AlarmListManager manager) async {
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
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        onDidReceiveNotificationResponse(response, manager);
      });
    
  flutterLocalNotificationsPlugin.resolvePlatformSpecificImplementation<
      AndroidFlutterLocalNotificationsPlugin>()?.requestNotificationsPermission();
}

void onDidReceiveNotificationResponse(NotificationResponse notificationResponse, AlarmListManager manager) async {
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

Future initBgService() async {
  final androidConfig = FlutterBackgroundAndroidConfig(
    notificationTitle: "Shocking service",
    notificationText: "Allows ShowAlarm to control your shockers",
    notificationImportance: AndroidNotificationImportance.normal,
    showBadge: true,
    notificationIcon: AndroidResource(name: 'monochrome_icon', defType: 'drawable'), // Default is ic_launcher from folder mipmap
  );
  bool success = await FlutterBackground.initialize(androidConfig: androidConfig);
  print("Background service initialized: $success");
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  AlarmListManager manager = AlarmListManager();
  await manager.loadAllFromStorage();
  initNotification(manager);

  // Register a custom protocol
  // For macOS platform needs to declare the scheme in ios/Runner/Info.plist
  if(isAndroid()) {
    await AndroidAlarmManager.initialize();
    await requestPermissions();
    await initBgService();
  }
  

  runApp(MyApp(null));
}

@pragma('vm:entry-point')
void alarmCallback(int id) async {
  AlarmListManager manager = AlarmListManager();
  await manager.loadAllFromStorage();

  //initNotification(manager);
  manager.getAlarms().forEach((element) {
    print("Checking alarm");
    if(element.active && id ==element.id) {
      element.trigger(manager, true);
    }
  });
}

class MyApp extends StatefulWidget {
  final int? alarmId;
  const MyApp(this.alarmId, {super.key});

  @override
  State<StatefulWidget> createState() => MyAppState();

}

class MyAppState extends State<MyApp> {
  int? alarmId;
  ThemeMode themeMode = AlarmListManager.getInstance().settings.theme;

  @override
  void initState() {
    super.initState();
    alarmId = widget.alarmId;
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  void onProtocolUrlReceived(String url) {
    print("Received protocol url: $url");
    showDialog(context: context, builder: (context) {
      return AlertDialog(
        title: Text("Received protocol url"),
        content: Text(url),
        actions: [
          TextButton(onPressed: () {
            Navigator.of(context).pop();
          }, child: Text("Close"))
        ],
      );
    });
  }

  void setThemeMode(ThemeMode themeMode) {
    AlarmListManager.getInstance().settings.theme = themeMode;
    AlarmListManager.getInstance().saveSettings();
    setState(() {
      this.themeMode = themeMode;
    });
  }

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return DynamicColorBuilder(builder: (lightColorScheme, darkColorScheme) {
      return MaterialApp(
        title: 'ShockAlarm',
        theme: lightColorScheme != null ? ThemeData(
          useMaterial3: true,
          colorScheme: lightColorScheme,
        ): ThemeData.light(),
        darkTheme: darkColorScheme != null ? ThemeData(
          useMaterial3: true,
          colorScheme: darkColorScheme,
        ): ThemeData.dark(),
        themeMode: themeMode,
        home: ScreenSelector(manager: AlarmListManager.getInstance())
      );
    });
  }
}