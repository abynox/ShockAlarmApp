import 'package:flutter/material.dart';
import 'package:shock_alarm_app/components/constrained_container.dart';
import 'package:shock_alarm_app/components/desktop_mobile_refresh_indicator.dart';
import 'package:shock_alarm_app/stores/alarm_store.dart';

import 'alarm_item.dart';
import '../../services/alarm_list_manager.dart';
import '../tones/tones.dart';

class AlarmsScreen extends StatefulWidget {
  final AlarmListManager manager;

  const AlarmsScreen({Key? key, required this.manager}) : super(key: key);

  @override
  State<StatefulWidget> createState() => _AlarmsScreenState(manager);
}

class _AlarmsScreenState extends State<AlarmsScreen> {
  final AlarmListManager manager;

  _AlarmsScreenState(this.manager);

  @override
  void initState() {
    manager.reloadAllMethod = rebuild;
    manager.addAlarmServerAlarms();
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
          alarm: x,
          manager: manager,
          onRebuild: rebuild,
          key: ValueKey(x.getId()));
    }).toList();

    return ConstrainedContainer(
        child: ListView(
      children: [
        Text(
          'Your alarms',
          style: t.textTheme.headlineMedium,
          textAlign: TextAlign.center,
        ),
        /*
        Text(
          "Alarms are currently semi working",
          style: t.textTheme.headlineSmall,
          textAlign: TextAlign.center,
        ),
        */
        Center(
          child: FilledButton(
              onPressed: () {
                Navigator.of(context).push(MaterialPageRoute(
                    builder: (context) => AlarmToneScreen(manager)));
              },
              child: Text("Edit Tones")),
        ),
        if (manager.settings.useAlarmServer)
          DesktopMobileRefreshIndicator(
              onRefresh: () async {
                await manager.addAlarmServerAlarms();
                setState(() {});
              },
              child: Column(
                children: alarms,
              )),
        if (!manager.settings.useAlarmServer) ...alarms,
      ],
    ));
  }
}
