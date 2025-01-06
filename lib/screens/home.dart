import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:shock_alarm_app/screens/shockers.dart';
import 'package:shock_alarm_app/services/openshock.dart';
import '../components/alarm_item.dart';
import '../components/bottom_add_button.dart';
import '../services/alarm_list_manager.dart';
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
  int _selectedIndex = 0;

  ScreenSelectorState({required this.manager});

  void _tap(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    manager.reloadAllMethod = () {
      setState(() {});
    };
    final screens = <Widget>[
      HomeScreen(manager: manager),
      ShockerScreen(manager: manager),
      TokenScreen(manager: manager)
    ];
    final floatingActionButtons = <Widget?>[
      FloatingActionButton(onPressed: () {
        TimeOfDay tod = TimeOfDay.fromDateTime(DateTime.now());
        print("alarms: ${manager.getAlarms().length}");
        final newAlarm = new ObservableAlarmBase(
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
      null
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
          BottomNavigationBarItem(icon: Icon(Icons.alarm), label: 'Alarms'),
          BottomNavigationBarItem(icon: OpenShockClient.getIconForControlType(ControlType.shock), label: 'Shockers'),
          BottomNavigationBarItem(icon: Icon(Icons.settings), label: 'Settings'),
        ],
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
