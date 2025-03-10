
import 'package:flutter/material.dart';
import 'package:shock_alarm_app/components/desktop_mobile_refresh_indicator.dart';
import 'package:shock_alarm_app/stores/alarm_store.dart';

import '../components/alarm_item.dart';
import '../services/alarm_list_manager.dart';
import 'tones.dart';

class AlarmScreen extends StatefulWidget {
  final AlarmListManager manager;

  const AlarmScreen({Key? key, required this.manager}) : super(key: key);

  @override
  State<StatefulWidget> createState() => AlarmScreenState(manager);
}

class AlarmScreenState extends State<AlarmScreen> {
  final AlarmListManager manager;

  AlarmScreenState(this.manager);

  @override
  void initState() {
    manager.reloadAllMethod = rebuild;
    super.initState();
  }

  void rebuild() {
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    manager.context = context;
    ThemeData t = Theme.of(context);
    List<Widget> alarms = manager.getAlarms().map((x) {
      return AlarmItem(
          alarm: x, manager: manager, onRebuild: rebuild, key: ValueKey(x.getId()));
    }).toList();

    return ListView(
      children: [
        Text(
          'Your alarms',
          style: t.textTheme.headlineMedium,
          textAlign: TextAlign.center,
        ),
        Text(
          "Alarms are currently semi working",
          style: t.textTheme.headlineSmall,
          textAlign: TextAlign.center,
        ),
        Center(
          child: FilledButton(
              onPressed: () {
                Navigator.of(context).push(MaterialPageRoute(
                    builder: (context) => AlarmToneScreen(manager)));
              },
              child: Text("Edit Tones")),
        ),
        if(manager.settings.useAlarmServer)
          DesktopMobileRefreshIndicator(onRefresh: () async {
            await manager.addAlarmServerAlarms();
            setState(() {
              
            });
          }, child: Column(children: alarms,)),
        if(!manager.settings.useAlarmServer)
          ...alarms,
      ],
    );
  }
}