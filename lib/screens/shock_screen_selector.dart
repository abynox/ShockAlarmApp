import 'package:flutter/material.dart';
import 'package:shock_alarm_app/screens/grouped_shockers.dart';
import 'package:shock_alarm_app/screens/shockers.dart';

import '../services/alarm_list_manager.dart';

class ShockScreenSelector extends StatefulWidget{
  final AlarmListManager manager;

  const ShockScreenSelector({Key? key, required this.manager}) : super(key: key);

  @override
  State<StatefulWidget> createState() => ShockScreenSelectorState();
}

class ShockScreenSelectorState extends State<ShockScreenSelector> {

  @override
  Widget build(BuildContext context) {
    return widget.manager.settings.useGroupedShockerSelection ? GroupedShockerScreen(manager: widget.manager) : ShockerScreen(manager: widget.manager);
  }
}