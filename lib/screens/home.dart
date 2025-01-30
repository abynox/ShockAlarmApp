import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shock_alarm_app/main.dart';
import 'package:shock_alarm_app/screens/grouped_shockers.dart';
import 'package:shock_alarm_app/screens/shockers.dart';
import 'package:shock_alarm_app/screens/tones.dart';
import 'package:shock_alarm_app/services/openshock.dart';
import '../components/alarm_item.dart';
import '../services/alarm_list_manager.dart';
import 'share_links.dart';
import 'tokens.dart';
import '../stores/alarm_store.dart';

class ScreenSelector extends StatefulWidget {
  final AlarmListManager manager;

  const ScreenSelector({Key? key, required this.manager}) : super(key: key);

  @override
  State<StatefulWidget> createState() => ScreenSelectorState(manager: manager);
}

class ScreenSelectorState extends State<ScreenSelector> {
  final AlarmListManager manager;
  int _selectedIndex = 3;
  bool supportsAlarms = isAndroid();

  @override void initState() {
    // TODO: implement initState
    if(manager.getAnyUserToken() == null) _selectedIndex = 4;
    if(!supportsAlarms) _selectedIndex -= 1;
  }

  ScreenSelectorState({required this.manager});

  void _tap(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    manager.startAnyWS();
    manager.reloadAllMethod = () {
      setState(() {});
    };
    final screens = <Widget>[
      if(supportsAlarms) HomeScreen(manager: manager),
      ShockerScreen(manager: manager),
      GroupedShockerScreen(manager: manager),
      ShareLinksScreen(),
      TokenScreen(manager: manager),
    ];
    final floatingActionButtons = <Widget?>[
      if(supportsAlarms) FloatingActionButton(onPressed: () {
        TimeOfDay tod = TimeOfDay.fromDateTime(DateTime.now());
        print("alarms: ${manager.getAlarms().length}");
        final newAlarm = new Alarm(
            id: manager.getNewAlarmId(),
            name: 'New Alarm',
            hour: tod.hour,
            minute: tod.minute,
            active: false);
        setState(() {
          manager.saveAlarm(newAlarm);
        });
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Alarm added'),
          duration: Duration(seconds: 3),
        ));
      }, child: Icon(Icons.add)),
      ShockerScreen.getFloatingActionButton(manager, context, () {
        setState(() {});
      }),
      ShockerScreen.getFloatingActionButton(manager, context, () {
        setState(() {});
      }),
      ShareLinksScreen.getFloatingActionButton(manager, context, () {
        setState(() {});
      }),
      null,
    ];
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.only(
          bottom: 15,
          left: 15,
          right: 15,
          top: 50,
        ),
        child: screens.elementAt(_selectedIndex),
      ),
      appBar: null,
      floatingActionButton: floatingActionButtons.elementAt(_selectedIndex),
      bottomNavigationBar: BottomNavigationBar(items: 
         [
          if(supportsAlarms) BottomNavigationBarItem(icon: Icon(Icons.alarm), label: 'Alarms'),
          BottomNavigationBarItem(icon: OpenShockClient.getIconForControlType(ControlType.shock), label: 'Devices'),
          BottomNavigationBarItem(icon: Icon(Icons.group), label: 'Grouped'),
          BottomNavigationBarItem(icon: Icon(Icons.link), label: 'Share Links'),
          BottomNavigationBarItem(icon: Icon(Icons.settings), label: 'Settings'),
        ],
        type: BottomNavigationBarType.fixed,
        currentIndex: _selectedIndex,
        onTap: _tap,
    ));
  }
}

class HomeScreen extends StatefulWidget {
  final AlarmListManager manager;

  const HomeScreen({Key? key, required this.manager}) : super(key: key);

  @override
  State<StatefulWidget> createState() => HomeScreenState(manager);
}

class HomeScreenState extends State<HomeScreen> {
  final AlarmListManager manager;
  
  HomeScreenState(this.manager);

  void rebuild() {
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    manager.context = context;
    ThemeData t = Theme.of(context);
    return Column(
        children: <Widget>[
          Text(
            'Your alarms',
            style: t.textTheme.headlineMedium,
          ),
          Text("Alarms are currently semi working",
          style: t.textTheme.headlineSmall),
          TextButton(onPressed: () {
            Navigator.of(context).push(MaterialPageRoute(builder: (context) => AlarmToneScreen(manager)));
          }, child: Text("Edit Tones")),
          Flexible(
            child: ListView.builder(
              shrinkWrap: true,
              itemBuilder: (context, index) {
                final alarm = manager.getAlarms()[index];

                return AlarmItem(alarm: alarm, manager: manager, onRebuild: rebuild, key: ValueKey(alarm.id));
              },
              itemCount: manager.getAlarms().length,
            ),
          )
        ],
      );
  }
}
