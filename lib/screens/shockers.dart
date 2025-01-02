import 'package:flutter/material.dart';
import 'package:shock_alarm_app/services/alarm_list_manager.dart';
import 'package:shock_alarm_app/services/openshock.dart';
import 'package:shock_alarm_app/stores/alarm_store.dart';
import '../components/bottom_add_button.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import '../components/shocker_item.dart';

class ShockerScreen extends StatefulWidget {
  final AlarmListManager manager;

  const ShockerScreen({Key? key, required this.manager}) : super(key: key);

  @override
  State<StatefulWidget> createState() => ShockerScreenState(manager);
}

class ShockerScreenState extends State<ShockerScreen> {
  final AlarmListManager manager;

  void rebuild() {
    setState(() {});
  }

  ShockerScreenState(this.manager);
  @override
  Widget build(BuildContext context) {
    List<Shocker> shockers = manager.shockers.where((shocker) => manager.enabledHubs[shocker.hub]!).toList();
    return Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          Text(
            'All Shockers',
            style: TextStyle(fontSize: 28, color: Theme.of(context).textTheme.headlineMedium?.color),
          ),
          Wrap(spacing: 5,runAlignment: WrapAlignment.start,children: manager.enabledHubs.keys.map<FilterChip>((hub) {
            return FilterChip(label: Text(hub), onSelected: (bool value) {setState(() {
              manager.enabledHubs[hub] = value;
            });}, selected: manager.enabledHubs[hub]!);
          }).toList(),),
          Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children:
            shockers.isEmpty ? [Text('No shockers found', style: TextStyle(fontSize: 24))] :
            shockers.map((shocker) {
              return ShockerItem(shocker: shocker, manager: manager, onRebuild: rebuild);
            }).toList()
          )
        ],
      );
  }
}