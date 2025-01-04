import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:shock_alarm_app/screens/shockers.dart';
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
      bottomNavigationBar: BottomNavigationBar(items: 
        const <BottomNavigationBarItem>[
          BottomNavigationBarItem(icon: Icon(Icons.alarm), label: 'Alarms'),
          BottomNavigationBarItem(icon: Icon(Icons.sports_hockey), label: 'Shockers'),
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
    return Column(
        children: <Widget>[
          Text(
            'Your alarms',
            style: TextStyle(fontSize: 28, color: Theme.of(context).textTheme.headlineMedium?.color),
          ),
          Text("Alarms are currently semi working",
          style: TextStyle(fontSize: 20),),
          Flexible(
            child: ListView.builder(
              shrinkWrap: true,
              itemBuilder: (context, index) {
                final alarm = manager.getAlarms()[index];

                return AlarmItem(alarm: alarm, manager: manager, onRebuild: rebuild, key: ValueKey(alarm.id));
              },
              itemCount: manager.getAlarms().length,
            ),
          ),
          BottomAddButton(
            onPressed: () {
              TimeOfDay tod = TimeOfDay.fromDateTime(DateTime.now());
              final newAlarm = new ObservableAlarmBase(
                  id: manager.getNewAlarmId(),
                  name: 'New Alarm',
                  hour: tod.hour,
                  minute: tod.minute,
                  active: false);
              setState(() {
                manager.saveAlarm(newAlarm);
              });
            },
          )
        ],
      );
  }
}
